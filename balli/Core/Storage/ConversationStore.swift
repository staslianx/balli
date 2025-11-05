//
//  ConversationStore.swift
//  balli
//
//  Manages local conversation persistence using Core Data
//  Enables offline conversation history and seamless sync
//  Swift 6 strict concurrency compliant
//

import Foundation
import OSLog

// MARK: - Message Sync Status

/// Sync status for offline message queue
enum MessageSyncStatus: String, Codable, Sendable {
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

// MARK: - Conversation Store

/// MainActor-bound store managing local conversation persistence
/// Uses ConversationRepository actor for thread-safe Core Data operations
@MainActor
final class ConversationStore: ObservableObject {

    // MARK: - Properties

    private let logger = Logger(subsystem: "com.anaxoniclabs.balli", category: "ConversationStore")
    private let repository: ConversationRepository

    /// Error encountered during initialization (if any)
    @Published private(set) var initializationError: Error?

    /// Whether the store is ready for operations
    var isReady: Bool {
        return true // Repository actor is always ready
    }

    // MARK: - Configuration

    /// Maximum number of sync retry attempts before marking as permanently failed
    static let maxRetryCount = 3

    /// Maximum age for cached messages (7 days)
    static let maxCacheAge: TimeInterval = 7 * 24 * 60 * 60

    // MARK: - Initialization

    init(repository: ConversationRepository = ConversationRepository()) {
        self.repository = repository
        self.initializationError = nil
        logger.info("✅ ConversationStore initialized with Core Data persistence")
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
    ) async throws {
        do {
            try await repository.saveMessage(
                id: id,
                text: text,
                isUser: isUser,
                userId: userId,
                sessionId: sessionId,
                syncStatus: syncStatus
            )
            logger.info("💾 Saved message locally: \(id) (status: \(syncStatus.rawValue))")
        } catch {
            logger.error("❌ Failed to save message: \(error.localizedDescription)")
            throw error
        }
    }

    /// Update message sync status
    func updateSyncStatus(messageId: String, status: MessageSyncStatus, error: String? = nil) async throws {
        do {
            try await repository.updateSyncStatus(messageId: messageId, status: status, error: error)
            logger.debug("🔄 Updated sync status for \(messageId): \(status.rawValue)")
        } catch {
            logger.error("❌ Failed to update sync status: \(error.localizedDescription)")
            throw error
        }
    }

    /// Fetch all messages for a user
    func fetchMessages(userId: String, limit: Int = 100) async throws -> [StoredMessage] {
        do {
            let messages = try await repository.fetchMessages(userId: userId, limit: limit)
            logger.debug("📖 Fetched \(messages.count) messages for user")
            return messages
        } catch {
            logger.error("❌ Failed to fetch messages: \(error.localizedDescription)")
            throw error
        }
    }

    /// Fetch messages pending sync (offline queue)
    func fetchPendingSyncMessages() async throws -> [StoredMessage] {
        do {
            let messages = try await repository.fetchPendingSyncMessages()
            logger.info("📤 Found \(messages.count) messages pending sync")
            return messages
        } catch {
            logger.error("❌ Failed to fetch pending messages: \(error.localizedDescription)")
            throw error
        }
    }

    /// Delete a message
    func deleteMessage(id: String) async throws {
        do {
            try await repository.deleteMessage(id: id)
            logger.info("🗑️ Deleted message: \(id)")
        } catch {
            logger.error("❌ Failed to delete message: \(error.localizedDescription)")
            throw error
        }
    }

    /// Clear old messages (older than maxCacheAge)
    func clearOldMessages() async throws {
        do {
            let count = try await repository.clearOldMessages(maxAge: Self.maxCacheAge)
            logger.info("🧹 Cleared \(count) old messages (older than 7 days)")
        } catch {
            logger.error("❌ Failed to clear old messages: \(error.localizedDescription)")
            throw error
        }
    }

    /// Get storage statistics
    func getStorageStats() async throws -> StorageStatistics {
        do {
            let stats = try await repository.getStorageStats()
            return stats
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
