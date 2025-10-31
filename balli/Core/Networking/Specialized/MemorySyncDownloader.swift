//
//  MemorySyncDownloader.swift
//  balli
//
//  Download and merge operations for memory sync
//  Fetches data via HTTP GET and merges with local SwiftData using conflict resolution
//  Swift 6 strict concurrency compliant
//

import Foundation
import OSLog

// MARK: - Memory Sync Downloader

/// Actor-isolated service for downloading and merging memory data
actor MemorySyncDownloader {

    // MARK: - Properties

    private let baseURL: String
    private let session: URLSession
    private let logger: Logger

    // MARK: - Initialization

    init(baseURL: String, session: URLSession, logger: Logger) {
        self.baseURL = baseURL
        self.session = session
        self.logger = logger
    }

    // MARK: - Download Methods

    func downloadUserFacts(userId: String) async throws -> [ServerUserFact] {
        guard let url = URL(string: "\(baseURL)/syncUserFacts?userId=\(userId)") else {
            logger.error("Invalid URL for syncUserFacts GET endpoint")
            throw MemorySyncError.invalidResponse
        }

        let data = try await performGET(url: url)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let factsArray = json["facts"] as? [[String: Any]] else {
            logger.warning("⚠️ Invalid response format from syncUserFacts")
            return []
        }

        return factsArray.compactMap { ServerUserFact(from: $0) }
    }

    func downloadConversationSummaries(userId: String) async throws -> [ServerConversationSummary] {
        guard let url = URL(string: "\(baseURL)/syncConversationSummaries?userId=\(userId)") else {
            logger.error("Invalid URL for syncConversationSummaries GET endpoint")
            throw MemorySyncError.invalidResponse
        }

        let data = try await performGET(url: url)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let summariesArray = json["summaries"] as? [[String: Any]] else {
            logger.warning("⚠️ Invalid response format from syncConversationSummaries")
            return []
        }

        return summariesArray.compactMap { ServerConversationSummary(from: $0) }
    }

    func downloadRecipePreferences(userId: String) async throws -> [ServerRecipePreference] {
        guard let url = URL(string: "\(baseURL)/syncRecipePreferences?userId=\(userId)") else {
            logger.error("Invalid URL for syncRecipePreferences GET endpoint")
            throw MemorySyncError.invalidResponse
        }

        let data = try await performGET(url: url)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let recipesArray = json["recipes"] as? [[String: Any]] else {
            logger.warning("⚠️ Invalid response format from syncRecipePreferences")
            return []
        }

        return recipesArray.compactMap { ServerRecipePreference(from: $0) }
    }

    func downloadGlucosePatterns(userId: String) async throws -> [ServerGlucosePattern] {
        guard let url = URL(string: "\(baseURL)/syncGlucosePatterns?userId=\(userId)") else {
            logger.error("Invalid URL for syncGlucosePatterns GET endpoint")
            throw MemorySyncError.invalidResponse
        }

        let data = try await performGET(url: url)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let patternsArray = json["patterns"] as? [[String: Any]] else {
            logger.warning("⚠️ Invalid response format from syncGlucosePatterns")
            return []
        }

        return patternsArray.compactMap { ServerGlucosePattern(from: $0) }
    }

    func downloadUserPreferences(userId: String) async throws -> [ServerUserPreference] {
        guard let url = URL(string: "\(baseURL)/syncUserPreferences?userId=\(userId)") else {
            logger.error("Invalid URL for syncUserPreferences GET endpoint")
            throw MemorySyncError.invalidResponse
        }

        let data = try await performGET(url: url)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let preferencesArray = json["preferences"] as? [[String: Any]] else {
            logger.warning("⚠️ Invalid response format from syncUserPreferences")
            return []
        }

        return preferencesArray.compactMap { ServerUserPreference(from: $0) }
    }

    // MARK: - Merge Methods

    func mergeUserFacts(serverFacts: [ServerUserFact], userId: String, persistence: MemoryPersistenceService) async throws {
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

    func mergeConversationSummaries(serverSummaries: [ServerConversationSummary], userId: String, persistence: MemoryPersistenceService) async throws {
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

    func mergeRecipePreferences(serverRecipes: [ServerRecipePreference], userId: String, persistence: MemoryPersistenceService) async throws {
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

    func mergeGlucosePatterns(serverPatterns: [ServerGlucosePattern], userId: String, persistence: MemoryPersistenceService) async throws {
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

    func mergeUserPreferences(serverPreferences: [ServerUserPreference], userId: String, persistence: MemoryPersistenceService) async throws {
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

    // MARK: - HTTP Helper

    private func performGET(url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw MemorySyncError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            logger.error("❌ HTTP \(httpResponse.statusCode): \(errorMessage)")
            throw MemorySyncError.httpError(httpResponse.statusCode, errorMessage)
        }

        return data
    }
}
