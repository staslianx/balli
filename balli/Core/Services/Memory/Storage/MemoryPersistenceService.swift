//
//  MemoryPersistenceService.swift
//  balli
//
//  Main coordinator for local memory persistence with SwiftData
//  Delegates read/write operations to specialized components
//
//  Swift 6 strict concurrency compliant
//

import Foundation
import SwiftData
import OSLog

// MARK: - Memory Persistence Service

/// @MainActor service for SwiftData persistence (ModelContext requires MainActor)
@MainActor
final class MemoryPersistenceService {
    // MARK: - Properties

    private let logger = AppLoggers.Data.sync
    private let modelContext: ModelContext
    private let writer: MemoryPersistenceWriter
    private let reader: MemoryPersistenceReader

    // MARK: - Configuration

    /// Maximum retry count before marking as permanently failed
    static let maxRetryCount = 3

    /// Maximum age for cached patterns (30 days)
    static let maxPatternAge: TimeInterval = 30 * 24 * 60 * 60

    // MARK: - Initialization

    init() {
        // Access MainActor-isolated singleton (we're already on MainActor)
        do {
            self.modelContext = try MemoryModelContainer.shared.makeContext()
            self.writer = MemoryPersistenceWriter(modelContext: modelContext)
            self.reader = MemoryPersistenceReader(modelContext: modelContext)
            logger.info("MemoryPersistenceService initialized")
        } catch {
            // If memory storage fails, create in-memory fallback
            logger.error("Failed to initialize memory storage, using in-memory fallback: \(error.localizedDescription)")

            let schema = Schema([
                PersistentUserFact.self,
                PersistentConversationSummary.self,
                PersistentRecipePreference.self,
                PersistentGlucosePattern.self,
                PersistentUserPreference.self
            ])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)

            do {
                let fallbackContainer = try ModelContainer(for: schema, configurations: [config])
                self.modelContext = ModelContext(fallbackContainer)
                self.writer = MemoryPersistenceWriter(modelContext: modelContext)
                self.reader = MemoryPersistenceReader(modelContext: modelContext)
                logger.info("Successfully created in-memory fallback container")
            } catch {
                logger.critical("CRITICAL: Failed to create in-memory fallback container: \(error.localizedDescription)")

                // ABSOLUTE LAST RESORT: Create empty schema container
                // This allows app to continue without memory features
                logger.fault("Creating emergency empty-schema container - memory features disabled")

                do {
                    let emptySchema = Schema([])
                    let emergencyContainer = try ModelContainer(for: emptySchema)
                    self.modelContext = ModelContext(emergencyContainer)
                    self.writer = MemoryPersistenceWriter(modelContext: modelContext)
                    self.reader = MemoryPersistenceReader(modelContext: modelContext)
                    logger.warning("Emergency container created - memory features will not work, but app can continue")
                } catch {
                    // If even THIS fails, SwiftData is completely broken
                    // Use fatalError only as absolute last resort after all attempts
                    logger.fault("💥 FAULT: SwiftData completely broken - cannot create any ModelContainer")
                    fatalError("SwiftData framework is non-functional. Please reinstall the app. Error: \(error)")
                }
            }
        }
    }

    // MARK: - User Facts CRUD

    /// Save a user fact locally
    func saveFact(_ fact: String, userId: String, category: String, confidence: Double, source: String, embedding: [Double]?) throws {
        try writer.saveFact(fact, userId: userId, category: category, confidence: confidence, source: source, embedding: embedding)
    }

    /// Fetch all facts for a user
    func fetchFacts(userId: String) throws -> [PersistentUserFact] {
        try reader.fetchFacts(userId: userId)
    }

    /// Update fact last accessed time
    func updateFactAccess(factId: String) throws {
        try writer.updateFactAccess(factId: factId)
    }

    /// Delete a fact
    func deleteFact(factId: String) throws {
        try writer.deleteFact(factId: factId)
    }

    // MARK: - Conversation Summaries CRUD

    /// Save a conversation summary
    func saveSummary(
        userId: String,
        summary: String,
        startTime: Date,
        endTime: Date,
        messageCount: Int,
        tier: MemoryTier,
        embedding: [Double]?
    ) throws {
        try writer.saveSummary(userId: userId, summary: summary, startTime: startTime, endTime: endTime, messageCount: messageCount, tier: tier, embedding: embedding)
    }

    /// Fetch summaries for a user
    func fetchSummaries(userId: String, tier: MemoryTier? = nil, limit: Int = 20) throws -> [PersistentConversationSummary] {
        try reader.fetchSummaries(userId: userId, tier: tier, limit: limit)
    }

    // MARK: - Recipe Preferences CRUD

    /// Save a recipe preference
    func saveRecipe(
        userId: String,
        title: String,
        content: String,
        embedding: [Double]?,
        metadata: [String: String]?
    ) throws {
        try writer.saveRecipe(userId: userId, title: title, content: content, embedding: embedding, metadata: metadata)
    }

    /// Fetch recipes for a user
    func fetchRecipes(userId: String, limit: Int = 50) throws -> [PersistentRecipePreference] {
        try reader.fetchRecipes(userId: userId, limit: limit)
    }

    /// Update recipe access count and time
    func updateRecipeAccess(recipeId: String) throws {
        try writer.updateRecipeAccess(recipeId: recipeId)
    }

    // MARK: - Glucose Patterns CRUD

    /// Save a glucose pattern
    func saveGlucosePattern(
        userId: String,
        meal: String,
        glucoseRise: Double,
        timeToBaseline: Int,
        confidence: Double,
        embedding: [Double]?
    ) throws {
        try writer.saveGlucosePattern(userId: userId, meal: meal, glucoseRise: glucoseRise, timeToBaseline: timeToBaseline, confidence: confidence, embedding: embedding)
    }

    /// Fetch glucose patterns for a user (non-expired only)
    func fetchGlucosePatterns(userId: String) throws -> [PersistentGlucosePattern] {
        try reader.fetchGlucosePatterns(userId: userId)
    }

    /// Clean up expired patterns
    func cleanupExpiredPatterns() throws {
        try writer.cleanupExpiredPatterns()
    }

    // MARK: - User Preferences CRUD

    /// Save a user preference
    func savePreference(userId: String, key: String, value: PreferenceValue) throws {
        try writer.savePreference(userId: userId, key: key, value: value)
    }

    /// Fetch all preferences for a user
    func fetchPreferences(userId: String) throws -> [PersistentUserPreference] {
        try reader.fetchPreferences(userId: userId)
    }

    // MARK: - Sync Operations

    /// Fetch all unsynced memory items (for sync to Cloud Functions)
    func fetchUnsyncedItems(userId: String) throws -> UnsyncedMemoryItems {
        try reader.fetchUnsyncedItems(userId: userId)
    }

    /// Mark items as synced
    func markAsSynced(
        factIds: [String] = [],
        summaryIds: [String] = [],
        recipeIds: [String] = [],
        patternIds: [String] = [],
        preferenceIds: [String] = []
    ) throws {
        try writer.markAsSynced(factIds: factIds, summaryIds: summaryIds, recipeIds: recipeIds, patternIds: patternIds, preferenceIds: preferenceIds)
    }

    // MARK: - Sync Helper Methods

    /// Fetch unsynced facts only (for MemorySyncService)
    func fetchUnsyncedFacts(userId: String) throws -> [PersistentUserFact] {
        try reader.fetchUnsyncedFacts(userId: userId)
    }

    /// Fetch unsynced summaries only
    func fetchUnsyncedSummaries(userId: String) throws -> [PersistentConversationSummary] {
        try reader.fetchUnsyncedSummaries(userId: userId)
    }

    /// Fetch unsynced recipes only
    func fetchUnsyncedRecipes(userId: String) throws -> [PersistentRecipePreference] {
        try reader.fetchUnsyncedRecipes(userId: userId)
    }

    /// Fetch unsynced glucose patterns only
    func fetchUnsyncedPatterns(userId: String) throws -> [PersistentGlucosePattern] {
        try reader.fetchUnsyncedPatterns(userId: userId)
    }

    /// Fetch unsynced user preferences only
    func fetchUnsyncedPreferences(userId: String) throws -> [PersistentUserPreference] {
        try reader.fetchUnsyncedPreferences(userId: userId)
    }

    // MARK: - Server Data Integration

    /// Update fact from server data
    func updateFact(from serverFact: ServerUserFact) throws {
        try writer.updateFact(from: serverFact)
    }

    /// Insert fact from server data
    func insertFact(from serverFact: ServerUserFact) throws {
        try writer.insertFact(from: serverFact)
    }

    /// Update summary from server data
    func updateSummary(from serverSummary: ServerConversationSummary) throws {
        try writer.updateSummary(from: serverSummary)
    }

    /// Insert summary from server data
    func insertSummary(from serverSummary: ServerConversationSummary) throws {
        try writer.insertSummary(from: serverSummary)
    }

    /// Update recipe from server data
    func updateRecipe(from serverRecipe: ServerRecipePreference) throws {
        try writer.updateRecipe(from: serverRecipe)
    }

    /// Insert recipe from server data
    func insertRecipe(from serverRecipe: ServerRecipePreference) throws {
        try writer.insertRecipe(from: serverRecipe)
    }

    /// Update glucose pattern from server data
    func updatePattern(from serverPattern: ServerGlucosePattern) throws {
        try writer.updatePattern(from: serverPattern)
    }

    /// Insert glucose pattern from server data
    func insertPattern(from serverPattern: ServerGlucosePattern) throws {
        try writer.insertPattern(from: serverPattern)
    }

    /// Update user preference from server data
    func updatePreference(from serverPref: ServerUserPreference) throws {
        try writer.updatePreference(from: serverPref)
    }

    /// Insert user preference from server data
    func insertPreference(from serverPref: ServerUserPreference) throws {
        try writer.insertPreference(from: serverPref)
    }
}

// MARK: - Error Types

enum MemoryPersistenceError: LocalizedError {
    case factNotFound(String)
    case summaryNotFound(String)
    case recipeNotFound(String)
    case patternNotFound(String)
    case preferenceNotFound(String)
    case invalidPreferenceValue

    var errorDescription: String? {
        switch self {
        case .factNotFound(let id):
            return "User fact not found: \(id)"
        case .summaryNotFound(let id):
            return "Conversation summary not found: \(id)"
        case .recipeNotFound(let id):
            return "Recipe preference not found: \(id)"
        case .patternNotFound(let id):
            return "Glucose pattern not found: \(id)"
        case .preferenceNotFound(let id):
            return "User preference not found: \(id)"
        case .invalidPreferenceValue:
            return "Invalid preference value type"
        }
    }
}

// MARK: - Unsynced Items Container

/// Container for all unsynced memory items
/// Note: SwiftData @Model classes are not Sendable, but actor isolation provides safety
struct UnsyncedMemoryItems {
    let facts: [PersistentUserFact]
    let summaries: [PersistentConversationSummary]
    let recipes: [PersistentRecipePreference]
    let patterns: [PersistentGlucosePattern]
    let preferences: [PersistentUserPreference]

    var isEmpty: Bool {
        facts.isEmpty && summaries.isEmpty && recipes.isEmpty && patterns.isEmpty && preferences.isEmpty
    }
}
