//
//  RecipeFormState.swift
//  balli
//
//  Centralized recipe form data model
//  Separates data from business logic for better testability
//  Swift 6 strict concurrency compliant
//

import Foundation
import SwiftUI

/// Holds all recipe form field data in a single, cohesive structure
@MainActor
public final class RecipeFormState: ObservableObject {
    // MARK: - Recipe Information
    @Published public var recipeName = ""
    @Published public var prepTime = ""
    @Published public var cookTime = ""
    @Published public var ingredients: [String] = [""]
    @Published public var directions: [String] = [""]
    @Published public var notes = ""
    @Published public var recipeContent = ""  // Markdown content for streaming (ingredients + directions)

    // MARK: - Nutrition Information
    @Published public var calories = ""
    @Published public var carbohydrates = ""
    @Published public var fiber = ""
    @Published public var protein = ""
    @Published public var fat = ""
    @Published public var sugar = ""
    @Published public var glycemicLoad = ""

    // MARK: - Serving Size
    // Note: Nutrition values from AI are per 100g (standard)
    // We store the actual gram amount directly for precise slider control
    @Published public var portionGrams: Double = 100.0  // Current portion in grams (5-300g range)

    // Deprecated - kept for backward compatibility, computed from portionGrams
    public var baseServings: Int16 { 1 }  // Always 1 (nutrition is per 100g)
    public var currentServings: Int16 { Int16(portionGrams / 100.0) }  // Computed from grams

    public init() {}

    // MARK: - Computed Properties

    /// Check if recipe has sufficient data for operations
    /// Supports both modern markdown format and legacy array format
    public var hasRecipeData: Bool {
        // Must have recipe name
        guard !recipeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }

        // NEW FORMAT: Check if markdown content exists (modern streaming recipes)
        if !recipeContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return true
        }

        // LEGACY FORMAT: Check if arrays have content (older recipes)
        return !ingredients.allSatisfy { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } &&
               !directions.allSatisfy { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    /// Check if shopping list can be created
    public var canCreateShoppingList: Bool {
        let hasValidIngredients = ingredients.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let hasTitle = !recipeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return hasValidIngredients && hasTitle
    }

    // MARK: - Content Management

    public func addIngredient() {
        ingredients.append("")
    }

    public func removeIngredient(at index: Int) {
        guard ingredients.count > 1 && index < ingredients.count else { return }
        ingredients.remove(at: index)
    }

    public func updateIngredient(at index: Int, newValue: String) {
        guard ingredients.indices.contains(index) else {
            print("⚠️ Warning: Attempted to update ingredient at invalid index \(index)")
            return
        }
        ingredients[index] = newValue
    }

    public func addDirection() {
        directions.append("")
    }

    public func removeDirection(at index: Int) {
        guard directions.count > 1 && index < directions.count else { return }
        directions.remove(at: index)
    }

    public func clearAll() {
        recipeName = ""
        prepTime = ""
        cookTime = ""
        ingredients = [""]
        directions = [""]
        notes = ""
        recipeContent = ""
        calories = ""
        carbohydrates = ""
        fiber = ""
        protein = ""
        fat = ""
        sugar = ""
        glycemicLoad = ""
        portionGrams = 100.0  // Reset to 100g default
    }

    // MARK: - Data Loading

    /// Load recipe data from Core Data entity
    /// Uses a transaction to batch all property updates and prevent flickering
    public func loadFromRecipe(_ recipe: Recipe) {
        // PERFORMANCE FIX: Wrap all updates in withAnimation(.none) to prevent flickering
        // This batches the updates and prevents 14 separate view re-renders
        withAnimation(.none) {
            recipeName = recipe.name
            prepTime = recipe.prepTime > 0 ? String(recipe.prepTime) : ""
            cookTime = recipe.cookTime > 0 ? String(recipe.cookTime) : ""

            if let ingredientsArray = recipe.ingredients as? [String] {
                ingredients = ingredientsArray.isEmpty ? [""] : ingredientsArray
            }

            if let directionsArray = recipe.instructions as? [String] {
                directions = directionsArray.isEmpty ? [""] : directionsArray
            }

            notes = recipe.notes ?? ""
            calories = recipe.calories > 0 ? String(Int(recipe.calories)) : ""
            carbohydrates = recipe.totalCarbs > 0 ? String(Int(recipe.totalCarbs)) : ""
            fiber = recipe.fiber > 0 ? String(Int(recipe.fiber)) : ""
            protein = recipe.protein > 0 ? String(Int(recipe.protein)) : ""
            fat = recipe.totalFat > 0 ? String(Int(recipe.totalFat)) : ""
            sugar = recipe.sugars > 0 ? String(Int(recipe.sugars)) : ""
            glycemicLoad = recipe.glycemicLoad > 0 ? String(Int(recipe.glycemicLoad)) : ""
            portionGrams = 100.0  // Nutrition values are per 100g (standard)
        }
    }

    /// Load recipe data from generation response
    /// Uses a transaction to batch all property updates and prevent flickering
    public func loadFromGenerationResponse(_ response: RecipeGenerationResponse) {
        // PERFORMANCE FIX: Wrap all updates in withAnimation(.none) to prevent flickering
        // This batches the updates and prevents 14 separate view re-renders that cause text stuttering
        withAnimation(.none) {
            recipeName = response.recipeName
            prepTime = response.prepTime
            cookTime = response.cookTime

            // NEW FORMAT: Use recipeContent if available (markdown), otherwise fall back to legacy arrays
            if let content = response.recipeContent, !content.isEmpty {
                recipeContent = content
                // Keep legacy arrays empty for new format
                ingredients = [""]
                directions = [""]
            } else {
                // Legacy format: structured arrays
                ingredients = response.ingredients.isEmpty ? [""] : response.ingredients
                directions = response.directions.isEmpty ? [""] : response.directions
                recipeContent = ""
            }

            notes = response.notes
            calories = response.calories
            carbohydrates = response.carbohydrates
            fiber = response.fiber
            protein = response.protein
            fat = response.fat
            sugar = response.sugar
            glycemicLoad = response.glycemicLoad
            portionGrams = 100.0  // Nutrition values from AI are per 100g (standard)
        }
    }
}
