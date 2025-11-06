//
//  RecipeGenerationViewModel.swift
//  balli
//
//  ViewModel for recipe generation screen
//  Handles generation logic, save operations, and shopping list integration
//  Swift 6 strict concurrency compliant
//

import Foundation
import SwiftUI
import CoreData
import OSLog

/// ViewModel for RecipeGenerationView
/// Manages recipe generation state, manual recipe entry, and business logic
@MainActor
final class RecipeGenerationViewModel: ObservableObject {
    // MARK: - Published State

    // Generation state
    @Published var selectedMealType = "Kahvaltı"
    @Published var selectedStyleType = ""
    @Published var isGenerating = false
    @Published var isSaved = false

    // Manual recipe state
    @Published var manualIngredients: [RecipeItem] = []
    @Published var manualSteps: [RecipeItem] = []

    // User context
    @Published var userNotes: String = ""

    // Shopping list state
    @Published var hasUncheckedIngredients = false

    // Story card
    @Published var storyCardTitle = "balli'nin tarif analizi"

    // MARK: - Dependencies

    private let viewContext: NSManagedObjectContext
    private let recipeViewModel: RecipeViewModel
    private let flowCoordinator: RecipeGenerationFlowCoordinator
    private let manualEntryService: RecipeManualEntryService
    private let helper: RecipeGenerationViewHelper
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.balli", category: "RecipeGenerationViewModel")

    // MARK: - Initialization

    init(
        viewContext: NSManagedObjectContext,
        recipeViewModel: RecipeViewModel,
        flowCoordinator: RecipeGenerationFlowCoordinator? = nil,
        manualEntryService: RecipeManualEntryService? = nil
    ) {
        self.viewContext = viewContext
        self.recipeViewModel = recipeViewModel
        self.flowCoordinator = flowCoordinator ?? RecipeGenerationFlowCoordinator(recipeViewModel: recipeViewModel)
        self.manualEntryService = manualEntryService ?? RecipeManualEntryService()
        self.helper = RecipeGenerationViewHelper()
    }

    // MARK: - Computed Properties

    /// Determines if save button should be visible
    /// Shows for AI-generated recipes OR manual recipes with content
    /// Only shows after character-by-character animation completes
    var shouldShowSaveButton: Bool {
        if isSaved { return false }

        // Wait for animation to complete before showing save button
        if !recipeViewModel.isAnimationComplete {
            return false
        }

        // AI-generated recipe
        if !recipeViewModel.recipeName.isEmpty {
            return true
        }

        // Manual recipe with ingredients or steps
        let hasManualContent = !manualIngredients.isEmpty || !manualSteps.isEmpty
        return hasManualContent
    }

    /// Determines if recipe is a manual entry (vs AI-generated)
    var isManualRecipe: Bool {
        recipeViewModel.recipeName.isEmpty && (!manualIngredients.isEmpty || !manualSteps.isEmpty)
    }

    /// Determines if nutrition data has been calculated
    var hasNutritionData: Bool {
        helper.hasNutritionData(
            calories: recipeViewModel.calories,
            carbohydrates: recipeViewModel.carbohydrates,
            protein: recipeViewModel.protein
        )
    }

    // MARK: - Generation Flow Logic

    /// Determines whether to show meal selection menu based on recipe state
    /// Returns tuple: (shouldShowMenu, logReason)
    func determineGenerationFlow() -> (shouldShowMenu: Bool, reason: String) {
        let hasExistingRecipe = !recipeViewModel.recipeName.isEmpty
        let hasIngredients = !manualIngredients.isEmpty
        let hasUserNotes = !userNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        return flowCoordinator.determineGenerationFlow(
            hasExistingRecipe: hasExistingRecipe,
            hasIngredients: hasIngredients,
            hasUserNotes: hasUserNotes
        )
    }

    // MARK: - Generation

    /// Generate recipe with user-selected meal type and style (called from meal selection modal)
    func startGeneration() async {
        isGenerating = true
        isSaved = false

        // Clear any previous errors before starting new generation
        recipeViewModel.generationCoordinator.generationError = nil

        // Extract ingredients from manual ingredients list
        let ingredientsList: [String]? = manualIngredients.isEmpty ? nil : manualIngredients.map { $0.text }

        // Extract user context from notes
        let contextText: String? = userNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : userNotes

        await flowCoordinator.generateRecipe(
            mealType: selectedMealType,
            styleType: selectedStyleType,
            ingredients: ingredientsList,
            userContext: contextText
        )

        isGenerating = false
    }

    /// Generate recipe with default meal type when user has provided notes (skips meal selection)
    /// Uses generic defaults since the user's notes contain all the specificity needed
    func startGenerationWithDefaults() async {
        isGenerating = true
        isSaved = false

        // Clear any previous errors before starting new generation
        recipeViewModel.generationCoordinator.generationError = nil

        // Extract ingredients from manual ingredients list
        let ingredientsList: [String]? = manualIngredients.isEmpty ? nil : manualIngredients.map { $0.text }

        // Extract user context from notes
        let contextText: String? = userNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : userNotes

        await flowCoordinator.generateRecipeWithDefaults(
            ingredients: ingredientsList,
            userContext: contextText
        )

        isGenerating = false
    }

    // MARK: - Shopping List

    /// Check if this recipe has unchecked ingredients in shopping list
    /// Matches by recipe name since generated recipes may not be saved yet
    func checkShoppingListStatus() async {
        let recipeName = recipeViewModel.recipeName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !recipeName.isEmpty else {
            hasUncheckedIngredients = false
            return
        }

        let request = ShoppingListItem.fetchRequest()
        request.predicate = NSPredicate(
            format: "recipeName == %@ AND isCompleted == NO",
            recipeName
        )

        do {
            let count = try viewContext.count(for: request)
            hasUncheckedIngredients = count > 0
        } catch {
            logger.error("❌ Failed to check shopping list status: \(error.localizedDescription)")
            hasUncheckedIngredients = false
        }
    }

    // MARK: - Save Recipe

    func saveRecipe() async {
        if isManualRecipe && recipeViewModel.recipeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            logger.warning("Cannot save manual recipe without a name")
            return
        }

        if recipeViewModel.isCalculatingNutrition {
            while recipeViewModel.isCalculatingNutrition {
                try? await Task.sleep(for: .milliseconds(100))
            }
        }

        let hasAIGeneratedContent = !recipeViewModel.recipeName.isEmpty || !recipeViewModel.recipeContent.isEmpty
        if (!manualIngredients.isEmpty || !manualSteps.isEmpty) && !hasAIGeneratedContent {
            buildManualRecipeContent()
        }

        if recipeViewModel.generatedPhotoURL != nil {
            await recipeViewModel.loadImageFromGeneratedURL()
        }

        recipeViewModel.saveRecipe()
        try? await Task.sleep(for: .milliseconds(100))

        if recipeViewModel.persistenceCoordinator.showingSaveConfirmation {
            isSaved = true
        }
    }

    /// Reset generation state after successful save
    /// Prevents ghost data from appearing in next recipe generation
    private func resetStateAfterSave() {
        manualIngredients = []
        manualSteps = []
        userNotes = ""
        selectedMealType = "Kahvaltı"
        selectedStyleType = ""
        hasUncheckedIngredients = false
        storyCardTitle = "balli'nin tarif analizi"
        recipeViewModel.clearAllFields()
    }

    private func buildManualRecipeContent() {
        let result = manualEntryService.buildManualRecipeContent(
            ingredients: manualIngredients,
            steps: manualSteps
        )

        recipeViewModel.recipeContent = result.content
        recipeViewModel.ingredients = result.ingredientList
        recipeViewModel.directions = result.directions

        // Mark as manual recipe
        recipeViewModel.formState.isManualRecipe = true
    }

    /// Generate a default name for manually entered recipes
    private func generateDefaultRecipeName() -> String {
        return manualEntryService.generateDefaultRecipeName(from: manualIngredients)
    }

    // MARK: - Photo Generation

    func generatePhoto() async {
        await recipeViewModel.generateRecipePhoto()

        if recipeViewModel.generatedPhotoURL != nil {
            await recipeViewModel.loadImageFromGeneratedURL()
        }
    }

    // MARK: - Story Card Handler

    /// Handle story card tap - returns true if should show modal immediately, false if calculation started
    func handleStoryCardTap() -> Bool {
        let hasNutrition = helper.hasNutritionData(
            calories: recipeViewModel.calories,
            carbohydrates: recipeViewModel.carbohydrates,
            protein: recipeViewModel.protein
        )

        if hasNutrition {
            return true
        } else {
            if isManualRecipe {
                if recipeViewModel.recipeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    logger.warning("Cannot calculate nutrition without recipe name")
                    return false
                }
                buildManualRecipeContent()
            }

            recipeViewModel.calculateNutrition(isManualRecipe: isManualRecipe)
            return false
        }
    }
}
