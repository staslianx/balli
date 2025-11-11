//
//  NutritionConstants.swift
//  balli
//
//  Centralized nutrition calculation constants
//  Prevents magic numbers scattered throughout the codebase
//

import Foundation

/// Constants for nutrition calculations and portion management
enum NutritionConstants {
    // MARK: - Portion Size Constraints

    /// Minimum portion size in grams
    /// Rationale: Portions smaller than 50g are not realistic for diabetes management
    static let minPortionSize: Double = 50.0

    /// Slider step size in grams
    /// Rationale: 5g increments balance precision with UX usability
    static let sliderStep: Double = 5.0

    // MARK: - Nutrition Facts Standard

    /// Standard nutrition facts base (per 100g)
    /// Used for per-100g nutrition calculations
    static let nutritionBasePer100g: Double = 100.0

    /// Default portion multiplier for new recipes
    static let defaultPortionMultiplier: Double = 1.0

    // MARK: - Validation Tolerances

    /// Tolerance for floating-point comparison in nutrition calculations
    /// Used to handle rounding errors in validation
    static let calculationTolerance: Double = 0.1

    /// Calorie validation tolerance (±1.0 kcal)
    static let calorieTolerance: Double = 1.0

    /// Glycemic load validation tolerance (±1.0)
    static let glycemicLoadTolerance: Double = 1.0

    // MARK: - Display Formatting

    /// Number of decimal places for nutrition display
    /// Most values show 0-1 decimals depending on magnitude
    static let displayDecimalPlaces: Int = 1

    /// Threshold for showing decimal places
    /// Values below this threshold show 1 decimal place, above show none
    static let decimalThreshold: Double = 10.0

    // MARK: - Cache Configuration

    /// Default portion size for caching calculations
    static let defaultCachePortion: Double = 100.0
}
