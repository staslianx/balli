//
//  MealEvent.swift
//  balli
//
//  Rich meal event model for correlation analysis
//  Swift 6 strict concurrency compliant
//

import Foundation

/// Complete meal event with glucose response and activity context
/// Used for correlation analysis and detailed export formats
struct MealEvent: Codable, Sendable {
    // MARK: - Core Meal Data

    let timestamp: Date
    let mealType: String // "Kahvaltı", "Öğle", "Akşam", "Ara Öğün"
    let carbs: Double
    let protein: Double?
    let fat: Double?
    let calories: Double?

    // MARK: - Insulin Data

    let bolusInsulin: Double? // Rapid-acting insulin taken with meal
    let basalRate: Double? // Background basal rate at time of meal

    // MARK: - Glucose Context

    let glucoseBefore: Double? // mg/dL reading before meal
    let glucoseResponse: GlucoseResponse? // Post-meal glucose trajectory

    // MARK: - Activity Context

    let activityContext: ActivityContext? // Activity before/after meal

    // MARK: - Meal Details

    let mealName: String?
    let foods: [String]? // List of foods/ingredients
    let notes: String?
    let photo: String? // Photo URL if available

    // MARK: - Metadata

    let source: String // "manual", "recipe", "imported"
    let confidence: Double? // AI confidence score if generated

    // MARK: - Computed Properties

    /// Total insulin delivered (bolus + basal contribution over 2 hours)
    var totalInsulin: Double? {
        guard let bolus = bolusInsulin else { return nil }

        if let basalRate = basalRate {
            // Add basal insulin over typical 2-hour meal window
            let basalContribution = basalRate * 2.0
            return bolus + basalContribution
        }

        return bolus
    }

    /// Insulin-to-carb ratio if both are present
    var insulinToCarbRatio: Double? {
        guard let insulin = bolusInsulin, carbs > 0 else { return nil }
        return insulin / carbs
    }

    /// Peak glucose change from baseline (if response available)
    var peakGlucoseChange: Double? {
        guard let response = glucoseResponse else { return nil }
        return response.peak - response.baseline
    }
}

// MARK: - CSV Export Helper

extension MealEvent {
    /// Flattened representation for CSV export
    /// Returns dictionary with all fields as strings
    func toCSVRow() -> [String: String] {
        var row: [String: String] = [:]

        // Core data
        row["timestamp"] = ISO8601DateFormatter().string(from: timestamp)
        row["meal_type"] = mealType
        row["carbs_g"] = String(format: "%.1f", carbs)
        row["protein_g"] = protein.map { String(format: "%.1f", $0) } ?? ""
        row["fat_g"] = fat.map { String(format: "%.1f", $0) } ?? ""
        row["calories"] = calories.map { String(format: "%.0f", $0) } ?? ""

        // Insulin
        row["bolus_insulin_u"] = bolusInsulin.map { String(format: "%.2f", $0) } ?? ""
        row["total_insulin_u"] = totalInsulin.map { String(format: "%.2f", $0) } ?? ""
        row["insulin_carb_ratio"] = insulinToCarbRatio.map { String(format: "%.3f", $0) } ?? ""

        // Glucose
        row["glucose_before_mg_dl"] = glucoseBefore != nil ? String(format: "%.0f", glucoseBefore!) : ""
        row["glucose_peak_mg_dl"] = glucoseResponse?.peak != nil ? String(format: "%.0f", glucoseResponse!.peak) : ""
        row["glucose_change_mg_dl"] = peakGlucoseChange != nil ? String(format: "%.0f", peakGlucoseChange!) : ""
        row["glucose_change_1h_mg_dl"] = glucoseResponse?.change1h != nil ? String(format: "%.0f", glucoseResponse!.change1h!) : ""
        row["glucose_change_2h_mg_dl"] = glucoseResponse?.change2h != nil ? String(format: "%.0f", glucoseResponse!.change2h!) : ""

        // Activity
        row["steps_2h_before"] = activityContext != nil ? String(activityContext!.steps2hBefore) : ""
        row["steps_2h_after"] = activityContext != nil ? String(activityContext!.steps2hAfter) : ""
        row["active_calories"] = activityContext != nil ? String(activityContext!.activeCalories) : ""

        // Meal details
        row["meal_name"] = mealName ?? ""
        row["foods"] = foods?.joined(separator: "; ") ?? ""
        row["notes"] = notes ?? ""
        row["has_photo"] = photo != nil ? "yes" : "no"

        return row
    }
}
