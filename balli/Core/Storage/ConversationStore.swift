//
//  ConversationStore.swift
//  balli
//
//  SwiftData models for local conversation persistence
//  Enables offline conversation history and seamless sync
//

import Foundation
import SwiftData
import OSLog

// MARK: - SwiftData Models

/// A conversation message stored locally with SwiftData
@Model
final class StoredMessage {
    /// Unique message identifier (matches server ID when synced)
    @Attribute(.unique) var id: String

    /// Message content text
    var text: String

    /// Whether this is a user message (true) or assistant response (false)
    var isUser: Bool

    /// Message timestamp
    var timestamp: Date

    /// User ID this message belongs to
    var userId: String

    /// Sync status for offline queue management (stored as raw value for SwiftData predicate compatibility)
    var syncStatusRawValue: String

    /// Optional: Session ID for grouping related messages
    var sessionId: String?

    /// Optional: Error message if sync failed
    var syncError: String?

    /// Number of sync retry attempts
    var retryCount: Int

    init(
        id: String,
        text: String,
        isUser: Bool,
        timestamp: Date,
        userId: String,
        syncStatus: MessageSyncStatus = .pending,
        sessionId: String? = nil,
        syncError: String? = nil,
        retryCount: Int = 0
    ) {
        self.id = id
        self.text = text
        self.isUser = isUser
        self.timestamp = timestamp
        self.userId = userId
        self.syncStatusRawValue = syncStatus.rawValue
        self.sessionId = sessionId
        self.syncError = syncError
        self.retryCount = retryCount
    }

    /// Computed property for sync status enum
    var syncStatus: MessageSyncStatus {
        get {
            MessageSyncStatus(rawValue: syncStatusRawValue) ?? .pending
        }
        set {
            syncStatusRawValue = newValue.rawValue
        }
    }
}

/// Sync status for offline message queue
enum MessageSyncStatus: String, Codable {
    /// Message not yet sent to server (offline)
    case pending

    /// Message currently being synced
    case syncing

    /// Message successfully synced to server
    case synced

    /// Message sync failed (will retry)
    case failed

    /// Message sync permanently failed (exceeded max retries)
    case permanentlyFailed
}

// MARK: - Conversation Store Actor

/// Actor managing local conversation persistence with SwiftData
/// Handles offline storage, sync status tracking, and query operations
@MainActor
final class ConversationStore: ObservableObject {

    // MARK: - Properties

    private let logger = Logger(subsystem: "com.anaxoniclabs.balli", category: "ConversationStore")
    private let modelContainer: ModelContainer
    private let modelContext: ModelContext

    // MARK: - Configuration

    /// Maximum number of sync retry attempts before marking as permanently failed
    static let maxRetryCount = 3

    /// Maximum age for cached messages (7 days)
    static let maxCacheAge: TimeInterval = 7 * 24 * 60 * 60

    // MARK: - Initialization

    init() {
        do {
            // Configure SwiftData schema
            let schema = Schema([StoredMessage.self])
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true
            )

            self.modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )

            self.modelContext = ModelContext(modelContainer)

            logger.info("✅ ConversationStore initialized with SwiftData persistence")

        } catch {
            fatalError("❌ Failed to initialize SwiftData container: \(error.localizedDescription)")
        }
    }

    // MARK: - Message Operations

    /// Save a new message locally
    func saveMessage(
        id: String,
        text: String,
        isUser: Bool,
        userId: String,
        sessionId: String? = nil,
        syncStatus: MessageSyncStatus = .pending
    ) throws {
        let message = StoredMessage(
            id: id,
            text: text,
            isUser: isUser,
            timestamp: Date(),
            userId: userId,
            syncStatus: syncStatus,
            sessionId: sessionId
        )

        modelContext.insert(message)

        do {
            try modelContext.save()
            logger.info("💾 Saved message locally: \(id) (status: \(syncStatus.rawValue))")
        } catch {
            logger.error("❌ Failed to save message: \(error.localizedDescription)")
            throw error
        }
    }

    /// Update message sync status
    func updateSyncStatus(messageId: String, status: MessageSyncStatus, error: String? = nil) throws {
        let descriptor = FetchDescriptor<StoredMessage>(
            predicate: #Predicate { $0.id == messageId }
        )

        guard let message = try modelContext.fetch(descriptor).first else {
            logger.warning("⚠️ Message not found for sync status update: \(messageId)")
            return
        }

        message.syncStatusRawValue = status.rawValue
        if let error = error {
            message.syncError = error
            message.retryCount += 1
        }

        do {
            try modelContext.save()
            logger.debug("🔄 Updated sync status for \(messageId): \(status.rawValue)")
        } catch {
            logger.error("❌ Failed to update sync status: \(error.localizedDescription)")
            throw error
        }
    }

    /// Fetch all messages for a user
    func fetchMessages(userId: String, limit: Int = 100) throws -> [StoredMessage] {
        var descriptor = FetchDescriptor<StoredMessage>(
            predicate: #Predicate { $0.userId == userId },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = limit

        do {
            let messages = try modelContext.fetch(descriptor)
            logger.debug("📖 Fetched \(messages.count) messages for user")
            return messages
        } catch {
            logger.error("❌ Failed to fetch messages: \(error.localizedDescription)")
            throw error
        }
    }

    /// Fetch messages pending sync (offline queue)
    func fetchPendingSyncMessages() throws -> [StoredMessage] {
        let pendingValue = MessageSyncStatus.pending.rawValue
        let failedValue = MessageSyncStatus.failed.rawValue

        let descriptor = FetchDescriptor<StoredMessage>(
            predicate: #Predicate { message in
                message.syncStatusRawValue == pendingValue || message.syncStatusRawValue == failedValue
            },
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )

        do {
            let messages = try modelContext.fetch(descriptor)
            logger.info("📤 Found \(messages.count) messages pending sync")
            return messages
        } catch {
            logger.error("❌ Failed to fetch pending messages: \(error.localizedDescription)")
            throw error
        }
    }

    /// Delete a message
    func deleteMessage(id: String) throws {
        let descriptor = FetchDescriptor<StoredMessage>(
            predicate: #Predicate { $0.id == id }
        )

        guard let message = try modelContext.fetch(descriptor).first else {
            logger.warning("⚠️ Message not found for deletion: \(id)")
            return
        }

        modelContext.delete(message)

        do {
            try modelContext.save()
            logger.info("🗑️ Deleted message: \(id)")
        } catch {
            logger.error("❌ Failed to delete message: \(error.localizedDescription)")
            throw error
        }
    }

    /// Clear old messages (older than maxCacheAge)
    func clearOldMessages() throws {
        let cutoffDate = Date().addingTimeInterval(-Self.maxCacheAge)
        let descriptor = FetchDescriptor<StoredMessage>(
            predicate: #Predicate { $0.timestamp < cutoffDate }
        )

        do {
            let oldMessages = try modelContext.fetch(descriptor)
            for message in oldMessages {
                modelContext.delete(message)
            }
            try modelContext.save()

            logger.info("🧹 Cleared \(oldMessages.count) old messages (older than 7 days)")
        } catch {
            logger.error("❌ Failed to clear old messages: \(error.localizedDescription)")
            throw error
        }
    }

    /// Get storage statistics
    func getStorageStats() throws -> StorageStatistics {
        let pendingValue = MessageSyncStatus.pending.rawValue
        let failedValue = MessageSyncStatus.failed.rawValue

        let allDescriptor = FetchDescriptor<StoredMessage>()
        let pendingDescriptor = FetchDescriptor<StoredMessage>(
            predicate: #Predicate { $0.syncStatusRawValue == pendingValue }
        )
        let failedDescriptor = FetchDescriptor<StoredMessage>(
            predicate: #Predicate { $0.syncStatusRawValue == failedValue }
        )

        do {
            let totalCount = try modelContext.fetchCount(allDescriptor)
            let pendingCount = try modelContext.fetchCount(pendingDescriptor)
            let failedCount = try modelContext.fetchCount(failedDescriptor)

            return StorageStatistics(
                totalMessages: totalCount,
                pendingSync: pendingCount,
                failedSync: failedCount
            )
        } catch {
            logger.error("❌ Failed to get storage stats: \(error.localizedDescription)")
            throw error
        }
    }
}

// MARK: - Storage Statistics

/// Local storage statistics
struct StorageStatistics: Sendable {
    let totalMessages: Int
    let pendingSync: Int
    let failedSync: Int

    var syncedMessages: Int {
        return totalMessages - pendingSync - failedSync
    }
}
