//
//  HealthEventContext+CoreDataProperties.swift
//  balli
//
//  Created by Claude on 11.09.2025.
//

import Foundation
import CoreData

extension HealthEventContext {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<HealthEventContext> {
        return NSFetchRequest<HealthEventContext>(entityName: "HealthEventContext")
    }
    
    // MARK: - Identifiers
    @NSManaged public var id: UUID
    @NSManaged public var timestamp: Date
    @NSManaged public var eventType: String
    
    // MARK: - Context Data
    @NSManaged public var glucoseValue: Double
    @NSManaged public var carbsConsumed: Double
    @NSManaged public var insulinAdministered: Double
    @NSManaged public var exerciseMinutes: Int16
    @NSManaged public var stressLevel: Int16
    @NSManaged public var sleepHours: Double
    
    // MARK: - Analysis
    @NSManaged public var aiAnalysis: String?
    @NSManaged public var patterns: NSObject?
    @NSManaged public var recommendations: NSObject?
    
    // MARK: - Relationships
    @NSManaged public var mealEntry: MealEntry?
    @NSManaged public var glucoseReading: GlucoseReading?
    @NSManaged public var medicationEntries: Set<MedicationEntry>?
    @NSManaged public var chatMessages: Set<HealthChatMessage>?
}

// MARK: Generated accessors for medicationEntries
extension HealthEventContext {
    
    @objc(addMedicationEntriesObject:)
    @NSManaged public func addToMedicationEntries(_ value: MedicationEntry)
    
    @objc(removeMedicationEntriesObject:)
    @NSManaged public func removeFromMedicationEntries(_ value: MedicationEntry)
    
    @objc(addMedicationEntries:)
    @NSManaged public func addToMedicationEntries(_ values: NSSet)
    
    @objc(removeMedicationEntries:)
    @NSManaged public func removeFromMedicationEntries(_ values: NSSet)
}

// MARK: Generated accessors for chatMessages
extension HealthEventContext {
    
    @objc(addChatMessagesObject:)
    @NSManaged public func addToChatMessages(_ value: HealthChatMessage)
    
    @objc(removeChatMessagesObject:)
    @NSManaged public func removeFromChatMessages(_ value: HealthChatMessage)
    
    @objc(addChatMessages:)
    @NSManaged public func addToChatMessages(_ values: NSSet)
    
    @objc(removeChatMessages:)
    @NSManaged public func removeFromChatMessages(_ values: NSSet)
}

extension HealthEventContext: Identifiable {
}