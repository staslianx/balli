//
//  MemoryStorageActor.swift
//  balli
//
//  Actor responsible for storing all memory entries
//  Handles user-isolated memory caches with thread-safe write access
//  Swift 6 strict concurrency compliant
//

import Foundation
import OSLog

// MARK: - Memory Storage Actor

actor MemoryStorageActor {
    // MARK: - Properties

    private let logger = AppLoggers.Data.sync

    // CRITICAL: User-specific memory - NEVER mix between users
    private var currentUserId: String?

    // User-isolated memory caches (keyed by userId)
    private var userMemories: [String: UserMemoryCache] = [:]

    // Configuration
    private let immediateLimit = 10  // 5 turns = 10 messages
    private let recentLimit = 8      // 8 summary entries
    private let historicalLimit = 5  // 5 key fact entries

    // MARK: - Initialization

    init() {
        logger.info("MemoryStorageActor initialized with persistent storage (ChatAssistant removed - local only)")
    }

    // MARK: - Persistence Helpers

    /// Get persistence service (MainActor-isolated)
    private func withPersistence<T: Sendable>(_ operation: @MainActor @Sendable (MemoryPersistenceService) throws -> T) async rethrows -> T {
        return try await MainActor.run {
            let service = MemoryPersistenceService()
            return try operation(service)
        }
    }

    /// Trigger background sync after data changes (non-blocking, debounced)
    nonisolated private func triggerAutoSync() {
        Task { @MainActor in
            do {
                try await MemorySyncCoordinator.shared.syncNow()
            } catch {
                // Sync failures are logged within MemorySyncCoordinator
            }
        }
    }

    /// Load persisted memory into cache for a user
    private func loadPersistedMemory(for userId: String) async {
        logger.info("Loading persisted memory for user: \(userId)")

        do {
            // Load and convert data on MainActor, return Sendable types
            let loadedData = try await MainActor.run {
                let service = MemoryPersistenceService()

                // Load facts and convert to Sendable format
                let persistedFacts = try service.fetchFacts(userId: userId)
                let facts = persistedFacts.map { $0.fact }

                // Load preferences and convert to Sendable format
                let persistedPreferences = try service.fetchPreferences(userId: userId)
                let preferences: [String: PreferenceValue] = persistedPreferences.reduce(into: [:]) { result, pref in
                    if let prefValue = pref.preferenceValue {
                        result[pref.key] = prefValue
                    }
                }

                // Load recipes and convert to Sendable format
                let persistedRecipes = try service.fetchRecipes(userId: userId)
                let recipes: [(String, MemoryEntry)] = persistedRecipes.map { recipe in
                    let embedding = recipe.embedding.flatMap { data in
                        try? JSONDecoder().decode([Double].self, from: data)
                    }
                    let entry = MemoryEntry(
                        id: recipe.id,
                        type: .recipe,
                        content: recipe.content,
                        metadata: ["title": recipe.title],
                        timestamp: recipe.savedAt,
                        source: "user_saved",
                        embedding: embedding
                    )
                    return (recipe.title, entry)
                }

                // Load patterns and convert to Sendable format
                let persistedPatterns = try service.fetchGlucosePatterns(userId: userId)
                let patterns: [MemoryEntry] = persistedPatterns.map { pattern in
                    let embedding = pattern.embedding.flatMap { data in
                        try? JSONDecoder().decode([Double].self, from: data)
                    }
                    return MemoryEntry(
                        type: .glucosePattern,
                        content: "\(pattern.meal) typically raises glucose by \(Int(pattern.glucoseRise)) mg/dL, returning to baseline in \(pattern.timeToBaseline) minutes",
                        metadata: [
                            "meal": pattern.meal,
                            "glucoseRise": String(pattern.glucoseRise),
                            "timeToBaseline": String(pattern.timeToBaseline)
                        ],
                        timestamp: pattern.observedAt,
                        expiresAt: pattern.expiresAt,
                        confidence: pattern.confidence,
                        source: "observed",
                        embedding: embedding
                    )
                }

                return (facts: facts, preferences: preferences, recipes: recipes, patterns: patterns)
            }

            // Populate in-memory cache (now on actor's isolation domain)
            guard let cache = userMemories[userId] else { return }

            cache.userFacts = loadedData.facts
            cache.preferences = loadedData.preferences
            for (title, entry) in loadedData.recipes {
                cache.storedRecipes[title] = entry
            }
            cache.recentPatterns = loadedData.patterns

            logger.info("Loaded \(loadedData.facts.count) facts, \(loadedData.preferences.count) preferences, \(loadedData.recipes.count) recipes, \(loadedData.patterns.count) patterns from persistent storage")

        } catch {
            logger.error("Failed to load persisted memory: \(error.localizedDescription)")
        }
    }

    // MARK: - User Management

    func switchUser(_ userId: String) async {
        guard userId != currentUserId else {
            logger.info("Already on user \(userId) memory context")
            return
        }

        currentUserId = userId

        // Create memory cache for new user if needed
        if userMemories[userId] == nil {
            userMemories[userId] = UserMemoryCache()
            // Load persisted memory from SwiftData
            await loadPersistedMemory(for: userId)
        }

        logger.info("Switched to user \(userId) memory context")
    }

    func clearUserMemory(_ userId: String) {
        userMemories[userId] = UserMemoryCache()
        logger.info("Cleared memory for user \(userId)")
    }

    func getCurrentUserId() -> String? {
        return currentUserId
    }

    // MARK: - Memory Storage - Facts

    func storeFact(_ fact: String, confidence: Double = 1.0, embedding: [Double]? = nil) async {
        guard let userId = currentUserId,
              let cache = userMemories[userId] else {
            logger.error("No active user for fact storage")
            return
        }

        let start = Date()

        // Write-through: Update in-memory cache
        cache.userFacts.append(fact)

        // Write-through: Persist to SwiftData (non-blocking)
        Task {
            do {
                try await withPersistence { service in
                    try service.saveFact(
                        fact,
                        userId: userId,
                        category: "general",
                        confidence: confidence,
                        source: "user_stated",
                        embedding: embedding
                    )
                }

                // Trigger background sync after data change
                triggerAutoSync()
            } catch {
                logger.error("Failed to persist fact: \(error.localizedDescription)")
            }
        }

        let duration = Date().timeIntervalSince(start)
        logger.info("Stored user fact in \(duration * 1000, privacy: .public)ms: \(fact)")
    }

    // MARK: - Memory Storage - Preferences

    func storePreference(key: String, value: PreferenceValue) async {
        guard let userId = currentUserId,
              let cache = userMemories[userId] else {
            logger.error("No active user for preference storage")
            return
        }

        // Write-through: Update in-memory cache
        cache.preferences[key] = value

        // Write-through: Persist to SwiftData (non-blocking)
        Task {
            do {
                try await withPersistence { service in
                    try service.savePreference(userId: userId, key: key, value: value)
                }

                // Trigger background sync after data change
                triggerAutoSync()
            } catch {
                logger.error("Failed to persist preference: \(error.localizedDescription)")
            }
        }

        logger.info("Stored preference: \(key, privacy: .public) = \(value.stringValue, privacy: .private)")
    }

    // MARK: - Memory Storage - Conversations

    func storeConversation(_ entry: MemoryEntry) {
        guard let userId = currentUserId,
              let cache = userMemories[userId] else {
            logger.error("No active user for memory storage")
            return
        }

        let start = Date()

        // Direct mutation - no copy needed with reference type
        cache.lastActivityTime = Date()
        cache.immediateMemory.append(entry)

        let duration = Date().timeIntervalSince(start)
        logger.debug("Stored conversation entry in \(duration * 1000, privacy: .public)ms (tier: \(entry.tier?.rawValue ?? "none"))")
    }

    // MARK: - Memory Storage - Recipes

    func storeRecipe(title: String, entry: MemoryEntry) async {
        guard let userId = currentUserId,
              let cache = userMemories[userId] else {
            logger.error("No active user for recipe storage")
            return
        }

        // Write-through: Update in-memory cache
        cache.storedRecipes[title] = entry

        // Write-through: Persist to SwiftData (non-blocking)
        Task {
            do {
                try await withPersistence { service in
                    try service.saveRecipe(
                        userId: userId,
                        title: title,
                        content: entry.content,
                        embedding: entry.embedding,
                        metadata: entry.metadata
                    )
                }

                // Trigger background sync after data change
                triggerAutoSync()
            } catch {
                logger.error("Failed to persist recipe: \(error.localizedDescription)")
            }
        }

        logger.info("Stored recipe: \(title)")
    }

    // MARK: - Memory Storage - Glucose Patterns

    func storeGlucosePattern(meal: String, glucoseRise: Double, timeToBaseline: Int, embedding: [Double]? = nil) async {
        guard let userId = currentUserId,
              let cache = userMemories[userId] else {
            logger.error("No active user for glucose pattern storage")
            return
        }

        let pattern = MemoryEntry(
            type: .glucosePattern,
            content: "\(meal) typically raises glucose by \(Int(glucoseRise)) mg/dL, returning to baseline in \(timeToBaseline) minutes",
            metadata: [
                "meal": meal,
                "glucoseRise": String(glucoseRise),
                "timeToBaseline": String(timeToBaseline)
            ],
            expiresAt: Date().addingTimeInterval(86400 * 30), // 30 days
            confidence: 0.8,
            source: "observed",
            embedding: embedding
        )

        // Write-through: Update in-memory cache
        cache.recentPatterns.append(pattern)

        // Write-through: Persist to SwiftData (non-blocking)
        Task {
            do {
                try await withPersistence { service in
                    try service.saveGlucosePattern(
                        userId: userId,
                        meal: meal,
                        glucoseRise: glucoseRise,
                        timeToBaseline: timeToBaseline,
                        confidence: 0.8,
                        embedding: embedding
                    )
                }

                // Trigger background sync after data change
                triggerAutoSync()
            } catch {
                logger.error("Failed to persist glucose pattern: \(error.localizedDescription)")
            }
        }

        logger.info("Stored glucose pattern for: \(meal)")
    }

    // MARK: - Memory Tier Management

    func cascadeMemoryTiers(summarize: @Sendable (MemoryEntry) async -> String,
                            extractFacts: @Sendable (MemoryEntry) async -> [String]) async {
        guard let userId = currentUserId,
              let cache = userMemories[userId] else { return }

        let start = Date()

        // Direct mutation - no copy needed with reference type
        // If immediate memory exceeds limit, move oldest to recent
        if cache.immediateMemory.count > immediateLimit {
            let toMove = cache.immediateMemory.removeFirst()

            // Summarize before moving to recent tier
            let summary = await summarize(toMove)
            var summarizedEntry = toMove
            summarizedEntry.content = summary
            summarizedEntry.tier = .recent

            cache.recentMemory.append(summarizedEntry)
        }

        // If recent memory exceeds limit, extract facts and move to historical
        if cache.recentMemory.count > recentLimit {
            let toMove = cache.recentMemory.removeFirst()

            // Extract key facts
            let facts = await extractFacts(toMove)
            if !facts.isEmpty {
                var factEntry = toMove
                factEntry.content = facts.joined(separator: "; ")
                factEntry.tier = .historical

                cache.historicalMemory.append(factEntry)
            }
        }

        // If historical exceeds limit, persist important facts
        if cache.historicalMemory.count > historicalLimit {
            let toRemove = cache.historicalMemory.removeFirst()

            // Persist if it's a significant fact
            if toRemove.confidence > 0.8 {
                cache.userFacts.append(toRemove.content)
            }
        }

        let duration = Date().timeIntervalSince(start)
        logger.debug("Cascaded memory tiers in \(duration * 1000, privacy: .public)ms")
    }

    // MARK: - Memory Cleanup

    func cleanupExpiredMemory(patternRetentionDays: Int = 30) {
        guard let userId = currentUserId,
              let cache = userMemories[userId] else { return }

        let start = Date()
        let now = Date()

        // Direct mutation - no copy needed with reference type
        let beforeCount = cache.immediateMemory.count + cache.recentPatterns.count

        // Remove expired immediate memories
        cache.immediateMemory.removeAll { entry in
            if let expiresAt = entry.expiresAt {
                return expiresAt < now
            }
            return false
        }

        // Remove old patterns
        cache.recentPatterns.removeAll { entry in
            let age = now.timeIntervalSince(entry.timestamp)
            return age > TimeInterval(patternRetentionDays * 86400)
        }

        let afterCount = cache.immediateMemory.count + cache.recentPatterns.count
        let removedCount = beforeCount - afterCount
        let duration = Date().timeIntervalSince(start)

        logger.info("Cleaned up \(removedCount) expired memories in \(duration * 1000, privacy: .public)ms")
    }

    // MARK: - Memory Retrieval (Read-Only Access)

    func getUserCache(for userId: String) -> UserMemoryCache? {
        return userMemories[userId]
    }

    func getCurrentUserCache() -> UserMemoryCache? {
        guard let userId = currentUserId else { return nil }
        return userMemories[userId]
    }

    func getLastActivityTime() -> Date? {
        guard let userId = currentUserId,
              let cache = userMemories[userId] else { return nil }
        return cache.lastActivityTime
    }

    func updateLastActivityTime(_ time: Date) {
        guard let userId = currentUserId,
              let cache = userMemories[userId] else { return }
        // Direct mutation - no copy needed with reference type
        cache.lastActivityTime = time
    }
}
