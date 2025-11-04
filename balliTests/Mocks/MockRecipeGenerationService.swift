//
//  MockRecipeGenerationService.swift
//  balliTests
//
//  Mock implementation of RecipeGenerationServiceProtocol for testing
//

import Foundation
@testable import balli

actor MockRecipeGenerationService: RecipeGenerationServiceProtocol {

    // MARK: - Mock Configuration

    var shouldSucceedGeneration = true
    var shouldSucceedIngredientsGeneration = true
    var mockResponse: RecipeGenerationResponse?
    var mockError: Error?

    // MARK: - Call Tracking

    private(set) var generateSpontaneousRecipeCallCount = 0
    private(set) var generateRecipeFromIngredientsCallCount = 0

    private(set) var lastMealType: String?
    private(set) var lastStyleType: String?
    private(set) var lastUserId: String?
    private(set) var lastRecentRecipes: [SimpleRecentRecipe]?
    private(set) var lastDiversityConstraints: DiversityConstraints?
    private(set) var lastUserContext: String?
    private(set) var lastIngredients: [String]?

    // MARK: - Protocol Implementation

    func generateSpontaneousRecipe(
        mealType: String,
        styleType: String,
        userId: String? = nil,
        recentRecipes: [SimpleRecentRecipe] = [],
        diversityConstraints: DiversityConstraints? = nil,
        userContext: String? = nil
    ) async throws -> RecipeGenerationResponse {
        generateSpontaneousRecipeCallCount += 1
        lastMealType = mealType
        lastStyleType = styleType
        lastUserId = userId
        lastRecentRecipes = recentRecipes
        lastDiversityConstraints = diversityConstraints
        lastUserContext = userContext

        if let error = mockError {
            throw error
        }

        guard shouldSucceedGeneration else {
            throw NetworkError.serverError(statusCode: 500, message: "Mock generation failed")
        }

        if let response = mockResponse {
            return response
        }

        // Return default mock response
        return Self.createMockRecipe(
            name: "Mock \(styleType) Recipe",
            mealType: mealType
        )
    }

    func generateRecipeFromIngredients(
        mealType: String,
        styleType: String,
        ingredients: [String],
        userId: String? = nil,
        userContext: String? = nil
    ) async throws -> RecipeGenerationResponse {
        generateRecipeFromIngredientsCallCount += 1
        lastMealType = mealType
        lastStyleType = styleType
        lastIngredients = ingredients
        lastUserId = userId
        lastUserContext = userContext

        if let error = mockError {
            throw error
        }

        guard shouldSucceedIngredientsGeneration else {
            throw NetworkError.serverError(statusCode: 500, message: "Mock ingredients generation failed")
        }

        if let response = mockResponse {
            return response
        }

        // Return default mock response with ingredients
        return Self.createMockRecipe(
            name: "Mock Recipe with \(ingredients.joined(separator: ", "))",
            mealType: mealType
        )
    }

    // MARK: - Test Helpers

    func reset() {
        shouldSucceedGeneration = true
        shouldSucceedIngredientsGeneration = true
        mockResponse = nil
        mockError = nil
        generateSpontaneousRecipeCallCount = 0
        generateRecipeFromIngredientsCallCount = 0
        lastMealType = nil
        lastStyleType = nil
        lastUserId = nil
        lastRecentRecipes = nil
        lastDiversityConstraints = nil
        lastUserContext = nil
        lastIngredients = nil
    }

    static func createMockRecipe(name: String, mealType: String) -> RecipeGenerationResponse {
        RecipeGenerationResponse(
            recipeName: name,
            prepTime: "15 dakika",
            cookTime: "20 dakika",
            ingredients: ["Mock ingredient 1", "Mock ingredient 2"],
            directions: ["Step 1", "Step 2"],
            notes: "Mock notes",
            recipeContent: "# \(name)\n\n## Malzemeler\n- Mock ingredient 1\n- Mock ingredient 2",
            calories: "350",
            carbohydrates: "45g",
            fiber: "8g",
            protein: "15g",
            fat: "12g",
            sugar: "5g",
            glycemicLoad: "12",
            extractedIngredients: ["ingredient1", "ingredient2"]
        )
    }
}
