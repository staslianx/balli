//
//  NutritionalValuesActions.swift
//  balli
//
//  Business logic for portion size saving and validation
//  Extracted from NutritionalValuesView.swift
//  Swift 6 strict concurrency compliant
//

import SwiftUI
import CoreData
import OSLog

/// Business logic for nutritional values view actions
@MainActor
struct NutritionalValuesActions {
    let viewContext: NSManagedObjectContext
    let recipe: ObservableRecipeWrapper
    let totalRecipeWeight: String
    let minPortionSize: Double
    let currentPortionSize: Double
    let logger: Logger

    @Binding var adjustingPortionWeight: Double
    @Binding var portionMultiplier: Double
    @Binding var isPortionAdjustmentExpanded: Bool
    @Binding var toastMessage: ToastType?

    /// Save portion size for saved recipes (persists to CoreData)
    func savePortionSize() {
        // Ensure recipe exists
        guard recipe.exists, let recipeEntity = recipe.recipe else {
            logger.warning("⚠️ Cannot save portion - recipe not available")
            toastMessage = .error("Tarif bulunamadı")
            return
        }

        // CRITICAL GUARD: Validate total weight is not zero (Issue #1)
        guard recipe.totalRecipeWeight > 0 else {
            logger.error("❌ Cannot save portion - recipe has zero weight")
            toastMessage = .error("Tarif ağırlığı eksik")
            return
        }

        // ISSUE #3 FIX: Validate portion size WITH USER FEEDBACK
        guard adjustingPortionWeight >= minPortionSize else {
            logger.warning("Portion size too small: \(adjustingPortionWeight)g")
            toastMessage = .error("Porsiyon en az \(Int(minPortionSize))g olmalı")
            return
        }

        guard adjustingPortionWeight <= recipe.totalRecipeWeight else {
            logger.warning("Portion size too large: \(adjustingPortionWeight)g")
            toastMessage = .error("Porsiyon toplam tariften büyük olamaz")
            return
        }

        // Calculate the ratio between new portion and total recipe
        let portionRatio = adjustingPortionWeight / recipe.totalRecipeWeight

        logger.info("💾 [PORTION SAVE] Saving new portion size")
        logger.info("   Total recipe weight: \(recipe.totalRecipeWeight)g")
        logger.info("   New portion size: \(adjustingPortionWeight)g")
        logger.info("   Portion ratio: \(portionRatio)")

        // Update recipe portion size
        recipe.updatePortionSize(adjustingPortionWeight)

        // CRITICAL FIX (Issue #2): Initialize immutable total values if not set
        // This ensures we have a stable source of truth for all calculations
        if recipeEntity.totalRecipeCalories == 0 && recipeEntity.caloriesPerServing > 0 {
            recipeEntity.totalRecipeCalories = recipeEntity.caloriesPerServing
            recipeEntity.totalRecipeCarbs = recipeEntity.carbsPerServing
            recipeEntity.totalRecipeFiber = recipeEntity.fiberPerServing
            recipeEntity.totalRecipeSugar = recipeEntity.sugarsPerServing
            recipeEntity.totalRecipeProtein = recipeEntity.proteinPerServing
            recipeEntity.totalRecipeFat = recipeEntity.fatPerServing
            recipeEntity.totalRecipeGlycemicLoad = recipeEntity.glycemicLoadPerServing
            logger.info("📦 [MIGRATION] Initialized immutable total recipe nutrition values")
        }

        // CRITICAL FIX (Issue #2): Calculate portion from IMMUTABLE total values
        // This prevents data corruption on repeated adjustments
        let totalNutrition = NutritionValues(
            calories: recipeEntity.totalRecipeCalories,    // ✅ From immutable field
            carbohydrates: recipeEntity.totalRecipeCarbs,   // ✅ From immutable field
            fiber: recipeEntity.totalRecipeFiber,           // ✅ From immutable field
            sugar: recipeEntity.totalRecipeSugar,           // ✅ From immutable field
            protein: recipeEntity.totalRecipeProtein,       // ✅ From immutable field
            fat: recipeEntity.totalRecipeFat,               // ✅ From immutable field
            glycemicLoad: recipeEntity.totalRecipeGlycemicLoad  // ✅ From immutable field
        )

        let portionNutrition = totalNutrition * portionRatio

        // Update per-serving values to match the new portion
        recipeEntity.caloriesPerServing = portionNutrition.calories
        recipeEntity.carbsPerServing = portionNutrition.carbohydrates
        recipeEntity.fiberPerServing = portionNutrition.fiber
        recipeEntity.sugarsPerServing = portionNutrition.sugar
        recipeEntity.proteinPerServing = portionNutrition.protein
        recipeEntity.fatPerServing = portionNutrition.fat
        recipeEntity.glycemicLoadPerServing = portionNutrition.glycemicLoad

        logger.info("✅ [PORTION SAVE] Updated per-serving nutrition values")
        logger.info("   Calories: \(portionNutrition.calories) kcal (from total: \(totalNutrition.calories))")
        logger.info("   Carbs: \(portionNutrition.carbohydrates)g (from total: \(totalNutrition.carbohydrates)g)")
        logger.info("   Protein: \(portionNutrition.protein)g (from total: \(totalNutrition.protein)g)")

        // Reset multiplier to 1.0 after saving new portion
        // Now portionMultiplier=1.0 means "1 serving = new portion size" with correct nutrition
        portionMultiplier = 1.0

        // Collapse menu immediately
        withAnimation(.easeInOut(duration: 0.3)) {
            isPortionAdjustmentExpanded = false
        }

        // Show success toast (independent of menu collapse)
        toastMessage = .success("Porsiyon kaydedildi!")

        // Save to Core Data asynchronously to avoid blocking UI
        Task { @MainActor in
            do {
                try viewContext.save()
                logger.info("✅ Saved portion size: \(self.adjustingPortionWeight)g with updated nutrition values")
            } catch {
                logger.error("❌ Failed to save portion size: \(error.localizedDescription)")
                toastMessage = .error("Kaydetme başarısız oldu")
            }
        }
    }

    /// Save portion size for unsaved recipes (updates in-memory state, not CoreData)
    func savePortionSizeForUnsavedRecipe() {
        logger.info("💾 [PORTION] Saving portion size for unsaved recipe")
        logger.info("   Adjusted weight: \(adjustingPortionWeight)g")
        logger.info("   Current multiplier: \(portionMultiplier)")

        // Validate portion size
        guard adjustingPortionWeight >= minPortionSize else {
            logger.error("❌ [PORTION] Portion size too small: \(adjustingPortionWeight)g")
            return
        }

        let totalWeight = Double(totalRecipeWeight) ?? 0
        guard adjustingPortionWeight <= totalWeight else {
            logger.error("❌ [PORTION] Portion size exceeds total weight: \(adjustingPortionWeight)g > \(totalWeight)g")
            return
        }

        // Update portion multiplier binding
        // This will update the formState in RecipeViewModel
        let newMultiplier = adjustingPortionWeight / currentPortionSize
        portionMultiplier = newMultiplier
        logger.info("✅ [PORTION] Updated multiplier to \(newMultiplier)")

        // Collapse menu immediately
        withAnimation(.easeInOut(duration: 0.3)) {
            isPortionAdjustmentExpanded = false
        }

        // Show success toast (independent of menu collapse)
        toastMessage = .success("Porsiyon kaydedildi!")
    }
}
