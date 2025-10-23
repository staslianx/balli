//
//  RecipeValidationService.swift
//  balli
//
//  Recipe validation logic extracted from RecipeViewModel
//  Validates nutrition values and business rules
//  Swift 6 strict concurrency compliant
//

import Foundation

/// Result of validation with success or error message
public enum ValidationResult {
    case success
    case failure(String)

    public var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }

    public var errorMessage: String? {
        if case .failure(let message) = self { return message }
        return nil
    }
}

/// Service for validating recipe data
@MainActor
public final class RecipeValidationService {
    private let dataManager: RecipeDataManager

    public init(dataManager: RecipeDataManager) {
        self.dataManager = dataManager
    }

    // MARK: - Validation

    /// Validate nutrition values (carbs, fiber, sugar relationships)
    public func validateNutritionValues(
        carbohydrates: String,
        fiber: String,
        sugar: String
    ) -> ValidationResult {
        let result = dataManager.validateNutritionValues(
            carbohydrates: carbohydrates,
            fiber: fiber,
            sugar: sugar
        )

        // Convert RecipeValidationResult to ValidationResult
        switch result {
        case .success:
            return .success
        case .failure(let message):
            return .failure(message)
        }
    }

    /// Validate recipe has minimum required data
    public func validateMinimumData(recipeName: String, ingredients: [String], directions: [String]) -> ValidationResult {
        let hasName = !recipeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasIngredients = !ingredients.allSatisfy { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let hasDirections = !directions.allSatisfy { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        if !hasName {
            return .failure("Recipe name is required")
        }
        if !hasIngredients {
            return .failure("At least one ingredient is required")
        }
        if !hasDirections {
            return .failure("At least one direction is required")
        }

        return .success
    }

    /// Validate all recipe data before save
    public func validateRecipe(
        recipeName: String,
        ingredients: [String],
        directions: [String],
        carbohydrates: String,
        fiber: String,
        sugar: String
    ) -> ValidationResult {
        // Validate minimum data
        let minimumResult = validateMinimumData(
            recipeName: recipeName,
            ingredients: ingredients,
            directions: directions
        )
        if !minimumResult.isSuccess {
            return minimumResult
        }

        // Validate nutrition values
        return validateNutritionValues(
            carbohydrates: carbohydrates,
            fiber: fiber,
            sugar: sugar
        )
    }
}
