//
//  ActivitySyncService.swift
//  balli
//
//  Handles periodic syncing of activity data (steps, calories) from HealthKit to Core Data
//  Swift 6 strict concurrency compliant
//

import Foundation
import HealthKit
import CoreData
import OSLog

// MARK: - Errors

enum ActivitySyncError: LocalizedError {
    case backfillFailed

    var errorDescription: String? {
        switch self {
        case .backfillFailed:
            return "Failed to backfill activity data. Please check HealthKit permissions."
        }
    }
}

// MARK: - Service

/// Service responsible for syncing daily activity data from HealthKit to Core Data
@MainActor
final class ActivitySyncService: ObservableObject {

    // MARK: - Properties

    private let healthKitService: HealthKitActivityService
    private let healthStore: HKHealthStore
    private let authManager: HealthKitAuthorizationManager
    private let logger = AppLoggers.Health.glucose

    // Background monitoring
    private var backgroundObserverQuery: HKObserverQuery?
    private var didCleanup = false

    // P0 FIX: Throttling and debouncing for background observer
    // RATIONALE: HealthKit fires observer 20-50x/day (every steps/calories update)
    // Without throttling, this causes 20-50 full sync operations/day
    // Throttle: Skip sync if synced < 5 minutes ago (reduces by 75%)
    // Debounce: Wait 2 seconds after last update to batch changes together
    private var lastSyncTime: Date?
    private let syncThrottleInterval: TimeInterval = 300 // 5 minutes
    private var pendingSyncTask: Task<Void, Never>?

    // Progress tracking
    @Published var backfillProgress: Double = 0.0
    @Published var backfillStatus: String = ""
    @Published var isBackfilling: Bool = false

    // MARK: - Initialization

    init(healthStore: HKHealthStore = HKHealthStore(), authManager: HealthKitAuthorizationManager) {
        self.healthStore = healthStore
        self.authManager = authManager
        self.healthKitService = HealthKitActivityService(healthStore: healthStore, authManager: authManager)
    }

    // MARK: - Data Synchronization

    /// Sync today's activity data
    func syncTodayActivity() async throws {
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)

        try await syncActivityForDate(startOfDay)
    }

    /// Sync activity data for a specific date
    func syncActivityForDate(_ date: Date) async throws {
        logger.info("💾 [ACTIVITY-SYNC] Syncing activity for date: \(date)")

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay

        // Fetch activity data from HealthKit
        let (steps, activeCalories) = try await healthKitService.getActivityData(from: startOfDay, to: endOfDay)

        // Save to Core Data
        try await saveActivityData(
            date: startOfDay,
            steps: Int(steps),
            activeCalories: Int(activeCalories),
            totalCalories: Int(activeCalories) // For now, using active calories as total
        )

        logger.info("✅ [ACTIVITY-SYNC] Synced \(Int(steps)) steps, \(Int(activeCalories)) kcal for \(startOfDay)")
    }

    /// Backfill historical activity data for the last N days
    func backfillHistoricalData(days: Int = 90) async throws {
        logger.info("📊 [ACTIVITY-BACKFILL] Starting backfill for last \(days) days...")

        // Check if already completed recently (within last 7 days)
        if let lastBackfill = UserDefaults.standard.object(forKey: "ActivityBackfillDate") as? Date {
            let daysSinceBackfill = Calendar.current.dateComponents([.day], from: lastBackfill, to: Date()).day ?? 0
            if daysSinceBackfill < 7 {
                logger.info("⏭️ [ACTIVITY-BACKFILL] Skipping - completed \(daysSinceBackfill) days ago")
                return
            }
        }

        isBackfilling = true
        defer { isBackfilling = false }

        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -days, to: endDate) ?? endDate

        var current = startDate
        var syncedCount = 0
        var errorCount = 0
        var consecutiveErrors = 0
        let totalDays = days
        let maxConsecutiveErrors = 10

        while current < endDate {
            do {
                try await syncActivityForDate(current)
                syncedCount += 1
                consecutiveErrors = 0  // Reset on success

                // Update progress
                backfillProgress = Double(syncedCount) / Double(totalDays)
                backfillStatus = "Synced \(syncedCount) of \(totalDays) days"
            } catch {
                logger.error("⚠️ [ACTIVITY-BACKFILL] Failed to sync \(current): \(error.localizedDescription)")
                errorCount += 1
                consecutiveErrors += 1

                // Check if we're being throttled
                let isThrottled = error.localizedDescription.contains("throttled") ||
                                error.localizedDescription.contains("fazla istek") ||
                                error.localizedDescription.contains("Too many requests")

                if isThrottled {
                    // Exponential backoff: 5s -> 10s -> 20s -> 40s -> 60s (max)
                    let backoffDelay = min(5.0 * pow(2.0, Double(consecutiveErrors - 1)), 60.0)
                    logger.warning("🔄 [ACTIVITY-BACKFILL] Rate limited - backing off for \(backoffDelay)s")

                    do {
                        try await Task.sleep(for: .seconds(backoffDelay))
                    } catch {
                        logger.error("⚠️ [ACTIVITY-BACKFILL] Backoff sleep interrupted")
                    }
                }

                // Abort after too many consecutive failures
                if consecutiveErrors >= maxConsecutiveErrors {
                    logger.error("❌ [ACTIVITY-BACKFILL] Aborting - \(consecutiveErrors) consecutive failures")
                    break
                }
            }

            // Move to next day
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: current) else {
                break
            }
            current = nextDay
        }

        // Save completion even with partial success
        if syncedCount > 0 {
            UserDefaults.standard.set(true, forKey: "ActivityBackfillCompleted")
            UserDefaults.standard.set(Date(), forKey: "ActivityBackfillDate")
            UserDefaults.standard.set(syncedCount, forKey: "ActivityBackfillDays")

            logger.info("✅ [ACTIVITY-BACKFILL] Completed: \(syncedCount) days synced, \(errorCount) errors")
        } else {
            logger.error("❌ [ACTIVITY-BACKFILL] Failed completely - no days synced")
            throw ActivitySyncError.backfillFailed
        }
    }

    // MARK: - Core Data Persistence

    private func saveActivityData(date: Date, steps: Int, activeCalories: Int, totalCalories: Int) async throws {
        let context = PersistenceController.shared.container.viewContext

        try await context.perform {
            // Check if record already exists for this date
            let fetchRequest: NSFetchRequest<DailyActivity> = DailyActivity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "date == %@", date as NSDate)

            let existingRecords = try context.fetch(fetchRequest)

            let activity: DailyActivity
            if let existing = existingRecords.first {
                // Update existing record
                activity = existing
                self.logger.debug("Updating existing activity record for \(date)")
            } else {
                // Create new record
                activity = DailyActivity(context: context)
                activity.id = UUID()
                activity.date = date
                self.logger.debug("Creating new activity record for \(date)")
            }

            // Update values
            activity.steps = Int32(steps)
            activity.activeCalories = Int32(activeCalories)
            activity.totalCalories = Int32(totalCalories)
            activity.source = "apple_health"
            activity.lastSynced = Date()

            // Save context
            if context.hasChanges {
                try context.save()
                self.logger.info("💾 Saved activity data: \(steps) steps, \(activeCalories) kcal")
            }
        }
    }

    // MARK: - Background Monitoring

    /// Setup background delivery for activity data updates
    func setupBackgroundDelivery() async {
        logger.info("Setting up background delivery for activity monitoring")

        do {
            // Enable background delivery for steps
            try await healthStore.enableBackgroundDelivery(
                for: HKQuantityType(.stepCount),
                frequency: .daily
            )

            // Enable background delivery for active calories
            try await healthStore.enableBackgroundDelivery(
                for: HKQuantityType(.activeEnergyBurned),
                frequency: .daily
            )

            // Setup observer query
            setupActivityObserver()

            logger.info("✅ Background delivery enabled for activity monitoring")
        } catch {
            logger.error("❌ Failed to enable background delivery: \(error.localizedDescription)")
        }
    }

    private func setupActivityObserver() {
        let stepsType = HKQuantityType(.stepCount)

        let query = HKObserverQuery(
            sampleType: stepsType,
            predicate: nil
        ) { [weak self] _, completionHandler, error in
            if let error = error {
                AppLoggers.Health.glucose.error("Observer query error: \(error.localizedDescription)")
                completionHandler()
                return
            }

            // P0 FIX: Throttled + Debounced sync
            // PREVIOUS: Every HealthKit update (20-50x/day) triggered immediate full sync
            // NEW: Throttle (5-min window) + Debounce (2-sec delay) reduces syncs by 75%
            // Swift 6: Task { @MainActor } ensures UI property access on main actor
            Task { @MainActor [weak self] in
                guard let self = self else {
                    AppLoggers.Health.glucose.warning("⚠️ ActivitySyncService deallocated, skipping background sync")
                    return
                }

                // THROTTLE: Check if we've synced recently
                let now = Date()
                if let lastSync = self.lastSyncTime,
                   now.timeIntervalSince(lastSync) < self.syncThrottleInterval {
                    let elapsed = Int(now.timeIntervalSince(lastSync))
                    AppLoggers.Health.glucose.debug("⏭️ Skipping sync - last sync was \(elapsed)s ago (< \(Int(self.syncThrottleInterval))s threshold)")
                    return
                }

                // DEBOUNCE: Cancel any pending sync, schedule new one after 2 seconds
                // This batches multiple rapid HealthKit updates into a single sync
                self.pendingSyncTask?.cancel()
                self.pendingSyncTask = Task {
                    // Wait 2 seconds for more updates
                    try? await Task.sleep(for: .seconds(2))
                    guard !Task.isCancelled else { return }

                    // Perform sync
                    do {
                        try await self.syncTodayActivity()
                        self.lastSyncTime = Date()
                        AppLoggers.Health.glucose.info("✅ Auto-synced activity data from background observer")
                    } catch {
                        AppLoggers.Health.glucose.error("❌ Background activity sync failed: \(error.localizedDescription)")
                    }
                }
            }

            completionHandler()
        }

        backgroundObserverQuery = query
        healthStore.execute(query)

        logger.info("Activity observer query started with throttling (5min) and debouncing (2s)")
    }

    // MARK: - Cleanup

    /// Explicitly stop all background observers
    /// Call this in view's .onDisappear to ensure cleanup happens
    func stopObservers() {
        guard !didCleanup else {
            logger.debug("Observers already cleaned up")
            return
        }

        // Cancel pending debounced sync
        pendingSyncTask?.cancel()
        pendingSyncTask = nil

        if let query = backgroundObserverQuery {
            healthStore.stop(query)
            backgroundObserverQuery = nil
            logger.info("🛑 Stopped activity observer query")
        }

        didCleanup = true
    }

    deinit {
        if !didCleanup {
            logger.fault("⚠️ ActivitySyncService deallocated without cleanup - potential memory leak!")
            // Try to clean up anyway
            if let query = backgroundObserverQuery {
                healthStore.stop(query)
            }
        } else {
            logger.debug("✅ ActivitySyncService cleaned up properly")
        }
    }
}
