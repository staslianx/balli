//
//  HealthNotificationSettings+CoreDataProperties.swift
//  balli
//
//  Created by Claude on 11.09.2025.
//

import Foundation
import CoreData

extension HealthNotificationSettings {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<HealthNotificationSettings> {
        return NSFetchRequest<HealthNotificationSettings>(entityName: "HealthNotificationSettings")
    }
    
    // MARK: - Identifiers
    @NSManaged public var id: UUID
    @NSManaged public var lastUpdated: Date
    
    // MARK: - General Notification Settings
    @NSManaged public var notificationsEnabled: Bool
    @NSManaged public var quietHoursStart: Date?
    @NSManaged public var quietHoursEnd: Date?
    
    // MARK: - Health Reminders
    @NSManaged public var glucoseCheckReminders: Bool
    @NSManaged public var glucoseCheckInterval: Int16
    @NSManaged public var mealLoggingReminders: Bool
    @NSManaged public var medicationReminders: Bool
    
    // MARK: - Alert Thresholds
    @NSManaged public var lowGlucoseThreshold: Double
    @NSManaged public var highGlucoseThreshold: Double
    @NSManaged public var criticalAlertsEnabled: Bool
    
    // MARK: - Reminder Timing
    @NSManaged public var morningReminderTime: Date?
    @NSManaged public var eveningReminderTime: Date?
    @NSManaged public var customReminderTimes: NSObject?
}

extension HealthNotificationSettings: Identifiable {
}