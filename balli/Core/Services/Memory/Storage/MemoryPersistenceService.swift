//
//  MemoryPersistenceService.swift
//  balli
//
//  Actor managing local memory persistence with SwiftData
//  Provides CRUD operations and sync status tracking
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

    // MARK: - Configuration

    /// Maximum retry count before marking as permanently failed
    static let maxRetryCount = 3

    /// Maximum age for cached patterns (30 days)
    static let maxPatternAge: TimeInterval = 30 * 24 * 60 * 60

    // MARK: - Initialization

    init() {
        // Access MainActor-isolated singleton (we're already on MainActor)
        self.modelContext = ModelContext(MemoryModelContainer.shared.container)
        logger.info("MemoryPersistenceService initialized")
    }

    // MARK: - User Facts CRUD

    /// Save a user fact locally
    func saveFact(_ fact: String, userId: String, category: String, confidence: Double, source: String, embedding: [Double]?) throws {
        let embeddingData: Data? = if let embedding = embedding {
            try? JSONEncoder().encode(embedding)
        } else {
            nil
        }

        let persistentFact = PersistentUserFact(
            id: UUID().uuidString,
            userId: userId,
            fact: fact,
            category: category,
            confidence: confidence,
            createdAt: Date(),
            lastAccessedAt: Date(),
            embedding: embeddingData,
            source: source
        )

        modelContext.insert(persistentFact)

        do {
            try modelContext.save()
            logger.info("💾 Saved user fact: \(fact.prefix(50))")
        } catch {
            logger.error("❌ Failed to save user fact: \(error.localizedDescription)")
            throw error
        }
    }

    /// Fetch all facts for a user
    func fetchFacts(userId: String) throws -> [PersistentUserFact] {
        let descriptor = FetchDescriptor<PersistentUserFact>(
            predicate: #Predicate { $0.userId == userId },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )

        do {
            let facts = try modelContext.fetch(descriptor)
            logger.debug("📖 Fetched \(facts.count) facts for user")
            return facts
        } catch {
            logger.error("❌ Failed to fetch facts: \(error.localizedDescription)")
            throw error
        }
    }

    /// Update fact last accessed time
    func updateFactAccess(factId: String) throws {
        let descriptor = FetchDescriptor<PersistentUserFact>(
            predicate: #Predicate { $0.id == factId }
        )

        guard let fact = try modelContext.fetch(descriptor).first else {
            logger.warning("⚠️ Fact not found for access update: \(factId)")
            return
        }

        fact.lastAccessedAt = Date()

        do {
            try modelContext.save()
            logger.debug("🔄 Updated fact access time")
        } catch {
            logger.error("❌ Failed to update fact access: \(error.localizedDescription)")
            throw error
        }
    }

    /// Delete a fact
    func deleteFact(factId: String) throws {
        let descriptor = FetchDescriptor<PersistentUserFact>(
            predicate: #Predicate { $0.id == factId }
        )

        guard let fact = try modelContext.fetch(descriptor).first else {
            logger.warning("⚠️ Fact not found for deletion: \(factId)")
            return
        }

        modelContext.delete(fact)

        do {
            try modelContext.save()
            logger.info("🗑️ Deleted fact: \(factId)")
        } catch {
            logger.error("❌ Failed to delete fact: \(error.localizedDescription)")
            throw error
        }
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
        let embeddingData: Data? = if let embedding = embedding {
            try? JSONEncoder().encode(embedding)
        } else {
            nil
        }

        let persistentSummary = PersistentConversationSummary(
            id: UUID().uuidString,
            userId: userId,
            summary: summary,
            startTime: startTime,
            endTime: endTime,
            messageCount: messageCount,
            embedding: embeddingData,
            tier: tier
        )

        modelContext.insert(persistentSummary)

        do {
            try modelContext.save()
            logger.info("💾 Saved conversation summary (\(messageCount) messages)")
        } catch {
            logger.error("❌ Failed to save summary: \(error.localizedDescription)")
            throw error
        }
    }

    /// Fetch summaries for a user
    func fetchSummaries(userId: String, tier: MemoryTier? = nil, limit: Int = 20) throws -> [PersistentConversationSummary] {
        var descriptor: FetchDescriptor<PersistentConversationSummary>

        if let tier = tier {
            let tierValue = tier.rawValue
            descriptor = FetchDescriptor<PersistentConversationSummary>(
                predicate: #Predicate { $0.userId == userId && $0.tierRawValue == tierValue },
                sortBy: [SortDescriptor(\.endTime, order: .reverse)]
            )
        } else {
            descriptor = FetchDescriptor<PersistentConversationSummary>(
                predicate: #Predicate { $0.userId == userId },
                sortBy: [SortDescriptor(\.endTime, order: .reverse)]
            )
        }

        descriptor.fetchLimit = limit

        do {
            let summaries = try modelContext.fetch(descriptor)
            logger.debug("📖 Fetched \(summaries.count) summaries for user")
            return summaries
        } catch {
            logger.error("❌ Failed to fetch summaries: \(error.localizedDescription)")
            throw error
        }
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
        let embeddingData: Data? = if let embedding = embedding {
            try? JSONEncoder().encode(embedding)
        } else {
            nil
        }

        let metadataJSON: String?
        if let metadata = metadata {
            let jsonData = try? JSONEncoder().encode(metadata)
            metadataJSON = jsonData.flatMap { String(data: $0, encoding: .utf8) }
        } else {
            metadataJSON = nil
        }

        let persistentRecipe = PersistentRecipePreference(
            id: UUID().uuidString,
            userId: userId,
            title: title,
            content: content,
            savedAt: Date(),
            lastAccessedAt: Date(),
            embedding: embeddingData,
            metadataJSON: metadataJSON
        )

        modelContext.insert(persistentRecipe)

        do {
            try modelContext.save()
            logger.info("💾 Saved recipe: \(title)")
        } catch {
            logger.error("❌ Failed to save recipe: \(error.localizedDescription)")
            throw error
        }
    }

    /// Fetch recipes for a user
    func fetchRecipes(userId: String, limit: Int = 50) throws -> [PersistentRecipePreference] {
        var descriptor = FetchDescriptor<PersistentRecipePreference>(
            predicate: #Predicate { $0.userId == userId },
            sortBy: [SortDescriptor(\.lastAccessedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit

        do {
            let recipes = try modelContext.fetch(descriptor)
            logger.debug("📖 Fetched \(recipes.count) recipes for user")
            return recipes
        } catch {
            logger.error("❌ Failed to fetch recipes: \(error.localizedDescription)")
            throw error
        }
    }

    /// Update recipe access count and time
    func updateRecipeAccess(recipeId: String) throws {
        let descriptor = FetchDescriptor<PersistentRecipePreference>(
            predicate: #Predicate { $0.id == recipeId }
        )

        guard let recipe = try modelContext.fetch(descriptor).first else {
            logger.warning("⚠️ Recipe not found for access update: \(recipeId)")
            return
        }

        recipe.lastAccessedAt = Date()
        recipe.accessCount += 1

        do {
            try modelContext.save()
            logger.debug("🔄 Updated recipe access count")
        } catch {
            logger.error("❌ Failed to update recipe access: \(error.localizedDescription)")
            throw error
        }
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
        let embeddingData: Data? = if let embedding = embedding {
            try? JSONEncoder().encode(embedding)
        } else {
            nil
        }

        let expiresAt = Date().addingTimeInterval(Self.maxPatternAge)

        let persistentPattern = PersistentGlucosePattern(
            id: UUID().uuidString,
            userId: userId,
            meal: meal,
            glucoseRise: glucoseRise,
            timeToBaseline: timeToBaseline,
            observedAt: Date(),
            confidence: confidence,
            embedding: embeddingData,
            expiresAt: expiresAt
        )

        modelContext.insert(persistentPattern)

        do {
            try modelContext.save()
            logger.info("💾 Saved glucose pattern for: \(meal)")
        } catch {
            logger.error("❌ Failed to save glucose pattern: \(error.localizedDescription)")
            throw error
        }
    }

    /// Fetch glucose patterns for a user (non-expired only)
    func fetchGlucosePatterns(userId: String) throws -> [PersistentGlucosePattern] {
        let now = Date()
        let descriptor = FetchDescriptor<PersistentGlucosePattern>(
            predicate: #Predicate { $0.userId == userId && $0.expiresAt > now },
            sortBy: [SortDescriptor(\.observedAt, order: .reverse)]
        )

        do {
            let patterns = try modelContext.fetch(descriptor)
            logger.debug("📖 Fetched \(patterns.count) glucose patterns for user")
            return patterns
        } catch {
            logger.error("❌ Failed to fetch glucose patterns: \(error.localizedDescription)")
            throw error
        }
    }

    /// Clean up expired patterns
    func cleanupExpiredPatterns() throws {
        let now = Date()
        let descriptor = FetchDescriptor<PersistentGlucosePattern>(
            predicate: #Predicate { $0.expiresAt < now }
        )

        do {
            let expiredPatterns = try modelContext.fetch(descriptor)
            for pattern in expiredPatterns {
                modelContext.delete(pattern)
            }
            try modelContext.save()

            logger.info("🧹 Cleaned up \(expiredPatterns.count) expired glucose patterns")
        } catch {
            logger.error("❌ Failed to cleanup expired patterns: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - User Preferences CRUD

    /// Save a user preference
    func savePreference(userId: String, key: String, value: PreferenceValue) throws {
        // Delete existing preference with same key (if any)
        let existingDescriptor = FetchDescriptor<PersistentUserPreference>(
            predicate: #Predicate { $0.userId == userId && $0.key == key }
        )

        if let existing = try modelContext.fetch(existingDescriptor).first {
            modelContext.delete(existing)
        }

        // Create new preference
        let preference = PersistentUserPreference(
            userId: userId,
            key: key,
            value: value
        )

        modelContext.insert(preference)

        do {
            try modelContext.save()
            logger.info("💾 Saved preference: \(key) = \(value.stringValue)")
        } catch {
            logger.error("❌ Failed to save preference: \(error.localizedDescription)")
            throw error
        }
    }

    /// Fetch all preferences for a user
    func fetchPreferences(userId: String) throws -> [PersistentUserPreference] {
        let descriptor = FetchDescriptor<PersistentUserPreference>(
            predicate: #Predicate { $0.userId == userId },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )

        do {
            let preferences = try modelContext.fetch(descriptor)
            logger.debug("📖 Fetched \(preferences.count) preferences for user")
            return preferences
        } catch {
            logger.error("❌ Failed to fetch preferences: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Sync Operations

    /// Fetch all unsynced memory items (for sync to Cloud Functions)
    func fetchUnsyncedItems(userId: String) throws -> UnsyncedMemoryItems {
        let pendingValue = MemorySyncStatus.pending.rawValue
        let failedValue = MemorySyncStatus.failed.rawValue

        // Fetch unsynced facts
        let factsDescriptor = FetchDescriptor<PersistentUserFact>(
            predicate: #Predicate { fact in
                fact.userId == userId && (
                    fact.syncStatusRawValue == pendingValue ||
                    fact.syncStatusRawValue == failedValue
                )
            }
        )
        let unsyncedFacts = try modelContext.fetch(factsDescriptor)

        // Fetch unsynced summaries
        let summariesDescriptor = FetchDescriptor<PersistentConversationSummary>(
            predicate: #Predicate { summary in
                summary.userId == userId && (
                    summary.syncStatusRawValue == pendingValue ||
                    summary.syncStatusRawValue == failedValue
                )
            }
        )
        let unsyncedSummaries = try modelContext.fetch(summariesDescriptor)

        // Fetch unsynced recipes
        let recipesDescriptor = FetchDescriptor<PersistentRecipePreference>(
            predicate: #Predicate { recipe in
                recipe.userId == userId && (
                    recipe.syncStatusRawValue == pendingValue ||
                    recipe.syncStatusRawValue == failedValue
                )
            }
        )
        let unsyncedRecipes = try modelContext.fetch(recipesDescriptor)

        // Fetch unsynced patterns
        let patternsDescriptor = FetchDescriptor<PersistentGlucosePattern>(
            predicate: #Predicate { pattern in
                pattern.userId == userId && (
                    pattern.syncStatusRawValue == pendingValue ||
                    pattern.syncStatusRawValue == failedValue
                )
            }
        )
        let unsyncedPatterns = try modelContext.fetch(patternsDescriptor)

        // Fetch unsynced preferences
        let preferencesDescriptor = FetchDescriptor<PersistentUserPreference>(
            predicate: #Predicate { pref in
                pref.userId == userId && (
                    pref.syncStatusRawValue == pendingValue ||
                    pref.syncStatusRawValue == failedValue
                )
            }
        )
        let unsyncedPreferences = try modelContext.fetch(preferencesDescriptor)

        logger.info("📤 Found \(unsyncedFacts.count) facts, \(unsyncedSummaries.count) summaries, \(unsyncedRecipes.count) recipes, \(unsyncedPatterns.count) patterns, \(unsyncedPreferences.count) preferences pending sync")

        return UnsyncedMemoryItems(
            facts: unsyncedFacts,
            summaries: unsyncedSummaries,
            recipes: unsyncedRecipes,
            patterns: unsyncedPatterns,
            preferences: unsyncedPreferences
        )
    }

    /// Mark items as synced
    func markAsSynced(factIds: [String] = [], summaryIds: [String] = [], recipeIds: [String] = [], patternIds: [String] = [], preferenceIds: [String] = []) throws {
        let now = Date()

        // Update facts
        for id in factIds {
            let descriptor = FetchDescriptor<PersistentUserFact>(
                predicate: #Predicate { $0.id == id }
            )
            if let fact = try modelContext.fetch(descriptor).first {
                fact.syncStatusRawValue = MemorySyncStatus.synced.rawValue
                fact.lastSyncedAt = now
                fact.syncError = nil
                fact.retryCount = 0
            }
        }

        // Update summaries
        for id in summaryIds {
            let descriptor = FetchDescriptor<PersistentConversationSummary>(
                predicate: #Predicate { $0.id == id }
            )
            if let summary = try modelContext.fetch(descriptor).first {
                summary.syncStatusRawValue = MemorySyncStatus.synced.rawValue
                summary.lastSyncedAt = now
                summary.syncError = nil
                summary.retryCount = 0
            }
        }

        // Similar for recipes, patterns, preferences...
        for id in recipeIds {
            let descriptor = FetchDescriptor<PersistentRecipePreference>(
                predicate: #Predicate { $0.id == id }
            )
            if let recipe = try modelContext.fetch(descriptor).first {
                recipe.syncStatusRawValue = MemorySyncStatus.synced.rawValue
                recipe.lastSyncedAt = now
                recipe.syncError = nil
                recipe.retryCount = 0
            }
        }

        for id in patternIds {
            let descriptor = FetchDescriptor<PersistentGlucosePattern>(
                predicate: #Predicate { $0.id == id }
            )
            if let pattern = try modelContext.fetch(descriptor).first {
                pattern.syncStatusRawValue = MemorySyncStatus.synced.rawValue
                pattern.lastSyncedAt = now
                pattern.syncError = nil
                pattern.retryCount = 0
            }
        }

        for id in preferenceIds {
            let descriptor = FetchDescriptor<PersistentUserPreference>(
                predicate: #Predicate { $0.id == id }
            )
            if let pref = try modelContext.fetch(descriptor).first {
                pref.syncStatusRawValue = MemorySyncStatus.synced.rawValue
                pref.lastSyncedAt = now
                pref.syncError = nil
                pref.retryCount = 0
            }
        }

        try modelContext.save()
        logger.debug("✅ Marked items as synced")
    }

    // MARK: - Sync Helper Methods

    /// Fetch unsynced facts only (for MemorySyncService)
    func fetchUnsyncedFacts(userId: String) throws -> [PersistentUserFact] {
        let pendingValue = MemorySyncStatus.pending.rawValue
        let failedValue = MemorySyncStatus.failed.rawValue

        let descriptor = FetchDescriptor<PersistentUserFact>(
            predicate: #Predicate { fact in
                fact.userId == userId && (
                    fact.syncStatusRawValue == pendingValue ||
                    fact.syncStatusRawValue == failedValue
                )
            }
        )

        return try modelContext.fetch(descriptor)
    }

    /// Fetch unsynced summaries only
    func fetchUnsyncedSummaries(userId: String) throws -> [PersistentConversationSummary] {
        let pendingValue = MemorySyncStatus.pending.rawValue
        let failedValue = MemorySyncStatus.failed.rawValue

        let descriptor = FetchDescriptor<PersistentConversationSummary>(
            predicate: #Predicate { summary in
                summary.userId == userId && (
                    summary.syncStatusRawValue == pendingValue ||
                    summary.syncStatusRawValue == failedValue
                )
            }
        )

        return try modelContext.fetch(descriptor)
    }

    /// Fetch unsynced recipes only
    func fetchUnsyncedRecipes(userId: String) throws -> [PersistentRecipePreference] {
        let pendingValue = MemorySyncStatus.pending.rawValue
        let failedValue = MemorySyncStatus.failed.rawValue

        let descriptor = FetchDescriptor<PersistentRecipePreference>(
            predicate: #Predicate { recipe in
                recipe.userId == userId && (
                    recipe.syncStatusRawValue == pendingValue ||
                    recipe.syncStatusRawValue == failedValue
                )
            }
        )

        return try modelContext.fetch(descriptor)
    }

    /// Fetch unsynced glucose patterns only
    func fetchUnsyncedPatterns(userId: String) throws -> [PersistentGlucosePattern] {
        let pendingValue = MemorySyncStatus.pending.rawValue
        let failedValue = MemorySyncStatus.failed.rawValue

        let descriptor = FetchDescriptor<PersistentGlucosePattern>(
            predicate: #Predicate { pattern in
                pattern.userId == userId && (
                    pattern.syncStatusRawValue == pendingValue ||
                    pattern.syncStatusRawValue == failedValue
                )
            }
        )

        return try modelContext.fetch(descriptor)
    }

    /// Fetch unsynced user preferences only
    func fetchUnsyncedPreferences(userId: String) throws -> [PersistentUserPreference] {
        let pendingValue = MemorySyncStatus.pending.rawValue
        let failedValue = MemorySyncStatus.failed.rawValue

        let descriptor = FetchDescriptor<PersistentUserPreference>(
            predicate: #Predicate { pref in
                pref.userId == userId && (
                    pref.syncStatusRawValue == pendingValue ||
                    pref.syncStatusRawValue == failedValue
                )
            }
        )

        return try modelContext.fetch(descriptor)
    }

    /// Update fact from server data
    func updateFact(from serverFact: ServerUserFact) throws {
        let factId = serverFact.id
        let descriptor = FetchDescriptor<PersistentUserFact>(
            predicate: #Predicate { $0.id == factId }
        )

        guard let fact = try modelContext.fetch(descriptor).first else {
            throw MemoryPersistenceError.factNotFound(factId)
        }

        fact.fact = serverFact.fact
        fact.category = serverFact.category
        fact.confidence = serverFact.confidence
        fact.lastAccessedAt = serverFact.lastAccessedAt
        fact.embedding = serverFact.embedding
        fact.source = serverFact.source
        fact.lastModifiedAt = serverFact.lastModifiedAt
        fact.syncStatusRawValue = MemorySyncStatus.synced.rawValue
        fact.lastSyncedAt = Date()

        try modelContext.save()
    }

    /// Insert fact from server data
    func insertFact(from serverFact: ServerUserFact) throws {
        let persistentFact = PersistentUserFact(
            id: serverFact.id,
            userId: serverFact.userId,
            fact: serverFact.fact,
            category: serverFact.category,
            confidence: serverFact.confidence,
            createdAt: serverFact.createdAt,
            lastAccessedAt: serverFact.lastAccessedAt,
            embedding: serverFact.embedding,
            source: serverFact.source,
            syncStatus: .synced
        )
        persistentFact.lastModifiedAt = serverFact.lastModifiedAt
        persistentFact.lastSyncedAt = Date()

        modelContext.insert(persistentFact)
        try modelContext.save()
    }

    /// Update summary from server data
    func updateSummary(from serverSummary: ServerConversationSummary) throws {
        let summaryId = serverSummary.id
        let descriptor = FetchDescriptor<PersistentConversationSummary>(
            predicate: #Predicate { $0.id == summaryId }
        )

        guard let summary = try modelContext.fetch(descriptor).first else {
            throw MemoryPersistenceError.summaryNotFound(summaryId)
        }

        summary.summary = serverSummary.summary
        summary.startTime = serverSummary.startTime
        summary.endTime = serverSummary.endTime
        summary.messageCount = serverSummary.messageCount
        summary.embedding = serverSummary.embedding
        summary.tierRawValue = serverSummary.tier
        summary.lastModifiedAt = serverSummary.lastModifiedAt
        summary.syncStatusRawValue = MemorySyncStatus.synced.rawValue
        summary.lastSyncedAt = Date()

        try modelContext.save()
    }

    /// Insert summary from server data
    func insertSummary(from serverSummary: ServerConversationSummary) throws {
        let tier = MemoryTier(rawValue: serverSummary.tier) ?? .persistent
        let persistentSummary = PersistentConversationSummary(
            id: serverSummary.id,
            userId: serverSummary.userId,
            summary: serverSummary.summary,
            startTime: serverSummary.startTime,
            endTime: serverSummary.endTime,
            messageCount: serverSummary.messageCount,
            embedding: serverSummary.embedding,
            tier: tier,
            syncStatus: .synced
        )
        persistentSummary.lastModifiedAt = serverSummary.lastModifiedAt
        persistentSummary.lastSyncedAt = Date()

        modelContext.insert(persistentSummary)
        try modelContext.save()
    }

    /// Update recipe from server data
    func updateRecipe(from serverRecipe: ServerRecipePreference) throws {
        let recipeId = serverRecipe.id
        let descriptor = FetchDescriptor<PersistentRecipePreference>(
            predicate: #Predicate { $0.id == recipeId }
        )

        guard let recipe = try modelContext.fetch(descriptor).first else {
            throw MemoryPersistenceError.recipeNotFound(recipeId)
        }

        recipe.title = serverRecipe.title
        recipe.content = serverRecipe.content
        recipe.savedAt = serverRecipe.savedAt
        recipe.lastAccessedAt = serverRecipe.lastAccessedAt
        recipe.accessCount = serverRecipe.accessCount
        recipe.embedding = serverRecipe.embedding
        recipe.metadataJSON = serverRecipe.metadataJSON
        recipe.lastModifiedAt = serverRecipe.lastModifiedAt
        recipe.syncStatusRawValue = MemorySyncStatus.synced.rawValue
        recipe.lastSyncedAt = Date()

        try modelContext.save()
    }

    /// Insert recipe from server data
    func insertRecipe(from serverRecipe: ServerRecipePreference) throws {
        let persistentRecipe = PersistentRecipePreference(
            id: serverRecipe.id,
            userId: serverRecipe.userId,
            title: serverRecipe.title,
            content: serverRecipe.content,
            savedAt: serverRecipe.savedAt,
            lastAccessedAt: serverRecipe.lastAccessedAt,
            accessCount: serverRecipe.accessCount,
            embedding: serverRecipe.embedding,
            metadataJSON: serverRecipe.metadataJSON,
            syncStatus: .synced
        )
        persistentRecipe.lastModifiedAt = serverRecipe.lastModifiedAt
        persistentRecipe.lastSyncedAt = Date()

        modelContext.insert(persistentRecipe)
        try modelContext.save()
    }

    /// Update glucose pattern from server data
    func updatePattern(from serverPattern: ServerGlucosePattern) throws {
        let patternId = serverPattern.id
        let descriptor = FetchDescriptor<PersistentGlucosePattern>(
            predicate: #Predicate { $0.id == patternId }
        )

        guard let pattern = try modelContext.fetch(descriptor).first else {
            throw MemoryPersistenceError.patternNotFound(patternId)
        }

        pattern.meal = serverPattern.meal
        pattern.glucoseRise = serverPattern.glucoseRise
        pattern.timeToBaseline = serverPattern.timeToBaseline
        pattern.observedAt = serverPattern.observedAt
        pattern.confidence = serverPattern.confidence
        pattern.embedding = serverPattern.embedding
        pattern.expiresAt = serverPattern.expiresAt
        pattern.syncStatusRawValue = MemorySyncStatus.synced.rawValue
        pattern.lastSyncedAt = Date()

        try modelContext.save()
    }

    /// Insert glucose pattern from server data
    func insertPattern(from serverPattern: ServerGlucosePattern) throws {
        let persistentPattern = PersistentGlucosePattern(
            id: serverPattern.id,
            userId: serverPattern.userId,
            meal: serverPattern.meal,
            glucoseRise: serverPattern.glucoseRise,
            timeToBaseline: serverPattern.timeToBaseline,
            observedAt: serverPattern.observedAt,
            confidence: serverPattern.confidence,
            embedding: serverPattern.embedding,
            expiresAt: serverPattern.expiresAt,
            syncStatus: .synced
        )
        persistentPattern.lastSyncedAt = Date()

        modelContext.insert(persistentPattern)
        try modelContext.save()
    }

    /// Update user preference from server data
    func updatePreference(from serverPref: ServerUserPreference) throws {
        let prefId = serverPref.id
        let descriptor = FetchDescriptor<PersistentUserPreference>(
            predicate: #Predicate { $0.id == prefId }
        )

        guard let pref = try modelContext.fetch(descriptor).first else {
            throw MemoryPersistenceError.preferenceNotFound(prefId)
        }

        pref.key = serverPref.key
        pref.valueType = serverPref.valueType
        pref.stringValue = serverPref.stringValue
        pref.intValue = serverPref.intValue
        pref.doubleValue = serverPref.doubleValue
        pref.boolValue = serverPref.boolValue
        pref.dateValue = serverPref.dateValue
        pref.arrayJSON = serverPref.arrayJSON
        pref.updatedAt = serverPref.updatedAt
        pref.syncStatusRawValue = MemorySyncStatus.synced.rawValue
        pref.lastSyncedAt = Date()

        try modelContext.save()
    }

    /// Insert user preference from server data
    func insertPreference(from serverPref: ServerUserPreference) throws {
        // Create PreferenceValue from server data
        let preferenceValue: PreferenceValue
        switch serverPref.valueType {
        case "string":
            guard let stringValue = serverPref.stringValue else {
                throw MemoryPersistenceError.invalidPreferenceValue
            }
            preferenceValue = .string(stringValue)
        case "int":
            guard let intValue = serverPref.intValue else {
                throw MemoryPersistenceError.invalidPreferenceValue
            }
            preferenceValue = .int(intValue)
        case "double":
            guard let doubleValue = serverPref.doubleValue else {
                throw MemoryPersistenceError.invalidPreferenceValue
            }
            preferenceValue = .double(doubleValue)
        case "bool":
            guard let boolValue = serverPref.boolValue else {
                throw MemoryPersistenceError.invalidPreferenceValue
            }
            preferenceValue = .bool(boolValue)
        case "date":
            guard let dateValue = serverPref.dateValue else {
                throw MemoryPersistenceError.invalidPreferenceValue
            }
            preferenceValue = .date(dateValue)
        case "array":
            guard let arrayJSON = serverPref.arrayJSON,
                  let data = arrayJSON.data(using: .utf8),
                  let arr = try? JSONDecoder().decode([String].self, from: data) else {
                throw MemoryPersistenceError.invalidPreferenceValue
            }
            preferenceValue = .array(arr)
        default:
            throw MemoryPersistenceError.invalidPreferenceValue
        }

        let persistentPref = PersistentUserPreference(
            userId: serverPref.userId,
            key: serverPref.key,
            value: preferenceValue,
            syncStatus: .synced
        )
        persistentPref.updatedAt = serverPref.updatedAt
        persistentPref.lastSyncedAt = Date()

        modelContext.insert(persistentPref)
        try modelContext.save()
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
