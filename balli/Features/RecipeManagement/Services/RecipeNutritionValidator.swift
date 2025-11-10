import Foundation
import OSLog

/// Validates nutrition data from AI-generated recipes to ensure physiologically reasonable values
/// and prevent dangerous medical advice from invalid data.
struct RecipeNutritionValidator {
    private static let logger = AppLoggers.Recipe.generation

    // MARK: - Physiologically Reasonable Ranges

    /// Valid ranges for nutrition values per serving
    /// Based on standard meal composition and physiological limits
    private static let validRanges: [String: ClosedRange<Double>] = [
        "carbohydrates": 0...200,    // 0-200g per serving (typical meal: 30-80g)
        "protein": 0...150,          // 0-150g per serving (typical: 20-50g)
        "fat": 0...100,              // 0-100g per serving (typical: 10-40g)
        "fiber": 0...50,             // 0-50g per serving (typical: 3-15g)
        "sugar": 0...150,            // 0-150g per serving (can be high for desserts)
        "calories": 0...2000,        // 0-2000 kcal per serving (typical: 300-800)
        "glycemicLoad": 0...100      // 0-100 GL (low: <10, medium: 10-20, high: >20)
    ]

    // MARK: - Validation

    /// Validates all nutrition values in a recipe generation response
    /// - Parameter response: The AI-generated recipe response
    /// - Returns: Array of validation error messages (empty if valid)
    static func validate(_ response: RecipeGenerationResponse) -> [String] {
        var errors: [String] = []

        // Validate each nutrition field
        errors.append(contentsOf: validateField("carbohydrates", value: response.carbohydrates))
        errors.append(contentsOf: validateField("protein", value: response.protein))
        errors.append(contentsOf: validateField("fat", value: response.fat))
        errors.append(contentsOf: validateField("fiber", value: response.fiber))
        errors.append(contentsOf: validateField("sugar", value: response.sugar))
        errors.append(contentsOf: validateField("calories", value: response.calories))
        errors.append(contentsOf: validateField("glycemicLoad", value: response.glycemicLoad))

        // Validate relationships between nutrition values
        errors.append(contentsOf: validateNutritionRelationships(response))

        if !errors.isEmpty {
            logger.error("⚠️ Nutrition validation failed: \(errors.joined(separator: "; "))")
        }

        return errors
    }

    // MARK: - Private Helpers

    /// Validates a single nutrition field against physiological bounds
    private static func validateField(_ fieldName: String, value: String) -> [String] {
        var errors: [String] = []

        // Check if value is empty
        guard !value.isEmpty else {
            errors.append("\(fieldName.capitalized) is missing")
            return errors
        }

        // Check if value is a valid number
        guard let numericValue = Double(value) else {
            errors.append("\(fieldName.capitalized) is not a valid number: '\(value)'")
            return errors
        }

        // Check for special numeric values
        if numericValue.isNaN {
            errors.append("\(fieldName.capitalized) is NaN (not a number)")
            return errors
        }

        if numericValue.isInfinite {
            errors.append("\(fieldName.capitalized) is infinite")
            return errors
        }

        // Check if value is within physiological range
        if let range = validRanges[fieldName] {
            if !range.contains(numericValue) {
                errors.append("\(fieldName.capitalized) out of range: \(numericValue)g (expected \(range.lowerBound)-\(range.upperBound)g)")
            }
        }

        return errors
    }

    /// Validates relationships between nutrition values (e.g., fiber can't exceed total carbs)
    private static func validateNutritionRelationships(_ response: RecipeGenerationResponse) -> [String] {
        var errors: [String] = []

        // Parse values for relationship checks
        let carbs = Double(response.carbohydrates)
        let fiber = Double(response.fiber)
        let sugar = Double(response.sugar)
        let protein = Double(response.protein)
        let fat = Double(response.fat)
        let calories = Double(response.calories)

        // Relationship 1: Fiber cannot exceed total carbohydrates
        if let fiberValue = fiber, let carbsValue = carbs {
            if fiberValue > carbsValue {
                errors.append("Fiber (\(fiberValue)g) exceeds total carbohydrates (\(carbsValue)g) - physiologically impossible")
            }
        }

        // Relationship 2: Sugar cannot exceed total carbohydrates
        if let sugarValue = sugar, let carbsValue = carbs {
            if sugarValue > carbsValue {
                errors.append("Sugar (\(sugarValue)g) exceeds total carbohydrates (\(carbsValue)g) - physiologically impossible")
            }
        }

        // Relationship 3: Calorie calculation sanity check (4 cal/g carbs, 4 cal/g protein, 9 cal/g fat)
        if let carbsValue = carbs, let proteinValue = protein, let fatValue = fat, let caloriesValue = calories {
            let calculatedCalories = (carbsValue * 4) + (proteinValue * 4) + (fatValue * 9)
            let tolerance = calculatedCalories * 0.3 // Allow 30% variance

            if abs(caloriesValue - calculatedCalories) > tolerance {
                errors.append("Calorie mismatch: reported \(Int(caloriesValue)) kcal but calculated ~\(Int(calculatedCalories)) kcal from macros (difference exceeds 30% tolerance)")
            }
        }

        return errors
    }
}
