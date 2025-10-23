//
//  UserPreferences+CoreDataProperties.swift
//  balli
//
//  Created by Claude on 11.09.2025.
//

import Foundation
import CoreData

extension UserPreferences {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<UserPreferences> {
        return NSFetchRequest<UserPreferences>(entityName: "UserPreferences")
    }
    
    // MARK: - Identifiers
    @NSManaged public var id: UUID
    @NSManaged public var lastUpdated: Date
    
    // MARK: - UI/UX Preferences
    @NSManaged public var themePreference: String
    @NSManaged public var primaryColor: String?
    @NSManaged public var fontSizeMultiplier: Double
    @NSManaged public var useHapticFeedback: Bool
    
    // MARK: - Accessibility
    @NSManaged public var voiceOverEnabled: Bool
    @NSManaged public var highContrastMode: Bool
    @NSManaged public var reduceMotion: Bool
    
    // MARK: - Language and Localization
    @NSManaged public var preferredLanguage: String
    @NSManaged public var measurementSystem: String
    @NSManaged public var glucoseUnit: String
    
    // MARK: - AI Assistant Preferences
    @NSManaged public var responseDetailLevel: String
    @NSManaged public var aiPersonality: String
    @NSManaged public var enableThinking: Bool
}

extension UserPreferences: Identifiable {
}