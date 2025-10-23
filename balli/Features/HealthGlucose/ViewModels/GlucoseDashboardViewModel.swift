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
    private let logger = AppLoggers.Health.glucose

    // MARK: - Dashboard Tab

    enum DashboardTab: String, CaseIterable {
        case activities = "Activities"
        case glucose = "Glucose"
    }

    // MARK: - Initialization

    init(dexcomService: DexcomService = DexcomService()) {
        self.dexcomService = dexcomService
    }

    // MARK: - Data Loading

    /// Loads glucose data from Dexcom service
    func loadData() async {
        guard dexcomService.isConnected else { return }

        isLoading = true
        error = nil

        do {
            // Always fetch 1 day of data for the 6am-6am view
            glucoseReadings = try await dexcomService.fetchRecentReadings(days: 1)
            glucoseReadings.sort { $0.timestamp > $1.timestamp }
            logger.info("Loaded \(self.glucoseReadings.count) glucose readings")
        } catch {
            self.error = error.localizedDescription
            logger.error("Failed to load glucose data: \(error.localizedDescription)")
        }

        isLoading = false
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
