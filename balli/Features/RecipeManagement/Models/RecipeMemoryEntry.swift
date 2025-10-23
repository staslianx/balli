//
//  RecipeMemoryEntry.swift
//  balli
//
//  Created by Claude Code
//  Recipe memory system - Stores minimal recipe data for similarity checking
//

import Foundation

/// Represents a single recipe entry in the memory system
/// Stores only essential data: main ingredients, timestamp, and category
struct RecipeMemoryEntry: Codable, Sendable, Equatable {
    /// 3-5 key ingredients in Turkish (normalized: lowercase, trimmed, singular)
    /// Includes: primary protein, 2-3 main vegetables, defining flavor component
    /// Excludes: common seasonings (tuz, karabiber, zeytinyağı), water, measurements
    let mainIngredients: [String]

    /// When this recipe was generated
    let dateGenerated: Date

    /// The subcategory this recipe belongs to
    let subcategory: RecipeSubcategory

    /// Optional recipe name for debugging/analytics
    let recipeName: String?

    // MARK: - Initialization

    init(
        mainIngredients: [String],
        dateGenerated: Date = Date(),
        subcategory: RecipeSubcategory,
        recipeName: String? = nil
    ) {
        // Normalize all ingredients during initialization
        self.mainIngredients = mainIngredients.map { Self.normalizeIngredient($0) }
        self.dateGenerated = dateGenerated
        self.subcategory = subcategory
        self.recipeName = recipeName
    }

    // MARK: - Ingredient Normalization

    /// Normalizes an ingredient name for consistent matching
    /// - Converts to lowercase
    /// - Trims whitespace
    /// - Applies consistent naming conventions
    static func normalizeIngredient(_ ingredient: String) -> String {
        var normalized = ingredient
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Apply consistent naming conventions for common variations
        let replacements: [String: String] = [
            "piliç": "tavuk",
            "hindi": "tavuk",  // Unless specifically turkey
            "peynir": "beyaz peynir",  // Be specific
            "domates": "domates",  // Ensure singular
            "domatesler": "domates",
            "brokoli": "brokoli",
            "brokoliler": "brokoli"
        ]

        if let standardName = replacements[normalized] {
            normalized = standardName
        }

        return normalized
    }

    // MARK: - Similarity Checking

    /// Checks if this entry shares 3 or more ingredients with another entry
    /// - Parameter other: The other memory entry to compare against
    /// - Returns: true if 3+ ingredients overlap (indicating too similar)
    func isSimilarTo(_ other: RecipeMemoryEntry) -> Bool {
        let commonIngredients = Set(mainIngredients).intersection(Set(other.mainIngredients))
        return commonIngredients.count >= 3
    }

    /// Checks if this entry shares 3 or more ingredients with a list of ingredients
    /// - Parameter ingredients: The ingredient list to compare against
    /// - Returns: true if 3+ ingredients overlap
    func isSimilarTo(ingredients: [String]) -> Bool {
        let normalizedIngredients = ingredients.map { Self.normalizeIngredient($0) }
        let commonIngredients = Set(mainIngredients).intersection(Set(normalizedIngredients))
        return commonIngredients.count >= 3
    }
}

// MARK: - Convenience Extensions

extension RecipeMemoryEntry {
    /// Creates a simple combo string for basic similarity checking
    /// Format: "protein-primaryVegetable" (e.g., "tavuk-brokoli")
    var comboString: String? {
        guard mainIngredients.count >= 2 else { return nil }
        return "\(mainIngredients[0])-\(mainIngredients[1])"
    }

    /// Returns a debug-friendly description
    var debugDescription: String {
        let ingredientsStr = mainIngredients.joined(separator: ", ")
        let dateStr = ISO8601DateFormatter().string(from: dateGenerated)
        return "\(recipeName ?? "Unknown") [\(subcategory.rawValue)]: \(ingredientsStr) @ \(dateStr)"
    }
}

// MARK: - Storage Container

/// Container for all memory entries organized by subcategory
struct RecipeMemoryStorage: Codable {
    /// Dictionary mapping subcategory raw value to array of memory entries
    var entries: [String: [RecipeMemoryEntry]]

    init() {
        self.entries = [:]
    }

    /// Get entries for a specific subcategory
    subscript(subcategory: RecipeSubcategory) -> [RecipeMemoryEntry] {
        get {
            return entries[subcategory.rawValue] ?? []
        }
        set {
            entries[subcategory.rawValue] = newValue
        }
    }

    /// Get the most recent N entries for a subcategory
    func recentEntries(for subcategory: RecipeSubcategory, limit: Int) -> [RecipeMemoryEntry] {
        let all = self[subcategory]
        return Array(all.sorted(by: { $0.dateGenerated > $1.dateGenerated }).prefix(limit))
    }
}
