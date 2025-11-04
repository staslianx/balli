//
//  RecipeGenerationFlowCoordinator.swift
//  balli
//
//  Coordinates recipe generation flow logic and routing
//  Determines whether to show meal selection or use defaults
//  Swift 6 strict concurrency compliant
//

import Foundation
import OSLog

/// Coordinates recipe generation flow decisions and execution
/// Handles smart routing between spontaneous and ingredients-based generation
@MainActor
final class RecipeGenerationFlowCoordinator {
    // MARK: - Dependencies

    private let recipeViewModel: RecipeViewModel
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.balli",
        category: "RecipeGenerationFlowCoordinator"
    )

    // MARK: - Initialization

    init(recipeViewModel: RecipeViewModel) {
        self.recipeViewModel = recipeViewModel
    }

    // MARK: - Flow Logic

    /// Determines whether to show meal selection menu based on recipe state
    /// Returns tuple: (shouldShowMenu, logReason)
    func determineGenerationFlow(
        hasExistingRecipe: Bool,
        hasIngredients: Bool,
        hasUserNotes: Bool
    ) -> (shouldShowMenu: Bool, reason: String) {
        // EDGE CASE PROTECTION: If recipe already exists, treat notes as personal notes (not prompts)
        // This prevents accidental regeneration when user writes post-generation notes
        if hasExistingRecipe {
            // Recipe exists → User's notes are personal, not prompts
            // Always show menu for explicit "regenerate" intent
            return (true, "⚠️ [EDGE-CASE] Recipe exists - treating notes as personal, showing menu for explicit regenerate")
        }

        // Smart behavior based on recipe generation flow logic:
        // Flow 1: No ingredients + No notes → Show menu (need user intent)
        // Flow 2: Ingredients only + No notes → Show menu (ingredients ambiguous without context)
        // Flow 3: No ingredients + Notes → Skip menu (notes contain explicit intent)
        // Flow 4: Ingredients + Notes → Skip menu (user being specific)

        if hasUserNotes {
            // Flows 3 & 4: Has notes (with or without ingredients) → Skip menu
            if hasIngredients {
                return (false, "🎯 [FLOW-4] Ingredients + Notes - skipping menu, user is specific")
            } else {
                return (false, "🎯 [FLOW-3] Notes only - skipping menu, notes contain intent")
            }
        } else {
            // Flows 1 & 2: No notes → Show menu
            if hasIngredients {
                return (true, "🥕 [FLOW-2] Ingredients only - showing menu for context")
            } else {
                return (true, "📋 [FLOW-1] Empty state - showing menu for intent")
            }
        }
    }

    // MARK: - Generation

    /// Generate recipe with user-selected meal type and style (called from meal selection modal)
    func generateRecipe(
        mealType: String,
        styleType: String,
        ingredients: [String]?,
        userContext: String?
    ) async {
        logger.info("🚀 [COORDINATOR] ========== START GENERATION ==========")
        logger.info("🚀 [COORDINATOR] MealType: '\(mealType)', StyleType: '\(styleType)'")

        // Log what we're passing
        if let ingredients = ingredients {
            logger.info("🥕 [COORDINATOR] Starting generation with \(ingredients.count) ingredients: \(ingredients.joined(separator: ", "))")
        } else {
            logger.info("🥕 [COORDINATOR] No ingredients provided")
        }

        if let context = userContext {
            logger.info("📝 [COORDINATOR] User context: '\(context)'")
        } else {
            logger.info("📝 [COORDINATOR] No user context")
        }

        logger.info("🔄 [COORDINATOR] Calling recipeViewModel.generationCoordinator.generateRecipeSmartRouting...")

        // Smart routing: Use ingredients-based generation if ingredients exist, otherwise spontaneous
        await recipeViewModel.generationCoordinator.generateRecipeSmartRouting(
            mealType: mealType,
            styleType: styleType,
            ingredients: ingredients,
            userContext: userContext
        )

        logger.info("✅ [COORDINATOR] Generation call completed")
        logger.info("✅ [COORDINATOR] Recipe name: '\(self.recipeViewModel.recipeName)'")
        logger.info("✅ [COORDINATOR] Has recipe data: \(self.recipeViewModel.hasRecipeData)")
        logger.info("🏁 [COORDINATOR] ========== GENERATION FINISHED ==========")
    }

    /// Generate recipe using ONLY user context (notes) - NO meal type
    /// This is Flow 3 (Notes only) or Flow 4 (Ingredients + Notes)
    /// The user's notes define what to make, so we don't send any meal type hints
    func generateRecipeWithDefaults(
        ingredients: [String]?,
        userContext: String?
    ) async {
        logger.info("🎯 [FLOW-3/4] User provided notes - ignoring meal type selection")
        logger.info("📝 [CONTEXT] UserContext: '\(userContext ?? "nil")'")

        if let ingredients = ingredients {
            logger.info("🥕 [FLOW-4] Ingredients: \(ingredients.joined(separator: ", "))")
        } else {
            logger.info("📝 [FLOW-3] Notes only, no ingredients")
        }

        // DON'T send mealType/styleType at all - let the Cloud Function handle this
        // The Cloud Function should detect when userContext exists and not require meal type
        await recipeViewModel.generationCoordinator.generateRecipeWithUserContextOnly(
            ingredients: ingredients,
            userContext: userContext
        )
    }
}
