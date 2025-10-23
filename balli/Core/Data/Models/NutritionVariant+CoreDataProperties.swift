//
//  NutritionVariant+CoreDataProperties.swift
//  balli
//
//  Created by Core Data Model Generator
//

import Foundation
import CoreData

extension NutritionVariant {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<NutritionVariant> {
        return NSFetchRequest<NutritionVariant>(entityName: "NutritionVariant")
    }
    
    // MARK: - Identifiers
    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var servingSize: Double
    @NSManaged public var servingUnit: String
    
    // MARK: - Nutrition that differs from parent
    @NSManaged public var calories: Double
    @NSManaged public var totalCarbs: Double
    @NSManaged public var fiber: Double
    @NSManaged public var sugars: Double
    @NSManaged public var protein: Double
    @NSManaged public var totalFat: Double
    
    // MARK: - Relationships
    @NSManaged public var parentFood: FoodItem?
}

extension NutritionVariant : Identifiable {
}