//
//  InsulinCurveCalculator.swift
//  balli
//
//  Calculates glucose absorption curves based on recipe nutrition
//  Implements formulas from dual-curve.md specification
//

import Foundation

/// Calculator for glucose absorption curves and insulin-glucose mismatch warnings
actor InsulinCurveCalculator {

    /// Shared singleton instance for convenient access
    static let shared = InsulinCurveCalculator()

    // MARK: - Nutrition Data Structure

    struct RecipeNutrition: Sendable {
        let carbohydrates: Double  // grams
        let fat: Double            // grams
        let protein: Double        // grams
        let sugar: Double          // grams (subset of carbs)
        let fiber: Double          // grams
        let glycemicLoad: Double   // calculated GL
    }

    // MARK: - Glucose Peak Time Calculation

    /// Calculate when glucose levels will peak after consuming this recipe
    /// - Parameter nutrition: Recipe nutrition data
    /// - Returns: Peak time in minutes (45-300 minutes)
    nonisolated func calculateGlucosePeakTime(nutrition: RecipeNutrition) -> Int {
        // Base peak time from carbohydrate type (sugar content)
        let basePeakTime: Int
        let sugarRatio = nutrition.carbohydrates > 0 ? nutrition.sugar / nutrition.carbohydrates : 0

        if sugarRatio > 0.7 {
            // High sugar (>70% of carbs) - fast absorption
            basePeakTime = 60  // Peak at 1 hour
        } else if sugarRatio > 0.4 {
            // Moderate sugar (40-70%) - medium absorption
            basePeakTime = 90  // Peak at 1.5 hours
        } else {
            // Complex carbs (<40% sugar) - slow absorption
            basePeakTime = 120  // Peak at 2 hours
        }

        // Fat delay factor (fat slows gastric emptying)
        let fatDelayMinutes: Int
        if nutrition.fat < 10 {
            fatDelayMinutes = 0  // Minimal fat, no delay
        } else if nutrition.fat < 20 {
            fatDelayMinutes = 30  // Moderate fat, 30 min delay
        } else if nutrition.fat < 30 {
            fatDelayMinutes = 60  // High fat, 1 hour delay
        } else if nutrition.fat < 40 {
            fatDelayMinutes = 90  // Very high fat, 1.5 hour delay
        } else {
            fatDelayMinutes = 120  // Extreme fat, 2 hour delay
        }

        // Protein delay factor (protein converts to glucose slowly via gluconeogenesis)
        let proteinDelayMinutes: Int
        if nutrition.protein < 15 {
            proteinDelayMinutes = 0  // Low protein, no delay
        } else if nutrition.protein < 25 {
            proteinDelayMinutes = 15  // Moderate protein, 15 min delay
        } else if nutrition.protein < 35 {
            proteinDelayMinutes = 30  // High protein, 30 min delay
        } else {
            proteinDelayMinutes = 45  // Very high protein, 45 min delay
        }

        // Fiber slowing factor (fiber slows carb absorption)
        let fiberDelayMinutes: Int
        if nutrition.fiber > 10 {
            fiberDelayMinutes = 20  // High fiber slows absorption
        } else if nutrition.fiber > 5 {
            fiberDelayMinutes = 10  // Moderate fiber
        } else {
            fiberDelayMinutes = 0  // Low fiber
        }

        // Total peak time (additive effects)
        let totalPeakTime = basePeakTime + fatDelayMinutes + proteinDelayMinutes + fiberDelayMinutes

        // Clamp between reasonable bounds (45 min to 5 hours)
        return min(max(totalPeakTime, 45), 300)
    }

    // MARK: - Glucose Duration Calculation

    /// Calculate how long glucose levels will remain elevated
    /// - Parameters:
    ///   - nutrition: Recipe nutrition data
    ///   - peakTime: Calculated glucose peak time in minutes
    /// - Returns: Duration in minutes
    nonisolated func calculateGlucoseDuration(nutrition: RecipeNutrition, peakTime: Int) -> Int {
        // Base duration from glycemic load
        let baseDuration: Int
        if nutrition.glycemicLoad < 10 {
            baseDuration = 180  // Low GL: 3 hours
        } else if nutrition.glycemicLoad < 20 {
            baseDuration = 240  // Medium GL: 4 hours
        } else {
            baseDuration = 300  // High GL: 5 hours
        }

        // Fat extends duration significantly (prolonged gastric emptying)
        let fatExtension: Int
        if nutrition.fat < 10 {
            fatExtension = 0
        } else if nutrition.fat < 20 {
            fatExtension = 60  // +1 hour
        } else if nutrition.fat < 30 {
            fatExtension = 120  // +2 hours
        } else {
            fatExtension = 180  // +3 hours
        }

        // Duration must be at least 1.5x peak time (physiologically realistic)
        let minDuration = Int(Double(peakTime) * 1.5)

        return max(baseDuration + fatExtension, minDuration)
    }

    // MARK: - Glucose Peak Height Calculation

    /// Calculate the relative intensity of the glucose peak
    /// - Parameter nutrition: Recipe nutrition data
    /// - Returns: Peak height (0.0 to 1.0, normalized)
    nonisolated func calculateGlucosePeakHeight(nutrition: RecipeNutrition) -> Double {
        // Peak height (normalized 0-1) based on glycemic load
        let baseHeight: Double
        if nutrition.glycemicLoad < 10 {
            baseHeight = 0.5  // Low impact
        } else if nutrition.glycemicLoad < 20 {
            baseHeight = 0.75  // Medium impact
        } else {
            baseHeight = 1.0  // High impact
        }

        // Sugar content increases peak height (rapid absorption)
        let sugarRatio = nutrition.carbohydrates > 0 ? nutrition.sugar / nutrition.carbohydrates : 0
        let sugarMultiplier = 1.0 + (sugarRatio * 0.3)  // Up to +30% for pure sugar

        // Fiber reduces peak height (slower absorption)
        let fiberReduction: Double
        if nutrition.fiber > 10 {
            fiberReduction = 0.85  // -15% for high fiber
        } else if nutrition.fiber > 5 {
            fiberReduction = 0.92  // -8% for moderate fiber
        } else {
            fiberReduction = 1.0  // No reduction
        }

        let finalHeight = baseHeight * sugarMultiplier * fiberReduction
        return min(finalHeight, 1.0)  // Cap at 1.0
    }

    // MARK: - Glucose Curve Generation

    /// Generate complete glucose absorption curve with multiple data points
    /// - Parameter nutrition: Recipe nutrition data
    /// - Returns: Array of curve points (time in minutes, intensity 0-1)
    nonisolated func generateGlucoseCurve(nutrition: RecipeNutrition) -> [GlucoseCurvePoint] {
        let peakTime = calculateGlucosePeakTime(nutrition: nutrition)
        let duration = calculateGlucoseDuration(nutrition: nutrition, peakTime: peakTime)
        let peakHeight = calculateGlucosePeakHeight(nutrition: nutrition)

        // Onset time is 30% of peak time (minimum 30 minutes)
        let onset = max(30, Int(Double(peakTime) * 0.3))

        // Generate curve points with realistic absorption profile
        return [
            GlucoseCurvePoint(timeMinutes: 0, intensity: 0.0),                                                      // Start (meal consumed)
            GlucoseCurvePoint(timeMinutes: onset, intensity: peakHeight * 0.2),                                     // Onset (digestion begins)
            GlucoseCurvePoint(timeMinutes: Int(Double(onset) * 1.5), intensity: peakHeight * 0.4),                 // Rising
            GlucoseCurvePoint(timeMinutes: Int(Double(peakTime) * 0.7), intensity: peakHeight * 0.7),              // Near peak
            GlucoseCurvePoint(timeMinutes: peakTime, intensity: peakHeight),                                        // PEAK (maximum glucose)
            GlucoseCurvePoint(timeMinutes: peakTime + Int(Double(duration - peakTime) * 0.3), intensity: peakHeight * 0.85),  // Plateau
            GlucoseCurvePoint(timeMinutes: peakTime + Int(Double(duration - peakTime) * 0.6), intensity: peakHeight * 0.6),   // Declining
            GlucoseCurvePoint(timeMinutes: Int(Double(duration) * 0.9), intensity: peakHeight * 0.3),              // Tail
            GlucoseCurvePoint(timeMinutes: duration, intensity: 0.0)                                                // End (complete absorption)
        ]
    }

    // MARK: - Mismatch Calculation

    /// Calculate the time difference between insulin and glucose peaks
    /// - Parameters:
    ///   - glucosePeakTime: Calculated glucose peak time
    ///   - insulinPeakTime: Insulin peak time (default: 75 minutes for NovoRapid)
    /// - Returns: Absolute mismatch in minutes
    nonisolated func calculateMismatch(glucosePeakTime: Int, insulinPeakTime: Int = InsulinCurveData.novorapidPeakTime) -> Int {
        return abs(glucosePeakTime - insulinPeakTime)
    }

    // MARK: - Warning Level Determination

    /// Determine appropriate warning level based on curve mismatch and nutrition
    /// - Parameter nutrition: Recipe nutrition data
    /// - Returns: Warning level and associated data
    nonisolated func determineWarning(nutrition: RecipeNutrition) -> (level: CurveWarningLevel, mismatch: Int, peakTime: Int) {
        let glucosePeakTime = calculateGlucosePeakTime(nutrition: nutrition)
        let mismatch = calculateMismatch(glucosePeakTime: glucosePeakTime)
        let level = CurveWarningLevel.determine(
            mismatchMinutes: mismatch,
            fatGrams: nutrition.fat,
            glycemicLoad: nutrition.glycemicLoad
        )

        return (level, mismatch, glucosePeakTime)
    }

    // MARK: - Edge Cases

    /// Check if recipe is very low carb (potential hypoglycemia risk)
    /// - Parameter carbsGrams: Total carbohydrates in grams
    /// - Returns: True if very low carb (<5g)
    nonisolated func isVeryLowCarb(carbsGrams: Double) -> Bool {
        return carbsGrams < 5
    }

    /// Check if recipe has extreme mismatch requiring special attention
    /// - Parameter mismatchMinutes: Time mismatch in minutes
    /// - Returns: True if extreme mismatch (>4 hours)
    nonisolated func isExtremeMismatch(mismatchMinutes: Int) -> Bool {
        return mismatchMinutes > 240
    }

    /// Check if recipe has high protein + low carb (gluconeogenesis concern)
    /// - Parameters:
    ///   - proteinGrams: Total protein in grams
    ///   - carbsGrams: Total carbohydrates in grams
    /// - Returns: True if high protein + low carb
    nonisolated func isHighProteinLowCarb(proteinGrams: Double, carbsGrams: Double) -> Bool {
        return proteinGrams > 30 && carbsGrams < 20
    }
}
