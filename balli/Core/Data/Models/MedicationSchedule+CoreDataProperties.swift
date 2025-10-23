//
//  MedicationSchedule+CoreDataProperties.swift
//  balli
//
//  Created by Claude on 11.09.2025.
//

import Foundation
import CoreData

extension MedicationSchedule {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<MedicationSchedule> {
        return NSFetchRequest<MedicationSchedule>(entityName: "MedicationSchedule")
    }
    
    // MARK: - Identifiers
    @NSManaged public var id: UUID
    @NSManaged public var medicationName: String
    @NSManaged public var medicationType: String
    
    // MARK: - Schedule Configuration
    @NSManaged public var defaultDosage: Double
    @NSManaged public var dosageUnit: String
    @NSManaged public var frequency: String
    @NSManaged public var scheduledTimes: NSObject?
    
    // MARK: - Active Schedule
    @NSManaged public var isActive: Bool
    @NSManaged public var startDate: Date
    @NSManaged public var endDate: Date?
    
    // MARK: - Reminders
    @NSManaged public var enableReminders: Bool
    @NSManaged public var reminderMinutesBefore: Int16
    
    // MARK: - Metadata
    @NSManaged public var dateCreated: Date
    @NSManaged public var lastModified: Date
    @NSManaged public var notes: String?
    
    // MARK: - Relationships
    @NSManaged public var entries: Set<MedicationEntry>?
}

// MARK: Generated accessors for entries
extension MedicationSchedule {
    
    @objc(addEntriesObject:)
    @NSManaged public func addToEntries(_ value: MedicationEntry)
    
    @objc(removeEntriesObject:)
    @NSManaged public func removeFromEntries(_ value: MedicationEntry)
    
    @objc(addEntries:)
    @NSManaged public func addToEntries(_ values: NSSet)
    
    @objc(removeEntries:)
    @NSManaged public func removeFromEntries(_ values: NSSet)
}

extension MedicationSchedule: Identifiable {
}