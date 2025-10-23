//
//  NetworkResponseCache.swift
//  balli
//
//  Specialized cache for network responses with automatic serialization
//  PERFORMANCE: Reduces redundant network requests
//

import Foundation

/// Actor for caching network responses
actor NetworkResponseCache {

    // MARK: - Response Entry

    struct CachedResponse: Codable {
        let data: Data
        let headers: [String: String]
        let statusCode: Int
        let url: URL
    }

    // MARK: - Properties

    private let cache: CacheManager<URL, CachedResponse>

    private static let configuration = CacheManager<URL, CachedResponse>.Configuration(
        memoryLimit: 20 * 1024 * 1024,      // 20MB for network responses
        diskLimit: 100 * 1024 * 1024,       // 100MB disk cache
        ttl: 1800,                           // 30 minutes
        cacheName: "network-responses"
    )

    // MARK: - Singleton

    static let shared = NetworkResponseCache()

    private init() {
        self.cache = CacheManager(configuration: Self.configuration)
    }

    // MARK: - Public API

    /// Cache a network response
    func cacheResponse(
        _ data: Data,
        response: URLResponse,
        for url: URL
    ) async {
        guard let httpResponse = response as? HTTPURLResponse else { return }

        // Only cache successful responses
        guard (200...299).contains(httpResponse.statusCode) else { return }

        let headers = httpResponse.allHeaderFields.reduce(into: [String: String]()) { result, pair in
            if let key = pair.key as? String, let value = pair.value as? String {
                result[key] = value
            }
        }

        let cachedResponse = CachedResponse(
            data: data,
            headers: headers,
            statusCode: httpResponse.statusCode,
            url: url
        )

        await cache.set(cachedResponse, forKey: url)
    }

    /// Retrieve cached response
    func getCachedResponse(for url: URL) async -> CachedResponse? {
        await cache.get(url)
    }

    /// Check if response is cached
    func isCached(_ url: URL) async -> Bool {
        await cache.get(url) != nil
    }

    /// Remove cached response
    func removeResponse(for url: URL) async {
        await cache.remove(url)
    }

    /// Clear all cached responses
    func clearAll() async {
        await cache.removeAll()
    }

    /// Get cache statistics
    func getStatistics() async -> CacheManagerStatistics {
        await cache.getStatistics()
    }
}
