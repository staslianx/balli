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
        let totalDays = days

        while current < endDate {
            do {
                try await syncActivityForDate(current)
                syncedCount += 1

                // Update progress
                backfillProgress = Double(syncedCount) / Double(totalDays)
                backfillStatus = "Synced \(syncedCount) of \(totalDays) days"
            } catch {
                logger.error("⚠️ [ACTIVITY-BACKFILL] Failed to sync \(current): \(error.localizedDescription)")
                errorCount += 1
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
        ) { @Sendable _, completionHandler, error in
            if let error = error {
                AppLoggers.Health.glucose.error("Observer query error: \(error.localizedDescription)")
                completionHandler()
                return
            }

            // Sync today's activity when new data arrives
            Task { @MainActor in
                do {
                    let healthStore = HKHealthStore()
                    let authManager = HealthKitAuthorizationManager(healthStore: healthStore)
                    let service = ActivitySyncService(healthStore: healthStore, authManager: authManager)
                    try await service.syncTodayActivity()
                    AppLoggers.Health.glucose.info("✅ Auto-synced activity data from background observer")
                } catch {
                    AppLoggers.Health.glucose.error("❌ Background activity sync failed: \(error.localizedDescription)")
                }
            }

            completionHandler()
        }

        backgroundObserverQuery = query
        healthStore.execute(query)

        logger.info("Activity observer query started")
    }

    // MARK: - Cleanup

    deinit {
        if let query = backgroundObserverQuery {
            healthStore.stop(query)
        }
    }
}
