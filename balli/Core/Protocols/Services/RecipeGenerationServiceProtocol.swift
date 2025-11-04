//
//  RecipeGenerationServiceProtocol.swift
//  balli
//
//  Protocol definition for RecipeGenerationService
//  Enables dependency injection and testing
//

import Foundation

/// Protocol for AI-powered recipe generation service
public protocol RecipeGenerationServiceProtocol: Actor, Sendable {

    // MARK: - Recipe Generation

    /// Generate a spontaneous recipe based on meal type and style
    /// - Parameters:
    ///   - mealType: The type of meal (e.g., "Kahvaltı", "Akşam Yemeği")
    ///   - styleType: The style subcategory for the meal type
    ///   - userId: Optional user ID for personalization
    ///   - recentRecipes: Recent recipes for diversity (empty array = no diversity constraints)
    ///   - diversityConstraints: Constraints for avoiding overused ingredients/proteins
    ///   - userContext: Optional user context or notes for recipe generation
    /// - Returns: Generated recipe with all fields populated
    /// - Throws: NetworkError if the request fails
    func generateSpontaneousRecipe(
        mealType: String,
        styleType: String,
        userId: String?,
        recentRecipes: [SimpleRecentRecipe],
        diversityConstraints: DiversityConstraints?,
        userContext: String?
    ) async throws -> RecipeGenerationResponse

    /// Generate recipe with ingredient suggestions based on meal type and style
    /// - Parameters:
    ///   - mealType: The type of meal (e.g., "Kahvaltı", "Akşam Yemeği")
    ///   - styleType: The style subcategory for the meal type
    ///   - ingredients: Available ingredients to use in the recipe
    ///   - userId: Optional user ID for personalization
    ///   - userContext: Optional user context or notes for recipe generation
    /// - Returns: Generated recipe incorporating the provided ingredients
    /// - Throws: NetworkError if the request fails
    func generateRecipeFromIngredients(
        mealType: String,
        styleType: String,
        ingredients: [String],
        userId: String?,
        userContext: String?
    ) async throws -> RecipeGenerationResponse
}
