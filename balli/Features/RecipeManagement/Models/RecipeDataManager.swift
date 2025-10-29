//
//  RecipeDataManager.swift
//  balli
//
//  Handles data persistence and validation for RecipeViewModel
//  Extracted for better separation of concerns
//

import Foundation
import CoreData

/// Handles recipe data persistence and validation
@MainActor
public class RecipeDataManager {
    
    // MARK: - Properties
    private let viewContext: NSManagedObjectContext
    
    // MARK: - Initialization
    public init(context: NSManagedObjectContext) {
        self.viewContext = context
    }
    
    // MARK: - Validation
    public func validateNutritionValues(
        carbohydrates: String,
        fiber: String,
        sugar: String
    ) -> RecipeValidationResult {
        let carbValue = Double(carbohydrates) ?? 0.0
        let fiberValue = Double(fiber) ?? 0.0
        let sugarValue = Double(sugar) ?? 0.0
        
        if (fiberValue + sugarValue) > carbValue && carbValue > 0 {
            let errorMessage = "Lif ve şeker toplamı (\(String(format: "%.1f", fiberValue + sugarValue))g) karbonhidrat değerini (\(String(format: "%.1f", carbValue))g) aşamaz."
            return .failure(errorMessage)
        }
        
        return .success
    }
    
    // MARK: - Save Recipe
    public func saveRecipe(data: RecipeSaveData) throws {
        let existingRecipeFetchRequest: NSFetchRequest<Recipe> = Recipe.fetchRequest()
        existingRecipeFetchRequest.predicate = NSPredicate(
            format: "name == %@ AND source == %@",
            data.recipeName,
            RecipeConstants.Source.ai
        )
        
        let existingAIRecipes = try viewContext.fetch(existingRecipeFetchRequest)

        if let existingRecipe = existingAIRecipes.first {
            updateExistingAIRecipe(existingRecipe, with: data)
        } else {
            createNewRecipe(with: data)
        }
        
        try viewContext.save()
        
        // Ensure changes are immediately available by refreshing the context
        viewContext.refreshAllObjects()
    }
    
    // MARK: - Shopping List Integration
    public func addIngredientsToShoppingList(
        ingredients: [String],
        sentIngredients: Set<String>,
        recipeName: String? = nil,
        recipeId: UUID? = nil
    ) async throws -> Set<String> {
        // Use recipe-specific parser if recipe context is provided
        if let recipeName = recipeName, let recipeId = recipeId {
            return try await addRecipeIngredientsToShoppingList(
                ingredients: ingredients,
                sentIngredients: sentIngredients,
                recipeName: recipeName,
                recipeId: recipeId
            )
        }
        
        // Original logic for non-recipe ingredients
        let parser = IngredientParser()
        
        let validIngredients = ingredients.filter { ingredient in
            let trimmed = ingredient.trimmingCharacters(in: .whitespacesAndNewlines)
            return !trimmed.isEmpty && !sentIngredients.contains(trimmed.lowercased())
        }
        
        guard !validIngredients.isEmpty else {
            return sentIngredients
        }
        
        let parsedIngredients = await parser.parseIngredients(
            from: validIngredients.joined(separator: ", ")
        )
        let _ = await parser.createShoppingItems(
            from: parsedIngredients,
            in: viewContext
        )
        
        try viewContext.save()
        
        var updatedSentIngredients = sentIngredients
        for ingredient in validIngredients {
            updatedSentIngredients.insert(
                ingredient.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
        }
        
        return updatedSentIngredients
    }
    
    // MARK: - Recipe-specific Shopping List Integration
    private func addRecipeIngredientsToShoppingList(
        ingredients: [String],
        sentIngredients: Set<String>,
        recipeName: String,
        recipeId: UUID
    ) async throws -> Set<String> {
        let recipeParser = RecipeIngredientParser()
        
        let validIngredients = ingredients.filter { ingredient in
            let trimmed = ingredient.trimmingCharacters(in: .whitespacesAndNewlines)
            return !trimmed.isEmpty && !sentIngredients.contains(trimmed.lowercased())
        }
        
        guard !validIngredients.isEmpty else {
            return sentIngredients
        }
        
        // Parse ingredients with recipe-specific parser
        let parsedIngredients = recipeParser.parseRecipeIngredients(validIngredients)
        
        // Create shopping items with recipe context
        let _ = recipeParser.createRecipeShoppingItems(
            from: parsedIngredients,
            recipeName: recipeName,
            recipeId: recipeId,
            in: viewContext
        )
        
        try viewContext.save()
        
        var updatedSentIngredients = sentIngredients
        for ingredient in validIngredients {
            updatedSentIngredients.insert(
                ingredient.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            )
        }
        
        return updatedSentIngredients
    }
    
    // MARK: - Private Methods
    private func updateExistingAIRecipe(_ recipe: Recipe, with data: RecipeSaveData) {
        recipe.isVerified = true
        recipe.lastModified = Date()

        // Per-100g nutrition values
        recipe.calories = Double(data.calories) ?? recipe.calories
        recipe.totalCarbs = Double(data.carbohydrates) ?? recipe.totalCarbs
        recipe.fiber = Double(data.fiber) ?? recipe.fiber
        recipe.sugars = Double(data.sugar) ?? recipe.sugars
        recipe.protein = Double(data.protein) ?? recipe.protein
        recipe.totalFat = Double(data.fat) ?? recipe.totalFat
        recipe.glycemicLoad = Double(data.glycemicLoad) ?? 0.0

        // Per-serving nutrition values (entire recipe = 1 serving)
        recipe.caloriesPerServing = Double(data.caloriesPerServing) ?? recipe.caloriesPerServing
        recipe.carbsPerServing = Double(data.carbohydratesPerServing) ?? recipe.carbsPerServing
        recipe.fiberPerServing = Double(data.fiberPerServing) ?? recipe.fiberPerServing
        recipe.sugarsPerServing = Double(data.sugarPerServing) ?? recipe.sugarsPerServing
        recipe.proteinPerServing = Double(data.proteinPerServing) ?? recipe.proteinPerServing
        recipe.fatPerServing = Double(data.fatPerServing) ?? recipe.fatPerServing
        recipe.glycemicLoadPerServing = Double(data.glycemicLoadPerServing) ?? recipe.glycemicLoadPerServing
        recipe.totalRecipeWeight = Double(data.totalRecipeWeight) ?? recipe.totalRecipeWeight

        // Update time fields
        recipe.prepTime = Int16(data.prepTime) ?? recipe.prepTime
        recipe.cookTime = Int16(data.cookTime) ?? recipe.cookTime
        
        // Update notes
        if !data.notes.isEmpty {
            recipe.notes = data.notes
        }
        
        recipe.ingredients = data.ingredients.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } as NSObject
        recipe.instructions = data.directions.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } as NSObject

        // Save markdown recipe content
        if let recipeContent = data.recipeContent, !recipeContent.isEmpty {
            recipe.setValue(recipeContent, forKey: "recipeContent")
        }

        // Save image URL if available
        if let imageURL = data.imageURL {
            recipe.imageURL = imageURL
        }

        // Save image data if available
        if let imageData = data.imageData {
            recipe.imageData = imageData
        }
    }
    
    private func createNewRecipe(with data: RecipeSaveData) {
        let recipe = Recipe(context: viewContext)
        recipe.id = UUID()
        recipe.name = data.recipeName
        recipe.dateCreated = Date()
        recipe.lastModified = Date()
        // Determine source: if recipe has content, it's AI-generated; otherwise it's manual
        recipe.source = (data.recipeContent != nil && !data.recipeContent!.isEmpty) ? RecipeConstants.Source.ai : RecipeConstants.Source.manual
        recipe.mealType = RecipeConstants.DefaultTypes.customMeal
        recipe.styleType = RecipeConstants.DefaultTypes.customStyle
        
        recipe.ingredients = data.ingredients.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } as NSObject
        recipe.instructions = data.directions.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } as NSObject
        recipe.servings = Int16(RecipeConstants.Defaults.servings)
        
        // Per-100g nutrition values
        recipe.calories = Double(data.calories) ?? 0.0
        recipe.totalCarbs = Double(data.carbohydrates) ?? 0.0
        recipe.fiber = Double(data.fiber) ?? 0.0
        recipe.sugars = Double(data.sugar) ?? 0.0
        recipe.protein = Double(data.protein) ?? 0.0
        recipe.totalFat = Double(data.fat) ?? 0.0
        recipe.glycemicLoad = Double(data.glycemicLoad) ?? 0.0

        // Per-serving nutrition values (entire recipe = 1 serving)
        recipe.caloriesPerServing = Double(data.caloriesPerServing) ?? 0.0
        recipe.carbsPerServing = Double(data.carbohydratesPerServing) ?? 0.0
        recipe.fiberPerServing = Double(data.fiberPerServing) ?? 0.0
        recipe.sugarsPerServing = Double(data.sugarPerServing) ?? 0.0
        recipe.proteinPerServing = Double(data.proteinPerServing) ?? 0.0
        recipe.fatPerServing = Double(data.fatPerServing) ?? 0.0
        recipe.glycemicLoadPerServing = Double(data.glycemicLoadPerServing) ?? 0.0
        recipe.totalRecipeWeight = Double(data.totalRecipeWeight) ?? 0.0

        // Save time fields
        recipe.prepTime = Int16(data.prepTime) ?? 0
        recipe.cookTime = Int16(data.cookTime) ?? 0
        
        // Save notes
        recipe.notes = data.notes.isEmpty ? nil : data.notes

        // Save markdown recipe content
        if let recipeContent = data.recipeContent, !recipeContent.isEmpty {
            recipe.setValue(recipeContent, forKey: "recipeContent")
        }

        recipe.isVerified = true
        recipe.isFavorite = false
        recipe.timesCooked = 0

        // Save image URL if available
        if let imageURL = data.imageURL {
            recipe.imageURL = imageURL
        }

        // Save image data if available
        if let imageData = data.imageData {
            recipe.imageData = imageData
        }

        // Also create RecipeHistory for tracking
        createRecipeHistory(with: data)
    }
    
    private func createRecipeHistory(with data: RecipeSaveData) {
        let recipeHistory = RecipeHistory(context: viewContext)
        recipeHistory.id = UUID()
        recipeHistory.dateGenerated = Date()
        recipeHistory.recipeName = data.recipeName
        recipeHistory.mealType = RecipeConstants.DefaultTypes.manualHistory
        recipeHistory.styleType = RecipeConstants.DefaultTypes.customStyle
        recipeHistory.carbCount = Int32(Double(data.carbohydrates) ?? 0.0)
        recipeHistory.mainProtein = data.protein.isEmpty ? nil : data.protein
        recipeHistory.ingredients = data.ingredients.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } as NSObject
        recipeHistory.instructions = data.directions.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } as NSObject
        recipeHistory.nutritionConfidence = Float(RecipeConstants.Defaults.nutritionConfidence)
        recipeHistory.wasCooked = false
        recipeHistory.servings = Int16(RecipeConstants.Defaults.servings)
    }
}

// MARK: - Supporting Types
public enum RecipeValidationResult {
    case success
    case failure(String)
}

public struct RecipeSaveData {
    let recipeName: String
    let prepTime: String
    let cookTime: String
    let ingredients: [String]
    let directions: [String]
    let notes: String
    let recipeContent: String?  // NEW: Markdown recipe content from streaming
    // Per-100g nutrition values
    let calories: String
    let carbohydrates: String
    let fiber: String
    let protein: String
    let fat: String
    let sugar: String
    let glycemicLoad: String
    // Per-serving nutrition values (entire recipe = 1 serving)
    let caloriesPerServing: String
    let carbohydratesPerServing: String
    let fiberPerServing: String
    let proteinPerServing: String
    let fatPerServing: String
    let sugarPerServing: String
    let glycemicLoadPerServing: String
    let totalRecipeWeight: String
    let imageURL: String?
    let imageData: Data?
}