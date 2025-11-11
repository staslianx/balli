//
//  NutritionLabelView+Calculations.swift
//  balli
//
//  Nutritional value calculations and formatting
//  Extracted from NutritionLabelView.swift
//  Swift 6 strict concurrency compliant
//

import SwiftUI
import OSLog

// Logger for calculations
private let calculationsLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.anaxonic.balli",
    category: "NutritionLabel.Calculations"
)

extension NutritionLabelView {

    // MARK: - Adjustment Ratio

    /// Calculate the adjustment ratio based on portion size
    var adjustmentRatio: Double {
        let baseServing = servingSize.toDouble ?? 100.0
        let ratio = portionGrams / baseServing

        calculationsLogger.debug("🔢 adjustmentRatio - servingSize: '\(self.servingSize)' -> parsed: \(baseServing, privacy: .public), portionGrams: \(self.portionGrams, privacy: .public), ratio: \(ratio, privacy: .public)")

        return ratio
    }

    // MARK: - Adjusted Values

    var adjustedCalories: String {
        guard let baseValue = calories.toDouble else {
            calculationsLogger.error("❌ adjustedCalories - failed to parse calories: '\(self.calories)'")
            return calories
        }
        let adjusted = baseValue * adjustmentRatio
        let result = adjusted.asLocalizedDecimal(decimalPlaces: 0)

        calculationsLogger.debug("✅ adjustedCalories - base: '\(self.calories)' -> \(baseValue, privacy: .public), ratio: \(self.adjustmentRatio, privacy: .public), adjusted: \(adjusted, privacy: .public), formatted: '\(result)'")

        return result
    }

    var adjustedCarbohydrates: String {
        guard let baseValue = carbohydrates.toDouble else {
            calculationsLogger.error("❌ adjustedCarbohydrates - failed to parse carbohydrates: '\(self.carbohydrates)'")
            return carbohydrates
        }
        let adjusted = baseValue * adjustmentRatio
        let result = formatNutritionValue(adjusted)

        calculationsLogger.debug("✅ adjustedCarbohydrates - base: '\(self.carbohydrates)' -> \(baseValue, privacy: .public), ratio: \(self.adjustmentRatio, privacy: .public), adjusted: \(adjusted, privacy: .public), formatted: '\(result)'")

        return result
    }

    var adjustedFiber: String {
        guard let baseValue = fiber.toDouble else {
            calculationsLogger.error("❌ adjustedFiber - failed to parse fiber: '\(self.fiber)'")
            return fiber
        }
        let adjusted = baseValue * adjustmentRatio
        let result = formatNutritionValue(adjusted)

        calculationsLogger.debug("✅ adjustedFiber - base: '\(self.fiber)' -> \(baseValue, privacy: .public), ratio: \(self.adjustmentRatio, privacy: .public), adjusted: \(adjusted, privacy: .public), formatted: '\(result)'")

        return result
    }

    var adjustedSugars: String {
        guard let baseValue = sugars.toDouble else {
            calculationsLogger.error("❌ adjustedSugars - failed to parse sugars: '\(self.sugars)'")
            return sugars
        }
        let adjusted = baseValue * adjustmentRatio
        let result = formatNutritionValue(adjusted)

        calculationsLogger.debug("✅ adjustedSugars - base: '\(self.sugars)' -> \(baseValue, privacy: .public), ratio: \(self.adjustmentRatio, privacy: .public), adjusted: \(adjusted, privacy: .public), formatted: '\(result)'")

        return result
    }

    var adjustedProtein: String {
        guard let baseValue = protein.toDouble else {
            calculationsLogger.error("❌ adjustedProtein - failed to parse protein: '\(self.protein)'")
            return protein
        }
        let adjusted = baseValue * adjustmentRatio
        let result = formatNutritionValue(adjusted)

        calculationsLogger.debug("✅ adjustedProtein - base: '\(self.protein)' -> \(baseValue, privacy: .public), ratio: \(self.adjustmentRatio, privacy: .public), adjusted: \(adjusted, privacy: .public), formatted: '\(result)'")

        return result
    }

    var adjustedFat: String {
        guard let baseValue = fat.toDouble else {
            calculationsLogger.error("❌ adjustedFat - failed to parse fat: '\(self.fat)'")
            return fat
        }
        let adjusted = baseValue * adjustmentRatio
        let result = formatNutritionValue(adjusted)

        calculationsLogger.debug("✅ adjustedFat - base: '\(self.fat)' -> \(baseValue, privacy: .public), ratio: \(self.adjustmentRatio, privacy: .public), adjusted: \(adjusted, privacy: .public), formatted: '\(result)'")

        return result
    }

    // MARK: - Formatting Helpers

    /// Format nutrition value with locale-aware decimal separator
    /// Show decimal only if there's a meaningful value (51.0 -> "51", 51.5 -> "51,5" in Turkish)
    func formatNutritionValue(_ value: Double) -> String {
        let rounded = round(value * 10) / 10  // Round to 1 decimal place
        if rounded.truncatingRemainder(dividingBy: 1) == 0 {
            // No decimal part, show as integer
            return rounded.asLocalizedDecimal(decimalPlaces: 0)
        } else {
            // Has decimal part, show 1 decimal with locale-aware separator
            return rounded.asLocalizedDecimal(decimalPlaces: 1)
        }
    }

    // MARK: - Impact Score Calculation

    /// Calculate real-time impact score for current portion using Nestlé formula
    /// Treats empty or invalid nutritional values as 0.0 to handle products with missing data
    var currentImpactResult: ImpactScoreResult? {
        // Require only carbs and serving size - other nutrients can be zero
        guard let baseCarbs = carbohydrates.toDouble,
              let baseServing = servingSize.toDouble,
              baseServing > 0 else {
            return nil
        }

        // Parse optional nutrients - default to 0.0 if missing/empty/invalid
        let baseFiber = fiber.toDouble ?? 0.0
        let baseSugars = sugars.toDouble ?? 0.0
        let baseProtein = protein.toDouble ?? 0.0
        let baseFat = fat.toDouble ?? 0.0

        return ImpactScoreCalculator.calculate(
            totalCarbs: baseCarbs,
            fiber: baseFiber,
            sugar: baseSugars,
            protein: baseProtein,
            fat: baseFat,
            servingSize: baseServing,
            portionGrams: portionGrams
        )
    }

    // MARK: - Animation Helpers

    /// Helper method to determine if a value should be visible based on animation state
    func shouldShowValue(_ fieldName: String) -> Bool {
        // Always show in editing mode
        if isEditing {
            return true
        }

        // For animation mode: only show if both general flag is true AND individual field is animated
        if !showingValues {
            // During animation sequence: only show individual fields when their animation is triggered
            return valuesAnimationProgress[fieldName] ?? false
        }

        // For immediate display mode (showingValues = true): show everything
        return true
    }
}
