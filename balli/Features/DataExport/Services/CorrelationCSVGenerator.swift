//
//  CorrelationCSVGenerator.swift
//  balli
//
//  Generates Excel-ready CSV for correlation analysis
//  Swift 6 strict concurrency compliant
//

import Foundation

/// Generates Correlation CSV format
/// Excel-ready format optimized for quick correlation analysis between meals, glucose, and activity
struct CorrelationCSVGenerator: Sendable {
    // MARK: - CSV Generation

    /// Generate Correlation CSV from meal events
    /// - Parameters:
    ///   - mealEvents: Array of MealEvent objects
    ///   - dateRange: Date interval being exported
    /// - Returns: CSV data ready for export
    /// - Throws: ExportError.encodingFailed if CSV generation fails
    func generate(mealEvents: [MealEvent], dateRange: DateInterval) throws -> Data {
        // Build CSV header
        let header = buildHeader()

        // Build CSV rows
        var rows: [String] = [header]

        for event in mealEvents {
            let row = buildRow(from: event)
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

    // MARK: - Header Construction

    /// Build CSV header row with all column names
    private func buildHeader() -> String {
        let columns = [
            // Time
            "timestamp",
            "date",
            "time",
            "day_of_week",

            // Meal
            "meal_type",
            "meal_name",
            "foods",

            // Macros
            "carbs_g",
            "protein_g",
            "fat_g",
            "calories",

            // Insulin
            "bolus_insulin_u",
            "basal_rate_u_h",
            "total_insulin_u",
            "insulin_carb_ratio",

            // Glucose
            "glucose_before_mg_dl",
            "glucose_peak_mg_dl",
            "glucose_change_mg_dl",
            "glucose_percent_increase",
            "glucose_1h_change_mg_dl",
            "glucose_2h_change_mg_dl",
            "glucose_3h_change_mg_dl",
            "peak_time_minutes",
            "time_to_baseline_minutes",
            "auc_mg_dl_h",
            "time_in_range_pct",
            "time_above_range_pct",

            // Activity
            "steps_2h_before",
            "steps_2h_after",
            "activity_change",
            "activity_change_pct",
            "active_calories",
            "exercise_minutes",
            "pre_meal_activity",
            "post_meal_activity",
            "had_pre_meal_exercise",
            "had_post_meal_exercise",

            // Metadata
            "notes",
            "has_photo",
            "source"
        ]

        return columns.joined(separator: ",")
    }

    // MARK: - Row Construction

    /// Build CSV row from MealEvent
    private func buildRow(from event: MealEvent) -> String {
        var fields: [String] = []

        // Time fields
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"

        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEEE"

        fields.append(csvField(isoFormatter.string(from: event.timestamp)))
        fields.append(csvField(dateFormatter.string(from: event.timestamp)))
        fields.append(csvField(timeFormatter.string(from: event.timestamp)))
        fields.append(csvField(dayFormatter.string(from: event.timestamp)))

        // Meal fields
        fields.append(csvField(event.mealType))
        fields.append(csvField(event.mealName ?? ""))
        fields.append(csvField(event.foods?.joined(separator: "; ") ?? ""))

        // Macros
        fields.append(csvField(event.carbs, decimals: 1))
        fields.append(csvField(event.protein, decimals: 1))
        fields.append(csvField(event.fat, decimals: 1))
        fields.append(csvField(event.calories, decimals: 0))

        // Insulin
        fields.append(csvField(event.bolusInsulin, decimals: 2))
        fields.append(csvField(event.basalRate, decimals: 2))
        fields.append(csvField(event.totalInsulin, decimals: 2))
        fields.append(csvField(event.insulinToCarbRatio, decimals: 3))

        // Glucose
        fields.append(csvField(event.glucoseBefore, decimals: 0))
        fields.append(csvField(event.glucoseResponse?.peak, decimals: 0))
        fields.append(csvField(event.glucoseResponse?.peakChange, decimals: 0))
        fields.append(csvField(event.glucoseResponse?.peakPercentIncrease, decimals: 1))
        fields.append(csvField(event.glucoseResponse?.change1h, decimals: 0))
        fields.append(csvField(event.glucoseResponse?.change2h, decimals: 0))
        fields.append(csvField(event.glucoseResponse?.change3h, decimals: 0))
        fields.append(csvField(event.glucoseResponse?.peakMinutesFromMeal))
        fields.append(csvField(event.glucoseResponse?.timeToBaseline))
        fields.append(csvField(event.glucoseResponse?.auc, decimals: 1))
        fields.append(csvField(event.glucoseResponse?.timeInRange(), decimals: 1))
        fields.append(csvField(event.glucoseResponse?.timeAboveRange(), decimals: 1))

        // Activity
        fields.append(csvField(event.activityContext?.steps2hBefore))
        fields.append(csvField(event.activityContext?.steps2hAfter))
        fields.append(csvField(event.activityContext?.activityChange))
        fields.append(csvField(event.activityContext?.activityChangePercent, decimals: 1))
        fields.append(csvField(event.activityContext?.activeCalories))
        fields.append(csvField(event.activityContext?.exerciseMinutes))
        fields.append(csvField(event.activityContext?.preMealActivityCategory.rawValue ?? ""))
        fields.append(csvField(event.activityContext?.postMealActivityCategory.rawValue ?? ""))
        fields.append(csvField(event.activityContext?.hadPreMealExercise == true ? "yes" : "no"))
        fields.append(csvField(event.activityContext?.hadPostMealExercise == true ? "yes" : "no"))

        // Metadata
        fields.append(csvField(event.notes ?? ""))
        fields.append(csvField(event.photo != nil ? "yes" : "no"))
        fields.append(csvField(event.source))

        return fields.joined(separator: ",")
    }

    // MARK: - CSV Field Formatting

    /// Format field for CSV (handles quoting, escaping, and nil)
    private func csvField(_ value: String?) -> String {
        guard let value = value, !value.isEmpty else {
            return ""
        }

        // Check if field needs quoting (contains comma, quote, or newline)
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            // Escape quotes by doubling them
            let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }

        return value
    }

    /// Format optional Double for CSV
    private func csvField(_ value: Double?, decimals: Int = 2) -> String {
        guard let value = value else {
            return ""
        }

        return String(format: "%.\(decimals)f", value)
    }

    /// Format optional Int for CSV
    private func csvField(_ value: Int?) -> String {
        guard let value = value else {
            return ""
        }

        return String(value)
    }

    /// Format Bool for CSV
    private func csvField(_ value: Bool) -> String {
        value ? "yes" : "no"
    }
}
