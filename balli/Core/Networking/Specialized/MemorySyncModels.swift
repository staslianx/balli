//
//  MemorySyncModels.swift
//  balli
//
//  Server-side models for memory sync operations
//  Shared between MemorySyncService and MemoryPersistenceService
//
//  Swift 6 strict concurrency compliant
//

import Foundation

// MARK: - Sendable Wrapper for Upload Data

/// Sendable wrapper for dictionary data used in uploads
struct SendableDictionary: @unchecked Sendable {
    let data: [String: Any]

    init(_ data: [String: Any]) {
        self.data = data
    }
}

// MARK: - Server User Fact

/// Server-side user fact model (from Cloud Functions)
struct ServerUserFact: Sendable {
    let id: String
    let userId: String
    let fact: String
    let category: String
    let confidence: Double
    let createdAt: Date
    let lastAccessedAt: Date
    let embedding: Data?
    let source: String
    let lastModifiedAt: Date

    init?(from dict: [String: Any]) {
        guard let id = dict["id"] as? String,
              let userId = dict["userId"] as? String,
              let fact = dict["fact"] as? String,
              let category = dict["category"] as? String,
              let confidence = dict["confidence"] as? Double,
              let createdAtString = dict["createdAt"] as? String,
              let lastAccessedAtString = dict["lastAccessedAt"] as? String,
              let source = dict["source"] as? String else {
            return nil
        }

        let formatter = ISO8601DateFormatter()
        guard let createdAt = formatter.date(from: createdAtString),
              let lastAccessedAt = formatter.date(from: lastAccessedAtString) else {
            return nil
        }

        // lastModifiedAt is optional, fallback to createdAt
        let lastModifiedAt: Date
        if let lastModifiedAtString = dict["lastModifiedAt"] as? String,
           let parsed = formatter.date(from: lastModifiedAtString) {
            lastModifiedAt = parsed
        } else {
            lastModifiedAt = createdAt
        }

        self.id = id
        self.userId = userId
        self.fact = fact
        self.category = category
        self.confidence = confidence
        self.createdAt = createdAt
        self.lastAccessedAt = lastAccessedAt
        self.source = source
        self.lastModifiedAt = lastModifiedAt

        // Decode embedding from base64
        if let embeddingBase64 = dict["embedding"] as? String {
            self.embedding = Data(base64Encoded: embeddingBase64)
        } else {
            self.embedding = nil
        }
    }
}

// MARK: - Server Conversation Summary

/// Server-side conversation summary model
struct ServerConversationSummary: Sendable {
    let id: String
    let userId: String
    let summary: String
    let startTime: Date
    let endTime: Date
    let messageCount: Int
    let embedding: Data?
    let tier: String
    let lastModifiedAt: Date

    init?(from dict: [String: Any]) {
        guard let id = dict["id"] as? String,
              let userId = dict["userId"] as? String,
              let summary = dict["summary"] as? String,
              let startTimeString = dict["startTime"] as? String,
              let endTimeString = dict["endTime"] as? String,
              let messageCount = dict["messageCount"] as? Int,
              let tier = dict["tier"] as? String else {
            return nil
        }

        let formatter = ISO8601DateFormatter()
        guard let startTime = formatter.date(from: startTimeString),
              let endTime = formatter.date(from: endTimeString) else {
            return nil
        }

        let lastModifiedAt: Date
        if let lastModifiedAtString = dict["lastModifiedAt"] as? String,
           let parsed = formatter.date(from: lastModifiedAtString) {
            lastModifiedAt = parsed
        } else {
            lastModifiedAt = endTime
        }

        self.id = id
        self.userId = userId
        self.summary = summary
        self.startTime = startTime
        self.endTime = endTime
        self.messageCount = messageCount
        self.tier = tier
        self.lastModifiedAt = lastModifiedAt

        if let embeddingBase64 = dict["embedding"] as? String {
            self.embedding = Data(base64Encoded: embeddingBase64)
        } else {
            self.embedding = nil
        }
    }
}

// MARK: - Server Recipe Preference

/// Server-side recipe preference model
struct ServerRecipePreference: Sendable {
    let id: String
    let userId: String
    let title: String
    let content: String
    let savedAt: Date
    let lastAccessedAt: Date
    let accessCount: Int
    let embedding: Data?
    let metadataJSON: String?
    let lastModifiedAt: Date

    init?(from dict: [String: Any]) {
        guard let id = dict["id"] as? String,
              let userId = dict["userId"] as? String,
              let title = dict["title"] as? String,
              let content = dict["content"] as? String,
              let savedAtString = dict["savedAt"] as? String,
              let lastAccessedAtString = dict["lastAccessedAt"] as? String else {
            return nil
        }

        let formatter = ISO8601DateFormatter()
        guard let savedAt = formatter.date(from: savedAtString),
              let lastAccessedAt = formatter.date(from: lastAccessedAtString) else {
            return nil
        }

        let lastModifiedAt: Date
        if let lastModifiedAtString = dict["lastModifiedAt"] as? String,
           let parsed = formatter.date(from: lastModifiedAtString) {
            lastModifiedAt = parsed
        } else {
            lastModifiedAt = savedAt
        }

        self.id = id
        self.userId = userId
        self.title = title
        self.content = content
        self.savedAt = savedAt
        self.lastAccessedAt = lastAccessedAt
        self.accessCount = dict["accessCount"] as? Int ?? 0
        self.metadataJSON = dict["metadataJSON"] as? String
        self.lastModifiedAt = lastModifiedAt

        if let embeddingBase64 = dict["embedding"] as? String {
            self.embedding = Data(base64Encoded: embeddingBase64)
        } else {
            self.embedding = nil
        }
    }
}

// MARK: - Server Glucose Pattern

/// Server-side glucose pattern model
struct ServerGlucosePattern: Sendable {
    let id: String
    let userId: String
    let meal: String
    let glucoseRise: Double
    let timeToBaseline: Int
    let observedAt: Date
    let confidence: Double
    let embedding: Data?
    let expiresAt: Date
    let lastModifiedAt: Date

    init?(from dict: [String: Any]) {
        guard let id = dict["id"] as? String,
              let userId = dict["userId"] as? String,
              let meal = dict["meal"] as? String,
              let glucoseRise = dict["glucoseRise"] as? Double,
              let timeToBaseline = dict["timeToBaseline"] as? Int,
              let observedAtString = dict["observedAt"] as? String,
              let confidence = dict["confidence"] as? Double,
              let expiresAtString = dict["expiresAt"] as? String else {
            return nil
        }

        let formatter = ISO8601DateFormatter()
        guard let observedAt = formatter.date(from: observedAtString),
              let expiresAt = formatter.date(from: expiresAtString) else {
            return nil
        }

        let lastModifiedAt: Date
        if let lastModifiedAtString = dict["lastModifiedAt"] as? String,
           let parsed = formatter.date(from: lastModifiedAtString) {
            lastModifiedAt = parsed
        } else {
            lastModifiedAt = observedAt
        }

        self.id = id
        self.userId = userId
        self.meal = meal
        self.glucoseRise = glucoseRise
        self.timeToBaseline = timeToBaseline
        self.observedAt = observedAt
        self.confidence = confidence
        self.expiresAt = expiresAt
        self.lastModifiedAt = lastModifiedAt

        if let embeddingBase64 = dict["embedding"] as? String {
            self.embedding = Data(base64Encoded: embeddingBase64)
        } else {
            self.embedding = nil
        }
    }
}

// MARK: - Server User Preference

/// Server-side user preference model
struct ServerUserPreference: Sendable {
    let id: String
    let userId: String
    let key: String
    let valueType: String
    let stringValue: String?
    let intValue: Int?
    let doubleValue: Double?
    let boolValue: Bool?
    let dateValue: Date?
    let arrayJSON: String?
    let updatedAt: Date
    let lastModifiedAt: Date

    init?(from dict: [String: Any]) {
        guard let id = dict["id"] as? String,
              let userId = dict["userId"] as? String,
              let key = dict["key"] as? String,
              let valueType = dict["valueType"] as? String,
              let updatedAtString = dict["updatedAt"] as? String else {
            return nil
        }

        let formatter = ISO8601DateFormatter()
        guard let updatedAt = formatter.date(from: updatedAtString) else {
            return nil
        }

        let lastModifiedAt: Date
        if let lastModifiedAtString = dict["lastModifiedAt"] as? String,
           let parsed = formatter.date(from: lastModifiedAtString) {
            lastModifiedAt = parsed
        } else {
            lastModifiedAt = updatedAt
        }

        self.id = id
        self.userId = userId
        self.key = key
        self.valueType = valueType
        self.updatedAt = updatedAt
        self.lastModifiedAt = lastModifiedAt

        // Parse value based on type
        self.stringValue = dict["stringValue"] as? String
        self.intValue = dict["intValue"] as? Int
        self.doubleValue = dict["doubleValue"] as? Double
        self.boolValue = dict["boolValue"] as? Bool

        if let dateValueString = dict["dateValue"] as? String,
           let parsed = formatter.date(from: dateValueString) {
            self.dateValue = parsed
        } else {
            self.dateValue = nil
        }

        self.arrayJSON = dict["arrayJSON"] as? String
    }
}
