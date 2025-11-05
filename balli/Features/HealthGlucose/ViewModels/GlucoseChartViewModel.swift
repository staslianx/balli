//
//  GlucoseChartViewModel.swift
//  balli
//
//  Manages glucose data loading from Dexcom and HealthKit
//

import Foundation
import SwiftUI
import HealthKit
import CoreData
import OSLog
import Combine

@MainActor
final class GlucoseChartViewModel: ObservableObject {
    // MARK: - Published State

    @Published var glucoseData: [GlucoseDataPoint] = []
    @Published var mealLogs: [MealEntry] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var dataSource: String? // "Dexcom", "SHARE", "Hybrid", or "HealthKit"
    @Published var isRealTimeModeEnabled: Bool = false

    // MARK: - Dependencies

    private let healthKitService: HealthKitServiceProtocol
    private let dexcomService: DexcomService
    private let dexcomShareService: DexcomShareService
    private let healthKitPermissions: HealthKitPermissionManager
    private let viewContext: NSManagedObjectContext?
    private let glucoseRepository: GlucoseReadingRepository
    private let logger = AppLoggers.Health.glucose

    // Hybrid data source (combines Official + SHARE)
    private var hybridDataSource: HybridGlucoseDataSource?

    // MARK: - Debouncing

    private var loadTask: Task<Void, Never>?
    private var lastLoadTime: Date?
    private let minimumLoadInterval: TimeInterval = 60 // Don't reload more than once per 60 seconds

    // MARK: - Combine Subscriptions

    /// Combine cancellables for automatic cleanup (replaces NotificationCenter observers)
    /// MEMORY LEAK FIX: Combine automatically cleans up subscriptions when cancellables are released
    private var cancellables = Set<AnyCancellable>()
    private var lastRefreshTime: Date?

    // MARK: - Initialization

    init(
        healthKitService: HealthKitServiceProtocol,
        dexcomService: DexcomService,
        dexcomShareService: DexcomShareService,
        healthKitPermissions: HealthKitPermissionManager,
        viewContext: NSManagedObjectContext? = nil,
        glucoseRepository: GlucoseReadingRepository = GlucoseReadingRepository()
    ) {
        self.healthKitService = healthKitService
        self.dexcomService = dexcomService
        self.dexcomShareService = dexcomShareService
        self.healthKitPermissions = healthKitPermissions
        self.viewContext = viewContext
        self.glucoseRepository = glucoseRepository

        // Initialize hybrid data source if both services available
        self.hybridDataSource = HybridGlucoseDataSource(
            officialService: dexcomService,
            shareService: dexcomShareService
        )

        // Load Real-Time Mode preference
        self.isRealTimeModeEnabled = UserDefaults.standard.bool(forKey: "isRealTimeModeEnabled")

        // Set up Combine subscriptions for automatic updates
        setupSubscriptions()
    }

    // Note: deinit removed - Combine automatically cancels subscriptions when cancellables set is deallocated

    // MARK: - Combine Subscriptions Setup

    /// MEMORY LEAK FIX: Use Combine instead of NotificationCenter observers
    /// Combine automatically cancels subscriptions when cancellables are released (no manual cleanup needed)
    private func setupSubscriptions() {
        // Subscribe to scene becoming active (app returns to foreground)
        NotificationCenter.default.publisher(for: .sceneDidBecomeActive)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }

                Task { @MainActor in
                    // DEBOUNCE: Don't refresh if we just refreshed
                    if let lastRefresh = self.lastRefreshTime,
                       Date().timeIntervalSince(lastRefresh) < 2.0 {
                        self.logger.debug("Skipping scene refresh - too soon (last refresh \(Date().timeIntervalSince(lastRefresh))s ago)")
                        return
                    }

                    self.logger.info("Scene became active - refreshing glucose chart")
                    self.lastRefreshTime = Date()
                    await self.refreshData()
                }
            }
            .store(in: &cancellables)

        // Subscribe to Core Data changes (meal entries added/updated/deleted)
        if let context = viewContext {
            NotificationCenter.default.publisher(for: .NSManagedObjectContextObjectsDidChange, object: context)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] notification in
                    guard let self = self else { return }

                    // Extract data from notification
                    let inserted = (notification.userInfo?[NSInsertedObjectsKey] as? Set<NSManagedObject>) ?? []
                    let updated = (notification.userInfo?[NSUpdatedObjectsKey] as? Set<NSManagedObject>) ?? []
                    let deleted = (notification.userInfo?[NSDeletedObjectsKey] as? Set<NSManagedObject>) ?? []

                    let hasMealChanges = inserted.contains { $0 is MealEntry } ||
                                        updated.contains { $0 is MealEntry } ||
                                        deleted.contains { $0 is MealEntry }

                    // Handle meal changes asynchronously
                    if hasMealChanges {
                        Task { @MainActor in
                            self.logger.info("Meal entry changed (inserted/updated/deleted) - refreshing meal logs")
                            if let timeRange = self.calculateTimeRange() {
                                self.loadMealLogs(timeRange: timeRange)
                            }
                        }
                    }
                }
                .store(in: &cancellables)
        }

        // Subscribe to custom data refresh notifications from Dexcom services
        NotificationCenter.default.publisher(for: .glucoseDataDidUpdate)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }

                Task { @MainActor in
                    self.logger.info("Glucose data updated - loading with debounce protection")
                    self.loadGlucoseData()  // Use loadGlucoseData (with debounce) instead of refreshData (bypasses debounce)
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Public Methods

    /// Refresh data immediately, bypassing debounce
    /// Used when app comes to foreground or data is explicitly updated
    func refreshData() async {
        logger.info("🔄 Explicit refresh requested - bypassing debounce")
        lastLoadTime = nil // Reset debounce timer
        loadGlucoseData()

        // Small delay to ensure loadGlucoseData task starts
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
    }

    /// Load glucose data from Dexcom (priority) or HealthKit (fallback)
    /// Includes debouncing to prevent excessive reloads
    func loadGlucoseData() {
        // Cancel any existing load task
        loadTask?.cancel()

        // PERFORMANCE: Debounce rapid successive calls
        // Don't reload if we loaded recently and already have data
        if let lastLoad = lastLoadTime,
           Date().timeIntervalSince(lastLoad) < minimumLoadInterval,
           !glucoseData.isEmpty {
            logger.debug("⚡️ Skipping reload - data was loaded \(Int(Date().timeIntervalSince(lastLoad)))s ago")
            return
        }

        // Create new load task
        loadTask = Task {
            // Only show loading if we don't have data already
            if glucoseData.isEmpty {
                isLoading = true
            }
            errorMessage = nil
            dataSource = nil
            lastLoadTime = Date()

            // Calculate last 6 hours time range
            guard let timeRange = calculateTimeRange() else {
                errorMessage = "Tarih hesaplama hatası"
                isLoading = false
                return
            }

            logger.debug("Time range: \(timeRange.start) to \(timeRange.end) (last 6 hours)")
            logger.debug("Current time: \(Date())")

            // Debug: Log data source decision
            logger.info("🔍 Data source decision:")
            logger.info("  - Real-Time Mode enabled: \(self.isRealTimeModeEnabled)")
            logger.info("  - Hybrid source available: \(self.hybridDataSource != nil)")
            logger.info("  - Dexcom Official connected: \(self.dexcomService.isConnected)")
            logger.info("  - Dexcom SHARE connected: \(self.dexcomShareService.isConnected)")

            // Debug: Log current state before data loading
            logger.debug("Current glucoseData count: \(self.glucoseData.count)")
            logger.debug("Time range being queried: \(timeRange.start) to \(timeRange.end)")

            // ALWAYS load CoreData first as baseline (fast, offline-capable)
            await loadFromCoreData(timeRange: timeRange)
            logger.info("Loaded \(self.glucoseData.count) readings from CoreData")

            // Try to refresh with real-time data if available
            // IMPORTANT: SHARE (0-3h) and Official API (3h+) are COMPLEMENTARY, not fallbacks
            // - SHARE API: Real-time data (now to -3 hours)
            // - Official API: Historical data (-3 hours to backwards)
            // - Hybrid mode: Intelligently combines both for complete timeline
            //
            // CRITICAL FIX: Always use Hybrid mode when BOTH services are connected,
            // regardless of Real-Time Mode setting, because they cover different time ranges!
            if hybridDataSource != nil && dexcomService.isConnected && dexcomShareService.isConnected {
                logger.info("✅ Refreshing with Hybrid mode (both services connected)")
                logger.info("  - SHARE API: Recent data (0-3h)")
                logger.info("  - Official API: Historical data (3h+)")
                await loadFromHybridSource(timeRange: timeRange, mergeWithExisting: true)
            } else if dexcomShareService.isConnected {
                logger.info("✅ Refreshing with SHARE API only (recent data 0-3h)")
                logger.info("  ⚠️ Historical data beyond 3h will not be fetched")
                await loadFromDexcomShare(timeRange: timeRange, mergeWithExisting: true)
            } else if dexcomService.isConnected {
                logger.info("✅ Refreshing with Official Dexcom API only (historical data 3h+)")
                logger.info("  ⚠️ Recent data (0-3h) will not be available due to EU 3h delay")
                await loadFromDexcom(timeRange: timeRange)
            } else {
                logger.info("No Dexcom sources available, trying HealthKit")
                await loadFromHealthKit(timeRange: timeRange)
            }

            // Load meal logs for the time range
            loadMealLogs(timeRange: timeRange)

            logger.info("Final glucose data count: \(self.glucoseData.count)")
            isLoading = false
        }
    }

    /// Load meal logs from Core Data for the given time range
    private func loadMealLogs(timeRange: (start: Date, end: Date)) {
        guard let context = viewContext else {
            logger.debug("No view context available for loading meal logs")
            return
        }

        do {
            let fetchRequest = MealEntry.mealsInRange(from: timeRange.start, to: timeRange.end)
            let meals = try context.fetch(fetchRequest)

            self.mealLogs = meals
            logger.info("Loaded \(meals.count) meal logs for time range")
        } catch {
            logger.error("Failed to fetch meal logs: \(error.localizedDescription)")
            self.mealLogs = []
        }
    }

    /// Calculate chart time range (last 6 hours)
    func calculateTimeRange() -> (start: Date, end: Date)? {
        let now = Date()
        let calendar = Calendar.current

        guard let startTime = calendar.date(byAdding: .hour, value: -6, to: now) else {
            return nil
        }

        return (startTime, now)
    }

    /// Calculate average glucose value from current data
    func calculateAverage() -> Double {
        guard !glucoseData.isEmpty else { return 0 }
        return glucoseData.map { $0.value }.reduce(0, +) / Double(glucoseData.count)
    }

    /// Toggle Real-Time Mode on/off
    func toggleRealTimeMode(_ enabled: Bool) {
        isRealTimeModeEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "isRealTimeModeEnabled")
        logger.info("Real-Time Mode \(enabled ? "enabled" : "disabled")")

        // Reload data with new setting
        loadGlucoseData()
    }

    // MARK: - Gap Detection

    /// Maximum time between readings before considering it a gap (15 minutes)
    private static let gapThresholdMinutes: Double = 15

    /// Mark gaps in glucose data where readings are >15 minutes apart
    /// - Parameter readings: Array of glucose readings sorted by time
    /// - Returns: Same readings with hasGapBefore flags set
    private func markGaps(_ readings: [GlucoseDataPoint]) -> [GlucoseDataPoint] {
        guard readings.count > 1 else { return readings }

        var markedReadings = readings

        // Use readings.count for loop bounds to ensure consistency
        for i in 1..<readings.count {
            let previousTime = markedReadings[i - 1].time
            let currentTime = markedReadings[i].time
            let minutesDifference = currentTime.timeIntervalSince(previousTime) / 60.0

            if minutesDifference > Self.gapThresholdMinutes {
                markedReadings[i].hasGapBefore = true
                logger.debug("Gap detected: \(String(format: "%.1f", minutesDifference)) minutes between \(previousTime) and \(currentTime)")
            }
        }

        let gapCount = markedReadings.filter { $0.hasGapBefore }.count
        if gapCount > 0 {
            logger.info("Marked \(gapCount) gaps in glucose data")
        }

        return markedReadings
    }

    // MARK: - Private Methods

    /// Load glucose readings from CoreData (persisted from previous Dexcom syncs)
    private func loadFromCoreData(timeRange: (start: Date, end: Date)) async {
        do {
            let readings = try await glucoseRepository.fetchReadings(
                startDate: timeRange.start,
                endDate: timeRange.end
            )

            logger.info("📦 Fetched \(readings.count) readings from CoreData")

            // Convert readings to chart data points
            // Note: readings are now HealthGlucoseReading value types (safe across threads)
            let points = readings
                .map { reading in
                    GlucoseDataPoint(time: reading.timestamp, value: reading.value)
                }
                .sorted { $0.time < $1.time }

            // Mark gaps in data
            glucoseData = markGaps(points)

            if !self.glucoseData.isEmpty {
                dataSource = "CoreData (Persisted)"
                logger.info("Loaded \(self.glucoseData.count) readings from CoreData")
                if let first = self.glucoseData.first, let last = self.glucoseData.last {
                    logger.debug("First: \(first.value) mg/dL at \(first.time)")
                    logger.debug("Last: \(last.value) mg/dL at \(last.time)")
                }
            }
        } catch {
            logger.error("Failed to load from CoreData: \(error.localizedDescription)")
        }
    }

    /// Load from Dexcom SHARE API and optionally merge with existing data
    private func loadFromDexcomShare(timeRange: (start: Date, end: Date), mergeWithExisting: Bool = false) async {
        do {
            // Fetch historical readings for the time range from SHARE API
            logger.info("📡 Fetching SHARE readings from \(timeRange.start) to \(timeRange.end)")

            let shareReadings = try await dexcomShareService.fetchGlucoseReadings(
                startDate: timeRange.start,
                endDate: timeRange.end
            )

            logger.info("📡 Fetched \(shareReadings.count) SHARE readings")

            // Convert SHARE readings to data points
            let newPoints = shareReadings.map { reading in
                GlucoseDataPoint(time: reading.displayTime, value: Double(reading.Value))
            }

            if mergeWithExisting {
                // Merge with existing CoreData readings
                var mergedData = glucoseData
                for newPoint in newPoints {
                    // Only add if not already present (within 60 second window)
                    if !mergedData.contains(where: { abs($0.time.timeIntervalSince(newPoint.time)) < 60 }) {
                        mergedData.append(newPoint)
                    }
                }
                let sortedData = mergedData.sorted { $0.time < $1.time }
                glucoseData = markGaps(sortedData)
                dataSource = "CoreData + SHARE"
                logger.info("Merged \(newPoints.count) SHARE readings with CoreData")
            } else {
                // Replace all data with SHARE readings
                let sortedData = newPoints.sorted { $0.time < $1.time }
                glucoseData = markGaps(sortedData)
                dataSource = "SHARE"
            }

            if !glucoseData.isEmpty {
                logger.info("Successfully loaded \(self.glucoseData.count) total readings")
                if let first = self.glucoseData.first, let last = self.glucoseData.last {
                    logger.debug("First: \(first.value) mg/dL at \(first.time)")
                    logger.debug("Last: \(last.value) mg/dL at \(last.time)")
                }
            }
        } catch {
            logger.error("Failed to load from SHARE: \(error.localizedDescription)")
        }
    }

    private func loadFromHybridSource(timeRange: (start: Date, end: Date), mergeWithExisting: Bool = false) async {
        logger.info("🔄 Using Hybrid mode (Official + SHARE)")

        guard let hybrid = hybridDataSource else {
            logger.error("Hybrid data source not initialized")
            return
        }

        do {
            // Fetch from hybrid source (handles time-based splitting automatically)
            let healthReadings = try await hybrid.fetchReadings(
                startDate: timeRange.start,
                endDate: timeRange.end
            )

            logger.info("Fetched \(healthReadings.count) readings from Hybrid source")

            // Convert HealthGlucoseReading to GlucoseDataPoint
            let newPoints = healthReadings.map { reading in
                GlucoseDataPoint(time: reading.timestamp, value: reading.value)
            }

            if mergeWithExisting {
                // Merge with existing CoreData readings
                var mergedData = glucoseData
                for newPoint in newPoints {
                    // Only add if not already present (within 60 second window)
                    if !mergedData.contains(where: { abs($0.time.timeIntervalSince(newPoint.time)) < 60 }) {
                        mergedData.append(newPoint)
                    }
                }
                let sortedData = mergedData.sorted { $0.time < $1.time }
                glucoseData = markGaps(sortedData)
                dataSource = "CoreData + Hybrid"
                logger.info("Merged \(newPoints.count) hybrid readings with \(self.glucoseData.count - newPoints.count) existing")
            } else {
                // Replace all data
                let sortedData = newPoints.sorted { $0.time < $1.time }
                glucoseData = markGaps(sortedData)
                dataSource = "Hybrid (Official + SHARE)"
            }

            if !glucoseData.isEmpty {
                logger.info("Successfully processed \(self.glucoseData.count) readings")
                if let first = glucoseData.first, let last = glucoseData.last {
                    logger.debug("First reading: \(first.value) mg/dL at \(first.time)")
                    logger.debug("Last reading: \(last.value) mg/dL at \(last.time)")
                }
            } else {
                logger.notice("Hybrid source returned no readings for this time range")
            }
        } catch {
            // Hybrid failed, will try HealthKit
            logger.error("Hybrid data fetch failed: \(error.localizedDescription)")
            logger.info("Falling back to HealthKit")
        }
    }

    private func loadFromDexcom(timeRange: (start: Date, end: Date)) async {
        logger.debug("Dexcom is connected, fetching data")

        do {
            // Use DexcomConfiguration helper to account for EU 3-hour data delay
            let dexcomEndDate = DexcomConfiguration.mostRecentAvailableDate()
            let dexcomStartDate = Calendar.current.date(byAdding: .day, value: -1, to: dexcomEndDate) ?? dexcomEndDate

            logger.debug("Adjusted time range for Dexcom \(DexcomConfiguration.euDataDelayHours)h EU delay: \(dexcomStartDate) to \(dexcomEndDate)")

            // Fetch Dexcom data (returns [HealthGlucoseReading])
            let healthReadings = try await dexcomService.fetchGlucoseReadings(
                startDate: dexcomStartDate,
                endDate: dexcomEndDate
            )

            logger.info("Fetched \(healthReadings.count) Dexcom readings")

            // Convert HealthGlucoseReading to GlucoseDataPoint and sort by time
            let points = healthReadings
                .map { reading in
                    GlucoseDataPoint(time: reading.timestamp, value: reading.value)
                }
                .sorted { $0.time < $1.time } // Sort chronologically for chart display

            // Mark gaps in data
            glucoseData = markGaps(points)

            if !glucoseData.isEmpty {
                logger.info("Successfully converted \(self.glucoseData.count) readings to chart data")
                if let first = glucoseData.first, let last = glucoseData.last {
                    logger.debug("First reading: \(first.value) mg/dL at \(first.time)")
                    logger.debug("Last reading: \(last.value) mg/dL at \(last.time)")
                }
                dataSource = "Dexcom"
            } else {
                logger.notice("Dexcom returned no readings for this time range")
            }
        } catch {
            // Dexcom failed, will try HealthKit
            logger.error("Dexcom data fetch failed: \(error.localizedDescription)")
            if let dexcomError = error as? DexcomError {
                logger.error("Dexcom error details: \(String(describing: dexcomError))")
            }
            logger.info("Falling back to HealthKit")
        }
    }

    private func loadFromHealthKit(timeRange: (start: Date, end: Date)) async {
        do {
            // Simplified permission check using new helper method
            guard await healthKitPermissions.hasGlucoseDataAccess() else {
                errorMessage = healthKitPermissions.getErrorMessage(for: .glucoseDataRequired)
                glucoseData = []
                return
            }

            // Fetch data (actor handles reentrancy/debouncing internally)
            let readings = try await healthKitService.getGlucoseReadings(
                from: timeRange.start,
                to: timeRange.end,
                limit: 50
            )

            // Convert to chart data points and sort by time with safety checks
            let points = readings
                .compactMap { reading -> GlucoseDataPoint? in
                    // Validate reading has valid data
                    guard reading.value > 0 else {
                        logger.warning("⚠️ Skipping invalid HealthKit reading with value: \(reading.value)")
                        return nil
                    }
                    return GlucoseDataPoint(time: reading.timestamp, value: reading.value)
                }
                .sorted { $0.time < $1.time } // Sort chronologically for chart display

            // Mark gaps in data
            glucoseData = markGaps(points)

            if !glucoseData.isEmpty {
                dataSource = "HealthKit"
            } else {
                errorMessage = "Son 6 saatte kan şekeri verisi bulunamadı"
            }
        } catch let error as HealthKitError {
            // Handle actor-level debouncing/reentrancy gracefully
            switch error {
            case .alreadyLoading, .debounced:
                // Silently ignore - actor is handling state management
                break
            default:
                errorMessage = error.localizedDescription
                glucoseData = []
            }
        } catch {
            // Map generic errors to user-friendly messages
            if let urlError = error as? URLError {
                switch urlError.code {
                case .notConnectedToInternet:
                    errorMessage = "İnternet bağlantısı yok. Lütfen ağ bağlantınızı kontrol edin."
                case .timedOut:
                    errorMessage = "Bağlantı zaman aşımına uğradı. Lütfen tekrar deneyin."
                default:
                    errorMessage = "Ağ hatası. Lütfen internet bağlantınızı kontrol edin."
                }
            } else {
                errorMessage = "Kan şekeri verileri yüklenemedi. Lütfen tekrar deneyin."
            }
            glucoseData = []
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// Posted when new glucose data is fetched from Dexcom or HealthKit
    static let glucoseDataDidUpdate = Notification.Name("glucoseDataDidUpdate")
}
