//
//  TimeSeriesCSVGenerator.swift
//  balli
//
//  Generates ML-ready time series CSV with 5-minute intervals
//  Swift 6 strict concurrency compliant
//

import Foundation
import CoreData

/// Generates Time Series CSV format
/// ML-ready chronological format with 5-minute intervals for advanced analysis
struct TimeSeriesCSVGenerator: Sendable {
    // MARK: - Configuration

    /// Time interval between rows (5 minutes)
    private let intervalSeconds: TimeInterval = 5 * 60

    // MARK: - CSV Generation

    /// Generate Time Series CSV from raw data
    /// - Parameters:
    ///   - glucoseReadings: Array of GlucoseReading entities
    ///   - meals: Array of MealEntry entities
    ///   - insulinEntries: Array of MedicationEntry entities
    ///   - dailyActivity: Array of DailyActivity entities
    ///   - dateRange: Date interval being exported
    /// - Returns: CSV data ready for export
    /// - Throws: ExportError.encodingFailed if CSV generation fails
    func generate(
        glucoseReadings: [GlucoseReading],
        meals: [MealEntry],
        insulinEntries: [MedicationEntry],
        dailyActivity: [DailyActivity],
        dateRange: DateInterval
    ) throws -> Data {
        // Build time series index (5-minute intervals)
        let timeIndex = buildTimeIndex(dateRange: dateRange)

        // Build lookup dictionaries for efficient access
        let glucoseLookup = buildGlucoseLookup(glucoseReadings)
        let mealLookup = buildMealLookup(meals)
        let insulinLookup = buildInsulinLookup(insulinEntries)
        let activityLookup = buildActivityLookup(dailyActivity)

        // Build CSV header
        let header = buildHeader()

        // Build CSV rows for each time point
        var rows: [String] = [header]

        for timestamp in timeIndex {
            let row = buildRow(
                timestamp: timestamp,
                glucoseLookup: glucoseLookup,
                mealLookup: mealLookup,
                insulinLookup: insulinLookup,
                activityLookup: activityLookup
            )
            rows.append(row)
        }

        // Join rows with newlines
        let csv = rows.joined(separator: "\n")

        // Convert to UTF-8 data
        guard let data = csv.data(using: .utf8) else {
            throw ExportError.encodingFailed
        }

        return data
    }

    // MARK: - Time Index

    /// Build array of timestamps at 5-minute intervals
    private func buildTimeIndex(dateRange: DateInterval) -> [Date] {
        var timestamps: [Date] = []
        var currentTime = dateRange.start

        while currentTime <= dateRange.end {
            timestamps.append(currentTime)
            currentTime = currentTime.addingTimeInterval(intervalSeconds)
        }

        return timestamps
    }

    // MARK: - Data Lookups

    /// Build lookup dictionary for glucose readings
    /// Key: timestamp rounded to 5-minute interval
    private func buildGlucoseLookup(_ readings: [GlucoseReading]) -> [Date: Double] {
        var lookup: [Date: Double] = [:]

        for reading in readings {
            let timestamp = reading.timestamp
            let roundedTime = roundToInterval(timestamp)
            lookup[roundedTime] = reading.value
        }

        return lookup
    }

    /// Build lookup dictionary for meals
    /// Key: timestamp rounded to 5-minute interval
    private func buildMealLookup(_ meals: [MealEntry]) -> [Date: TimeSeriesMealData] {
        var lookup: [Date: TimeSeriesMealData] = [:]

        for meal in meals {
            let timestamp = meal.timestamp
            let roundedTime = roundToInterval(timestamp)

            lookup[roundedTime] = TimeSeriesMealData(
                type: meal.mealType,
                carbs: meal.consumedCarbs,
                protein: meal.consumedProtein,
                fat: meal.consumedFat,
                calories: meal.consumedCalories
            )
        }

        return lookup
    }

    /// Build lookup dictionary for insulin entries
    /// Key: timestamp rounded to 5-minute interval
    private func buildInsulinLookup(_ entries: [MedicationEntry]) -> [Date: TimeSeriesInsulinData] {
        var lookup: [Date: TimeSeriesInsulinData] = [:]

        for entry in entries {
            guard let timestamp = entry.timestamp as Date? else { continue }
            let roundedTime = roundToInterval(timestamp)

            let type = entry.medicationType
            let isRapid = type == "rapid" || type == "bolus"

            if let existing = lookup[roundedTime] {
                // Accumulate if multiple entries at same time
                lookup[roundedTime] = TimeSeriesInsulinData(
                    rapid: existing.rapid + (isRapid ? entry.dosage : 0),
                    basal: existing.basal + (isRapid ? 0 : entry.dosage)
                )
            } else {
                lookup[roundedTime] = TimeSeriesInsulinData(
                    rapid: isRapid ? entry.dosage : 0,
                    basal: isRapid ? 0 : entry.dosage
                )
            }
        }

        return lookup
    }

    /// Build lookup dictionary for daily activity
    /// Key: start of day
    private func buildActivityLookup(_ activities: [DailyActivity]) -> [Date: TimeSeriesActivityData] {
        var lookup: [Date: TimeSeriesActivityData] = [:]

        let calendar = Calendar.current

        for activity in activities {
            guard let date = activity.date as Date? else { continue }
            let startOfDay = calendar.startOfDay(for: date)

            lookup[startOfDay] = TimeSeriesActivityData(
                steps: Int(activity.steps),
                activeCalories: Int(activity.activeCalories),
                totalCalories: Int(activity.totalCalories)
            )
        }

        return lookup
    }

    /// Round timestamp to nearest 5-minute interval
    private func roundToInterval(_ timestamp: Date) -> Date {
        let timeInterval = timestamp.timeIntervalSinceReferenceDate
        let rounded = (timeInterval / intervalSeconds).rounded() * intervalSeconds
        return Date(timeIntervalSinceReferenceDate: rounded)
    }

    // MARK: - Header Construction

    /// Build CSV header row
    private func buildHeader() -> String {
        let columns = [
            // Time
            "timestamp",
            "date",
            "time",
            "hour",
            "minute",
            "day_of_week",
            "is_weekend",

            // Glucose
            "glucose_mg_dl",
            "glucose_rate_of_change",
            "glucose_trend",

            // Meal
            "meal_event",
            "meal_type",
            "carbs_g",
            "protein_g",
            "fat_g",
            "calories",

            // Insulin
            "insulin_rapid_u",
            "insulin_basal_u",
            "insulin_total_u",

            // Activity (daily totals distributed)
            "steps_daily",
            "active_calories_daily",
            "total_calories_daily",

            // Context
            "minutes_since_last_meal",
            "minutes_since_last_insulin"
        ]

        return columns.joined(separator: ",")
    }

    // MARK: - Row Construction

    /// Build CSV row for specific timestamp
    private func buildRow(
        timestamp: Date,
        glucoseLookup: [Date: Double],
        mealLookup: [Date: TimeSeriesMealData],
        insulinLookup: [Date: TimeSeriesInsulinData],
        activityLookup: [Date: TimeSeriesActivityData]
    ) -> String {
        var fields: [String] = []

        // Time fields
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"

        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute, .weekday], from: timestamp)

        fields.append(csvField(isoFormatter.string(from: timestamp)))
        fields.append(csvField(dateFormatter.string(from: timestamp)))
        fields.append(csvField(timeFormatter.string(from: timestamp)))
        fields.append(csvField(components.hour))
        fields.append(csvField(components.minute))
        fields.append(csvField(weekdayName(components.weekday)))
        fields.append(csvField(isWeekend(components.weekday)))

        // Glucose fields
        let roundedTime = roundToInterval(timestamp)
        let glucose = glucoseLookup[roundedTime]

        fields.append(csvField(glucose, decimals: 0))
        fields.append(csvField(calculateRateOfChange(timestamp: roundedTime, lookup: glucoseLookup), decimals: 1))
        fields.append(csvField(calculateTrend(timestamp: roundedTime, lookup: glucoseLookup)))

        // Meal fields
        if let meal = mealLookup[roundedTime] {
            fields.append(csvField("yes"))
            fields.append(csvField(meal.type))
            fields.append(csvField(meal.carbs, decimals: 1))
            fields.append(csvField(meal.protein, decimals: 1))
            fields.append(csvField(meal.fat, decimals: 1))
            fields.append(csvField(meal.calories, decimals: 0))
        } else {
            fields.append(csvField("no"))
            fields.append("") // meal_type
            fields.append("") // carbs
            fields.append("") // protein
            fields.append("") // fat
            fields.append("") // calories
        }

        // Insulin fields
        if let insulin = insulinLookup[roundedTime] {
            fields.append(csvField(insulin.rapid, decimals: 2))
            fields.append(csvField(insulin.basal, decimals: 2))
            fields.append(csvField(insulin.rapid + insulin.basal, decimals: 2))
        } else {
            fields.append("") // rapid
            fields.append("") // basal
            fields.append("") // total
        }

        // Activity fields (daily totals)
        let startOfDay = calendar.startOfDay(for: timestamp)
        if let activity = activityLookup[startOfDay] {
            fields.append(csvField(activity.steps))
            fields.append(csvField(activity.activeCalories))
            fields.append(csvField(activity.totalCalories))
        } else {
            fields.append("") // steps
            fields.append("") // active_calories
            fields.append("") // total_calories
        }

        // Context fields
        fields.append(csvField(minutesSinceLastEvent(timestamp: roundedTime, eventLookup: mealLookup)))
        fields.append(csvField(minutesSinceLastEvent(timestamp: roundedTime, eventLookup: insulinLookup)))

        return fields.joined(separator: ",")
    }

    // MARK: - Helpers

    /// Calculate rate of change (mg/dL per minute)
    private func calculateRateOfChange(timestamp: Date, lookup: [Date: Double]) -> Double? {
        guard let currentGlucose = lookup[timestamp] else { return nil }

        // Look back 5 minutes
        let previousTime = timestamp.addingTimeInterval(-intervalSeconds)
        guard let previousGlucose = lookup[previousTime] else { return nil }

        let change = currentGlucose - previousGlucose
        let ratePerMinute = change / 5.0

        return ratePerMinute
    }

    /// Calculate trend based on rate of change
    private func calculateTrend(timestamp: Date, lookup: [Date: Double]) -> String {
        guard let rate = calculateRateOfChange(timestamp: timestamp, lookup: lookup) else {
            return "steady"
        }

        switch rate {
        case ..<(-2.0):
            return "falling_fast"
        case -2.0..<(-1.0):
            return "falling"
        case -1.0...1.0:
            return "steady"
        case 1.0...2.0:
            return "rising"
        default:
            return "rising_fast"
        }
    }

    /// Calculate minutes since last event in lookup
    private func minutesSinceLastEvent<T>(timestamp: Date, eventLookup: [Date: T]) -> Int? {
        let pastEvents = eventLookup.keys.filter { $0 <= timestamp }.sorted(by: >)

        guard let lastEvent = pastEvents.first else { return nil }

        let seconds = timestamp.timeIntervalSince(lastEvent)
        return Int(seconds / 60)
    }

    /// Get weekday name
    private func weekdayName(_ weekday: Int?) -> String {
        guard let weekday = weekday else { return "" }

        let days = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        return days[weekday - 1]
    }

    /// Check if weekend
    private func isWeekend(_ weekday: Int?) -> String {
        guard let weekday = weekday else { return "" }
        return (weekday == 1 || weekday == 7) ? "yes" : "no"
    }

    // MARK: - CSV Field Formatting

    private func csvField(_ value: String?) -> String {
        guard let value = value, !value.isEmpty else {
            return ""
        }

        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }

        return value
    }

    private func csvField(_ value: Double?, decimals: Int = 2) -> String {
        guard let value = value else { return "" }
        return String(format: "%.\(decimals)f", value)
    }

    private func csvField(_ value: Int?) -> String {
        guard let value = value else { return "" }
        return String(value)
    }

    private func csvField(_ value: Bool) -> String {
        value ? "yes" : "no"
    }
}

// MARK: - Helper Structures

private struct TimeSeriesMealData {
    let type: String
    let carbs: Double
    let protein: Double
    let fat: Double
    let calories: Double
}

private struct TimeSeriesInsulinData {
    let rapid: Double
    let basal: Double
}

private struct TimeSeriesActivityData {
    let steps: Int
    let activeCalories: Int
    let totalCalories: Int
}
