//
//  HTTPCacheConfiguration.swift
//  balli
//
//  URLCache configuration for HTTP response caching
//  Enables offline support by caching Cloud Function responses
//

import Foundation
import OSLog

/// Manages HTTP response caching for offline support
/// Uses URLCache to cache successful responses from Cloud Functions
actor HTTPCacheConfiguration {

    // MARK: - Properties

    private let logger = Logger(subsystem: "com.anaxoniclabs.balli", category: "HTTPCache")
    private let cache: URLCache

    // MARK: - Singleton

    static let shared = HTTPCacheConfiguration()

    // MARK: - Configuration

    /// Memory capacity: 50MB for fast access to recent responses
    static let memoryCapacity = 50 * 1024 * 1024

    /// Disk capacity: 100MB for persistent offline cache
    static let diskCapacity = 100 * 1024 * 1024

    // MARK: - Initialization

    private init() {
        // Create cache with specified capacities
        self.cache = URLCache(
            memoryCapacity: Self.memoryCapacity,
            diskCapacity: Self.diskCapacity,
            directory: FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?.appendingPathComponent("HTTPCache")
        )

        logger.info("📦 HTTP cache initialized: \(Self.memoryCapacity / 1024 / 1024)MB memory, \(Self.diskCapacity / 1024 / 1024)MB disk")
    }

    // MARK: - Public API

    /// Get configured URLSession for GenkitService
    /// Returns a session with proper caching configured
    func configuredURLSession() -> URLSession {
        let config = URLSessionConfiguration.default
        config.urlCache = cache
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60

        return URLSession(configuration: config)
    }

    /// Get cached response for request (if available)
    func getCachedResponse(for request: URLRequest) -> CachedURLResponse? {
        let cached = cache.cachedResponse(for: request)

        if let cached = cached {
            logger.debug("✅ Cache HIT for \(request.url?.lastPathComponent ?? "unknown")")
        } else {
            logger.debug("❌ Cache MISS for \(request.url?.lastPathComponent ?? "unknown")")
        }

        return cached
    }

    /// Store response in cache
    func storeResponse(_ response: CachedURLResponse, for request: URLRequest) {
        cache.storeCachedResponse(response, for: request)
        logger.debug("💾 Cached response for \(request.url?.lastPathComponent ?? "unknown")")
    }

    /// Clear all cached responses
    func clearCache() {
        cache.removeAllCachedResponses()
        logger.info("🗑️ All HTTP cache cleared")
    }

    /// Get cache statistics
    func getCacheStats() -> HTTPCacheStatistics {
        return HTTPCacheStatistics(
            currentMemoryUsage: cache.currentMemoryUsage,
            currentDiskUsage: cache.currentDiskUsage,
            memoryCapacity: cache.memoryCapacity,
            diskCapacity: cache.diskCapacity
        )
    }
}

// MARK: - Cache Statistics

/// HTTP cache usage statistics
struct HTTPCacheStatistics: Sendable {
    let currentMemoryUsage: Int
    let currentDiskUsage: Int
    let memoryCapacity: Int
    let diskCapacity: Int

    var formattedMemoryUsage: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return "\(formatter.string(fromByteCount: Int64(currentMemoryUsage))) / \(formatter.string(fromByteCount: Int64(memoryCapacity)))"
    }

    var formattedDiskUsage: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return "\(formatter.string(fromByteCount: Int64(currentDiskUsage))) / \(formatter.string(fromByteCount: Int64(diskCapacity)))"
    }

    var memoryUsagePercentage: Double {
        return Double(currentMemoryUsage) / Double(memoryCapacity) * 100
    }

    var diskUsagePercentage: Double {
        return Double(currentDiskUsage) / Double(diskCapacity) * 100
    }
}
