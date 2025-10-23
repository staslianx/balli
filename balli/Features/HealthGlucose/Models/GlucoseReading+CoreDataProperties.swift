//
//  GlucoseReading+CoreDataProperties.swift
//  balli
//
//  Created by Core Data Model Generator
//

import Foundation
import CoreData

extension GlucoseReading {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<GlucoseReading> {
        return NSFetchRequest<GlucoseReading>(entityName: "GlucoseReading")
    }
    
    // MARK: - Identifiers
    @NSManaged public var id: UUID
    @NSManaged public var timestamp: Date
    @NSManaged public var value: Double
    @NSManaged public var source: String
    @NSManaged public var deviceName: String?
    @NSManaged public var notes: String?
    
    // MARK: - HealthKit Integration
    @NSManaged public var healthKitUUID: String?
    @NSManaged public var syncStatus: String
    @NSManaged public var lastSyncAttempt: Date?
    
    // MARK: - Relationships
    @NSManaged public var mealEntry: MealEntry?
}

extension GlucoseReading : Identifiable {
}