//
//  GlucoseDashboardViewModel.swift
//  balli
//
//  ViewModel for GlucoseDashboardView - handles glucose data loading and statistics
//  Swift 6 strict concurrency compliant
//

import Foundation
import SwiftUI
import OSLog

@MainActor
final class GlucoseDashboardViewModel: ObservableObject {
    // MARK: - Published State

    @Published var glucoseReadings: [HealthGlucoseReading] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var selectedTab: DashboardTab = .activities

    // MARK: - Dependencies

    private let dexcomService: DexcomService
    private let repository: GlucoseReadingRepository
    private let logger = AppLoggers.Health.glucose

    // MARK: - Dashboard Tab

    enum DashboardTab: String, CaseIterable {
        case activities = "Activities"
        case glucose = "Glucose"
    }

    // MARK: - Initialization

    /// Initialize with dependency injection support
    /// - Parameters:
    ///   - dexcomService: Dexcom service (optional, uses DependencyContainer if not provided)
    ///   - repository: Glucose data repository
    init(
        dexcomService: DexcomService? = nil,
        repository: GlucoseReadingRepository = GlucoseReadingRepository()
    ) {
        // CRITICAL FIX: Safe unwrapping instead of force cast
        // If DependencyContainer has wrong type, we gracefully fail instead of crashing
        if let service = dexcomService {
            self.dexcomService = service
        } else if let service = DependencyContainer.shared.dexcomService as? DexcomService {
            self.dexcomService = service
        } else {
            // Fallback: Create default DexcomService if container has wrong type
            // This prevents crashes during initialization
            let logger = AppLoggers.Health.glucose
            logger.error("DexcomService not properly configured in DependencyContainer - using default")
            self.dexcomService = DexcomService()
        }

        self.repository = repository
    }

    // MARK: - Data Loading

    /// Loads glucose data from Core Data (where Official API data is stored)
    /// This ensures we display ALL glucose data regardless of API delay
    func loadData() async {
        logger.info("🔵 [LOAD] loadData() called - isConnected: \(self.dexcomService.isConnected)")

        isLoading = true
        error = nil

        do {
            // Calculate date range for last 7 days
            let endDate = Date()
            let startDate = Calendar.current.date(byAdding: .day, value: -7, to: endDate) ?? endDate

            logger.info("📊 [LOAD] Loading from Core Data: \(startDate) to \(endDate)")

            // Load ALL readings from Core Data (includes both Official and Share API data)
            let allReadings = try await repository.fetchReadings(
                startDate: startDate,
                endDate: endDate
            )

            glucoseReadings = allReadings.sorted { $0.timestamp > $1.timestamp }
            logger.info("✅ [LOAD] Loaded \(self.glucoseReadings.count) glucose readings from Core Data")

            // Log breakdown by source for debugging
            let officialCount = glucoseReadings.filter { $0.source == "dexcom_official" }.count
            let shareCount = glucoseReadings.filter { $0.source == "dexcom_share" }.count
            logger.info("📊 [LOAD] Breakdown: Official API: \(officialCount), Share API: \(shareCount)")

        } catch {
            self.error = error.localizedDescription
            logger.error("❌ [LOAD] Failed to load glucose data: \(error.localizedDescription)")
        }

        isLoading = false
        logger.info("🏁 [LOAD] loadData() complete - readings: \(self.glucoseReadings.count), isLoading: false")
    }

    // MARK: - Chart X-Axis Range

    /// Calculates the 6am-6am chart range for 24-hour glucose view
    var chartXAxisRange: ClosedRange<Date> {
        let calendar = Calendar.current
        let now = Date()

        // Get today's 6am
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = 6
        components.minute = 0
        components.second = 0

        guard let today6am = calendar.date(from: components) else {
            return now...now
        }

        // Determine start time (6am today or yesterday depending on current time)
        let startTime: Date
        if now < today6am {
            // Before 6am today, so show yesterday 6am to today 6am
            startTime = calendar.date(byAdding: .day, value: -1, to: today6am) ?? today6am
        } else {
            // After 6am today, so show today 6am to tomorrow 6am
            startTime = today6am
        }

        let endTime = calendar.date(byAdding: .day, value: 1, to: startTime) ?? startTime

        return startTime...endTime
    }

    /// Filters glucose readings to the 24-hour 6am-6am window
    func filteredReadingsFor24Hours() -> [HealthGlucoseReading] {
        let range = chartXAxisRange
        return glucoseReadings.filter { reading in
            reading.timestamp >= range.lowerBound && reading.timestamp < range.upperBound
        }
    }

    // MARK: - Statistics Calculations

    /// Calculates average glucose for selected tab
    func calculateAverageGlucose() -> Double {
        let readings = selectedTab == .glucose ? filteredReadingsFor24Hours() : glucoseReadings
        guard !readings.isEmpty else { return 0 }
        return readings.map { $0.value }.reduce(0, +) / Double(readings.count)
    }

    /// Calculates minimum glucose value
    func calculateMinimumGlucose() -> Double {
        glucoseReadings.map { $0.value }.min() ?? 0
    }

    /// Calculates maximum glucose value
    func calculateMaximumGlucose() -> Double {
        glucoseReadings.map { $0.value }.max() ?? 0
    }

    /// Calculates percentage of time in target range (70-180 mg/dL)
    func calculateTimeInRange() -> Double {
        guard !glucoseReadings.isEmpty else { return 0 }
        let inRange = glucoseReadings.filter { $0.value >= 70 && $0.value <= 180 }.count
        return Double(inRange) / Double(glucoseReadings.count) * 100
    }

    // MARK: - Glucose Color Logic

    /// Returns appropriate color based on glucose value
    func glucoseColor(for value: Double) -> Color {
        switch value {
        case ..<70: return .red
        case 70..<180: return .green
        case 180..<250: return .orange
        default: return .red
        }
    }

    /// Returns color for specific range indicator
    func rangeColor(for value: Double, index: Int) -> Color {
        let ranges: [(min: Double, max: Double)] = [
            (0, 70),    // Very low
            (70, 100),  // Low normal
            (100, 140), // Optimal
            (140, 180), // High normal
            (180, 400)  // High
        ]

        let range = ranges[index]
        return (value >= range.min && value < range.max) ? glucoseColor(for: value) : .gray.opacity(0.2)
    }

    // MARK: - Trend Helpers

    /// Returns SF Symbol name for trend
    func trendSymbol(for trend: String) -> String {
        switch trend.lowercased() {
        case "flat": return "arrow.forward"
        case "doubleup": return "arrow.up.to.line"
        case "singleup": return "arrow.up"
        case "fortyup": return "arrow.up.right"
        case "fortydown": return "arrow.down.right"
        case "singledown": return "arrow.down"
        case "doubledown": return "arrow.down.to.line"
        default: return "arrow.forward"
        }
    }

    /// Returns human-readable trend description
    func trendDescription(for trend: String) -> String {
        switch trend.lowercased() {
        case "flat": return "Steady"
        case "doubleup": return "Rising fast"
        case "singleup": return "Rising"
        case "fortyup": return "Rising slow"
        case "fortydown": return "Falling slow"
        case "singledown": return "Falling"
        case "doubledown": return "Falling fast"
        default: return "Unknown"
        }
    }
}

// MARK: - Preview Support

#if DEBUG
extension GlucoseDashboardViewModel {
    /// Preview with sample glucose data
    static var previewWithData: GlucoseDashboardViewModel {
        let service = DexcomService.mock
        let repository = GlucoseReadingRepository()
        let vm = GlucoseDashboardViewModel(dexcomService: service, repository: repository)

        // Add sample readings
        let now = Date()
        vm.glucoseReadings = (0..<24).map { index in
            let timestamp = Calendar.current.date(byAdding: .hour, value: -Int(index), to: now) ?? now
            let value = 120.0 + Double.random(in: -30...30)

            return HealthGlucoseReading(
                id: UUID(),
                value: value,
                timestamp: timestamp,
                source: "dexcom_official",
                metadata: ["trend": "Flat"]
            )
        }

        return vm
    }

    /// Preview with no data (empty state)
    static var previewEmpty: GlucoseDashboardViewModel {
        let service = DexcomService.mock
        let repository = GlucoseReadingRepository()
        let vm = GlucoseDashboardViewModel(dexcomService: service, repository: repository)
        vm.glucoseReadings = []
        return vm
    }

    /// Preview in loading state
    static var previewLoading: GlucoseDashboardViewModel {
        let service = DexcomService.mock
        let repository = GlucoseReadingRepository()
        let vm = GlucoseDashboardViewModel(dexcomService: service, repository: repository)
        vm.isLoading = true
        vm.glucoseReadings = []
        return vm
    }
}
#endif
