//
//  RecipeMemoryRepository.swift
//  balli
//
//  Created by Claude Code
//  Recipe memory system - Thread-safe UserDefaults-based memory storage
//

import Foundation
import OSLog

/// Thread-safe repository for recipe memory storage using UserDefaults
/// Manages 9 independent memory pools, one per subcategory
actor RecipeMemoryRepository {
    // MARK: - Properties

    private let userDefaults: UserDefaults
    private let storageKey = "recipeMemory_v1"
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.balli.app",
        category: "RecipeMemory"
    )

    // MARK: - Initialization

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    // MARK: - Public Methods

    /// Fetches all memory entries for a specific subcategory
    /// - Parameter subcategory: The subcategory to fetch entries for
    /// - Returns: Array of memory entries, sorted by date (newest first)
    /// - Throws: RecipeMemoryError if storage read fails
    func fetchMemory(for subcategory: RecipeSubcategory) throws -> [RecipeMemoryEntry] {
        logger.debug("Fetching memory for subcategory: \(subcategory.rawValue)")

        let storage = try loadStorage()
        let entries = storage[subcategory]

        logger.debug("Found \(entries.count) entries for \(subcategory.rawValue)")
        return entries.sorted(by: { $0.dateGenerated > $1.dateGenerated })
    }

    /// Fetches the most recent N entries for a subcategory
    /// - Parameters:
    ///   - subcategory: The subcategory to fetch entries for
    ///   - limit: Maximum number of entries to return
    /// - Returns: Array of recent memory entries
    /// - Throws: RecipeMemoryError if storage read fails
    func fetchRecentMemory(for subcategory: RecipeSubcategory, limit: Int) throws -> [RecipeMemoryEntry] {
        let allEntries = try fetchMemory(for: subcategory)
        return Array(allEntries.prefix(limit))
    }

    /// Saves a new memory entry for a subcategory
    /// Automatically trims old entries if memory limit is exceeded
    /// - Parameters:
    ///   - entry: The memory entry to save
    ///   - subcategory: The subcategory to save to
    /// - Throws: RecipeMemoryError if storage write fails
    func saveEntry(_ entry: RecipeMemoryEntry, for subcategory: RecipeSubcategory) throws {
        logger.info("Saving new memory entry for \(subcategory.rawValue): \(entry.recipeName ?? "Unknown")")

        var storage = try loadStorage()
        var entries = storage[subcategory]

        // Add new entry
        entries.append(entry)

        // Auto-trim if needed
        if entries.count > subcategory.memoryLimit {
            let trimCount = entries.count - subcategory.memoryLimit
            entries = trimMemoryEntries(entries, removeCount: trimCount)
            logger.debug("Auto-trimmed \(trimCount) old entries from \(subcategory.rawValue)")
        }

        storage[subcategory] = entries
        try saveStorage(storage)

        logger.info("Successfully saved entry. Total entries for \(subcategory.rawValue): \(entries.count)")
    }

    /// Trims old entries from a subcategory memory
    /// Removes oldest entries first (by date)
    /// - Parameters:
    ///   - subcategory: The subcategory to trim
    ///   - targetCount: Target number of entries to keep (defaults to subcategory limit)
    /// - Throws: RecipeMemoryError if storage operations fail
    func trimMemory(for subcategory: RecipeSubcategory, to targetCount: Int? = nil) throws {
        let target = targetCount ?? subcategory.memoryLimit
        logger.info("Trimming memory for \(subcategory.rawValue) to \(target) entries")

        var storage = try loadStorage()
        var entries = storage[subcategory]

        if entries.count <= target {
            logger.debug("No trimming needed. Current count: \(entries.count), target: \(target)")
            return
        }

        let removeCount = entries.count - target
        entries = trimMemoryEntries(entries, removeCount: removeCount)

        storage[subcategory] = entries
        try saveStorage(storage)

        logger.info("Trimmed \(removeCount) entries. New count: \(entries.count)")
    }

    /// Clears all memory entries for a specific subcategory
    /// - Parameter subcategory: The subcategory to clear, or nil to clear all
    /// - Throws: RecipeMemoryError if storage operations fail
    func clearMemory(for subcategory: RecipeSubcategory? = nil) throws {
        if let subcategory = subcategory {
            logger.info("Clearing memory for subcategory: \(subcategory.rawValue)")

            var storage = try loadStorage()
            storage[subcategory] = []
            try saveStorage(storage)

            logger.info("Successfully cleared memory for \(subcategory.rawValue)")
        } else {
            logger.info("Clearing ALL memory across all subcategories")

            let emptyStorage = RecipeMemoryStorage()
            try saveStorage(emptyStorage)

            logger.info("Successfully cleared all memory")
        }
    }

    /// Returns memory statistics for debugging
    /// - Returns: Dictionary mapping subcategory name to entry count
    func getMemoryStats() throws -> [String: Int] {
        let storage = try loadStorage()
        var stats: [String: Int] = [:]

        for subcategory in RecipeSubcategory.allCases {
            stats[subcategory.rawValue] = storage[subcategory].count
        }

        return stats
    }

    // MARK: - Private Methods

    /// Loads the entire memory storage from UserDefaults
    private func loadStorage() throws -> RecipeMemoryStorage {
        guard let data = userDefaults.data(forKey: storageKey) else {
            logger.debug("No existing storage found, creating new storage")
            return RecipeMemoryStorage()
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let storage = try decoder.decode(RecipeMemoryStorage.self, from: data)
            return storage
        } catch {
            logger.error("Failed to decode storage: \(error.localizedDescription)")
            throw RecipeMemoryError.decodingFailure(underlying: error)
        }
    }

    /// Saves the entire memory storage to UserDefaults
    private func saveStorage(_ storage: RecipeMemoryStorage) throws {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(storage)
            userDefaults.set(data, forKey: storageKey)

            // Force synchronize for immediate persistence
            userDefaults.synchronize()
        } catch {
            logger.error("Failed to encode storage: \(error.localizedDescription)")
            throw RecipeMemoryError.encodingFailure(underlying: error)
        }
    }

    /// Trims entries by removing oldest ones
    /// - Parameters:
    ///   - entries: Entries to trim
    ///   - removeCount: Number of entries to remove
    /// - Returns: Trimmed array of entries
    private func trimMemoryEntries(_ entries: [RecipeMemoryEntry], removeCount: Int) -> [RecipeMemoryEntry] {
        guard removeCount > 0, removeCount < entries.count else { return entries }

        // Sort by date (oldest first) and remove oldest
        let sorted = entries.sorted(by: { $0.dateGenerated < $1.dateGenerated })
        return Array(sorted.dropFirst(removeCount))
    }
}

// MARK: - Testing Support

#if DEBUG
extension RecipeMemoryRepository {
    /// Creates a test repository with in-memory storage (doesn't persist)
    static func testRepository() -> RecipeMemoryRepository {
        let testDefaults = UserDefaults(suiteName: "com.balli.test.\(UUID().uuidString)")!
        return RecipeMemoryRepository(userDefaults: testDefaults)
    }
}
#endif
