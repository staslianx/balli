//
//  RecipeGenerationViewHelper.swift
//  balli
//
//  Helper methods for RecipeGenerationView UI coordination
//  Extracted for single responsibility and testability
//

import Foundation
import OSLog

/// Helper for RecipeGenerationView UI coordination logic
struct RecipeGenerationViewHelper {
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.balli",
        category: "RecipeGenerationViewHelper"
    )

    // MARK: - Manual Recipe Building

    /// Build markdown content from manual ingredients and steps
    func buildManualRecipeContent(
        ingredients: [RecipeItem],
        steps: [RecipeItem]
    ) -> (content: String, ingredientList: [String], directions: [String]) {
        var sections: [String] = []
        var ingredientList: [String] = []
        var directions: [String] = []

        if !ingredients.isEmpty {
            var ingredientLines = ["## Malzemeler", "---"]
            ingredientLines.append(contentsOf: ingredients.map { "- \($0.text)" })
            sections.append(ingredientLines.joined(separator: "\n"))
            ingredientList = ingredients.map { $0.text }
        }

        if !steps.isEmpty {
            var stepLines = ["## Yapılışı", "---"]
            stepLines.append(contentsOf: steps.enumerated().map { "\($0.offset + 1). \($0.element.text)" })
            sections.append(stepLines.joined(separator: "\n"))
            directions = steps.map { $0.text }
        }

        let content = sections.joined(separator: "\n\n")
        return (content, ingredientList, directions)
    }

    /// Generate a default name for manually entered recipes
    func generateDefaultRecipeName(from ingredients: [RecipeItem]) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd MMM"
        dateFormatter.locale = Locale(identifier: "tr_TR")
        let dateString = dateFormatter.string(from: Date())

        // Try to infer recipe type from first ingredient
        if let firstIngredient = ingredients.first?.text.lowercased() {
            let ingredientWords = firstIngredient.components(separatedBy: " ")
            let commonIngredients = [
                "tavuk": "Tavuk",
                "balık": "Balık",
                "et": "Et",
                "sebze": "Sebze",
                "salata": "Salata",
                "çorba": "Çorba",
                "makarna": "Makarna",
                "pilav": "Pilav",
                "börek": "Börek",
                "tatlı": "Tatlı"
            ]

            for (key, value) in commonIngredients {
                if ingredientWords.contains(key) {
                    return "\(value) Tarifi - \(dateString)"
                }
            }
        }

        return "Manuel Tarif - \(dateString)"
    }

    // MARK: - Nutrition Handling

    /// Check if nutrition data exists
    func hasNutritionData(calories: String, carbohydrates: String, protein: String) -> Bool {
        return !calories.isEmpty && !carbohydrates.isEmpty && !protein.isEmpty
    }
}
