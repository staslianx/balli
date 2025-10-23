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
    @Published var dataSource: String? // "Dexcom" or "HealthKit"

    // MARK: - Dependencies

    private let healthKitService: HealthKitServiceProtocol
    private let dexcomService: DexcomService
    private let healthKitPermissions: HealthKitPermissionManager
    private let viewContext: NSManagedObjectContext?
    private let logger = AppLoggers.Health.glucose

    // MARK: - Debouncing

    private var loadTask: Task<Void, Never>?
    private var lastLoadTime: Date?
    private let minimumLoadInterval: TimeInterval = 30 // Don't reload more than once per 30 seconds

    // MARK: - Initialization

    init(
        healthKitService: HealthKitServiceProtocol,
        dexcomService: DexcomService,
        healthKitPermissions: HealthKitPermissionManager,
        viewContext: NSManagedObjectContext? = nil
    ) {
        self.healthKitService = healthKitService
        self.dexcomService = dexcomService
        self.healthKitPermissions = healthKitPermissions
        self.viewContext = viewContext
    }

    // MARK: - Public Methods

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

            // Try Dexcom first if connected
            if dexcomService.isConnected {
                await loadFromDexcom(timeRange: timeRange)
                if !glucoseData.isEmpty {
                    isLoading = false
                    return
                }
            } else {
                logger.info("Dexcom not connected, falling back to HealthKit")
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

    // MARK: - Private Methods

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

            // Convert HealthGlucoseReading to GlucoseDataPoint
            glucoseData = healthReadings.map { reading in
                GlucoseDataPoint(time: reading.timestamp, value: reading.value)
            }

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

            // Convert to chart data points
            glucoseData = readings.map { reading in
                GlucoseDataPoint(time: reading.timestamp, value: reading.value)
            }

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
