//
//  ActivityContext.swift
//  balli
//
//  Activity data surrounding a meal event
//  Swift 6 strict concurrency compliant
//

import Foundation

/// Activity context before and after a meal
/// Used to understand impact of physical activity on glucose response
struct ActivityContext: Codable, Sendable {
    // MARK: - Activity Windows

    /// Steps in 2-hour window BEFORE meal
    let steps2hBefore: Int

    /// Steps in 2-hour window AFTER meal
    let steps2hAfter: Int

    /// Active calories burned during post-meal window
    let activeCalories: Int

    /// Total calories burned during post-meal window
    let totalCalories: Int?

    /// Exercise minutes during post-meal window (iOS definition: >3 METs)
    let exerciseMinutes: Int?

    /// Distance covered in post-meal window (meters)
    let distance: Double?

    // MARK: - Metadata

    /// Date of the meal (for linking to DailyActivity record)
    let date: Date

    /// Source of activity data
    let source: String // "apple_health", "manual"

    // MARK: - Computed Properties

    /// Change in activity level (post vs pre meal)
    var activityChange: Int {
        steps2hAfter - steps2hBefore
    }

    /// Percentage change in activity
    var activityChangePercent: Double {
        guard steps2hBefore > 0 else { return 0 }
        return (Double(activityChange) / Double(steps2hBefore)) * 100
    }

    /// Activity category for pre-meal window
    var preMealActivityCategory: ActivityCategory {
        ActivityCategory.categorize(steps: steps2hBefore)
    }

    /// Activity category for post-meal window
    var postMealActivityCategory: ActivityCategory {
        ActivityCategory.categorize(steps: steps2hAfter)
    }

    /// Was there significant exercise before the meal?
    var hadPreMealExercise: Bool {
        steps2hBefore >= 3000 // ~30 min brisk walking
    }

    /// Was there significant exercise after the meal?
    var hadPostMealExercise: Bool {
        steps2hAfter >= 3000
    }

    /// Calories per step (efficiency metric)
    var caloriesPerStep: Double? {
        guard steps2hAfter > 0 else { return nil }
        return Double(activeCalories) / Double(steps2hAfter)
    }
}

// MARK: - Activity Category

/// Classification of activity level based on steps
enum ActivityCategory: String, Codable, Sendable {
    case sedentary // <1000 steps
    case light // 1000-2000 steps
    case moderate // 2000-4000 steps
    case active // 4000-6000 steps
    case veryActive // >6000 steps

    static func categorize(steps: Int) -> ActivityCategory {
        switch steps {
        case 0..<1000:
            return .sedentary
        case 1000..<2000:
            return .light
        case 2000..<4000:
            return .moderate
        case 4000..<6000:
            return .active
        default:
            return .veryActive
        }
    }

    var displayName: String {
        switch self {
        case .sedentary:
            return "Sedentary"
        case .light:
            return "Light Activity"
        case .moderate:
            return "Moderate Activity"
        case .active:
            return "Active"
        case .veryActive:
            return "Very Active"
        }
    }

    var emoji: String {
        switch self {
        case .sedentary:
            return "🪑"
        case .light:
            return "🚶"
        case .moderate:
            return "🚶‍♂️"
        case .active:
            return "🏃"
        case .veryActive:
            return "🏃‍♂️💨"
        }
    }
}

// MARK: - Builder Helper

extension ActivityContext {
    /// Build activity context from DailyActivity Core Data entity and meal timestamp
    /// - Parameters:
    ///   - dailyActivity: DailyActivity entity for the meal date
    ///   - mealTimestamp: Time of the meal
    /// - Returns: ActivityContext with 2-hour windows around meal, or nil if data unavailable
    static func build(from dailyActivity: DailyActivity, mealTimestamp: Date) -> ActivityContext? {
        // For now, we don't have time-windowed step data from HealthKit
        // We'll use daily totals and estimate proportional distribution
        // Future enhancement: Store hourly activity data for precise windows

        let totalSteps = Int(dailyActivity.steps)
        let totalActiveCalories = Int(dailyActivity.activeCalories)
        let totalCalories = Int(dailyActivity.totalCalories)

        // Estimate: Assume activity is distributed across 16 waking hours (6am-10pm)
        // 2-hour window = 2/16 = 12.5% of daily activity
        let windowProportion = 2.0 / 16.0

        let estimatedWindowSteps = Int(Double(totalSteps) * windowProportion)
        let estimatedWindowCalories = Int(Double(totalActiveCalories) * windowProportion)

        return ActivityContext(
            steps2hBefore: estimatedWindowSteps,
            steps2hAfter: estimatedWindowSteps,
            activeCalories: estimatedWindowCalories,
            totalCalories: totalCalories,
            exerciseMinutes: Int(dailyActivity.exerciseMinutes),
            distance: dailyActivity.distance,
            date: dailyActivity.date,
            source: dailyActivity.source
        )
    }

    /// Build empty context when no activity data is available
    static func empty(date: Date) -> ActivityContext {
        ActivityContext(
            steps2hBefore: 0,
            steps2hAfter: 0,
            activeCalories: 0,
            totalCalories: nil,
            exerciseMinutes: nil,
            distance: nil,
            date: date,
            source: "unavailable"
        )
    }
}

// MARK: - CSV Export Helper

extension ActivityContext {
    /// Flattened representation for CSV export
    func toCSVRow() -> [String: String] {
        [
            "steps_2h_before": String(steps2hBefore),
            "steps_2h_after": String(steps2hAfter),
            "active_calories": String(activeCalories),
            "total_calories": totalCalories != nil ? String(totalCalories!) : "",
            "exercise_minutes": exerciseMinutes != nil ? String(exerciseMinutes!) : "",
            "distance_meters": distance != nil ? String(format: "%.0f", distance!) : "",
            "activity_change": String(activityChange),
            "activity_change_pct": String(format: "%.1f", activityChangePercent),
            "pre_meal_category": preMealActivityCategory.rawValue,
            "post_meal_category": postMealActivityCategory.rawValue,
            "had_pre_meal_exercise": hadPreMealExercise ? "yes" : "no",
            "had_post_meal_exercise": hadPostMealExercise ? "yes" : "no"
        ]
    }
}
