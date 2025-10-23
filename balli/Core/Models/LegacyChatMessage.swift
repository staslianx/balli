//
//  LegacyChatMessage.swift
//  balli
//
//  Stub for legacy chat message type after ChatAssistant deletion
//  Memory system still references this type but feature is unused
//

import Foundation

struct LegacyChatMessage: Identifiable, Sendable {
    let id: UUID
    let content: String
    let isUser: Bool
    let timestamp: Date

    init(id: UUID = UUID(), content: String, isUser: Bool, timestamp: Date = Date()) {
        self.id = id
        self.content = content
        self.isUser = isUser
        self.timestamp = timestamp
    }
}
