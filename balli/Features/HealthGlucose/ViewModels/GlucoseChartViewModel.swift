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
    private let logger = AppLoggers.Health.glucose

    // Hybrid data source (combines Official + SHARE)
    private var hybridDataSource: HybridGlucoseDataSource?

    // MARK: - Debouncing

    private var loadTask: Task<Void, Never>?
    private var lastLoadTime: Date?
    private let minimumLoadInterval: TimeInterval = 30 // Don't reload more than once per 30 seconds

    // MARK: - Observers

    // nonisolated(unsafe) allows deinit to access these from any isolation context
    nonisolated(unsafe) private var scenePhaseObserver: NSObjectProtocol?
    nonisolated(unsafe) private var coreDataObserver: NSObjectProtocol?
    nonisolated(unsafe) private var dataRefreshObserver: NSObjectProtocol?

    // MARK: - Initialization

    init(
        healthKitService: HealthKitServiceProtocol,
        dexcomService: DexcomService,
        dexcomShareService: DexcomShareService,
        healthKitPermissions: HealthKitPermissionManager,
        viewContext: NSManagedObjectContext? = nil
    ) {
        self.healthKitService = healthKitService
        self.dexcomService = dexcomService
        self.dexcomShareService = dexcomShareService
        self.healthKitPermissions = healthKitPermissions
        self.viewContext = viewContext

        // Initialize hybrid data source if both services available
        self.hybridDataSource = HybridGlucoseDataSource(
            officialService: dexcomService,
            shareService: dexcomShareService
        )

        // Load Real-Time Mode preference
        self.isRealTimeModeEnabled = UserDefaults.standard.bool(forKey: "isRealTimeModeEnabled")

        // Set up observers for automatic updates
        setupObservers()
    }

    deinit {
        // Remove observers
        if let observer = scenePhaseObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = coreDataObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = dataRefreshObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Observers Setup

    private func setupObservers() {
        // Observe scene becoming active (app returns to foreground)
        scenePhaseObserver = NotificationCenter.default.addObserver(
            forName: .sceneDidBecomeActive,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.logger.info("Scene became active - refreshing glucose chart")
                await self?.refreshData()
            }
        }

        // Observe Core Data changes (meal entries added/updated)
        if let context = viewContext {
            coreDataObserver = NotificationCenter.default.addObserver(
                forName: .NSManagedObjectContextObjectsDidChange,
                object: context,
                queue: .main
            ) { [weak self] notification in
                // Extract data from notification synchronously on main queue
                let inserted = (notification.userInfo?[NSInsertedObjectsKey] as? Set<NSManagedObject>) ?? []
                let updated = (notification.userInfo?[NSUpdatedObjectsKey] as? Set<NSManagedObject>) ?? []

                let hasMealChanges = inserted.contains { $0 is MealEntry } ||
                                    updated.contains { $0 is MealEntry }

                // Then handle asynchronously
                if hasMealChanges {
                    Task { @MainActor [weak self] in
                        guard let self = self else { return }
                        self.logger.info("Meal entry changed - refreshing meal logs")
                        if let timeRange = self.calculateTimeRange() {
                            self.loadMealLogs(timeRange: timeRange)
                        }
                    }
                }
            }
        }

        // Observe custom data refresh notifications from Dexcom services
        dataRefreshObserver = NotificationCenter.default.addObserver(
            forName: .glucoseDataDidUpdate,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.logger.info("Glucose data updated - refreshing chart")
                await self?.refreshData()
            }
        }
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
            isLoading = true
            errorMessage = nil
            dataSource = nil
            lastLoadTime = Date()

            // Calculate 6am-6am time range (24 hours)
            guard let timeRange = calculateTimeRange() else {
                errorMessage = "Tarih hesaplama hatası"
                isLoading = false
                return
            }

            logger.debug("Time range: \(timeRange.start) to \(timeRange.end) (24 hours, 6am-6am)")
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

            // Try hybrid/Dexcom data source first
            if isRealTimeModeEnabled && hybridDataSource != nil {
                logger.info("✅ Using Hybrid mode")
                await loadFromHybridSource(timeRange: timeRange)
                if !glucoseData.isEmpty {
                    isLoading = false
                    return
                }
            } else if dexcomService.isConnected {
                logger.info("✅ Using Official Dexcom API")
                await loadFromDexcom(timeRange: timeRange)
                if !glucoseData.isEmpty {
                    isLoading = false
                    return
                }
            } else {
                logger.info("No Dexcom sources available, falling back to HealthKit")
            }

            // Fall back to HealthKit
            await loadFromHealthKit(timeRange: timeRange)

            // Load meal logs for the time range
            loadMealLogs(timeRange: timeRange)

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

    /// Calculate chart time range (6am to 6am, 24 hours)
    func calculateTimeRange() -> (start: Date, end: Date)? {
        let calendar = Calendar.current
        let now = Date()

        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = 6
        components.minute = 0
        components.second = 0

        guard let today6am = calendar.date(from: components) else {
            return nil
        }

        let startTime: Date
        if now < today6am {
            // Before 6am today, show yesterday 6am to today 6am
            startTime = calendar.date(byAdding: .day, value: -1, to: today6am) ?? today6am
        } else {
            // After 6am today, show today 6am to tomorrow 6am
            startTime = today6am
        }

        let endTime = calendar.date(byAdding: .day, value: 1, to: startTime) ?? startTime
        return (startTime, endTime)
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

    // MARK: - Private Methods

    private func loadFromHybridSource(timeRange: (start: Date, end: Date)) async {
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

            // Convert HealthGlucoseReading to GlucoseDataPoint and sort by time
            glucoseData = healthReadings
                .map { reading in
                    GlucoseDataPoint(time: reading.timestamp, value: reading.value)
                }
                .sorted { $0.time < $1.time } // Sort chronologically for chart display

            if !glucoseData.isEmpty {
                logger.info("Successfully converted \(self.glucoseData.count) readings to chart data")
                if let first = glucoseData.first, let last = glucoseData.last {
                    logger.debug("First reading: \(first.value) mg/dL at \(first.time)")
                    logger.debug("Last reading: \(last.value) mg/dL at \(last.time)")
                }

                // Debug: Log all readings to find the issue
                logger.debug("📊 ALL READINGS:")
                for (index, reading) in glucoseData.enumerated() {
                    logger.debug("  [\(index)] \(reading.value) mg/dL at \(reading.time)")
                }

                dataSource = "Hybrid (Official + SHARE)"
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
            glucoseData = healthReadings
                .map { reading in
                    GlucoseDataPoint(time: reading.timestamp, value: reading.value)
                }
                .sorted { $0.time < $1.time } // Sort chronologically for chart display

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

            // Convert to chart data points and sort by time
            glucoseData = readings
                .map { reading in
                    GlucoseDataPoint(time: reading.timestamp, value: reading.value)
                }
                .sorted { $0.time < $1.time } // Sort chronologically for chart display

            if !glucoseData.isEmpty {
                dataSource = "HealthKit"
            } else {
                errorMessage = "Son 24 saatte kan şekeri verisi bulunamadı"
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
