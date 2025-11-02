import Foundation
import SwiftData

/// Represents a single message in a research conversation session
@Model
final class SessionMessage {
    /// Unique identifier for the message
    @Attribute(.unique) var id: UUID

    /// Role of the message sender (user or model/assistant)
    var roleRaw: String

    /// Content of the message
    var content: String

    /// Timestamp when the message was created
    var timestamp: Date

    /// Research tier used for model/assistant messages (T1/T2/T3)
    var tierRaw: String?

    /// Sources used in research responses (serialized JSON)
    var sourcesData: Data?

    /// Image attachment data (serialized JSON)
    var imageAttachmentData: Data?

    /// Text highlights data (serialized JSON)
    var highlightsData: Data?

    /// Computed property for role (maps 'model' from core MessageRole)
    var role: MessageRole {
        get { MessageRole(rawValue: roleRaw) ?? .user }
        set { roleRaw = newValue.rawValue }
    }

    /// Computed property for tier
    var tier: ResponseTier? {
        get {
            guard let tierRaw else { return nil }
            return ResponseTier(rawValue: tierRaw)
        }
        set { tierRaw = newValue?.rawValue }
    }

    /// Computed property for sources
    var sources: [ResearchSource]? {
        get {
            guard let sourcesData else { return nil }
            return try? JSONDecoder().decode([ResearchSource].self, from: sourcesData)
        }
        set {
            sourcesData = try? JSONEncoder().encode(newValue)
        }
    }

    /// Computed property for image attachment
    var imageAttachment: ImageAttachment? {
        get {
            guard let imageAttachmentData else { return nil }
            return try? JSONDecoder().decode(ImageAttachment.self, from: imageAttachmentData)
        }
        set {
            imageAttachmentData = try? JSONEncoder().encode(newValue)
        }
    }

    /// Computed property for text highlights
    var highlights: [TextHighlight] {
        get {
            guard let highlightsData else { return [] }
            return (try? JSONDecoder().decode([TextHighlight].self, from: highlightsData)) ?? []
        }
        set {
            highlightsData = try? JSONEncoder().encode(newValue)
        }
    }

    /// Initializer for user messages
    init(
        role: MessageRole,
        content: String,
        timestamp: Date = Date(),
        imageAttachment: ImageAttachment? = nil
    ) {
        self.id = UUID()
        self.roleRaw = role.rawValue
        self.content = content
        self.timestamp = timestamp
        self.tierRaw = nil
        self.sourcesData = nil
        self.imageAttachmentData = try? JSONEncoder().encode(imageAttachment)
    }

    /// Initializer for assistant messages with research metadata
    init(
        role: MessageRole,
        content: String,
        timestamp: Date = Date(),
        tier: ResponseTier? = nil,
        sources: [ResearchSource]? = nil
    ) {
        self.id = UUID()
        self.roleRaw = role.rawValue
        self.content = content
        self.timestamp = timestamp
        self.tierRaw = tier?.rawValue
        self.sourcesData = try? JSONEncoder().encode(sources)
    }
}
