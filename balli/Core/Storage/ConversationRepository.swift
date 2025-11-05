//
//  ConversationRepository.swift
//  balli
//
//  Thread-safe repository for conversation message persistence using Core Data
//  Handles StoredMessageEntity with offline sync support
//  Swift 6 strict concurrency compliant
//

import CoreData
import OSLog

/// Actor-based repository for thread-safe conversation persistence
actor ConversationRepository {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.balli", category: "ConversationRepository")
    private let persistence: Persistence.PersistenceController

    init(persistence: Persistence.PersistenceController = .shared) {
        self.persistence = persistence
    }

    // MARK: - Message Operations

    /// Save a new message to Core Data
    func saveMessage(
        id: String,
        text: String,
        isUser: Bool,
        userId: String,
        sessionId: String? = nil,
        syncStatus: MessageSyncStatus = .pending
    ) async throws {
        try await persistence.performBackgroundTask { context in
            // Check if message already exists (upsert pattern)
            let request = NSFetchRequest<StoredMessageEntity>(entityName: "StoredMessageEntity")
            request.predicate = NSPredicate(format: "id == %@", id)
            request.fetchLimit = 1

            let entity: StoredMessageEntity
            if let existing = try context.fetch(request).first {
                entity = existing
            } else {
                entity = StoredMessageEntity(context: context)
                entity.id = id
                entity.timestamp = Date()
            }

            // Update properties
            entity.text = text
            entity.isUser = isUser
            entity.userId = userId
            entity.sessionId = sessionId
            entity.syncStatusRawValue = syncStatus.rawValue

            try context.save()
            self.logger.debug("💾 Saved message: \(id) (status: \(syncStatus.rawValue))")
        }
    }

    /// Update message sync status
    func updateSyncStatus(messageId: String, status: MessageSyncStatus, error: String? = nil) async throws {
        try await persistence.performBackgroundTask { context in
            let request = NSFetchRequest<StoredMessageEntity>(entityName: "StoredMessageEntity")
            request.predicate = NSPredicate(format: "id == %@", messageId)
            request.fetchLimit = 1

            guard let entity = try context.fetch(request).first else {
                self.logger.warning("⚠️ Message not found for sync status update: \(messageId)")
                return
            }

            entity.syncStatusRawValue = status.rawValue
            if let error = error {
                entity.syncError = error
                entity.retryCount += 1
            }

            try context.save()
            self.logger.debug("🔄 Updated sync status for \(messageId): \(status.rawValue)")
        }
    }

    /// Fetch messages for a specific user
    func fetchMessages(userId: String, limit: Int = 100) async throws -> [StoredMessage] {
        try await persistence.performBackgroundTask { context in
            let request = NSFetchRequest<StoredMessageEntity>(entityName: "StoredMessageEntity")
            request.predicate = NSPredicate(format: "userId == %@", userId)
            request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
            request.fetchLimit = limit

            let entities = try context.fetch(request)
            let messages = entities.compactMap { try? self.convertToStoredMessage($0) }

            self.logger.debug("📖 Fetched \(messages.count) messages for user")
            return messages
        }
    }

    /// Fetch messages pending sync
    func fetchPendingSyncMessages() async throws -> [StoredMessage] {
        try await persistence.performBackgroundTask { context in
            let pendingStatus = MessageSyncStatus.pending.rawValue
            let failedStatus = MessageSyncStatus.failed.rawValue

            let request = NSFetchRequest<StoredMessageEntity>(entityName: "StoredMessageEntity")
            request.predicate = NSPredicate(
                format: "syncStatusRawValue == %@ OR syncStatusRawValue == %@",
                pendingStatus,
                failedStatus
            )
            request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]

            let entities = try context.fetch(request)
            let messages = entities.compactMap { try? self.convertToStoredMessage($0) }

            self.logger.info("📤 Found \(messages.count) messages pending sync")
            return messages
        }
    }

    /// Delete a specific message
    func deleteMessage(id: String) async throws {
        try await persistence.performBackgroundTask { context in
            let request = NSFetchRequest<StoredMessageEntity>(entityName: "StoredMessageEntity")
            request.predicate = NSPredicate(format: "id == %@", id)

            guard let entity = try context.fetch(request).first else {
                self.logger.warning("⚠️ Message not found for deletion: \(id)")
                return
            }

            context.delete(entity)
            try context.save()

            self.logger.info("🗑️ Deleted message: \(id)")
        }
    }

    /// Clear old messages (older than maxAge)
    func clearOldMessages(maxAge: TimeInterval) async throws -> Int {
        try await persistence.performBackgroundTask { context in
            let cutoffDate = Date().addingTimeInterval(-maxAge)

            let request = NSFetchRequest<StoredMessageEntity>(entityName: "StoredMessageEntity")
            request.predicate = NSPredicate(format: "timestamp < %@", cutoffDate as NSDate)

            let oldMessages = try context.fetch(request)
            for message in oldMessages {
                context.delete(message)
            }

            try context.save()

            let count = oldMessages.count
            self.logger.info("🧹 Cleared \(count) old messages")
            return count
        }
    }

    /// Get storage statistics
    func getStorageStats() async throws -> StorageStatistics {
        try await persistence.performBackgroundTask { context in
            let allRequest = NSFetchRequest<StoredMessageEntity>(entityName: "StoredMessageEntity")
            let totalCount = try context.count(for: allRequest)

            let pendingStatus = MessageSyncStatus.pending.rawValue
            let pendingRequest = NSFetchRequest<StoredMessageEntity>(entityName: "StoredMessageEntity")
            pendingRequest.predicate = NSPredicate(format: "syncStatusRawValue == %@", pendingStatus)
            let pendingCount = try context.count(for: pendingRequest)

            let failedStatus = MessageSyncStatus.failed.rawValue
            let failedRequest = NSFetchRequest<StoredMessageEntity>(entityName: "StoredMessageEntity")
            failedRequest.predicate = NSPredicate(format: "syncStatusRawValue == %@", failedStatus)
            let failedCount = try context.count(for: failedRequest)

            return StorageStatistics(
                totalMessages: totalCount,
                pendingSync: pendingCount,
                failedSync: failedCount
            )
        }
    }

    // MARK: - Helper Methods

    /// Convert StoredMessageEntity to StoredMessage struct
    nonisolated private func convertToStoredMessage(_ entity: StoredMessageEntity) throws -> StoredMessage {
        guard let id = entity.id,
              let text = entity.text,
              let userId = entity.userId,
              let timestamp = entity.timestamp else {
            throw ConversationRepositoryError.invalidData
        }

        let syncStatus = MessageSyncStatus(rawValue: entity.syncStatusRawValue ?? MessageSyncStatus.pending.rawValue) ?? .pending

        return StoredMessage(
            id: id,
            text: text,
            isUser: entity.isUser,
            timestamp: timestamp,
            userId: userId,
            syncStatus: syncStatus,
            sessionId: entity.sessionId,
            syncError: entity.syncError,
            retryCount: Int(entity.retryCount)
        )
    }
}

// MARK: - Stored Message Model

/// Sendable struct representing a stored conversation message
struct StoredMessage: Sendable, Identifiable {
    let id: String
    let text: String
    let isUser: Bool
    let timestamp: Date
    let userId: String
    var syncStatus: MessageSyncStatus
    let sessionId: String?
    let syncError: String?
    let retryCount: Int
}

// MARK: - Errors

enum ConversationRepositoryError: LocalizedError {
    case invalidData
    case storageUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidData:
            return "Invalid message data in Core Data entity"
        case .storageUnavailable:
            return "Conversation storage is unavailable"
        }
    }
}
