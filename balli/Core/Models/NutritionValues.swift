//
//  NutritionValues.swift
//  balli
//
//  Created by Claude Code on 2025-11-04.
//  Critical for diabetes management - portion-based nutrition calculations
//

import Foundation

/// Unified nutrition values model with scaling support
/// Used for portion calculations to ensure medical accuracy for diabetes management
///
/// # Mathematical Properties
/// - All scaling operations preserve proportionality
/// - Supports ratio-based calculations: `portion = total × (portionSize / totalWeight)`
/// - Reversible: `total = portion × portionCount`
///
/// # Example Usage
/// ```swift
/// let totalNutrition = NutritionValues(
///     calories: 1200,
///     carbohydrates: 150,
///     fiber: 20,
///     sugar: 10,
///     protein: 80,
///     fat: 40,
///     glycemicLoad: 30
/// )
///
/// // Calculate nutrition for 1/3 of recipe
/// let ratio = 1.0 / 3.0
/// let portionNutrition = totalNutrition.scaled(by: ratio)
/// // OR
/// let portionNutrition = totalNutrition * ratio
/// ```
public struct NutritionValues: Codable, Equatable, Sendable {

    // MARK: - Properties

    /// Calories in kcal
    public var calories: Double

    /// Total carbohydrates in grams
    public var carbohydrates: Double

    /// Dietary fiber in grams
    public var fiber: Double

    /// Sugar in grams
    public var sugar: Double

    /// Protein in grams
    public var protein: Double

    /// Total fat in grams
    public var fat: Double

    /// Glycemic load (unitless, 0-100+)
    /// NOTE: GL is additive and can be divided proportionally
    public var glycemicLoad: Double

    // MARK: - Initialization

    /// Initialize with all nutrition values
    public init(
        calories: Double = 0,
        carbohydrates: Double = 0,
        fiber: Double = 0,
        sugar: Double = 0,
        protein: Double = 0,
        fat: Double = 0,
        glycemicLoad: Double = 0
    ) {
        self.calories = calories
        self.carbohydrates = carbohydrates
        self.fiber = fiber
        self.sugar = sugar
        self.protein = protein
        self.fat = fat
        self.glycemicLoad = glycemicLoad
    }

    // MARK: - Computed Properties

    /// Net carbohydrates (total carbs - fiber)
    /// Used for diabetes management calculations
    public var netCarbs: Double {
        return max(0, carbohydrates - fiber)
    }

    /// Check if nutrition values are zero (uninitialized)
    public var isEmpty: Bool {
        return calories == 0 &&
               carbohydrates == 0 &&
               protein == 0 &&
               fat == 0
    }

    // MARK: - Scaling Methods

    /// Scale all nutrition values by a given ratio
    ///
    /// - Parameter ratio: Scaling factor (e.g., 0.5 for half, 2.0 for double)
    /// - Returns: New `NutritionValues` with all values scaled proportionally
    ///
    /// # Example
    /// ```swift
    /// let totalNutrition = NutritionValues(calories: 1200, protein: 80, ...)
    /// let halfPortion = totalNutrition.scaled(by: 0.5)
    /// // halfPortion.calories = 600, halfPortion.protein = 40
    /// ```
    ///
    /// # Medical Accuracy Note
    /// All values are scaled, including glycemic load, which is mathematically correct
    /// because GL is additive across ingredients.
    public func scaled(by ratio: Double) -> NutritionValues {
        return NutritionValues(
            calories: (calories * ratio).rounded(toPlaces: 1),
            carbohydrates: (carbohydrates * ratio).rounded(toPlaces: 1),
            fiber: (fiber * ratio).rounded(toPlaces: 1),
            sugar: (sugar * ratio).rounded(toPlaces: 1),
            protein: (protein * ratio).rounded(toPlaces: 1),
            fat: (fat * ratio).rounded(toPlaces: 1),
            glycemicLoad: (glycemicLoad * ratio).rounded(toPlaces: 0)
        )
    }

    /// Multiply operator for convenient scaling
    ///
    /// - Parameters:
    ///   - lhs: Nutrition values to scale
    ///   - rhs: Scaling ratio
    /// - Returns: Scaled nutrition values
    ///
    /// # Example
    /// ```swift
    /// let total = NutritionValues(calories: 900, ...)
    /// let oneThird = total * (1.0 / 3.0)
    /// ```
    public static func * (lhs: NutritionValues, rhs: Double) -> NutritionValues {
        return lhs.scaled(by: rhs)
    }

    // MARK: - Validation

    /// Validate nutrition values are within reasonable ranges
    ///
    /// - Returns: Array of validation error messages (empty if valid)
    ///
    /// # Validation Rules
    /// - All values must be non-negative
    /// - Calories should match 4-4-9 rule: `(carbs×4 + protein×4 + fat×9) ≈ calories`
    /// - Fiber should not exceed total carbs
    /// - Sugar should not exceed total carbs
    public func validate() -> [String] {
        var errors: [String] = []

        // Check non-negative
        if calories < 0 { errors.append("Calories cannot be negative") }
        if carbohydrates < 0 { errors.append("Carbohydrates cannot be negative") }
        if fiber < 0 { errors.append("Fiber cannot be negative") }
        if sugar < 0 { errors.append("Sugar cannot be negative") }
        if protein < 0 { errors.append("Protein cannot be negative") }
        if fat < 0 { errors.append("Fat cannot be negative") }
        if glycemicLoad < 0 { errors.append("Glycemic load cannot be negative") }

        // Check macro relationships
        if fiber > carbohydrates {
            errors.append("Fiber (\(fiber)g) exceeds total carbohydrates (\(carbohydrates)g)")
        }
        if sugar > carbohydrates {
            errors.append("Sugar (\(sugar)g) exceeds total carbohydrates (\(carbohydrates)g)")
        }

        // Validate 4-4-9 rule (with 10% tolerance for rounding)
        let calculatedCalories = (carbohydrates * 4) + (protein * 4) + (fat * 9)
        let diff = abs(calculatedCalories - calories)
        let tolerance = calories * 0.10  // 10% tolerance
        if diff > tolerance && calories > 0 {
            errors.append("Calorie mismatch: calculated \(Int(calculatedCalories)) vs reported \(Int(calories))")
        }

        return errors
    }
}

// MARK: - Double Extension for Rounding

extension Double {
    /// Round to specified decimal places
    ///
    /// - Parameter places: Number of decimal places (0-10)
    /// - Returns: Rounded value
    ///
    /// # Example
    /// ```swift
    /// let value = 123.456789
    /// value.rounded(toPlaces: 0)  // 123.0
    /// value.rounded(toPlaces: 1)  // 123.5
    /// value.rounded(toPlaces: 2)  // 123.46
    /// ```
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}
