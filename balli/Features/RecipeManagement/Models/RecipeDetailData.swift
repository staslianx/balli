//
//  RecipeDetailData.swift
//  balli
//
//  Recipe detail display model with additional properties for rich UI
//  Wraps Core Data Recipe with presentation-specific data
//

import Foundation

/// Display model for recipe detail view with additional UI-specific properties
struct RecipeDetailData {
    // Core recipe reference
    let recipe: Recipe

    // Additional display properties
    let recipeSource: String?     // e.g., "Better Homes & Gardens"
    let author: String?            // e.g., "Danielle Centoni"
    let yieldText: String?         // e.g., "4"
    let recipeDescription: String? // Full description text
    let storyTitle: String?        // Related story headline
    let storyDescription: String?  // Story preview text (AI notes)
    let storyThumbnailURL: String? // Story thumbnail image URL

    /// Initialize with a Recipe and optional display properties
    init(
        recipe: Recipe,
        recipeSource: String? = nil,
        author: String? = nil,
        yieldText: String? = nil,
        recipeDescription: String? = nil,
        storyTitle: String? = nil,
        storyDescription: String? = nil,
        storyThumbnailURL: String? = nil
    ) {
        self.recipe = recipe
        self.recipeSource = recipeSource ?? recipe.sourceDisplayName
        self.author = author
        self.yieldText = yieldText ?? "\(recipe.servings) servings"
        // Use first instruction as description (NOT AI notes - those go in story card)
        self.recipeDescription = recipeDescription ?? recipe.instructionsArray.first
        // Show AI notes in story card if available
        self.storyTitle = storyTitle ?? (recipe.notes != nil && !recipe.notes!.isEmpty ? "balli'nin notu" : nil)
        self.storyDescription = storyDescription ?? recipe.notes
        self.storyThumbnailURL = storyThumbnailURL
    }

    // MARK: - Convenience Properties

    var recipeName: String {
        recipe.name
    }

    var imageURL: String? {
        recipe.imageURL
    }

    var imageData: Data? {
        recipe.imageData
    }

    var hasStory: Bool {
        storyTitle != nil && !(storyTitle?.isEmpty ?? true)
    }

    var displayYield: String {
        yieldText ?? "\(recipe.servings)"
    }
}

// MARK: - Preview Helpers

extension RecipeDetailData {
    /// Sample data for previews
    static func preview(
        recipeName: String = "Tamarind-Peach Lassi",
        recipeSource: String = "Better Homes & Gardens",
        author: String = "Danielle Centoni",
        yieldText: String = "4",
        imageURL: String? = nil
    ) -> RecipeDetailData {
        // Create in-memory recipe
        let context = Persistence.PersistenceController(inMemory: true).viewContext
        let recipe = Recipe(context: context)
        recipe.id = UUID()
        recipe.name = recipeName
        recipe.servings = 4
        recipe.prepTime = 10
        recipe.cookTime = 5
        recipe.calories = 150
        recipe.totalCarbs = 35
        recipe.fiber = 2
        recipe.sugars = 28
        recipe.protein = 4
        recipe.totalFat = 2
        recipe.ingredients = ["1 cup tamarind pulp", "2 ripe peaches", "2 cups yogurt", "1/4 cup honey", "1 cup ice", "Fresh mint leaves"] as NSArray
        recipe.instructions = ["Blend tamarind pulp with peaches", "Add yogurt and honey", "Blend until smooth", "Add ice and blend again", "Garnish with mint"] as NSArray
        recipe.dateCreated = Date()
        recipe.lastModified = Date()
        recipe.source = "manual"
        recipe.imageURL = imageURL

        return RecipeDetailData(
            recipe: recipe,
            recipeSource: recipeSource,
            author: author,
            yieldText: yieldText,
            recipeDescription: "Tamarind pulp can be found in jars on the international foods aisle. Or look for tamarind pods in the produce section and peel the sticky pulp away from the seeds. Using peaches adds fresh sweetness to balance the tart tamarind flavor.",
            storyTitle: "Pucker Up! Here's Seven Tantalizing Reasons to Embrace Tamarind",
            storyDescription: "Discover why this tangy fruit deserves a place in your pantry. From digestive benefits to its unique flavor profile, tamarind adds complexity to both sweet and savory dishes.",
            storyThumbnailURL: nil
        )
    }
}
