//
//  MemorySyncService.swift
//  balli
//
//  HTTP sync service coordinator for memory data (SwiftData ← HTTP → Cloud Functions → Firestore)
//  Pure URLSession implementation (NO Firebase SDK)
//  Swift 6 strict concurrency compliant
//
//  Architecture:
//  - Upload: SwiftData → HTTP POST → Cloud Functions → Firestore (via MemorySyncUploader)
//  - Download: Firestore → Cloud Functions → HTTP GET → SwiftData (via MemorySyncDownloader)
//  - Conflict Resolution: Last-write-wins using lastModifiedAt timestamps
//
//  Usage:
//    let syncService = MemorySyncService()
//    try await syncService.syncUserFacts(userId: "user@example.com")
//    try await syncService.syncAll(userId: "user@example.com")
//

import Foundation
import OSLog

// MARK: - Memory Sync Service

/// Actor-isolated HTTP sync coordinator for memory data
actor MemorySyncService {

    // MARK: - Properties

    private let baseURL = "https://us-central1-balli-project.cloudfunctions.net"
    private let session: URLSession
    private let logger = AppLoggers.Data.sync
    private let uploader: MemorySyncUploader
    private let downloader: MemorySyncDownloader

    // MARK: - Initialization

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = true
        config.requestCachePolicy = .reloadIgnoringLocalCacheData // Always fresh for sync
        self.session = URLSession(configuration: config)

        let logger = AppLoggers.Data.sync
        let baseURL = "https://us-central1-balli-project.cloudfunctions.net"

        self.uploader = MemorySyncUploader(baseURL: baseURL, session: session, logger: logger)
        self.downloader = MemorySyncDownloader(baseURL: baseURL, session: session, logger: logger)

        logger.info("🔄 MemorySyncService initialized")
    }

    // MARK: - User Facts Sync

    /// Sync user facts: upload unsynced → download latest → merge
    func syncUserFacts(userId: String) async throws {
        logger.info("📤 Starting user facts sync for userId: \(userId, privacy: .private)")

        // Get persistence service (MainActor-isolated)
        let persistence = await getPersistenceService()

        // 1. Fetch unsynced facts on MainActor
        let unsyncedFacts = try await persistence.fetchUnsyncedFacts(userId: userId)

        // 2. Upload unsynced facts to Cloud Functions
        if !unsyncedFacts.isEmpty {
            logger.debug("📤 Uploading \(unsyncedFacts.count) unsynced facts")

            try await withRetry {
                try await uploader.uploadUserFacts(facts: unsyncedFacts, userId: userId)
            }

            // Mark as synced locally
            let factIds = unsyncedFacts.map { $0.id }
            try await persistence.markAsSynced(factIds: factIds)
            logger.info("✅ Marked \(factIds.count) facts as synced")
        } else {
            logger.debug("✅ No unsynced facts to upload")
        }

        // 3. Download latest facts from Cloud Functions
        let serverFacts = try await withRetry {
            try await downloader.downloadUserFacts(userId: userId)
        }
        logger.debug("📥 Downloaded \(serverFacts.count) facts from server")

        // 4. Merge with local data (conflict resolution: last-write-wins)
        try await downloader.mergeUserFacts(serverFacts: serverFacts, userId: userId, persistence: persistence)

        logger.info("✅ User facts sync completed")
    }

    // MARK: - Conversation Summaries Sync

    /// Sync conversation summaries: upload unsynced → download latest → merge
    func syncConversationSummaries(userId: String) async throws {
        logger.info("📤 Starting conversation summaries sync for userId: \(userId, privacy: .private)")

        let persistence = await getPersistenceService()

        // 1. Upload unsynced summaries
        let unsyncedSummaries = try await persistence.fetchUnsyncedSummaries(userId: userId)

        if !unsyncedSummaries.isEmpty {
            logger.debug("📤 Uploading \(unsyncedSummaries.count) unsynced summaries")
            try await withRetry {
                try await uploader.uploadConversationSummaries(summaries: unsyncedSummaries, userId: userId)
            }

            let summaryIds = unsyncedSummaries.map { $0.id }
            try await persistence.markAsSynced(summaryIds: summaryIds)
            logger.info("✅ Marked \(summaryIds.count) summaries as synced")
        } else {
            logger.debug("✅ No unsynced summaries to upload")
        }

        // 2. Download latest summaries
        let serverSummaries = try await withRetry {
            try await downloader.downloadConversationSummaries(userId: userId)
        }
        logger.debug("📥 Downloaded \(serverSummaries.count) summaries from server")

        // 3. Merge
        try await downloader.mergeConversationSummaries(serverSummaries: serverSummaries, userId: userId, persistence: persistence)

        logger.info("✅ Conversation summaries sync completed")
    }

    // MARK: - Recipe Preferences Sync

    /// Sync recipe preferences: upload unsynced → download latest → merge
    func syncRecipePreferences(userId: String) async throws {
        logger.info("📤 Starting recipe preferences sync for userId: \(userId, privacy: .private)")

        let persistence = await getPersistenceService()

        // 1. Upload unsynced recipes
        let unsyncedRecipes = try await persistence.fetchUnsyncedRecipes(userId: userId)

        if !unsyncedRecipes.isEmpty {
            logger.debug("📤 Uploading \(unsyncedRecipes.count) unsynced recipes")
            try await withRetry {
                try await uploader.uploadRecipePreferences(recipes: unsyncedRecipes, userId: userId)
            }

            let recipeIds = unsyncedRecipes.map { $0.id }
            try await persistence.markAsSynced(recipeIds: recipeIds)
            logger.info("✅ Marked \(recipeIds.count) recipes as synced")
        } else {
            logger.debug("✅ No unsynced recipes to upload")
        }

        // 2. Download latest recipes
        let serverRecipes = try await withRetry {
            try await downloader.downloadRecipePreferences(userId: userId)
        }
        logger.debug("📥 Downloaded \(serverRecipes.count) recipes from server")

        // 3. Merge
        try await downloader.mergeRecipePreferences(serverRecipes: serverRecipes, userId: userId, persistence: persistence)

        logger.info("✅ Recipe preferences sync completed")
    }

    // MARK: - Glucose Patterns Sync

    /// Sync glucose patterns: upload unsynced → download latest → merge
    func syncGlucosePatterns(userId: String) async throws {
        logger.info("📤 Starting glucose patterns sync for userId: \(userId, privacy: .private)")

        let persistence = await getPersistenceService()

        // 1. Upload unsynced patterns
        let unsyncedPatterns = try await persistence.fetchUnsyncedPatterns(userId: userId)

        if !unsyncedPatterns.isEmpty {
            logger.debug("📤 Uploading \(unsyncedPatterns.count) unsynced patterns")
            try await withRetry {
                try await uploader.uploadGlucosePatterns(patterns: unsyncedPatterns, userId: userId)
            }

            let patternIds = unsyncedPatterns.map { $0.id }
            try await persistence.markAsSynced(patternIds: patternIds)
            logger.info("✅ Marked \(patternIds.count) patterns as synced")
        } else {
            logger.debug("✅ No unsynced patterns to upload")
        }

        // 2. Download latest patterns
        let serverPatterns = try await withRetry {
            try await downloader.downloadGlucosePatterns(userId: userId)
        }
        logger.debug("📥 Downloaded \(serverPatterns.count) patterns from server")

        // 3. Merge
        try await downloader.mergeGlucosePatterns(serverPatterns: serverPatterns, userId: userId, persistence: persistence)

        logger.info("✅ Glucose patterns sync completed")
    }

    // MARK: - User Preferences Sync

    /// Sync user preferences: upload unsynced → download latest → merge
    func syncUserPreferences(userId: String) async throws {
        logger.info("📤 Starting user preferences sync for userId: \(userId, privacy: .private)")

        let persistence = await getPersistenceService()

        // 1. Upload unsynced preferences
        let unsyncedPreferences = try await persistence.fetchUnsyncedPreferences(userId: userId)

        if !unsyncedPreferences.isEmpty {
            logger.debug("📤 Uploading \(unsyncedPreferences.count) unsynced preferences")
            try await withRetry {
                try await uploader.uploadUserPreferences(preferences: unsyncedPreferences, userId: userId)
            }

            let preferenceIds = unsyncedPreferences.map { $0.id }
            try await persistence.markAsSynced(preferenceIds: preferenceIds)
            logger.info("✅ Marked \(preferenceIds.count) preferences as synced")
        } else {
            logger.debug("✅ No unsynced preferences to upload")
        }

        // 2. Download latest preferences
        let serverPreferences = try await withRetry {
            try await downloader.downloadUserPreferences(userId: userId)
        }
        logger.debug("📥 Downloaded \(serverPreferences.count) preferences from server")

        // 3. Merge
        try await downloader.mergeUserPreferences(serverPreferences: serverPreferences, userId: userId, persistence: persistence)

        logger.info("✅ User preferences sync completed")
    }

    // MARK: - Unified Sync

    /// Sync all memory types (facts, summaries, recipes, patterns, preferences)
    func syncAll(userId: String) async throws {
        logger.info("🔄 Starting full memory sync for userId: \(userId, privacy: .private)")

        do {
            // Sync in dependency order
            try await syncUserFacts(userId: userId)
            try await syncConversationSummaries(userId: userId)
            try await syncRecipePreferences(userId: userId)
            try await syncGlucosePatterns(userId: userId)
            try await syncUserPreferences(userId: userId)

            logger.info("✅ Full memory sync completed successfully")
        } catch {
            logger.error("❌ Full memory sync failed: \(error.localizedDescription)")
            throw error
        }
    }


    // MARK: - Retry Logic

    /// Retry an operation with exponential backoff
    private func withRetry<T: Sendable>(
        maxAttempts: Int = 3,
        _ operation: @Sendable () async throws -> T
    ) async throws -> T {
        var lastError: Error?

        for attempt in 0..<maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error

                // PERFORMANCE FIX: Don't retry permanent errors (403 Forbidden, 404 Not Found, etc.)
                // These errors indicate client misconfiguration or missing resources that won't resolve with retries
                if let syncError = error as? MemorySyncError,
                   case .httpError(let statusCode, _) = syncError {
                    // Permanent client errors (4xx except 408, 429) - don't retry
                    if statusCode >= 400 && statusCode < 500 && statusCode != 408 && statusCode != 429 {
                        logger.error("❌ Permanent HTTP error \(statusCode) - aborting retry (not retryable)")
                        throw error
                    }
                }

                // Don't retry on last attempt
                if attempt < maxAttempts - 1 {
                    // Exponential backoff: 1s, 2s, 4s
                    let delay = Double(1 << attempt)
                    logger.warning("Sync attempt \(attempt + 1)/\(maxAttempts) failed, retrying in \(delay)s: \(error.localizedDescription)")

                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }

        logger.error("All \(maxAttempts) sync attempts failed")
        throw lastError ?? MemorySyncError.uploadFailed
    }


    // MARK: - Persistence Service Access

    @MainActor
    private func getPersistenceService() -> MemoryPersistenceService {
        return MemoryPersistenceService()
    }

}

// MARK: - Error Types

enum MemorySyncError: LocalizedError {
    case uploadFailed
    case downloadFailed
    case mergeFailed
    case invalidResponse
    case httpError(Int, String)
    case networkUnavailable

    var errorDescription: String? {
        switch self {
        case .uploadFailed:
            return "Failed to upload data to server"
        case .downloadFailed:
            return "Failed to download data from server"
        case .mergeFailed:
            return "Failed to merge local and server data"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let status, _):
            return "HTTP error \(status)"
        case .networkUnavailable:
            return "Network connection unavailable"
        }
    }
}
