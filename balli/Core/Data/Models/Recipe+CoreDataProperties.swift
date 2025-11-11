//
//  Recipe+CoreDataProperties.swift
//  balli
//
//  Generated Core Data properties for Recipe entity
//

import Foundation
import CoreData

extension Recipe: Identifiable {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Recipe> {
        return NSFetchRequest<Recipe>(entityName: "Recipe")
    }

    // MARK: - Identifiers
    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var dateCreated: Date
    @NSManaged public var lastModified: Date

    // MARK: - Recipe Content
    @NSManaged public var ingredients: NSObject?
    @NSManaged public var instructions: NSObject?
    @NSManaged public var prepTime: Int16
    @NSManaged public var cookTime: Int16
    @NSManaged public var waitingTime: Int16
    @NSManaged public var servings: Int16

    // MARK: - Nutrition Information (per 100g)
    @NSManaged public var calories: Double
    @NSManaged public var totalCarbs: Double
    @NSManaged public var fiber: Double
    @NSManaged public var sugars: Double
    @NSManaged public var protein: Double
    @NSManaged public var totalFat: Double
    @NSManaged public var glycemicLoad: Double

    // MARK: - Nutrition Information (per serving / entire recipe)
    @NSManaged public var caloriesPerServing: Double
    @NSManaged public var carbsPerServing: Double
    @NSManaged public var fiberPerServing: Double
    @NSManaged public var sugarsPerServing: Double
    @NSManaged public var proteinPerServing: Double
    @NSManaged public var fatPerServing: Double
    @NSManaged public var glycemicLoadPerServing: Double
    @NSManaged public var totalRecipeWeight: Double
    @NSManaged public var portionMultiplier: Double

    // MARK: - IMMUTABLE: Total Recipe Nutrition (Original Values)
    /// These store the ORIGINAL total recipe nutrition values
    /// CRITICAL: These should NEVER be modified after initial calculation
    /// All portion calculations derive from these immutable values
    @NSManaged public var totalRecipeCalories: Double
    @NSManaged public var totalRecipeCarbs: Double
    @NSManaged public var totalRecipeFiber: Double
    @NSManaged public var totalRecipeSugar: Double
    @NSManaged public var totalRecipeProtein: Double
    @NSManaged public var totalRecipeFat: Double
    @NSManaged public var totalRecipeGlycemicLoad: Double

    // MARK: - Portion Definition System (for diabetes management)
    @NSManaged public var portionSize: Double  // User-defined portion in grams (0 = not defined)
    @NSManaged public var recipeType: String   // "aiGenerated" or "manual"

    // MARK: - Recipe Metadata
    @NSManaged public var source: String
    @NSManaged public var mealType: String?
    @NSManaged public var styleType: String?
    @NSManaged public var isVerified: Bool
    @NSManaged public var isFavorite: Bool
    @NSManaged public var timesCooked: Int32
    @NSManaged public var userRating: Int16
    @NSManaged public var notes: String?
    @NSManaged public var recipeContent: String?  // Full markdown content from AI generation
    @NSManaged public var imageURL: String?
    @NSManaged public var paperColor: String?
    @NSManaged public var imageData: Data?

}