//
//  RecipeHistory+CoreDataClass.swift
//  balli
//
//  Created by Core Data Model Generator
//

import Foundation
import CoreData

@objc(RecipeHistory)
public class RecipeHistory: NSManagedObject, @unchecked Sendable {
    
    override public func awakeFromInsert() {
        super.awakeFromInsert()
        setPrimitiveValue(UUID(), forKey: "id")
        setPrimitiveValue(Date(), forKey: "dateGenerated")
        setPrimitiveValue(false, forKey: "wasCooked")
        setPrimitiveValue(1, forKey: "servings")
        setPrimitiveValue(0.0, forKey: "nutritionConfidence")
        setPrimitiveValue(0, forKey: "carbCount")
    }
    
    // Computed properties for easier access
    public var ingredientsList: [String] {
        return (ingredients as? [String]) ?? []
    }
    
    public var instructionsList: [String] {
        return (instructions as? [String]) ?? []
    }
    
}