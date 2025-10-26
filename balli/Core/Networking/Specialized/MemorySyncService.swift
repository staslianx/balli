//
//  MemorySyncService.swift
//  balli
//
//  HTTP sync service for memory data (SwiftData ← HTTP → Cloud Functions → Firestore)
//  Pure URLSession implementation (NO Firebase SDK)
//  Swift 6 strict concurrency compliant
//
//  Architecture:
//  - Upload: SwiftData → HTTP POST → Cloud Functions → Firestore
//  - Download: Firestore → Cloud Functions → HTTP GET → SwiftData
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

/// Actor-isolated HTTP sync service for memory data
actor MemorySyncService {

    // MARK: - Properties

    private let baseURL = "https://us-central1-balli-project.cloudfunctions.net"
    private let session: URLSession
    private let logger = AppLoggers.Data.sync

    // MARK: - Initialization

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = true
        config.requestCachePolicy = .reloadIgnoringLocalCacheData // Always fresh for sync
        self.session = URLSession(configuration: config)

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

            try await uploadUserFacts(facts: unsyncedFacts, userId: userId)

            // Mark as synced locally
            let factIds = unsyncedFacts.map { $0.id }
            try await persistence.markAsSynced(factIds: factIds)
            logger.info("✅ Marked \(factIds.count) facts as synced")
        } else {
            logger.debug("✅ No unsynced facts to upload")
        }

        // 3. Download latest facts from Cloud Functions
        let serverFacts = try await downloadUserFacts(userId: userId)
        logger.debug("📥 Downloaded \(serverFacts.count) facts from server")

        // 4. Merge with local data (conflict resolution: last-write-wins)
        try await mergeUserFacts(serverFacts: serverFacts, userId: userId, persistence: persistence)

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
            try await uploadConversationSummaries(summaries: unsyncedSummaries, userId: userId)

            let summaryIds = unsyncedSummaries.map { $0.id }
            try await persistence.markAsSynced(summaryIds: summaryIds)
            logger.info("✅ Marked \(summaryIds.count) summaries as synced")
        } else {
            logger.debug("✅ No unsynced summaries to upload")
        }

        // 2. Download latest summaries
        let serverSummaries = try await downloadConversationSummaries(userId: userId)
        logger.debug("📥 Downloaded \(serverSummaries.count) summaries from server")

        // 3. Merge
        try await mergeConversationSummaries(serverSummaries: serverSummaries, userId: userId, persistence: persistence)

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
            try await uploadRecipePreferences(recipes: unsyncedRecipes, userId: userId)

            let recipeIds = unsyncedRecipes.map { $0.id }
            try await persistence.markAsSynced(recipeIds: recipeIds)
            logger.info("✅ Marked \(recipeIds.count) recipes as synced")
        } else {
            logger.debug("✅ No unsynced recipes to upload")
        }

        // 2. Download latest recipes
        let serverRecipes = try await downloadRecipePreferences(userId: userId)
        logger.debug("📥 Downloaded \(serverRecipes.count) recipes from server")

        // 3. Merge
        try await mergeRecipePreferences(serverRecipes: serverRecipes, userId: userId, persistence: persistence)

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
            try await uploadGlucosePatterns(patterns: unsyncedPatterns, userId: userId)

            let patternIds = unsyncedPatterns.map { $0.id }
            try await persistence.markAsSynced(patternIds: patternIds)
            logger.info("✅ Marked \(patternIds.count) patterns as synced")
        } else {
            logger.debug("✅ No unsynced patterns to upload")
        }

        // 2. Download latest patterns
        let serverPatterns = try await downloadGlucosePatterns(userId: userId)
        logger.debug("📥 Downloaded \(serverPatterns.count) patterns from server")

        // 3. Merge
        try await mergeGlucosePatterns(serverPatterns: serverPatterns, userId: userId, persistence: persistence)

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
            try await uploadUserPreferences(preferences: unsyncedPreferences, userId: userId)

            let preferenceIds = unsyncedPreferences.map { $0.id }
            try await persistence.markAsSynced(preferenceIds: preferenceIds)
            logger.info("✅ Marked \(preferenceIds.count) preferences as synced")
        } else {
            logger.debug("✅ No unsynced preferences to upload")
        }

        // 2. Download latest preferences
        let serverPreferences = try await downloadUserPreferences(userId: userId)
        logger.debug("📥 Downloaded \(serverPreferences.count) preferences from server")

        // 3. Merge
        try await mergeUserPreferences(serverPreferences: serverPreferences, userId: userId, persistence: persistence)

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

    // MARK: - Private Upload Methods

    private func uploadUserFacts(facts: [PersistentUserFact], userId: String) async throws {
        // Convert SwiftData models to JSON-compatible dictionaries on MainActor
        let factDicts = await MainActor.run {
            facts.map { fact -> SendableDictionary in
                var dict: [String: Any] = [
                    "id": fact.id,
                    "userId": fact.userId,
                    "fact": fact.fact,
                    "category": fact.category,
                    "confidence": fact.confidence,
                    "createdAt": ISO8601DateFormatter().string(from: fact.createdAt),
                    "lastAccessedAt": ISO8601DateFormatter().string(from: fact.lastAccessedAt),
                    "source": fact.source,
                    "lastModifiedAt": ISO8601DateFormatter().string(from: fact.lastModifiedAt ?? fact.createdAt)
                ]

                // Add embedding if present (as base64)
                if let embedding = fact.embedding {
                    dict["embedding"] = embedding.base64EncodedString()
                }

                return SendableDictionary(dict)
            }
        }

        guard let url = URL(string: "\(baseURL)/syncUserFacts") else {
            logger.error("Invalid URL for syncUserFacts endpoint")
            throw SyncError.invalidResponse
        }

        let body: [String: Any] = [
            "userId": userId,
            "facts": factDicts.map { $0.data }
        ]

        _ = try await performPOST(url: url, body: body)
        logger.debug("✅ Uploaded \(facts.count) facts successfully")
    }

    private func uploadConversationSummaries(summaries: [PersistentConversationSummary], userId: String) async throws {
        // Convert SwiftData models to JSON-compatible dictionaries on MainActor
        let summaryDicts = await MainActor.run {
            summaries.map { summary -> SendableDictionary in
            var dict: [String: Any] = [
                "id": summary.id,
                "userId": summary.userId,
                "summary": summary.summary,
                "startTime": ISO8601DateFormatter().string(from: summary.startTime),
                "endTime": ISO8601DateFormatter().string(from: summary.endTime),
                "messageCount": summary.messageCount,
                "tier": summary.tier.rawValue,
                "lastModifiedAt": ISO8601DateFormatter().string(from: summary.lastModifiedAt ?? summary.endTime)
            ]

            if let embedding = summary.embedding {
                dict["embedding"] = embedding.base64EncodedString()
            }

                return SendableDictionary(dict)
            }
        }

        guard let url = URL(string: "\(baseURL)/syncConversationSummaries") else {
            logger.error("Invalid URL for syncConversationSummaries endpoint")
            throw SyncError.invalidResponse
        }

        let body: [String: Any] = [
            "userId": userId,
            "summaries": summaryDicts.map { $0.data }
        ]

        _ = try await performPOST(url: url, body: body)
        logger.debug("✅ Uploaded \(summaries.count) summaries successfully")
    }

    private func uploadRecipePreferences(recipes: [PersistentRecipePreference], userId: String) async throws {
        // Convert SwiftData models to JSON-compatible dictionaries on MainActor
        let recipeDicts = await MainActor.run {
            recipes.map { recipe -> SendableDictionary in
            var dict: [String: Any] = [
                "id": recipe.id,
                "userId": recipe.userId,
                "title": recipe.title,
                "content": recipe.content,
                "savedAt": ISO8601DateFormatter().string(from: recipe.savedAt),
                "lastAccessedAt": ISO8601DateFormatter().string(from: recipe.lastAccessedAt),
                "accessCount": recipe.accessCount,
                "lastModifiedAt": ISO8601DateFormatter().string(from: recipe.lastModifiedAt ?? recipe.savedAt)
            ]

            if let embedding = recipe.embedding {
                dict["embedding"] = embedding.base64EncodedString()
            }

            if let metadata = recipe.metadataJSON {
                dict["metadataJSON"] = metadata
            }

                return SendableDictionary(dict)
            }
        }

        guard let url = URL(string: "\(baseURL)/syncRecipePreferences") else {
            logger.error("Invalid URL for syncRecipePreferences endpoint")
            throw SyncError.invalidResponse
        }

        let body: [String: Any] = [
            "userId": userId,
            "recipes": recipeDicts.map { $0.data }
        ]

        _ = try await performPOST(url: url, body: body)
        logger.debug("✅ Uploaded \(recipes.count) recipes successfully")
    }

    private func uploadGlucosePatterns(patterns: [PersistentGlucosePattern], userId: String) async throws {
        // Convert SwiftData models to JSON-compatible dictionaries on MainActor
        let patternDicts = await MainActor.run {
            patterns.map { pattern -> SendableDictionary in
            var dict: [String: Any] = [
                "id": pattern.id,
                "userId": pattern.userId,
                "meal": pattern.meal,
                "glucoseRise": pattern.glucoseRise,
                "timeToBaseline": pattern.timeToBaseline,
                "observedAt": ISO8601DateFormatter().string(from: pattern.observedAt),
                "confidence": pattern.confidence,
                "expiresAt": ISO8601DateFormatter().string(from: pattern.expiresAt)
            ]

            if let embedding = pattern.embedding {
                dict["embedding"] = embedding.base64EncodedString()
            }

                return SendableDictionary(dict)
            }
        }

        guard let url = URL(string: "\(baseURL)/syncGlucosePatterns") else {
            logger.error("Invalid URL for syncGlucosePatterns endpoint")
            throw SyncError.invalidResponse
        }

        let body: [String: Any] = [
            "userId": userId,
            "patterns": patternDicts.map { $0.data }
        ]

        _ = try await performPOST(url: url, body: body)
        logger.debug("✅ Uploaded \(patterns.count) patterns successfully")
    }

    private func uploadUserPreferences(preferences: [PersistentUserPreference], userId: String) async throws {
        // Convert SwiftData models to JSON-compatible dictionaries on MainActor
        let prefDicts = await MainActor.run {
            preferences.map { pref -> SendableDictionary in
            var dict: [String: Any] = [
                "id": pref.id,
                "userId": pref.userId,
                "key": pref.key,
                "valueType": pref.valueType,
                "updatedAt": ISO8601DateFormatter().string(from: pref.updatedAt)
            ]

            // Add value based on type
            if let stringValue = pref.stringValue {
                dict["stringValue"] = stringValue
            }
            if let intValue = pref.intValue {
                dict["intValue"] = intValue
            }
            if let doubleValue = pref.doubleValue {
                dict["doubleValue"] = doubleValue
            }
            if let boolValue = pref.boolValue {
                dict["boolValue"] = boolValue
            }
            if let dateValue = pref.dateValue {
                dict["dateValue"] = ISO8601DateFormatter().string(from: dateValue)
            }
            if let arrayJSON = pref.arrayJSON {
                dict["arrayJSON"] = arrayJSON
            }

                return SendableDictionary(dict)
            }
        }

        guard let url = URL(string: "\(baseURL)/syncUserPreferences") else {
            logger.error("Invalid URL for syncUserPreferences endpoint")
            throw SyncError.invalidResponse
        }

        let body: [String: Any] = [
            "userId": userId,
            "preferences": prefDicts.map { $0.data }
        ]

        _ = try await performPOST(url: url, body: body)
        logger.debug("✅ Uploaded \(preferences.count) preferences successfully")
    }

    // MARK: - Private Download Methods

    private func downloadUserFacts(userId: String) async throws -> [ServerUserFact] {
        guard let url = URL(string: "\(baseURL)/syncUserFacts?userId=\(userId)") else {
            logger.error("Invalid URL for syncUserFacts GET endpoint")
            throw SyncError.invalidResponse
        }

        let data = try await performGET(url: url)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let factsArray = json["facts"] as? [[String: Any]] else {
            logger.warning("⚠️ Invalid response format from syncUserFacts")
            return []
        }

        return factsArray.compactMap { ServerUserFact(from: $0) }
    }

    private func downloadConversationSummaries(userId: String) async throws -> [ServerConversationSummary] {
        guard let url = URL(string: "\(baseURL)/syncConversationSummaries?userId=\(userId)") else {
            logger.error("Invalid URL for syncConversationSummaries GET endpoint")
            throw SyncError.invalidResponse
        }

        let data = try await performGET(url: url)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let summariesArray = json["summaries"] as? [[String: Any]] else {
            logger.warning("⚠️ Invalid response format from syncConversationSummaries")
            return []
        }

        return summariesArray.compactMap { ServerConversationSummary(from: $0) }
    }

    private func downloadRecipePreferences(userId: String) async throws -> [ServerRecipePreference] {
        guard let url = URL(string: "\(baseURL)/syncRecipePreferences?userId=\(userId)") else {
            logger.error("Invalid URL for syncRecipePreferences GET endpoint")
            throw SyncError.invalidResponse
        }

        let data = try await performGET(url: url)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let recipesArray = json["recipes"] as? [[String: Any]] else {
            logger.warning("⚠️ Invalid response format from syncRecipePreferences")
            return []
        }

        return recipesArray.compactMap { ServerRecipePreference(from: $0) }
    }

    private func downloadGlucosePatterns(userId: String) async throws -> [ServerGlucosePattern] {
        guard let url = URL(string: "\(baseURL)/syncGlucosePatterns?userId=\(userId)") else {
            logger.error("Invalid URL for syncGlucosePatterns GET endpoint")
            throw SyncError.invalidResponse
        }

        let data = try await performGET(url: url)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let patternsArray = json["patterns"] as? [[String: Any]] else {
            logger.warning("⚠️ Invalid response format from syncGlucosePatterns")
            return []
        }

        return patternsArray.compactMap { ServerGlucosePattern(from: $0) }
    }

    private func downloadUserPreferences(userId: String) async throws -> [ServerUserPreference] {
        guard let url = URL(string: "\(baseURL)/syncUserPreferences?userId=\(userId)") else {
            logger.error("Invalid URL for syncUserPreferences GET endpoint")
            throw SyncError.invalidResponse
        }

        let data = try await performGET(url: url)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let preferencesArray = json["preferences"] as? [[String: Any]] else {
            logger.warning("⚠️ Invalid response format from syncUserPreferences")
            return []
        }

        return preferencesArray.compactMap { ServerUserPreference(from: $0) }
    }

    // MARK: - Private Merge Methods

    private func mergeUserFacts(serverFacts: [ServerUserFact], userId: String, persistence: MemoryPersistenceService) async throws {
        let localFacts = try await persistence.fetchFacts(userId: userId)
        let localFactsDict = Dictionary(uniqueKeysWithValues: localFacts.map { ($0.id, $0) })

        for serverFact in serverFacts {
            if let localFact = localFactsDict[serverFact.id] {
                // Conflict resolution: last-write-wins
                let serverModified = serverFact.lastModifiedAt
                let localModified = localFact.lastModifiedAt ?? localFact.createdAt

                if serverModified > localModified {
                    // Server is newer, update local
                    try await persistence.updateFact(from: serverFact)
                    logger.debug("🔄 Updated local fact \(serverFact.id) from server")
                }
                // else: local is newer or equal, keep local
            } else {
                // New fact from server, insert locally
                try await persistence.insertFact(from: serverFact)
                logger.debug("➕ Inserted new fact \(serverFact.id) from server")
            }
        }
    }

    private func mergeConversationSummaries(serverSummaries: [ServerConversationSummary], userId: String, persistence: MemoryPersistenceService) async throws {
        let localSummaries = try await persistence.fetchSummaries(userId: userId, limit: 1000)
        let localSummariesDict = Dictionary(uniqueKeysWithValues: localSummaries.map { ($0.id, $0) })

        for serverSummary in serverSummaries {
            if let localSummary = localSummariesDict[serverSummary.id] {
                let serverModified = serverSummary.lastModifiedAt
                let localModified = localSummary.lastModifiedAt ?? localSummary.endTime

                if serverModified > localModified {
                    try await persistence.updateSummary(from: serverSummary)
                    logger.debug("🔄 Updated local summary \(serverSummary.id) from server")
                }
            } else {
                try await persistence.insertSummary(from: serverSummary)
                logger.debug("➕ Inserted new summary \(serverSummary.id) from server")
            }
        }
    }

    private func mergeRecipePreferences(serverRecipes: [ServerRecipePreference], userId: String, persistence: MemoryPersistenceService) async throws {
        let localRecipes = try await persistence.fetchRecipes(userId: userId, limit: 1000)
        let localRecipesDict = Dictionary(uniqueKeysWithValues: localRecipes.map { ($0.id, $0) })

        for serverRecipe in serverRecipes {
            if let localRecipe = localRecipesDict[serverRecipe.id] {
                let serverModified = serverRecipe.lastModifiedAt
                let localModified = localRecipe.lastModifiedAt ?? localRecipe.savedAt

                if serverModified > localModified {
                    try await persistence.updateRecipe(from: serverRecipe)
                    logger.debug("🔄 Updated local recipe \(serverRecipe.id) from server")
                }
            } else {
                try await persistence.insertRecipe(from: serverRecipe)
                logger.debug("➕ Inserted new recipe \(serverRecipe.id) from server")
            }
        }
    }

    private func mergeGlucosePatterns(serverPatterns: [ServerGlucosePattern], userId: String, persistence: MemoryPersistenceService) async throws {
        let localPatterns = try await persistence.fetchGlucosePatterns(userId: userId)
        let localPatternsDict = Dictionary(uniqueKeysWithValues: localPatterns.map { ($0.id, $0) })

        for serverPattern in serverPatterns {
            if let localPattern = localPatternsDict[serverPattern.id] {
                let serverModified = serverPattern.lastModifiedAt
                let localModified = localPattern.observedAt

                if serverModified > localModified {
                    try await persistence.updatePattern(from: serverPattern)
                    logger.debug("🔄 Updated local pattern \(serverPattern.id) from server")
                }
            } else {
                try await persistence.insertPattern(from: serverPattern)
                logger.debug("➕ Inserted new pattern \(serverPattern.id) from server")
            }
        }
    }

    private func mergeUserPreferences(serverPreferences: [ServerUserPreference], userId: String, persistence: MemoryPersistenceService) async throws {
        let localPreferences = try await persistence.fetchPreferences(userId: userId)
        let localPreferencesDict = Dictionary(uniqueKeysWithValues: localPreferences.map { ($0.id, $0) })

        for serverPref in serverPreferences {
            if let localPref = localPreferencesDict[serverPref.id] {
                let serverModified = serverPref.lastModifiedAt
                let localModified = localPref.updatedAt

                if serverModified > localModified {
                    try await persistence.updatePreference(from: serverPref)
                    logger.debug("🔄 Updated local preference \(serverPref.id) from server")
                }
            } else {
                try await persistence.insertPreference(from: serverPref)
                logger.debug("➕ Inserted new preference \(serverPref.id) from server")
            }
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
        throw lastError ?? SyncError.uploadFailed
    }

    // MARK: - HTTP Helpers

    private func performPOST(url: URL, body: [String: Any]) async throws -> Data {
        // Serialize body to Data before entering @Sendable closure
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        return try await withRetry {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = bodyData

            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw SyncError.invalidResponse
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                logger.error("❌ HTTP \(httpResponse.statusCode): \(errorMessage)")
                throw SyncError.httpError(httpResponse.statusCode, errorMessage)
            }

            return data
        }
    }

    private func performGET(url: URL) async throws -> Data {
        return try await withRetry {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"

            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw SyncError.invalidResponse
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                logger.error("❌ HTTP \(httpResponse.statusCode): \(errorMessage)")
                throw SyncError.httpError(httpResponse.statusCode, errorMessage)
            }

            return data
        }
    }

    // MARK: - Persistence Service Access

    @MainActor
    private func getPersistenceService() -> MemoryPersistenceService {
        return MemoryPersistenceService()
    }

    // MARK: - Error Types

    enum SyncError: LocalizedError {
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
}
