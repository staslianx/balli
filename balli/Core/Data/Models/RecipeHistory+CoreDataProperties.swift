//
//  RecipeHistory+CoreDataProperties.swift
//  balli
//
//  Created by Core Data Model Generator
//

import Foundation
import CoreData

extension RecipeHistory {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<RecipeHistory> {
        return NSFetchRequest<RecipeHistory>(entityName: "RecipeHistory")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var dateGenerated: Date?
    @NSManaged public var mealType: String?
    @NSManaged public var styleType: String?
    @NSManaged public var recipeName: String?
    @NSManaged public var ingredients: NSObject?
    @NSManaged public var instructions: NSObject?
    @NSManaged public var mainProtein: String?
    @NSManaged public var carbCount: Int32
    @NSManaged public var preparationTime: Int32
    @NSManaged public var servings: Int16
    @NSManaged public var nutritionConfidence: Float
    @NSManaged public var wasCooked: Bool
    @NSManaged public var userRating: Int16

}