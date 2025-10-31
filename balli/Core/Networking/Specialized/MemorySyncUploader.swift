//
//  MemorySyncUploader.swift
//  balli
//
//  Upload operations for memory sync
//  Converts SwiftData models to JSON and sends via HTTP POST
//  Swift 6 strict concurrency compliant
//

import Foundation
import OSLog

// MARK: - Memory Sync Uploader

/// Actor-isolated service for uploading memory data to Cloud Functions
actor MemorySyncUploader {

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

    // MARK: - Upload Methods

    func uploadUserFacts(facts: [PersistentUserFact], userId: String) async throws {
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
            throw MemorySyncError.invalidResponse
        }

        let body: [String: Any] = [
            "userId": userId,
            "facts": factDicts.map { $0.data }
        ]

        _ = try await performPOST(url: url, body: body)
        logger.debug("✅ Uploaded \(facts.count) facts successfully")
    }

    func uploadConversationSummaries(summaries: [PersistentConversationSummary], userId: String) async throws {
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
            throw MemorySyncError.invalidResponse
        }

        let body: [String: Any] = [
            "userId": userId,
            "summaries": summaryDicts.map { $0.data }
        ]

        _ = try await performPOST(url: url, body: body)
        logger.debug("✅ Uploaded \(summaries.count) summaries successfully")
    }

    func uploadRecipePreferences(recipes: [PersistentRecipePreference], userId: String) async throws {
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
            throw MemorySyncError.invalidResponse
        }

        let body: [String: Any] = [
            "userId": userId,
            "recipes": recipeDicts.map { $0.data }
        ]

        _ = try await performPOST(url: url, body: body)
        logger.debug("✅ Uploaded \(recipes.count) recipes successfully")
    }

    func uploadGlucosePatterns(patterns: [PersistentGlucosePattern], userId: String) async throws {
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
            throw MemorySyncError.invalidResponse
        }

        let body: [String: Any] = [
            "userId": userId,
            "patterns": patternDicts.map { $0.data }
        ]

        _ = try await performPOST(url: url, body: body)
        logger.debug("✅ Uploaded \(patterns.count) patterns successfully")
    }

    func uploadUserPreferences(preferences: [PersistentUserPreference], userId: String) async throws {
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
            throw MemorySyncError.invalidResponse
        }

        let body: [String: Any] = [
            "userId": userId,
            "preferences": prefDicts.map { $0.data }
        ]

        _ = try await performPOST(url: url, body: body)
        logger.debug("✅ Uploaded \(preferences.count) preferences successfully")
    }

    // MARK: - HTTP Helper

    private func performPOST(url: URL, body: [String: Any]) async throws -> Data {
        // Serialize body to Data before entering @Sendable closure
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

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
