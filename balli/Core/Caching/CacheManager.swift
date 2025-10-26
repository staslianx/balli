//
//  CacheManager.swift
//  balli
//
//  Unified caching infrastructure with memory and disk support
//  PERFORMANCE: Reduces redundant data fetching and processing
//

import Foundation
import UIKit

/// Actor-based cache manager for thread-safe caching operations
/// Supports both memory and disk caching with automatic eviction
actor CacheManager<Key: Hashable & Codable, Value: Codable> {

    // MARK: - Configuration

    struct Configuration {
        /// Maximum memory cache size in bytes (default: 50MB)
        let memoryLimit: Int

        /// Maximum disk cache size in bytes (default: 200MB)
        let diskLimit: Int

        /// Time-to-live for cached items in seconds (default: 1 hour)
        let ttl: TimeInterval

        /// Cache directory name
        let cacheName: String
    }

    // MARK: - Private Properties

    /// In-memory cache storage
    private var memoryCache: [Key: CacheEntry<Value>] = [:]

    /// Current memory usage estimate
    private var currentMemoryUsage: Int = 0

    /// Cache configuration
    private let configuration: Configuration

    /// Disk cache directory URL
    private let diskCacheURL: URL

    /// Background queue for disk operations
    private let diskQueue = DispatchQueue(label: "com.balli.cache.disk", qos: .utility)

    // MARK: - Cache Entry

    private struct CacheEntry<T> {
        let value: T
        let timestamp: Date
        let size: Int

        var isExpired: Bool {
            Date().timeIntervalSince(timestamp) > 3600 // 1 hour
        }
    }

    // MARK: - Initialization

    init(configuration: Configuration = Configuration(
        memoryLimit: 50 * 1024 * 1024,      // 50MB
        diskLimit: 200 * 1024 * 1024,       // 200MB
        ttl: 3600,                           // 1 hour
        cacheName: "default"
    )) {
        self.configuration = configuration

        // Setup disk cache directory
        guard let cacheDirectory = FileManager.default.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        ).first else {
            fatalError("Unable to access cache directory - this should never happen on iOS")
        }

        self.diskCacheURL = cacheDirectory
            .appendingPathComponent("balli-cache")
            .appendingPathComponent(configuration.cacheName)

        // Create directory if needed
        try? FileManager.default.createDirectory(
            at: diskCacheURL,
            withIntermediateDirectories: true
        )
    }

    // MARK: - Public API

    /// Retrieve value from cache (checks memory first, then disk)
    func get(_ key: Key) async -> Value? {
        // Check memory cache first
        if let entry = memoryCache[key] {
            if entry.isExpired {
                memoryCache.removeValue(forKey: key)
                currentMemoryUsage -= entry.size
            } else {
                return entry.value
            }
        }

        // Check disk cache
        if let value = await getDiskCache(key) {
            // Promote to memory cache
            await set(value, forKey: key, toDisk: false)
            return value
        }

        return nil
    }

    /// Store value in cache (memory and optionally disk)
    func set(_ value: Value, forKey key: Key, toDisk: Bool = true) async {
        // Estimate size (rough approximation)
        let size = estimateSize(of: value)

        // Evict if necessary
        await evictIfNeeded(requiredSpace: size)

        // Store in memory
        let entry = CacheEntry(value: value, timestamp: Date(), size: size)
        memoryCache[key] = entry
        currentMemoryUsage += size

        // Store to disk if requested
        if toDisk {
            await setDiskCache(value, forKey: key)
        }
    }

    /// Remove value from cache
    func remove(_ key: Key) async {
        if let entry = memoryCache.removeValue(forKey: key) {
            currentMemoryUsage -= entry.size
        }

        await removeDiskCache(key)
    }

    /// Clear all cached data
    func removeAll() async {
        memoryCache.removeAll()
        currentMemoryUsage = 0

        try? FileManager.default.removeItem(at: diskCacheURL)
        try? FileManager.default.createDirectory(
            at: diskCacheURL,
            withIntermediateDirectories: true
        )
    }

    /// Remove expired entries
    func removeExpired() async {
        let expiredKeys = memoryCache.filter { $0.value.isExpired }.map { $0.key }

        for key in expiredKeys {
            if let entry = memoryCache.removeValue(forKey: key) {
                currentMemoryUsage -= entry.size
            }
        }
    }

    /// Get current memory usage
    func getMemoryUsage() -> Int {
        currentMemoryUsage
    }

    /// Get cache statistics
    func getStatistics() async -> CacheManagerStatistics {
        let diskSize = await getDiskCacheSize()

        return CacheManagerStatistics(
            memoryEntries: memoryCache.count,
            memorySize: currentMemoryUsage,
            diskSize: diskSize,
            memoryLimit: configuration.memoryLimit,
            diskLimit: configuration.diskLimit
        )
    }

    // MARK: - Private Helpers

    /// Evict entries if memory limit exceeded
    private func evictIfNeeded(requiredSpace: Int) async {
        guard currentMemoryUsage + requiredSpace > configuration.memoryLimit else {
            return
        }

        // Sort by timestamp (oldest first)
        let sortedEntries = memoryCache.sorted { $0.value.timestamp < $1.value.timestamp }

        var freedSpace = 0
        var keysToRemove: [Key] = []

        for (key, entry) in sortedEntries {
            keysToRemove.append(key)
            freedSpace += entry.size

            if currentMemoryUsage - freedSpace + requiredSpace <= configuration.memoryLimit {
                break
            }
        }

        // Remove evicted entries
        for key in keysToRemove {
            if let entry = memoryCache.removeValue(forKey: key) {
                currentMemoryUsage -= entry.size
            }
        }
    }

    /// Estimate size of value in bytes
    private func estimateSize<T>(of value: T) -> Int {
        // Rough estimation based on type
        if let data = value as? Data {
            return data.count
        } else if let string = value as? String {
            return string.utf8.count
        } else if let _ = value as? UIImage {
            return 1024 * 1024 // Assume 1MB per image
        } else {
            // Default estimate for complex objects
            return MemoryLayout.size(ofValue: value) * 10
        }
    }

    // MARK: - Disk Cache Operations

    private func getDiskCache(_ key: Key) async -> Value? {
        let cacheKey = self.cacheKey(key)
        let ttl = self.configuration.ttl
        return await withCheckedContinuation { continuation in
            diskQueue.async { [cacheKey, diskCacheURL, ttl] in
                let fileURL = diskCacheURL.appendingPathComponent(cacheKey)

                guard let data = try? Data(contentsOf: fileURL),
                      let entry = try? JSONDecoder().decode(DiskCacheEntry<Value>.self, from: data) else {
                    continuation.resume(returning: nil)
                    return
                }

                // Check expiration
                if Date().timeIntervalSince(entry.timestamp) > ttl {
                    try? FileManager.default.removeItem(at: fileURL)
                    continuation.resume(returning: nil)
                    return
                }

                continuation.resume(returning: entry.value)
            }
        }
    }

    private func setDiskCache(_ value: Value, forKey key: Key) async {
        let cacheKey = self.cacheKey(key)
        await withCheckedContinuation { continuation in
            diskQueue.async { [cacheKey, diskCacheURL] in
                let fileURL = diskCacheURL.appendingPathComponent(cacheKey)
                let entry = DiskCacheEntry(value: value, timestamp: Date())

                if let data = try? JSONEncoder().encode(entry) {
                    try? data.write(to: fileURL)
                }

                continuation.resume()
            }
        }
    }

    private func removeDiskCache(_ key: Key) async {
        let cacheKey = self.cacheKey(key)
        await withCheckedContinuation { continuation in
            diskQueue.async { [cacheKey, diskCacheURL] in
                let fileURL = diskCacheURL.appendingPathComponent(cacheKey)
                try? FileManager.default.removeItem(at: fileURL)
                continuation.resume()
            }
        }
    }

    private func getDiskCacheSize() async -> Int {
        return await withCheckedContinuation { continuation in
            diskQueue.async {
                let enumerator = FileManager.default.enumerator(at: self.diskCacheURL, includingPropertiesForKeys: [.fileSizeKey])

                var totalSize = 0
                while let fileURL = enumerator?.nextObject() as? URL {
                    if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                        totalSize += size
                    }
                }

                continuation.resume(returning: totalSize)
            }
        }
    }

    private func cacheKey(_ key: Key) -> String {
        // Hash the key for filename
        let data = try? JSONEncoder().encode(key)
        let hash = data?.base64EncodedString().replacingOccurrences(of: "/", with: "_")
        return hash ?? UUID().uuidString
    }
}

// MARK: - Supporting Types

private struct DiskCacheEntry<Value: Codable>: Codable {
    let value: Value
    let timestamp: Date
}

public struct CacheManagerStatistics: Sendable {
    public let memoryEntries: Int
    public let memorySize: Int
    public let diskSize: Int
    public let memoryLimit: Int
    public let diskLimit: Int

    public var memoryUsagePercentage: Double {
        Double(memorySize) / Double(memoryLimit) * 100
    }

    public var diskUsagePercentage: Double {
        Double(diskSize) / Double(diskLimit) * 100
    }

    public init(memoryEntries: Int, memorySize: Int, diskSize: Int, memoryLimit: Int, diskLimit: Int) {
        self.memoryEntries = memoryEntries
        self.memorySize = memorySize
        self.diskSize = diskSize
        self.memoryLimit = memoryLimit
        self.diskLimit = diskLimit
    }
}
