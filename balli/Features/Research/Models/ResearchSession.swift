import Foundation
import SwiftData

/// Represents a complete research conversation session with full message history
@Model
final class ResearchSession {
    /// Unique identifier for the session
    @Attribute(.unique) var sessionId: UUID

    /// Full conversation history (user and assistant messages)
    @Relationship(deleteRule: .cascade) var conversationHistory: [SessionMessage]

    /// Current status of the session
    var statusRaw: String

    /// Timestamp when the session was created
    var createdAt: Date

    /// Timestamp of the last update to the session
    var lastUpdated: Date

    /// Optional title generated when session completes
    var title: String?

    /// Optional summary generated when session completes
    var summary: String?

    /// Optional key topics extracted when session completes (serialized JSON array)
    var keyTopicsData: Data?

    /// Computed property for status
    var status: SessionStatus {
        get { SessionStatus(rawValue: statusRaw) ?? .active }
        set { statusRaw = newValue.rawValue }
    }

    /// Computed property for key topics
    var keyTopics: [String] {
        get {
            guard let keyTopicsData else { return [] }
            return (try? JSONDecoder().decode([String].self, from: keyTopicsData)) ?? []
        }
        set {
            keyTopicsData = try? JSONEncoder().encode(newValue)
        }
    }

    /// Number of messages in the conversation
    var messageCount: Int {
        conversationHistory.count
    }

    /// Initializer for a new session
    init() {
        self.sessionId = UUID()
        self.conversationHistory = []
        self.statusRaw = SessionStatus.active.rawValue
        self.createdAt = Date()
        self.lastUpdated = Date()
        self.title = nil
        self.summary = nil
        self.keyTopicsData = nil
    }

    /// Appends a message to the conversation history
    func appendMessage(_ message: SessionMessage) {
        conversationHistory.append(message)
        lastUpdated = Date()
    }

    /// Marks the session as complete with metadata
    func complete(title: String, summary: String, keyTopics: [String]) {
        self.status = .complete
        self.title = title
        self.summary = summary
        self.keyTopics = keyTopics
        self.lastUpdated = Date()
    }
}
