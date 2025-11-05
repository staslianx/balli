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
    var shouldShowSaveButton: Bool {
        if isSaved { return false }

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
        logger.info("💾 [VM] saveRecipe() called")

        // Validate manual recipe has a name
        if isManualRecipe && recipeViewModel.recipeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            logger.warning("⚠️ [VM] Cannot save manual recipe without a name")
            return
        }

        // Wait for nutrition calculation to finish if it's running
        if recipeViewModel.isCalculatingNutrition {
            logger.info("⏳ [VM] Nutrition calculation in progress - waiting for completion...")
            while recipeViewModel.isCalculatingNutrition {
                try? await Task.sleep(for: .milliseconds(100))
            }
            logger.info("✅ [VM] Nutrition calculation completed - proceeding with save")
        }

        // Build manual recipe content ONLY if this is truly a manual recipe (no AI generation happened)
        // If user provided ingredients but AI generated a recipe, DON'T overwrite the AI content
        let hasAIGeneratedContent = !recipeViewModel.recipeName.isEmpty || !recipeViewModel.recipeContent.isEmpty
        if (!manualIngredients.isEmpty || !manualSteps.isEmpty) && !hasAIGeneratedContent {
            logger.info("🔨 [VM] Building manual recipe content (no AI generation)")
            buildManualRecipeContent()
        } else if hasAIGeneratedContent {
            logger.info("🤖 [VM] Skipping manual content build - AI already generated recipe")
        }

        // Load image data if present
        if recipeViewModel.generatedPhotoURL != nil {
            logger.info("🖼️ [VM] Photo URL present - loading image data before save...")
            await recipeViewModel.loadImageFromGeneratedURL()
            logger.info("✅ [VM] Image data loaded - proceeding with save")
        }

        // Save recipe
        logger.info("💾 [VM] Calling recipeViewModel.saveRecipe()...")
        recipeViewModel.saveRecipe()

        // Wait for save to complete
        try? await Task.sleep(for: .milliseconds(100))

        // Show confirmation if successful
        if recipeViewModel.persistenceCoordinator.showingSaveConfirmation {
            logger.info("✅ [VM] Save confirmed - showing success state")
            isSaved = true

            // Keep recipe visible after save - don't reset state
            // User can continue viewing/interacting with their saved recipe
            logger.info("📌 [VM] Recipe saved - keeping view state intact")
        } else {
            logger.warning("⚠️ [VM] Save confirmation not shown")
        }
    }

    /// Reset generation state after successful save
    /// Prevents ghost data from appearing in next recipe generation
    private func resetStateAfterSave() {
        logger.info("🧹 [VM] Resetting state after successful save")

        // Reset manual entry state
        manualIngredients = []
        manualSteps = []

        // Reset user context
        userNotes = ""

        // Reset meal selection to defaults
        selectedMealType = "Kahvaltı"
        selectedStyleType = ""

        // Reset shopping list state
        hasUncheckedIngredients = false

        // Reset story card
        storyCardTitle = "balli'nin tarif analizi"

        // Clear recipe view model state
        recipeViewModel.clearAllFields()

        logger.info("✅ [VM] State reset complete - ready for next recipe")
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
        logger.info("🎬 [VM] Photo generation button tapped")
        await recipeViewModel.generateRecipePhoto()

        if recipeViewModel.generatedPhotoURL != nil {
            logger.info("🖼️ [VM] Loading image from generated URL")
            await recipeViewModel.loadImageFromGeneratedURL()
        }
        logger.info("🏁 [VM] Photo generation completed")
    }

    // MARK: - Story Card Handler

    /// Handle story card tap - returns true if should show modal immediately, false if calculation started
    func handleStoryCardTap() -> Bool {
        logger.info("🔍 [STORY] Story card tapped")

        let hasNutrition = helper.hasNutritionData(
            calories: recipeViewModel.calories,
            carbohydrates: recipeViewModel.carbohydrates,
            protein: recipeViewModel.protein
        )

        if hasNutrition {
            logger.info("✅ [STORY] Nutrition data exists - showing modal")
            return true // Signal to show modal
        } else {
            logger.info("🔄 [STORY] Starting nutrition calculation")

            // Build manual recipe content if needed before calculating nutrition
            if isManualRecipe {
                // Validate manual recipe has a name before calculating nutrition
                if recipeViewModel.recipeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    logger.warning("⚠️ [STORY] Cannot calculate nutrition without recipe name")
                    return false
                }
                buildManualRecipeContent()
            }

            recipeViewModel.calculateNutrition(isManualRecipe: isManualRecipe)
            return false // Modal will open via onChange when calculation completes
        }
    }
}
