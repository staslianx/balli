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

/// Coordinates recipe persistence with validation and image management
@MainActor
public final class RecipePersistenceCoordinator: ObservableObject {
    // MARK: - UI State
    @Published public var showingSaveConfirmation = false
    @Published public var showingValidationError = false
    @Published public var validationErrorMessage = ""

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
        // Validate nutrition values
        let validationResult = dataManager.validateNutritionValues(
            carbohydrates: formState.carbohydrates,
            fiber: formState.fiber,
            sugar: formState.sugar
        )

        switch validationResult {
        case .success:
            break
        case .failure(let message):
            validationErrorMessage = message
            showingValidationError = true
            return
        }

        // Save or update
        if let existingRecipe = existingRecipe {
            updateExistingRecipe(existingRecipe, imageURL: imageURL, imageData: imageData)
        } else {
            createNewRecipe(imageURL: imageURL, imageData: imageData)
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

        recipe.calories = Double(formState.calories) ?? recipe.calories
        recipe.totalCarbs = Double(formState.carbohydrates) ?? recipe.totalCarbs
        recipe.fiber = Double(formState.fiber) ?? recipe.fiber
        recipe.protein = Double(formState.protein) ?? recipe.protein
        recipe.totalFat = Double(formState.fat) ?? recipe.totalFat
        recipe.sugars = Double(formState.sugar) ?? recipe.sugars
        recipe.glycemicLoad = Double(formState.glycemicLoad) ?? recipe.glycemicLoad
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

            // Upload image in background if needed
            if let imageData = imageData, imageURL == nil {
                Task {
                    await imageService.uploadImageToStorageInBackground(imageData: imageData, recipe: recipe)
                }
            }
        } catch {
            ErrorHandler.shared.handle(error)
            validationErrorMessage = "Save failed: \(error.localizedDescription)"
            showingValidationError = true
        }
    }

    private func createNewRecipe(imageURL: String?, imageData: Data?) {
        let saveData = RecipeSaveData(
            recipeName: formState.recipeName,
            prepTime: formState.prepTime,
            cookTime: formState.cookTime,
            ingredients: formState.ingredients,
            directions: formState.directions,
            notes: formState.notes,
            recipeContent: formState.recipeContent.isEmpty ? nil : formState.recipeContent,
            calories: formState.calories,
            carbohydrates: formState.carbohydrates,
            fiber: formState.fiber,
            protein: formState.protein,
            fat: formState.fat,
            sugar: formState.sugar,
            glycemicLoad: formState.glycemicLoad,
            imageURL: imageURL,
            imageData: imageData
        )

        do {
            try dataManager.saveRecipe(data: saveData)
            showingSaveConfirmation = true

            // Upload image in background if needed
            if let imageData = imageData, imageURL == nil {
                Task {
                    if let savedRecipe = try? viewContext.fetch(Recipe.fetchRequest()).first(where: { $0.name == formState.recipeName }) {
                        await imageService.uploadImageToStorageInBackground(imageData: imageData, recipe: savedRecipe)
                    }
                }
            }
        } catch {
            ErrorHandler.shared.handle(error)
            validationErrorMessage = "Save failed: \(error.localizedDescription)"
            showingValidationError = true
        }
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
}
