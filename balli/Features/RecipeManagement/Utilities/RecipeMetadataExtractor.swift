//
//  RecipeMetadataExtractor.swift
//  balli
//
//  Extracts metadata from recipe responses for diversity tracking
//  Identifies cooking methods and main ingredients from Turkish recipes
//  Swift 6 strict concurrency compliant
//

import Foundation

/// Extracts cooking method and main ingredient from recipe data
enum RecipeMetadataExtractor {

    // MARK: - Cooking Method Extraction

    /// Extract cooking method from recipe name using Turkish keywords
    /// - Parameter recipeName: The Turkish recipe name
    /// - Returns: Cooking method (e.g., "Fırın", "Tava", "Haşlama")
    static func extractCookingMethod(from recipeName: String) -> String {
        let lowerName = recipeName.lowercased()

        // Turkish cooking method keywords (ordered by specificity)
        let cookingMethods: [(keyword: String, method: String)] = [
            // Specific cooking methods
            ("fırın", "Fırın"),
            ("fırında", "Fırın"),
            ("ızgara", "Izgara"),
            ("izgara", "Izgara"),
            ("kızart", "Kızartma"),
            ("tava", "Tava"),
            ("kavur", "Kavurma"),
            ("haşla", "Haşlama"),
            ("buğu", "Buharda"),
            ("sote", "Sote"),
            ("güveç", "Güveç"),

            // Dish types that imply cooking method
            ("çorba", "Çorba"),
            ("salata", "Salata"),
            ("smoothie", "Karıştırma"),
            ("shake", "Karıştırma"),
            ("yoğurt", "Karıştırma"),

            // Preparation styles
            ("dolma", "Dolma"),
            ("sarma", "Sarma"),
            ("köfte", "Yoğurma"),
            ("börek", "Fırın"),
            ("pilav", "Haşlama"),
            ("mantı", "Haşlama")
        ]

        // Find first matching keyword
        for (keyword, method) in cookingMethods {
            if lowerName.contains(keyword) {
                return method
            }
        }

        // Default if no method detected
        return "Diğer"
    }

    // MARK: - Main Ingredient Extraction

    /// Extract main ingredient from ingredients array
    /// Uses first ingredient, stripped of quantities
    /// - Parameter ingredients: Array of ingredient strings
    /// - Returns: Main ingredient name (e.g., "Tavuk Göğsü", "Yumurta")
    static func extractMainIngredient(from ingredients: [String]) -> String {
        guard let firstIngredient = ingredients.first,
              !firstIngredient.isEmpty else {
            return "Bilinmiyor"
        }

        // Clean the ingredient string
        let cleaned = cleanIngredientString(firstIngredient)

        // Return cleaned ingredient or fallback
        return cleaned.isEmpty ? "Bilinmiyor" : cleaned
    }

    // MARK: - Private Helpers

    /// Remove quantities, units, and extra details from ingredient string
    /// - Parameter ingredient: Raw ingredient string (e.g., "200 gr tavuk göğsü, küp doğranmış")
    /// - Returns: Cleaned ingredient name (e.g., "Tavuk Göğsü")
    private static func cleanIngredientString(_ ingredient: String) -> String {
        var cleaned = ingredient

        // Remove common Turkish units and quantities
        let unitsToRemove = [
            // Weight units
            "gr", "gram", "kg", "kilogram", "mg",
            // Volume units
            "ml", "lt", "litre", "su bardağı", "çay bardağı", "yemek kaşığı", "tatlı kaşığı", "çay kaşığı",
            // Count units
            "adet", "demet", "dal", "diş", "parça", "dilim", "tutam"
        ]

        // Remove numbers and units at the beginning
        // Pattern: "200 gr" or "2 adet" or "1,5 su bardağı"
        let quantityPattern = "^[0-9,\\.\\s]+"
        if let regex = try? NSRegularExpression(pattern: quantityPattern) {
            let range = NSRange(cleaned.startIndex..., in: cleaned)
            cleaned = regex.stringByReplacingMatches(in: cleaned, range: range, withTemplate: "")
        }

        // Remove units
        for unit in unitsToRemove {
            cleaned = cleaned.replacingOccurrences(of: unit, with: "", options: .caseInsensitive)
        }

        // Remove preparation notes after comma (e.g., ", küp doğranmış")
        if let commaIndex = cleaned.firstIndex(of: ",") {
            cleaned = String(cleaned[..<commaIndex])
        }

        // Remove parenthetical notes (e.g., "(opsiyonel)")
        if let parenIndex = cleaned.firstIndex(of: "(") {
            cleaned = String(cleaned[..<parenIndex])
        }

        // Clean up whitespace and capitalize properly
        cleaned = cleaned
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .capitalizingFirstLetter()

        return cleaned
    }
}

// MARK: - String Extension

private extension String {
    /// Capitalize only the first letter, leave rest as-is
    /// This preserves Turkish capitalization (e.g., "tavuk göğsü" → "Tavuk göğsü")
    func capitalizingFirstLetter() -> String {
        guard !isEmpty else { return self }
        return prefix(1).uppercased() + dropFirst()
    }
}
