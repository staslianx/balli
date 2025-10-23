//
//  PersistentMemoryModels.swift
//  balli
//
//  SwiftData models for persistent memory storage
//  Stores user facts, preferences, conversation summaries, and patterns locally
//  Syncs with Cloud Functions via HTTP (no Firebase SDK)
//
//  Swift 6 strict concurrency compliant
//

import Foundation
import SwiftData

// MARK: - Persistent User Fact

/// A long-term fact about the user stored locally with SwiftData
@Model
final class PersistentUserFact {
    /// Unique identifier
    @Attribute(.unique) var id: String

    /// User ID this fact belongs to
    var userId: String

    /// The fact content
    var fact: String

    /// Category for organization (e.g., "health", "preference", "lifestyle")
    var category: String

    /// Confidence score (0.0-1.0)
    var confidence: Double

    /// When the fact was created
    var createdAt: Date

    /// Last time this fact was accessed/referenced
    var lastAccessedAt: Date

    /// Optional embedding vector (768D) stored as Data
    var embedding: Data?

    /// Source of the fact ("user_stated", "inferred", "observed")
    var source: String

    // MARK: Sync Tracking

    /// Sync status (stored as raw value for SwiftData predicate compatibility)
    var syncStatusRawValue: String

    /// Last successful sync timestamp
    var lastSyncedAt: Date?

    /// Error message if sync failed
    var syncError: String?

    /// Number of sync retry attempts
    var retryCount: Int

    /// Last modification timestamp (for conflict resolution)
    var lastModifiedAt: Date?

    init(
        id: String,
        userId: String,
        fact: String,
        category: String,
        confidence: Double,
        createdAt: Date,
        lastAccessedAt: Date,
        embedding: Data? = nil,
        source: String,
        syncStatus: MemorySyncStatus = .pending
    ) {
        self.id = id
        self.userId = userId
        self.fact = fact
        self.category = category
        self.confidence = confidence
        self.createdAt = createdAt
        self.lastAccessedAt = lastAccessedAt
        self.embedding = embedding
        self.source = source
        self.syncStatusRawValue = syncStatus.rawValue
        self.retryCount = 0
        self.lastModifiedAt = Date()
    }

    /// Computed property for sync status enum
    var syncStatus: MemorySyncStatus {
        get { MemorySyncStatus(rawValue: syncStatusRawValue) ?? .pending }
        set { syncStatusRawValue = newValue.rawValue }
    }
}

// MARK: - Persistent Conversation Summary

/// A summary of a conversation segment stored locally
@Model
final class PersistentConversationSummary {
    /// Unique identifier
    @Attribute(.unique) var id: String

    /// User ID this summary belongs to
    var userId: String

    /// Summary text
    var summary: String

    /// When this conversation segment started
    var startTime: Date

    /// When this conversation segment ended
    var endTime: Date

    /// Number of messages in this segment
    var messageCount: Int

    /// Optional embedding vector (768D) stored as Data
    var embedding: Data?

    /// Memory tier (immediate, recent, historical)
    var tierRawValue: String

    // MARK: Sync Tracking

    var syncStatusRawValue: String
    var lastSyncedAt: Date?
    var syncError: String?
    var retryCount: Int
    var lastModifiedAt: Date?

    init(
        id: String,
        userId: String,
        summary: String,
        startTime: Date,
        endTime: Date,
        messageCount: Int,
        embedding: Data? = nil,
        tier: MemoryTier,
        syncStatus: MemorySyncStatus = .pending
    ) {
        self.id = id
        self.userId = userId
        self.summary = summary
        self.startTime = startTime
        self.endTime = endTime
        self.messageCount = messageCount
        self.embedding = embedding
        self.tierRawValue = tier.rawValue
        self.syncStatusRawValue = syncStatus.rawValue
        self.retryCount = 0
        self.lastModifiedAt = Date()
    }

    var tier: MemoryTier {
        get { MemoryTier(rawValue: tierRawValue) ?? .persistent }
        set { tierRawValue = newValue.rawValue }
    }

    var syncStatus: MemorySyncStatus {
        get { MemorySyncStatus(rawValue: syncStatusRawValue) ?? .pending }
        set { syncStatusRawValue = newValue.rawValue }
    }
}

// MARK: - Persistent Recipe Preference

/// A saved recipe or meal preference
@Model
final class PersistentRecipePreference {
    /// Unique identifier
    @Attribute(.unique) var id: String

    /// User ID this recipe belongs to
    var userId: String

    /// Recipe title
    var title: String

    /// Full recipe content
    var content: String

    /// When the recipe was saved
    var savedAt: Date

    /// Last time the recipe was accessed
    var lastAccessedAt: Date

    /// How many times the recipe was referenced
    var accessCount: Int

    /// Optional embedding vector (768D) stored as Data
    var embedding: Data?

    /// Recipe metadata stored as JSON string
    var metadataJSON: String?

    // MARK: Sync Tracking

    var syncStatusRawValue: String
    var lastSyncedAt: Date?
    var syncError: String?
    var retryCount: Int
    var lastModifiedAt: Date?

    init(
        id: String,
        userId: String,
        title: String,
        content: String,
        savedAt: Date,
        lastAccessedAt: Date,
        accessCount: Int = 0,
        embedding: Data? = nil,
        metadataJSON: String? = nil,
        syncStatus: MemorySyncStatus = .pending
    ) {
        self.id = id
        self.userId = userId
        self.title = title
        self.content = content
        self.savedAt = savedAt
        self.lastAccessedAt = lastAccessedAt
        self.accessCount = accessCount
        self.embedding = embedding
        self.metadataJSON = metadataJSON
        self.syncStatusRawValue = syncStatus.rawValue
        self.retryCount = 0
        self.lastModifiedAt = Date()
    }

    var syncStatus: MemorySyncStatus {
        get { MemorySyncStatus(rawValue: syncStatusRawValue) ?? .pending }
        set { syncStatusRawValue = newValue.rawValue }
    }
}

// MARK: - Persistent Glucose Pattern

/// A glucose response pattern (meal → glucose rise)
@Model
final class PersistentGlucosePattern {
    /// Unique identifier
    @Attribute(.unique) var id: String

    /// User ID this pattern belongs to
    var userId: String

    /// Meal description
    var meal: String

    /// Glucose rise in mg/dL
    var glucoseRise: Double

    /// Time to return to baseline in minutes
    var timeToBaseline: Int

    /// When this pattern was observed
    var observedAt: Date

    /// Confidence score (0.0-1.0)
    var confidence: Double

    /// Optional embedding vector (768D) stored as Data
    var embedding: Data?

    /// Expires after 30 days
    var expiresAt: Date

    // MARK: Sync Tracking

    var syncStatusRawValue: String
    var lastSyncedAt: Date?
    var syncError: String?
    var retryCount: Int

    init(
        id: String,
        userId: String,
        meal: String,
        glucoseRise: Double,
        timeToBaseline: Int,
        observedAt: Date,
        confidence: Double,
        embedding: Data? = nil,
        expiresAt: Date,
        syncStatus: MemorySyncStatus = .pending
    ) {
        self.id = id
        self.userId = userId
        self.meal = meal
        self.glucoseRise = glucoseRise
        self.timeToBaseline = timeToBaseline
        self.observedAt = observedAt
        self.confidence = confidence
        self.embedding = embedding
        self.expiresAt = expiresAt
        self.syncStatusRawValue = syncStatus.rawValue
        self.retryCount = 0
    }

    var syncStatus: MemorySyncStatus {
        get { MemorySyncStatus(rawValue: syncStatusRawValue) ?? .pending }
        set { syncStatusRawValue = newValue.rawValue }
    }
}

// MARK: - Persistent User Preference

/// A user preference (key-value pair)
@Model
final class PersistentUserPreference {
    /// Unique identifier (userId + key)
    @Attribute(.unique) var id: String

    /// User ID this preference belongs to
    var userId: String

    /// Preference key
    var key: String

    /// Preference value type
    var valueType: String

    /// String value (if valueType == "string")
    var stringValue: String?

    /// Int value (if valueType == "int")
    var intValue: Int?

    /// Double value (if valueType == "double")
    var doubleValue: Double?

    /// Bool value (if valueType == "bool")
    var boolValue: Bool?

    /// Date value as timestamp (if valueType == "date")
    var dateValue: Date?

    /// Array value as JSON string (if valueType == "array")
    var arrayJSON: String?

    /// When the preference was set
    var updatedAt: Date

    // MARK: Sync Tracking

    var syncStatusRawValue: String
    var lastSyncedAt: Date?
    var syncError: String?
    var retryCount: Int

    init(
        userId: String,
        key: String,
        value: PreferenceValue,
        syncStatus: MemorySyncStatus = .pending
    ) {
        self.id = "\(userId)_\(key)"
        self.userId = userId
        self.key = key
        self.updatedAt = Date()
        self.syncStatusRawValue = syncStatus.rawValue
        self.retryCount = 0

        // Set value type and appropriate field
        switch value {
        case .string(let v):
            self.valueType = "string"
            self.stringValue = v
        case .int(let v):
            self.valueType = "int"
            self.intValue = v
        case .double(let v):
            self.valueType = "double"
            self.doubleValue = v
        case .bool(let v):
            self.valueType = "bool"
            self.boolValue = v
        case .date(let v):
            self.valueType = "date"
            self.dateValue = v
        case .array(let v):
            self.valueType = "array"
            self.arrayJSON = try? String(data: JSONEncoder().encode(v), encoding: .utf8)
        }
    }

    /// Convert back to PreferenceValue
    var preferenceValue: PreferenceValue? {
        switch valueType {
        case "string":
            if let v = stringValue { return .string(v) }
        case "int":
            if let v = intValue { return .int(v) }
        case "double":
            if let v = doubleValue { return .double(v) }
        case "bool":
            if let v = boolValue { return .bool(v) }
        case "date":
            if let v = dateValue { return .date(v) }
        case "array":
            if let json = arrayJSON,
               let data = json.data(using: .utf8),
               let arr = try? JSONDecoder().decode([String].self, from: data) {
                return .array(arr)
            }
        default:
            break
        }
        return nil
    }

    var syncStatus: MemorySyncStatus {
        get { MemorySyncStatus(rawValue: syncStatusRawValue) ?? .pending }
        set { syncStatusRawValue = newValue.rawValue }
    }
}

// MARK: - Memory Sync Status

/// Sync status for memory entries
enum MemorySyncStatus: String, Codable, Sendable {
    /// Not yet synced to server (offline)
    case pending

    /// Currently being synced
    case syncing

    /// Successfully synced to server
    case synced

    /// Sync failed (will retry)
    case failed

    /// Sync permanently failed (exceeded max retries)
    case permanentlyFailed
}

// MARK: - Sendable Conformance

/// SwiftData @Model classes need @unchecked Sendable to cross actor boundaries
/// Thread Safety Guarantee: SwiftData manages thread safety internally via ModelContext
/// which is bound to a specific thread/actor. All modifications happen on MainActor.

extension PersistentUserFact: @unchecked Sendable {}
extension PersistentConversationSummary: @unchecked Sendable {}
extension PersistentRecipePreference: @unchecked Sendable {}
extension PersistentGlucosePattern: @unchecked Sendable {}
extension PersistentUserPreference: @unchecked Sendable {}
