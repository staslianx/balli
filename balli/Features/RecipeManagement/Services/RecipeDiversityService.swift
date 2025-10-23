//
//  RecipeDiversityService.swift
//  balli
//
//  Manages recipe diversity by tracking recent recipes per (mealType, styleType)
//  Uses UserDefaults for simple, lightweight storage
//  Maintains last 25 recipes per category combination
//  Swift 6 strict concurrency compliant
//

import Foundation
import OSLog

/// Actor for thread-safe recipe diversity tracking
public actor RecipeDiversityService {
    // MARK: - Singleton
    public static let shared = RecipeDiversityService()

    // MARK: - Constants
    private let userDefaultsKey = "balli.recentRecipes"
    private let maxRecipesPerCategory = 25
    private let logger = AppLoggers.Recipe.generation

    // MARK: - Initialization
    private init() {}

    // MARK: - Public Methods

    /// Load recent recipes for a specific (mealType, styleType) combination
    /// - Parameters:
    ///   - mealType: The meal type (e.g., "Kahvaltı", "Akşam Yemeği")
    ///   - styleType: The style type (e.g., "Geleneksel", "Protein Ağırlıklı")
    /// - Returns: Array of recent recipes for this category (max 25)
    public func loadRecentRecipes(mealType: String, styleType: String) -> [RecentRecipe] {
        let categoryKey = "\(mealType):\(styleType)"
        let allRecipes = loadAllRecipes()
        let categoryRecipes = allRecipes[categoryKey] ?? []

        logger.debug("📖 Loaded \(categoryRecipes.count) recent recipes for category: \(categoryKey)")
        return categoryRecipes
    }

    /// Save a new recipe to history for its category
    /// Automatically maintains 25-recipe limit per category
    /// - Parameter recipe: The recipe to save (includes mealType and styleType)
    public func saveRecipe(_ recipe: RecentRecipe) {
        let categoryKey = recipe.categoryKey
        var allRecipes = loadAllRecipes()

        // Get or create category list
        var categoryRecipes = allRecipes[categoryKey] ?? []

        // Add new recipe to beginning
        categoryRecipes.insert(recipe, at: 0)

        // Trim to max 25 recipes
        if categoryRecipes.count > maxRecipesPerCategory {
            categoryRecipes = Array(categoryRecipes.prefix(maxRecipesPerCategory))
        }

        // Update category
        allRecipes[categoryKey] = categoryRecipes

        // Save back to UserDefaults
        saveAllRecipes(allRecipes)

        logger.info("💾 Saved recipe to history: \(recipe.title) in category: \(categoryKey)")
        logger.debug("   Category now has \(categoryRecipes.count) recipes")
    }

    /// Clear all recipe history (for testing or user reset)
    public func clearHistory() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        logger.warning("🗑️ Cleared all recipe history")
    }

    /// Clear history for a specific category
    /// - Parameters:
    ///   - mealType: The meal type to clear
    ///   - styleType: The style type to clear
    public func clearCategory(mealType: String, styleType: String) {
        let categoryKey = "\(mealType):\(styleType)"
        var allRecipes = loadAllRecipes()
        allRecipes.removeValue(forKey: categoryKey)
        saveAllRecipes(allRecipes)

        logger.info("🗑️ Cleared recipe history for category: \(categoryKey)")
    }

    /// Get statistics about stored recipes
    /// - Returns: Dictionary with category keys and recipe counts
    public func getStatistics() -> [String: Int] {
        let allRecipes = loadAllRecipes()
        return allRecipes.mapValues { $0.count }
    }

    // MARK: - Private Methods

    /// Load all recipes from UserDefaults
    /// - Returns: Dictionary mapping category keys to recipe arrays
    private func loadAllRecipes() -> [String: [RecentRecipe]] {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else {
            logger.debug("No existing recipe history found")
            return [:]
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let recipes = try decoder.decode([String: [RecentRecipe]].self, from: data)
            return recipes
        } catch {
            logger.error("Failed to decode recipe history: \(error.localizedDescription)")
            return [:]
        }
    }

    /// Save all recipes to UserDefaults
    /// - Parameter recipes: Dictionary mapping category keys to recipe arrays
    private func saveAllRecipes(_ recipes: [String: [RecentRecipe]]) {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(recipes)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
            logger.debug("✅ Successfully saved recipe history to UserDefaults")
        } catch {
            logger.error("Failed to encode recipe history: \(error.localizedDescription)")
        }
    }
}
