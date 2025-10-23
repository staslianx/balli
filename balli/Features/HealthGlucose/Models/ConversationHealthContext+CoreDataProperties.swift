//
//  ConversationHealthContext+CoreDataProperties.swift
//  balli
//
//  Created by Claude on 11.09.2025.
//

import Foundation
import CoreData

extension ConversationHealthContext {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<ConversationHealthContext> {
        return NSFetchRequest<ConversationHealthContext>(entityName: "ConversationHealthContext")
    }
    
    // MARK: - Identifiers
    @NSManaged public var id: UUID
    @NSManaged public var conversationId: UUID
    @NSManaged public var startTimestamp: Date
    @NSManaged public var lastUpdated: Date
    
    // MARK: - Context Summary
    @NSManaged public var contextSummary: String?
    @NSManaged public var healthTopics: NSObject?
    @NSManaged public var relevantHealthData: NSObject?
    
    // MARK: - Memory Management
    @NSManaged public var isActive: Bool
    @NSManaged public var memoryPriority: Int16
    @NSManaged public var lastAccessTimestamp: Date
    
    // MARK: - Relationships
    @NSManaged public var messages: Set<HealthChatMessage>?
}

// MARK: Generated accessors for messages
extension ConversationHealthContext {
    
    @objc(addMessagesObject:)
    @NSManaged public func addToMessages(_ value: HealthChatMessage)
    
    @objc(removeMessagesObject:)
    @NSManaged public func removeFromMessages(_ value: HealthChatMessage)
    
    @objc(addMessages:)
    @NSManaged public func addToMessages(_ values: NSSet)
    
    @objc(removeMessages:)
    @NSManaged public func removeFromMessages(_ values: NSSet)
}

extension ConversationHealthContext: Identifiable {
}