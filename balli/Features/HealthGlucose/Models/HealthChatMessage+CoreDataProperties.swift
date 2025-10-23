//
//  HealthChatMessage+CoreDataProperties.swift
//  balli
//
//  Created by Claude on 11.09.2025.
//

import Foundation
import CoreData

extension HealthChatMessage {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<HealthChatMessage> {
        return NSFetchRequest<HealthChatMessage>(entityName: "HealthChatMessage")
    }
    
    // MARK: - Identifiers
    @NSManaged public var id: UUID
    @NSManaged public var timestamp: Date
    @NSManaged public var content: String
    @NSManaged public var isUser: Bool
    
    // MARK: - Health Context
    @NSManaged public var messageType: String
    @NSManaged public var healthDataAttached: Bool
    @NSManaged public var medicalDisclaimer: String?
    @NSManaged public var confidenceScore: Double
    
    // MARK: - AI Processing
    @NSManaged public var aiProcessed: Bool
    @NSManaged public var embeddingVector: NSObject?
    @NSManaged public var healthKeywords: NSObject?
    
    // MARK: - Streaming Support
    @NSManaged public var isStreamingComplete: Bool
    @NSManaged public var tokenCount: Int32
    
    // MARK: - Relationships
    @NSManaged public var healthEventContext: HealthEventContext?
    @NSManaged public var conversationHealthContext: ConversationHealthContext?
}

extension HealthChatMessage: Identifiable {
}