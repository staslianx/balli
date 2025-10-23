//
//  QueryCache.swift
//  balli
//
//  Query result caching with TTL and automatic eviction
//

@preconcurrency import CoreData
import Foundation
import os.log

/// Thread-safe cache for Core Data query results
actor QueryCache {
    private let logger = os.Logger(subsystem: "com.balli.diabetes", category: "QueryCache")
    
    // Cache storage
    private var cache: [String: CachedQuery] = [:]
    
    // Configuration
    private let maxSize: Int
    private let ttl: TimeInterval
    
    // Statistics
    private var hitCount = 0
    private var missCount = 0
    private var evictionCount = 0
    
    // MARK: - Types

    /// Reference-type cache entry for efficient in-place mutation
    /// Uses class instead of struct to avoid copy-on-write overhead
    /// Thread-safety guaranteed by actor isolation
    private final class CachedQuery: @unchecked Sendable {
        let results: [NSManagedObject]
        let timestamp: Date
        var accessCount: Int // Now mutable for direct increments
        let size: Int // Approximate memory size

        init(results: [NSManagedObject], timestamp: Date, accessCount: Int, size: Int) {
            self.results = results
            self.timestamp = timestamp
            self.accessCount = accessCount
            self.size = size
        }

        var isExpired: Bool {
            Date().timeIntervalSince(timestamp) > 300 // 5 minutes default TTL
        }

        func incrementAccess() {
            accessCount += 1
        }
    }
    
    // MARK: - Initialization
    
    init(maxSize: Int = 100, ttl: TimeInterval = 300) {
        self.maxSize = maxSize
        self.ttl = ttl
        
        // Schedule periodic cleanup
        Task {
            await startPeriodicCleanup()
        }
    }
    
    // MARK: - Public API
    
    /// Get cached results for a fetch request
    func get<T: NSManagedObject>(for request: NSFetchRequest<T>) -> [T]? {
        guard let fetchRequest = request as? NSFetchRequest<NSFetchRequestResult> else {
            logger.error("Unable to cast fetch request to NSFetchRequestResult")
            return nil
        }
        let key = cacheKey(for: fetchRequest)

        guard let cached = cache[key], !cached.isExpired else {
            missCount += 1
            logger.debug("Cache miss for key: \(key)")
            return nil
        }

        // Direct mutation - no copy needed with reference type
        cached.incrementAccess()
        hitCount += 1

        logger.debug("Cache hit for key: \(key)")
        return cached.results as? [T]
    }

    /// Store results in cache
    func set<T: NSManagedObject>(_ results: [T], for request: NSFetchRequest<T>) {
        guard let fetchRequest = request as? NSFetchRequest<NSFetchRequestResult> else {
            logger.error("Unable to cast fetch request to NSFetchRequestResult")
            return
        }
        let key = cacheKey(for: fetchRequest)
        
        // Estimate memory size (rough approximation)
        let size = results.count * 100 // Assume 100 bytes per object average
        
        // Check if we need to evict entries
        if cache.count >= maxSize {
            evictLeastRecentlyUsed()
        }
        
        cache[key] = CachedQuery(
            results: results,
            timestamp: Date(),
            accessCount: 0,
            size: size
        )
        
        logger.debug("Cached \(results.count) results for key: \(key)")
    }
    
    /// Invalidate specific cache entry
    func invalidate(for request: NSFetchRequest<NSFetchRequestResult>) {
        let key = cacheKey(for: request)
        if cache.removeValue(forKey: key) != nil {
            logger.debug("Invalidated cache for key: \(key)")
        }
    }
    
    /// Invalidate all cache entries
    func invalidateAll() {
        let count = cache.count
        cache.removeAll()
        logger.info("Invalidated all \(count) cache entries")
    }
    
    /// Invalidate cache entries for a specific entity type
    func invalidate(entityName: String) {
        let keysToRemove = cache.keys.filter { $0.contains(entityName) }
        for key in keysToRemove {
            cache.removeValue(forKey: key)
        }
        logger.debug("Invalidated \(keysToRemove.count) entries for entity: \(entityName)")
    }
    
    /// Get cache statistics
    func statistics() -> CacheStatistics {
        let currentSize = cache.count
        
        return CacheStatistics(
            hitCount: hitCount,
            missCount: missCount,
            evictionCount: evictionCount,
            currentSize: currentSize,
            maxSize: maxSize
        )
    }
    
    /// Clear all statistics
    func resetStatistics() {
        hitCount = 0
        missCount = 0
        evictionCount = 0
    }
    
    // MARK: - Private Methods
    
    private func cacheKey(for request: NSFetchRequest<NSFetchRequestResult>) -> String {
        var components: [String] = []
        
        // Entity name
        if let entityName = request.entityName {
            components.append(entityName)
        }
        
        // Predicate
        if let predicate = request.predicate {
            components.append(predicate.predicateFormat)
        }
        
        // Sort descriptors
        if let sortDescriptors = request.sortDescriptors {
            let sortKeys = sortDescriptors.compactMap { $0.key }.joined(separator: ",")
            components.append(sortKeys)
        }
        
        // Fetch limit
        if request.fetchLimit > 0 {
            components.append("limit:\(request.fetchLimit)")
        }
        
        // Fetch offset
        if request.fetchOffset > 0 {
            components.append("offset:\(request.fetchOffset)")
        }
        
        // Properties to fetch
        if let properties = request.propertiesToFetch {
            let propertyNames = properties.compactMap { ($0 as? String) ?? String(describing: $0) }.joined(separator: ",")
            components.append(propertyNames)
        }
        
        return components.joined(separator: "_")
    }
    
    private func evictLeastRecentlyUsed() {
        // Find entries to evict (expired or least recently used)
        let expiredKeys = cache.compactMap { key, value in
            value.isExpired ? key : nil
        }
        
        // Remove expired entries first
        for key in expiredKeys {
            cache.removeValue(forKey: key)
            evictionCount += 1
        }
        
        // If still over capacity, remove least recently used
        if cache.count >= maxSize {
            let sortedByAccess = self.cache.sorted { $0.value.accessCount < $1.value.accessCount }
            let toEvict = sortedByAccess.prefix(self.cache.count - maxSize + 1)
            
            for (key, _) in toEvict {
                cache.removeValue(forKey: key)
                evictionCount += 1
            }
        }
        
        logger.debug("Evicted entries, current size: \(self.cache.count)")
    }
    
    private func cleanupExpired() {
        let expiredKeys = cache.compactMap { key, value in
            value.isExpired ? key : nil
        }
        
        for key in expiredKeys {
            cache.removeValue(forKey: key)
            evictionCount += 1
        }
        
        if !expiredKeys.isEmpty {
            logger.debug("Cleaned up \(expiredKeys.count) expired entries")
        }
    }
    
    private func startPeriodicCleanup() async {
        // Run cleanup every minute
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 60_000_000_000) // 60 seconds
            cleanupExpired()
        }
    }
    
    // MARK: - Cache Warming
    
    /// Pre-populate cache with frequently accessed queries
    func warmup(with requests: [(NSFetchRequest<NSFetchRequestResult>, [NSManagedObject])]) {
        for (request, results) in requests {
            let key = cacheKey(for: request)
            cache[key] = CachedQuery(
                results: results,
                timestamp: Date(),
                accessCount: 0,
                size: results.count * 100
            )
        }
        
        logger.info("Warmed up cache with \(requests.count) entries")
    }
}

