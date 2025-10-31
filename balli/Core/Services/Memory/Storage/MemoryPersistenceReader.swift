//
//  MemoryPersistenceReader.swift
//  balli
//
//  Handles all read, fetch, and query operations
//  for SwiftData memory persistence
//
//  Swift 6 strict concurrency compliant
//

import Foundation
import SwiftData
import OSLog

// MARK: - Memory Persistence Reader

/// @MainActor service for SwiftData read operations (ModelContext requires MainActor)
@MainActor
final class MemoryPersistenceReader {
    // MARK: - Properties

    private let modelContext: ModelContext
    private let logger = AppLoggers.Data.sync

    // MARK: - Initialization

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - User Facts Read Operations

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

    /// Fetch unsynced facts only
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

    // MARK: - Conversation Summaries Read Operations

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

    // MARK: - Recipe Preferences Read Operations

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

    // MARK: - Glucose Patterns Read Operations

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

    // MARK: - User Preferences Read Operations

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

    // MARK: - Batch Operations

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
}
