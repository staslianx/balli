//
//  RecipeManualEntryService.swift
//  balli
//
//  Handles manual recipe entry building and formatting
//  Converts RecipeItem arrays to markdown format
//  Swift 6 strict concurrency compliant
//

import Foundation
import OSLog

/// Service for building manual recipe content from user input
/// Handles conversion from RecipeItem arrays to structured markdown
@MainActor
final class RecipeManualEntryService {
    // MARK: - Dependencies

    private let helper: RecipeGenerationViewHelper
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.balli",
        category: "RecipeManualEntryService"
    )

    // MARK: - Initialization

    init(helper: RecipeGenerationViewHelper = RecipeGenerationViewHelper()) {
        self.helper = helper
    }

    // MARK: - Manual Recipe Building

    /// Build markdown recipe content from manual ingredients and steps
    /// Returns structured content ready for recipe storage
    func buildManualRecipeContent(
        ingredients: [RecipeItem],
        steps: [RecipeItem]
    ) -> (content: String, ingredientList: [String], directions: [String]) {
        logger.info("🔨 [SERVICE] Building manual recipe content")
        logger.info("📝 [SERVICE] Ingredients: \(ingredients.count), Steps: \(steps.count)")

        let result = helper.buildManualRecipeContent(
            ingredients: ingredients,
            steps: steps
        )

        logger.info("✅ [SERVICE] Built content: \(result.content.count) chars, \(result.ingredientList.count) ingredients, \(result.directions.count) steps")

        return result
    }

    /// Generate a default name for manually entered recipes
    /// Uses ingredient list to create descriptive name
    func generateDefaultRecipeName(from ingredients: [RecipeItem]) -> String {
        logger.info("📝 [SERVICE] Generating default recipe name from \(ingredients.count) ingredients")

        let name = helper.generateDefaultRecipeName(from: ingredients)

        logger.info("✅ [SERVICE] Generated name: '\(name)'")

        return name
    }

    /// Check if manual recipe has any content
    func hasManualContent(ingredients: [RecipeItem], steps: [RecipeItem]) -> Bool {
        return !ingredients.isEmpty || !steps.isEmpty
    }
}
