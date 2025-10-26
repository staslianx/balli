//
//  OfflineCache.swift
//  balli
//
//  Simple caching layer for critical Firebase operations
//  Pragmatic approach for 2-user app
//

import Foundation
import OSLog

/// Simple cache for critical app data when offline
/// Uses UserDefaults for lightweight data and file system for larger data
actor OfflineCache {

    // MARK: - Types

    struct CachedMemories: Codable {
        let memories: [CachedMemory]
        let timestamp: Date
    }

    struct CachedMemory: Codable {
        let id: String
        let text: String
        let isUser: Bool
        let timestamp: Date
        let similarity: Double
    }

    struct CachedRecipe: Codable {
        let id: String
        let name: String
        let ingredients: [String]
        let directions: [String]
        let mealType: String
        let timestamp: Date
        let imageURL: String?
    }

    // MARK: - Properties

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.balli", category: "OfflineCache")
    private let defaults = UserDefaults.standard
    private let cacheDirectory: URL
    private let maxCacheAge: TimeInterval = 86400 * 7 // 7 days

    // Cache keys
    private enum CacheKey: String {
        case recentMemories = "offline_recent_memories"
        case recentRecipes = "offline_recent_recipes"
        case researchCache = "offline_research_cache"
        case lastSyncTimestamp = "offline_last_sync"
    }

    // MARK: - Singleton

    static let shared = OfflineCache()

    // MARK: - Initialization

    private init() {
        // Set up cache directory
        guard let documentsPath = FileManager.default.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        ).first else {
            fatalError("Failed to access caches directory")
        }

        self.cacheDirectory = documentsPath.appendingPathComponent("OfflineCache")

        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(
            at: cacheDirectory,
            withIntermediateDirectories: true
        )
    }

    // MARK: - Memory Caching

    /// Cache similar messages for offline retrieval
    func cacheMemories(_ memories: [CachedMemory]) async {
        let cached = CachedMemories(memories: memories, timestamp: Date())

        do {
            let data = try JSONEncoder().encode(cached)
            defaults.set(data, forKey: CacheKey.recentMemories.rawValue)
            logger.info("Cached \(memories.count) memories for offline access")
        } catch {
            logger.error("Failed to cache memories: \(error.localizedDescription)")
        }
    }

    /// Retrieve cached memories
    func getCachedMemories() async -> [CachedMemory]? {
        guard let data = defaults.data(forKey: CacheKey.recentMemories.rawValue) else {
            return nil
        }

        do {
            let cached = try JSONDecoder().decode(CachedMemories.self, from: data)

            // Check if cache is still valid
            let age = Date().timeIntervalSince(cached.timestamp)
            if age > maxCacheAge {
                logger.info("Cached memories expired (age: \(Int(age / 3600))h)")
                return nil
            }

            logger.info("Retrieved \(cached.memories.count) cached memories (age: \(Int(age / 60))m)")
            return cached.memories
        } catch {
            logger.error("Failed to retrieve cached memories: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Recipe Caching

    /// Cache recipes for offline viewing
    func cacheRecipes(_ recipes: [CachedRecipe]) async {
        let fileURL = cacheDirectory.appendingPathComponent("recipes.json")

        do {
            let data = try JSONEncoder().encode(recipes)
            try data.write(to: fileURL)
            logger.info("Cached \(recipes.count) recipes for offline access")
        } catch {
            logger.error("Failed to cache recipes: \(error.localizedDescription)")
        }
    }

    /// Retrieve cached recipes
    func getCachedRecipes() async -> [CachedRecipe]? {
        let fileURL = cacheDirectory.appendingPathComponent("recipes.json")

        do {
            let data = try Data(contentsOf: fileURL)
            let recipes = try JSONDecoder().decode([CachedRecipe].self, from: data)

            // Check file age
            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            if let modificationDate = attributes[.modificationDate] as? Date {
                let age = Date().timeIntervalSince(modificationDate)
                if age > maxCacheAge {
                    logger.info("Cached recipes expired (age: \(Int(age / 3600))h)")
                    return nil
                }
            }

            logger.info("Retrieved \(recipes.count) cached recipes")
            return recipes
        } catch {
            logger.error("Failed to retrieve cached recipes: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Research Cache

    /// Cache research results with timestamp
    func cacheResearchResult(query: String, answer: String, sources: [[String: String]]) async {
        let cacheKey = "research_\(query.hash)"
        let result: [String: Any] = [
            "query": query,
            "answer": answer,
            "sources": sources,
            "timestamp": Date().timeIntervalSince1970
        ]

        do {
            let data = try JSONSerialization.data(withJSONObject: result)
            let fileURL = cacheDirectory.appendingPathComponent("\(cacheKey).json")
            try data.write(to: fileURL)
            logger.info("Cached research result for query: \(query)")
        } catch {
            logger.error("Failed to cache research result: \(error.localizedDescription)")
        }
    }

    /// Retrieve cached research result
    func getCachedResearchResult(query: String) async -> (answer: String, sources: [[String: String]])? {
        let cacheKey = "research_\(query.hash)"
        let fileURL = cacheDirectory.appendingPathComponent("\(cacheKey).json")

        do {
            let data = try Data(contentsOf: fileURL)
            guard let result = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let answer = result["answer"] as? String,
                  let sources = result["sources"] as? [[String: String]],
                  let timestamp = result["timestamp"] as? TimeInterval else {
                return nil
            }

            // Check age
            let age = Date().timeIntervalSince1970 - timestamp
            if age > maxCacheAge {
                logger.info("Cached research result expired")
                return nil
            }

            logger.info("Retrieved cached research result (age: \(Int(age / 3600))h)")
            return (answer, sources)
        } catch {
            return nil
        }
    }

    // MARK: - Cache Management

    /// Clear all cached data
    func clearAllCache() async {
        // Clear UserDefaults
        defaults.removeObject(forKey: CacheKey.recentMemories.rawValue)
        defaults.removeObject(forKey: CacheKey.recentRecipes.rawValue)
        defaults.removeObject(forKey: CacheKey.lastSyncTimestamp.rawValue)

        // Clear file cache
        let fileManager = FileManager.default
        if let files = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil) {
            for file in files {
                try? fileManager.removeItem(at: file)
            }
        }

        logger.info("All offline cache cleared")
    }

    /// Clear expired cache entries
    func clearExpiredCache() async {
        let fileManager = FileManager.default
        let now = Date()

        if let files = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.contentModificationDateKey]) {
            for file in files {
                if let attributes = try? file.resourceValues(forKeys: [.contentModificationDateKey]),
                   let modificationDate = attributes.contentModificationDate,
                   now.timeIntervalSince(modificationDate) > maxCacheAge {
                    try? fileManager.removeItem(at: file)
                    logger.debug("Removed expired cache file: \(file.lastPathComponent)")
                }
            }
        }

        logger.info("Expired cache entries cleared")
    }

    /// Get cache statistics
    func getCacheStats() async -> OfflineCacheStatistics {
        var totalSize: Int64 = 0
        var fileCount = 0

        let fileManager = FileManager.default
        if let files = try? fileManager.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: [.fileSizeKey]
        ) {
            fileCount = files.count
            for file in files {
                if let attributes = try? file.resourceValues(forKeys: [.fileSizeKey]),
                   let size = attributes.fileSize {
                    totalSize += Int64(size)
                }
            }
        }

        return OfflineCacheStatistics(
            fileCount: fileCount,
            totalSizeBytes: totalSize
        )
    }

    // MARK: - Sync Management

    /// Update last sync timestamp
    func updateLastSyncTimestamp() async {
        defaults.set(Date().timeIntervalSince1970, forKey: CacheKey.lastSyncTimestamp.rawValue)
    }

    /// Get time since last sync
    func getTimeSinceLastSync() async -> TimeInterval? {
        let timestamp = defaults.double(forKey: CacheKey.lastSyncTimestamp.rawValue)
        guard timestamp > 0 else {
            return nil
        }
        return Date().timeIntervalSince1970 - timestamp
    }
}

// MARK: - Offline Cache Statistics

/// Statistics specific to offline file cache (not to be confused with PersistenceActor.CacheStatistics)
struct OfflineCacheStatistics: Sendable {
    let fileCount: Int
    let totalSizeBytes: Int64

    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: totalSizeBytes)
    }
}
