//
//  MedicationEntry+CoreDataProperties.swift
//  balli
//
//  Created by Claude on 11.09.2025.
//

import Foundation
import CoreData

extension MedicationEntry {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<MedicationEntry> {
        return NSFetchRequest<MedicationEntry>(entityName: "MedicationEntry")
    }
    
    // MARK: - Identifiers
    @NSManaged public var id: UUID
    @NSManaged public var timestamp: Date
    @NSManaged public var medicationName: String
    @NSManaged public var medicationType: String
    
    // MARK: - Dosage Information
    @NSManaged public var dosage: Double
    @NSManaged public var dosageUnit: String
    @NSManaged public var administrationRoute: String
    @NSManaged public var injectionSite: String?
    
    // MARK: - Timing and Context
    @NSManaged public var timingRelation: String?
    @NSManaged public var glucoseAtTime: Double
    @NSManaged public var notes: String?
    @NSManaged public var isScheduled: Bool
    
    // MARK: - Metadata
    @NSManaged public var dateAdded: Date
    @NSManaged public var lastModified: Date
    @NSManaged public var source: String
    
    // MARK: - Relationships
    @NSManaged public var mealEntry: MealEntry?
    @NSManaged public var glucoseReading: GlucoseReading?
    @NSManaged public var medicationSchedule: MedicationSchedule?
    @NSManaged public var healthContext: HealthEventContext?
}

extension MedicationEntry: Identifiable {
}