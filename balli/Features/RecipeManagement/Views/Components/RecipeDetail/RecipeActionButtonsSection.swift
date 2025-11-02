//
//  RecipeActionButtonsSection.swift
//  balli
//
//  Action buttons component for recipe detail
//  Handles favorite, notes, and shopping actions
//

import SwiftUI
import CoreData
import OSLog

/// Action buttons section with favorite, notes, and shopping actions
struct RecipeActionButtonsSection: View {
    let recipe: Recipe
    let isEditing: Bool
    let hasUncheckedIngredientsInShoppingList: Bool  // Dynamic shopping basket state
    let onAction: (RecipeAction) -> Void

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.balli", category: "RecipeActionButtonsSection")

    var body: some View {
        RecipeActionRow(
            actions: [.favorite, .notes, .shopping],
            activeStates: [recipe.isFavorite, false, hasUncheckedIngredientsInShoppingList],
            loadingStates: [false, false, false],
            completedStates: [false, false, false],
            progressStates: [0, 0, 0]
        ) { action in
            onAction(action)
        }
    }
}

// MARK: - Preview

#Preview("Default State") {
    let controller = Persistence.PersistenceController(inMemory: true)
    let context = controller.viewContext
    let recipe = Recipe(context: context)

    recipe.id = UUID()
    recipe.name = "Test Recipe"
    recipe.isFavorite = false
    recipe.servings = 4
    recipe.dateCreated = Date()
    recipe.lastModified = Date()
    recipe.source = "manual"
    recipe.isVerified = false
    recipe.timesCooked = 0
    recipe.userRating = 0
    recipe.calories = 0
    recipe.totalCarbs = 0
    recipe.fiber = 0
    recipe.sugars = 0
    recipe.protein = 0
    recipe.totalFat = 0
    recipe.glycemicLoad = 0
    recipe.prepTime = 0
    recipe.cookTime = 0

    return RecipeActionButtonsSection(
        recipe: recipe,
        isEditing: false,
        hasUncheckedIngredientsInShoppingList: false,
        onAction: { _ in }
    )
    .padding()
}

#Preview("Favorite Active") {
    let controller = Persistence.PersistenceController(inMemory: true)
    let context = controller.viewContext
    let recipe = Recipe(context: context)

    recipe.id = UUID()
    recipe.name = "Test Recipe"
    recipe.isFavorite = true
    recipe.servings = 4
    recipe.dateCreated = Date()
    recipe.lastModified = Date()
    recipe.source = "manual"
    recipe.isVerified = false
    recipe.timesCooked = 0
    recipe.userRating = 0
    recipe.calories = 0
    recipe.totalCarbs = 0
    recipe.fiber = 0
    recipe.sugars = 0
    recipe.protein = 0
    recipe.totalFat = 0
    recipe.glycemicLoad = 0
    recipe.prepTime = 0
    recipe.cookTime = 0

    return RecipeActionButtonsSection(
        recipe: recipe,
        isEditing: false,
        hasUncheckedIngredientsInShoppingList: true,
        onAction: { _ in }
    )
    .padding()
}
