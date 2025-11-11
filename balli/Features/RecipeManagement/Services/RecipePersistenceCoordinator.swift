//
//  RecipePersistenceCoordinator.swift
//  balli
//
//  Coordinates recipe save/update operations with Core Data
//  Handles validation, persistence, and image upload orchestration
//  Swift 6 strict concurrency compliant
//

import SwiftUI
import CoreData
import OSLog

/// Coordinates recipe persistence with validation and image management
@MainActor
public final class RecipePersistenceCoordinator: ObservableObject {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.balli", category: "RecipePersistence")
    // MARK: - UI State
    @Published public var showingSaveConfirmation = false
    @Published public var showingValidationError = false
    @Published public var validationErrorMessage = ""
    @Published public var showingDuplicateWarning = false  // P0.11: Duplicate detection
    @Published public var duplicateWarningMessage = ""  // P0.11: Duplicate message

    // Dependencies
    private let viewContext: NSManagedObjectContext
    private let dataManager: RecipeDataManager
    private let imageService: RecipeImageService
    private let formState: RecipeFormState

    private var existingRecipe: Recipe?

    init(
        context: NSManagedObjectContext,
        dataManager: RecipeDataManager,
        imageService: RecipeImageService,
        formState: RecipeFormState,
        existingRecipe: Recipe? = nil
    ) {
        self.viewContext = context
        self.dataManager = dataManager
        self.imageService = imageService
        self.formState = formState
        self.existingRecipe = existingRecipe
    }

    // MARK: - Save Operations

    /// Save recipe (create new or update existing)
    public func saveRecipe(imageURL: String?, imageData: Data?) async {
        logger.info("💾 [PERSIST] saveRecipe() called for '\(self.formState.recipeName)'")
        logger.debug("📋 [PERSIST] Image parameters:")
        logger.debug("  - imageURL: \(imageURL != nil ? "present" : "nil")")
        if let data = imageData {
            logger.debug("  - imageData: \(data.count) bytes")
        } else {
            logger.debug("  - imageData: nil")
        }

        // Validate nutrition values
        let validationResult = dataManager.validateNutritionValues(
            carbohydrates: formState.carbohydrates,
            fiber: formState.fiber,
            sugar: formState.sugar
        )

        switch validationResult {
        case .success:
            logger.info("✅ [PERSIST] Nutrition validation passed")
            break
        case .failure(let message):
            logger.error("❌ [PERSIST] Nutrition validation failed: \(message)")
            validationErrorMessage = message
            showingValidationError = true
            return
        }

        // Save or update
        if let existingRecipe = existingRecipe {
            logger.info("🔄 [PERSIST] Updating existing recipe")
            updateExistingRecipe(existingRecipe, imageURL: imageURL, imageData: imageData)
        } else {
            logger.info("✨ [PERSIST] Creating new recipe")
            createNewRecipe(imageURL: imageURL, imageData: imageData)
        }
    }

    // MARK: - Duplicate Detection

    /// P0.11 FIX: Checks if a recipe with the same name already exists
    /// - Parameter name: Recipe name to check
    /// - Returns: Existing recipe if found, nil otherwise
    private func checkForDuplicateRecipe(name: String) -> Recipe? {
        let fetchRequest: NSFetchRequest<Recipe> = Recipe.fetchRequest()

        // Case-insensitive comparison for better UX
        // Matches: "Scrambled Eggs" == "scrambled eggs" == "SCRAMBLED EGGS"
        fetchRequest.predicate = NSPredicate(
            format: "name ==[cd] %@",  // [cd] = case and diacritic insensitive
            name.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        fetchRequest.fetchLimit = 1  // Performance optimization

        do {
            let existingRecipes = try viewContext.fetch(fetchRequest)
            if let existing = existingRecipes.first {
                logger.info("🔍 [DUPLICATE-CHECK] Found existing recipe: '\(existing.name)' (ID: \(existing.id.uuidString))")
                logger.info("  - Source: \(existing.source)")
                logger.info("  - Created: \(existing.dateCreated)")
                return existing
            }
            logger.info("✅ [DUPLICATE-CHECK] No duplicate found for '\(name)'")
            return nil
        } catch {
            logger.error("❌ [DUPLICATE-CHECK] Failed to query recipes: \(error.localizedDescription)")
            return nil  // Fail open - allow save if query fails
        }
    }

    // MARK: - Private Methods

    private func updateExistingRecipe(_ recipe: Recipe, imageURL: String?, imageData: Data?) {
        // Update recipe data
        recipe.name = formState.recipeName
        recipe.prepTime = Int16(formState.prepTime) ?? recipe.prepTime
        recipe.cookTime = Int16(formState.cookTime) ?? recipe.cookTime
        recipe.ingredients = formState.ingredients.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } as NSObject
        recipe.instructions = formState.directions.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } as NSObject
        recipe.notes = formState.notes.isEmpty ? nil : formState.notes
        recipe.recipeContent = formState.recipeContent.isEmpty ? nil : formState.recipeContent

        // Per-100g nutrition values
        recipe.calories = formState.calories.toDouble ?? recipe.calories
        recipe.totalCarbs = formState.carbohydrates.toDouble ?? recipe.totalCarbs
        recipe.fiber = formState.fiber.toDouble ?? recipe.fiber
        recipe.protein = formState.protein.toDouble ?? recipe.protein
        recipe.totalFat = formState.fat.toDouble ?? recipe.totalFat
        recipe.sugars = formState.sugar.toDouble ?? recipe.sugars
        recipe.glycemicLoad = formState.glycemicLoad.toDouble ?? recipe.glycemicLoad

        // Per-serving nutrition values (entire recipe = 1 serving)
        recipe.caloriesPerServing = formState.caloriesPerServing.toDouble ?? recipe.caloriesPerServing
        recipe.carbsPerServing = formState.carbohydratesPerServing.toDouble ?? recipe.carbsPerServing
        recipe.fiberPerServing = formState.fiberPerServing.toDouble ?? recipe.fiberPerServing
        recipe.proteinPerServing = formState.proteinPerServing.toDouble ?? recipe.proteinPerServing
        recipe.fatPerServing = formState.fatPerServing.toDouble ?? recipe.fatPerServing
        recipe.sugarsPerServing = formState.sugarPerServing.toDouble ?? recipe.sugarsPerServing
        recipe.glycemicLoadPerServing = formState.glycemicLoadPerServing.toDouble ?? recipe.glycemicLoadPerServing

        // DEBUG: Track totalRecipeWeight changes
        let oldTotalWeight = recipe.totalRecipeWeight
        let formTotalWeightString = formState.totalRecipeWeight
        let formTotalWeight = formTotalWeightString.toDouble ?? recipe.totalRecipeWeight
        recipe.totalRecipeWeight = formTotalWeight
        logger.info("📏 [TOTAL WEIGHT UPDATE]")
        logger.info("   Old value: \(oldTotalWeight)g")
        logger.info("   FormState value: \(formTotalWeightString) -> \(formTotalWeight)g")
        logger.info("   New value: \(recipe.totalRecipeWeight)g")
        logger.info("   PortionSize: \(recipe.portionSize)g")

        recipe.portionMultiplier = formState.portionMultiplier

        // CRITICAL: Initialize IMMUTABLE total recipe nutrition fields if not already set
        // These preserve the original full recipe nutrition and NEVER change
        // Used as the source of truth for all portion calculations
        if recipe.totalRecipeCalories == 0 {
            recipe.totalRecipeCalories = formState.caloriesPerServing.toDouble ?? recipe.caloriesPerServing
            recipe.totalRecipeCarbs = formState.carbohydratesPerServing.toDouble ?? recipe.carbsPerServing
            recipe.totalRecipeFiber = formState.fiberPerServing.toDouble ?? recipe.fiberPerServing
            recipe.totalRecipeSugar = formState.sugarPerServing.toDouble ?? recipe.sugarsPerServing
            recipe.totalRecipeProtein = formState.proteinPerServing.toDouble ?? recipe.proteinPerServing
            recipe.totalRecipeFat = formState.fatPerServing.toDouble ?? recipe.fatPerServing
            recipe.totalRecipeGlycemicLoad = formState.glycemicLoadPerServing.toDouble ?? recipe.glycemicLoadPerServing
        }

        recipe.lastModified = Date()

        // Update image data
        if let imageURL = imageURL {
            recipe.imageURL = imageURL
        }
        if let imageData = imageData {
            recipe.imageData = imageData
        }

        do {
            try viewContext.save()
            showingSaveConfirmation = true

            // PERFORMANCE FIX: Sync shopping list items with real recipe ID
            syncShoppingListWithRecipeId(recipeName: recipe.name, recipeId: recipe.id)

            // NOTE: Photos are now stored only in CoreData (imageData)
            // Firebase Storage upload removed per user request
        } catch {
            ErrorHandler.shared.handle(error)
            validationErrorMessage = "Save failed: \(error.localizedDescription)"
            showingValidationError = true
        }
    }

    private func createNewRecipe(imageURL: String?, imageData: Data?, forceCreate: Bool = false) {
        logger.info("📝 [PERSIST] Building RecipeSaveData...")
        logger.debug("  - Recipe name: '\(self.formState.recipeName)'")
        logger.debug("  - Force create: \(forceCreate)")
        if let data = imageData {
            logger.debug("  - imageData: \(data.count) bytes")
        } else {
            logger.debug("  - imageData: nil")
        }

        // P0.11 FIX: Check for duplicates BEFORE building save data
        // This prevents wasted work and provides better UX
        if !forceCreate, let existingRecipe = checkForDuplicateRecipe(name: formState.recipeName) {
            // Found duplicate - show warning dialog
            let source = existingRecipe.source
            let created = existingRecipe.dateCreated.formatted(date: .abbreviated, time: .omitted)

            duplicateWarningMessage = """
            A recipe named "\(self.formState.recipeName)" already exists.

            Source: \(source == "ai" ? "AI Generated" : source == "manual" ? "Manual" : source)
            Created: \(created)

            Do you want to save this as a separate recipe?
            """

            logger.warning("⚠️ [DUPLICATE-WARNING] Showing duplicate warning for '\(self.formState.recipeName)'")
            showingDuplicateWarning = true
            return  // Stop here - user must confirm
        }

        // No duplicate OR user confirmed - proceed with save
        logger.info("✅ [DUPLICATE-CHECK] Proceeding with save (forceCreate: \(forceCreate))")

        // CRITICAL DEBUG: Log formState values BEFORE creating saveData
        logger.info("🔍 [PERSIST-DEBUG] FormState values:")
        logger.info("  - prepTime: '\(self.formState.prepTime)'")
        logger.info("  - cookTime: '\(self.formState.cookTime)'")
        logger.info("  - ingredients count: \(self.formState.ingredients.count)")
        logger.info("  - ingredients: \(self.formState.ingredients)")
        logger.info("  - directions count: \(self.formState.directions.count)")
        logger.info("  - recipeContent length: \(self.formState.recipeContent.count) chars")
        logger.info("  - calories: '\(self.formState.calories)'")
        logger.info("  - carbohydrates: '\(self.formState.carbohydrates)'")
        logger.info("  - fiber: '\(self.formState.fiber)'")
        logger.info("  - protein: '\(self.formState.protein)'")
        logger.info("  - fat: '\(self.formState.fat)'")
        logger.info("  - sugar: '\(self.formState.sugar)'")
        logger.info("  - glycemicLoad: '\(self.formState.glycemicLoad)'")
        logger.info("  - totalRecipeWeight: '\(self.formState.totalRecipeWeight)'")
        logger.info("  - caloriesPerServing: '\(self.formState.caloriesPerServing)'")

        let saveData = RecipeSaveData(
            recipeName: formState.recipeName,
            prepTime: formState.prepTime,
            cookTime: formState.cookTime,
            ingredients: formState.ingredients,
            directions: formState.directions,
            notes: formState.notes,
            recipeContent: formState.recipeContent.isEmpty ? nil : formState.recipeContent,
            isManualRecipe: formState.isManualRecipe,
            // Per-100g nutrition values
            calories: formState.calories,
            carbohydrates: formState.carbohydrates,
            fiber: formState.fiber,
            protein: formState.protein,
            fat: formState.fat,
            sugar: formState.sugar,
            glycemicLoad: formState.glycemicLoad,
            // Per-serving nutrition values
            caloriesPerServing: formState.caloriesPerServing,
            carbohydratesPerServing: formState.carbohydratesPerServing,
            fiberPerServing: formState.fiberPerServing,
            proteinPerServing: formState.proteinPerServing,
            fatPerServing: formState.fatPerServing,
            sugarPerServing: formState.sugarPerServing,
            glycemicLoadPerServing: formState.glycemicLoadPerServing,
            totalRecipeWeight: formState.totalRecipeWeight,
            portionMultiplier: formState.portionMultiplier,
            imageURL: imageURL,
            imageData: imageData
        )

        do {
            logger.info("💾 [PERSIST] Calling dataManager.saveRecipe()...")
            try dataManager.saveRecipe(data: saveData)
            logger.info("✅ [PERSIST] Recipe saved successfully to Core Data")
            showingSaveConfirmation = true

            // PERFORMANCE FIX: Sync shopping list items with real recipe ID
            if let savedRecipe = try? viewContext.fetch(Recipe.fetchRequest()).first(where: { $0.name == formState.recipeName }) {
                syncShoppingListWithRecipeId(recipeName: savedRecipe.name, recipeId: savedRecipe.id)

                // CRITICAL DEBUG: Verify what was actually saved to Core Data
                logger.info("🔍 [PERSIST-VERIFY] Core Data values after save:")
                logger.info("  - prepTime: \(savedRecipe.prepTime)")
                logger.info("  - cookTime: \(savedRecipe.cookTime)")
                logger.info("  - calories: \(savedRecipe.calories)")
                logger.info("  - totalCarbs: \(savedRecipe.totalCarbs)")
                logger.info("  - fiber: \(savedRecipe.fiber)")
                logger.info("  - protein: \(savedRecipe.protein)")
                logger.info("  - totalFat: \(savedRecipe.totalFat)")
                logger.info("  - sugars: \(savedRecipe.sugars)")
                logger.info("  - glycemicLoad: \(savedRecipe.glycemicLoad)")
                logger.info("  - totalRecipeWeight: \(savedRecipe.totalRecipeWeight)")
                logger.info("  - caloriesPerServing: \(savedRecipe.caloriesPerServing)")
            }

            // NOTE: Photos are now stored only in CoreData (imageData)
            // Firebase Storage upload removed per user request
            logger.info("✅ [PERSIST] Recipe photo saved to CoreData (imageData: \(imageData != nil ? "\(imageData!.count) bytes" : "nil"))")
        } catch {
            logger.error("❌ [PERSIST] Save failed: \(error.localizedDescription)")
            ErrorHandler.shared.handle(error)
            validationErrorMessage = "Save failed: \(error.localizedDescription)"
            showingValidationError = true
        }
    }

    // MARK: - Duplicate Handling

    /// P0.11 FIX: Saves recipe even if duplicate exists (user confirmed)
    public func saveRecipeIgnoringDuplicates(imageURL: String?, imageData: Data?) async {
        logger.info("✅ [DUPLICATE-OVERRIDE] User confirmed duplicate save")
        createNewRecipe(imageURL: imageURL, imageData: imageData, forceCreate: true)
    }

    // MARK: - Recipe Loading

    /// Load existing recipe data
    public func loadExistingRecipe(_ recipe: Recipe) {
        self.existingRecipe = recipe

        // Refresh from context
        viewContext.refresh(recipe, mergeChanges: true)

        // Load form state
        formState.loadFromRecipe(recipe)
    }

    // MARK: - Shopping List UUID Sync

    /// Sync shopping list items with real recipe ID after save
    /// Fixes orphaned shopping list items that were created before recipe was saved
    private func syncShoppingListWithRecipeId(recipeName: String, recipeId: UUID) {
        logger.info("🔗 [SYNC] Syncing shopping list items for recipe: '\(recipeName)' with ID: \(recipeId)")

        let request = ShoppingListItem.fetchRequest()
        request.predicate = NSPredicate(
            format: "recipeName == %@ AND isFromRecipe == YES",
            recipeName
        )

        do {
            let items = try viewContext.fetch(request)

            if items.isEmpty {
                logger.debug("ℹ️ [SYNC] No shopping list items found for '\(recipeName)'")
                return
            }

            // Update all matching items with the real recipe ID
            for item in items {
                if item.recipeId != recipeId {
                    logger.debug("🔄 [SYNC] Updating item '\(item.name)' from UUID \(item.recipeId?.uuidString ?? "nil") to \(recipeId.uuidString)")
                    item.recipeId = recipeId
                }
            }

            try viewContext.save()
            logger.info("✅ [SYNC] Successfully synced \(items.count) shopping list items with recipe ID")
        } catch {
            logger.error("❌ [SYNC] Failed to sync shopping list UUIDs: \(error.localizedDescription)")
            // Don't fail the recipe save if sync fails - just log it
        }
    }
}
