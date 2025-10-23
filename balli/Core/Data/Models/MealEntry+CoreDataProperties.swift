//
//  MealEntry+CoreDataProperties.swift
//  balli
//
//  Created by Core Data Model Generator
//

import Foundation
import CoreData

extension MealEntry {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<MealEntry> {
        return NSFetchRequest<MealEntry>(entityName: "MealEntry")
    }
    
    // MARK: - Identifiers
    @NSManaged public var id: UUID
    @NSManaged public var timestamp: Date
    @NSManaged public var mealType: String
    
    // MARK: - Portion Information
    @NSManaged public var quantity: Double
    @NSManaged public var unit: String
    @NSManaged public var portionGrams: Double
    
    // MARK: - Calculated Nutrition (based on portion)
    @NSManaged public var consumedCarbs: Double
    @NSManaged public var consumedProtein: Double
    @NSManaged public var consumedFat: Double
    @NSManaged public var consumedCalories: Double
    @NSManaged public var consumedFiber: Double
    
    // MARK: - Context
    @NSManaged public var glucoseBefore: Double
    @NSManaged public var glucoseAfter: Double
    @NSManaged public var insulinUnits: Double
    @NSManaged public var notes: String?
    @NSManaged public var photoData: Data?
    
    // MARK: - Relationships
    @NSManaged public var foodItem: FoodItem?
    @NSManaged public var glucoseReadings: Set<GlucoseReading>?
}

// MARK: Generated accessors for glucoseReadings
extension MealEntry {
    
    @objc(addGlucoseReadingsObject:)
    @NSManaged public func addToGlucoseReadings(_ value: GlucoseReading)
    
    @objc(removeGlucoseReadingsObject:)
    @NSManaged public func removeFromGlucoseReadings(_ value: GlucoseReading)
    
    @objc(addGlucoseReadings:)
    @NSManaged public func addToGlucoseReadings(_ values: NSSet)
    
    @objc(removeGlucoseReadings:)
    @NSManaged public func removeFromGlucoseReadings(_ values: NSSet)
}

extension MealEntry : Identifiable {
}