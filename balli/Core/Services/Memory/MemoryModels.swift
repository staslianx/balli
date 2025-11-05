//
//  MemoryModels.swift
//  balli
//
//  Shared memory data models and types
//  Extracted from MemoryService for better organization
//  Swift 6 strict concurrency compliant
//

import Foundation

// MARK: - Memory Types

enum MemoryType: String, Codable, Sendable {
    case userFact = "user_fact"           // Persistent facts about user
    case preference = "preference"         // User preferences
    case mealPattern = "meal_pattern"     // Recurring meal behaviors
    case glucosePattern = "glucose_pattern" // Glucose response patterns
    case contextual = "contextual"         // Temporary contextual info
    case conversation = "conversation"     // Conversation history
    case recipe = "recipe"                // Full recipe storage
    case summary = "summary"              // AI-generated summaries
}

// MARK: - Memory Tier

enum MemoryTier: String, Codable, Sendable {
    case immediate = "immediate"   // Last 7 messages - full text
    case recent = "recent"         // Messages 8-14 - summaries
    case historical = "historical" // Messages 15-20 - key facts
    case persistent = "persistent" // User profile facts
}

// MARK: - Memory Entry

struct MemoryEntry: Codable, Sendable {
    let id: String
    let type: MemoryType
    var content: String
    let metadata: [String: String]?
    let timestamp: Date
    let expiresAt: Date?
    let confidence: Double
    let source: String // "user_stated", "inferred", "observed"
    var tier: MemoryTier?
    var embedding: [Double]? // Vector embedding for semantic search

    init(
        id: String = UUID().uuidString,
        type: MemoryType,
        content: String,
        metadata: [String: String]? = nil,
        timestamp: Date = Date(),
        expiresAt: Date? = nil,
        confidence: Double = 1.0,
        source: String = "user_stated",
        tier: MemoryTier? = nil,
        embedding: [Double]? = nil
    ) {
        self.id = id
        self.type = type
        self.content = content
        self.metadata = metadata
        self.timestamp = timestamp
        self.expiresAt = expiresAt
        self.confidence = confidence
        self.source = source
        self.tier = tier
        self.embedding = embedding
    }
}

// MARK: - Preference Value

/// Type-safe preference value that conforms to Sendable
enum PreferenceValue: Codable, Sendable, Equatable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case date(Date)
    case array([String])

    /// Convert from Any value (fallback for legacy code)
    init(anyValue: Any) {
        switch anyValue {
        case let value as String:
            self = .string(value)
        case let value as Int:
            self = .int(value)
        case let value as Double:
            self = .double(value)
        case let value as Bool:
            self = .bool(value)
        case let value as Date:
            self = .date(value)
        case let value as [String]:
            self = .array(value)
        default:
            // Fallback: convert to string representation
            self = .string(String(describing: anyValue))
        }
    }

    /// Get string representation for display/storage
    var stringValue: String {
        switch self {
        case .string(let value): return value
        case .int(let value): return String(value)
        case .double(let value): return String(value)
        case .bool(let value): return String(value)
        case .date(let value): return ISO8601DateFormatter().string(from: value)
        case .array(let value): return value.joined(separator: ", ")
        }
    }

    /// Access typed value safely
    var asString: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    var asInt: Int? {
        if case .int(let value) = self { return value }
        return nil
    }

    var asDouble: Double? {
        if case .double(let value) = self { return value }
        return nil
    }

    var asBool: Bool? {
        if case .bool(let value) = self { return value }
        return nil
    }

    var asDate: Date? {
        if case .date(let value) = self { return value }
        return nil
    }

    var asArray: [String]? {
        if case .array(let value) = self { return value }
        return nil
    }
}

// MARK: - User Memory Cache

/// Reference-type cache for efficient in-place mutation within actor isolation
/// Uses class instead of struct to avoid expensive copying of large arrays
/// Thread-safety is guaranteed by actor isolation in MemoryStorageActor
final class UserMemoryCache: @unchecked Sendable {
    var immediateMemory: [MemoryEntry] = []  // Last 7 full messages
    var recentMemory: [MemoryEntry] = []     // Messages 8-14 summaries
    var historicalMemory: [MemoryEntry] = [] // Messages 15-20 facts
    var userFacts: [String] = []
    var preferences: [String: PreferenceValue] = [:] // Type-safe Sendable preferences
    var recentPatterns: [MemoryEntry] = []
    var storedRecipes: [String: MemoryEntry] = [:] // Recipe deduplication
    var lastActivityTime = Date()

    // Repository for Core Data persistence
    private let repository: MemoryRepository?

    init(repository: MemoryRepository? = nil) {
        self.repository = repository
    }

    // MARK: - Persistence Methods

    /// Load memory from Core Data persistence
    func loadFromPersistence() async throws {
        guard let repository = repository else { return }

        // Load immediate tier
        let immediate = try await repository.loadMemoryEntries(tier: .immediate)
        self.immediateMemory = immediate

        // Load recent tier
        let recent = try await repository.loadMemoryEntries(tier: .recent)
        self.recentMemory = recent

        // Load historical tier
        let historical = try await repository.loadMemoryEntries(tier: .historical)
        self.historicalMemory = historical

        // Load user facts (persistent tier or type)
        let facts = try await repository.loadMemoryEntries(type: .userFact)
        self.userFacts = facts.map { $0.content }

        // Load preferences
        self.preferences = try await repository.loadPreferences()

        // Load patterns
        let patterns = try await repository.loadMemoryEntries(type: .mealPattern)
        self.recentPatterns = patterns

        // Load recipes
        let recipes = try await repository.loadMemoryEntries(type: .recipe)
        for recipe in recipes {
            self.storedRecipes[recipe.id] = recipe
        }
    }

    /// Save memory to Core Data persistence
    func saveToPersistence() async throws {
        guard let repository = repository else { return }

        // Collect all memory entries to save
        var allEntries: [MemoryEntry] = []
        allEntries.append(contentsOf: immediateMemory)
        allEntries.append(contentsOf: recentMemory)
        allEntries.append(contentsOf: historicalMemory)
        allEntries.append(contentsOf: recentPatterns)
        allEntries.append(contentsOf: storedRecipes.values)

        // Batch save memory entries
        try await repository.saveMemoryEntries(allEntries)

        // Save preferences
        for (key, value) in preferences {
            try await repository.savePreference(key: key, value: value)
        }
    }

    /// Background auto-save (call periodically)
    func backgroundSave() async {
        do {
            try await saveToPersistence()
        } catch {
            // Silent fail for background saves - will retry next time
        }
    }

    /// Create a deep copy for testing or serialization
    func copy() -> UserMemoryCache {
        let newCache = UserMemoryCache()
        newCache.immediateMemory = self.immediateMemory
        newCache.recentMemory = self.recentMemory
        newCache.historicalMemory = self.historicalMemory
        newCache.userFacts = self.userFacts
        newCache.preferences = self.preferences
        newCache.recentPatterns = self.recentPatterns
        newCache.storedRecipes = self.storedRecipes
        newCache.lastActivityTime = self.lastActivityTime
        return newCache
    }
}
