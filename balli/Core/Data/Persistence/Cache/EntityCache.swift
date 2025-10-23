//
//  EntityCache.swift
//  balli
//
//  Object-level caching for frequently accessed entities
//

@preconcurrency import CoreData
import Foundation
import os.log

/// Thread-safe cache for individual Core Data entities
actor EntityCache {
    private let logger = os.Logger(subsystem: "com.balli.diabetes", category: "EntityCache")
    
    // Cache storage
    private var cache: [NSManagedObjectID: CachedEntity] = [:]
    
    // Configuration
    private let maxSize: Int
    private let ttl: TimeInterval
    
    // Statistics
    private var hitCount = 0
    private var missCount = 0
    private var evictionCount = 0
    
    // Memory pressure handling
    private var isUnderMemoryPressure = false
    
    // MARK: - Types
    
    private struct CachedEntity {
        let object: NSManagedObject
        let timestamp: Date
        let accessCount: Int
        let entityName: String
        let estimatedSize: Int
        
        var isExpired: Bool {
            Date().timeIntervalSince(timestamp) > 600 // 10 minutes TTL for entities
        }
        
        func incrementAccess() -> CachedEntity {
            CachedEntity(
                object: object,
                timestamp: timestamp,
                accessCount: accessCount + 1,
                entityName: entityName,
                estimatedSize: estimatedSize
            )
        }
    }
    
    // MARK: - Initialization
    
    init(maxSize: Int = 500, ttl: TimeInterval = 600) {
        self.maxSize = maxSize
        self.ttl = ttl
        
        // Start monitoring
        Task {
            await startMonitoring()
        }
    }
    
    // MARK: - Public API
    
    /// Get cached entity by object ID
    func get(_ objectID: NSManagedObjectID) -> NSManagedObject? {
        guard !isUnderMemoryPressure else {
            logger.debug("Skipping cache under memory pressure")
            return nil
        }
        
        guard let cached = cache[objectID], !cached.isExpired else {
            missCount += 1
            return nil
        }
        
        // Check if object is still valid
        guard !cached.object.isFault && !cached.object.isDeleted else {
            cache.removeValue(forKey: objectID)
            missCount += 1
            return nil
        }
        
        // Update access count
        cache[objectID] = cached.incrementAccess()
        hitCount += 1
        
        return cached.object
    }
    
    /// Store entity in cache
    func set(_ object: NSManagedObject) {
        guard !isUnderMemoryPressure else {
            logger.debug("Not caching due to memory pressure")
            return
        }
        
        // Don't cache temporary objects
        guard object.objectID.isTemporaryID == false else {
            return
        }
        
        // Don't cache deleted objects
        guard !object.isDeleted else {
            return
        }
        
        // Check capacity
        if cache.count >= maxSize {
            evictLeastRecentlyUsed()
        }
        
        let entityName = object.entity.name ?? "Unknown"
        let estimatedSize = estimateSize(of: object)
        
        cache[object.objectID] = CachedEntity(
            object: object,
            timestamp: Date(),
            accessCount: 0,
            entityName: entityName,
            estimatedSize: estimatedSize
        )
        
        logger.debug("Cached entity: \(entityName)")
    }
    
    /// Remove entity from cache
    func remove(_ objectID: NSManagedObjectID) {
        if cache.removeValue(forKey: objectID) != nil {
            logger.debug("Removed entity from cache")
        }
    }
    
    /// Clear all cached entities
    func clear() {
        let count = cache.count
        cache.removeAll()
        logger.info("Cleared \(count) cached entities")
    }
    
    /// Clear entities of specific type
    func clear(entityName: String) {
        let keysToRemove = cache.compactMap { key, value in
            value.entityName == entityName ? key : nil
        }
        
        for key in keysToRemove {
            cache.removeValue(forKey: key)
        }
        
        logger.debug("Cleared \(keysToRemove.count) entities of type: \(entityName)")
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
    
    /// Handle memory pressure
    func handleMemoryPressure() {
        logger.warning("Handling memory pressure")
        isUnderMemoryPressure = true
        
        // Aggressively clear cache
        let removed = cache.count
        cache.removeAll()
        evictionCount += removed
        
        // Schedule recovery
        Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
            isUnderMemoryPressure = false
            logger.info("Recovered from memory pressure")
        }
    }
    
    // MARK: - Private Methods
    
    private func estimateSize(of object: NSManagedObject) -> Int {
        // Rough estimation based on property count and types
        var size = 100 // Base overhead
        
        for property in object.entity.properties {
            if property is NSAttributeDescription {
                size += 50 // Assume 50 bytes per attribute
            } else if property is NSRelationshipDescription {
                size += 8 // Just the reference
            }
        }
        
        return size
    }
    
    private func evictLeastRecentlyUsed() {
        // Remove expired entries first
        let expiredKeys = cache.compactMap { key, value in
            value.isExpired ? key : nil
        }
        
        for key in expiredKeys {
            cache.removeValue(forKey: key)
            evictionCount += 1
        }
        
        // If still over capacity, remove least recently used
        if cache.count >= maxSize {
            let sortedByAccess = cache.sorted { $0.value.accessCount < $1.value.accessCount }
            let toEvict = sortedByAccess.prefix(max(1, cache.count - maxSize + 1))
            
            for (key, _) in toEvict {
                cache.removeValue(forKey: key)
                evictionCount += 1
            }
        }
    }
    
    private func cleanupExpired() {
        let expiredKeys = cache.compactMap { key, value in
            value.isExpired || value.object.isFault || value.object.isDeleted ? key : nil
        }
        
        for key in expiredKeys {
            cache.removeValue(forKey: key)
            evictionCount += 1
        }
        
        if !expiredKeys.isEmpty {
            logger.debug("Cleaned up \(expiredKeys.count) expired/invalid entities")
        }
    }
    
    private func startMonitoring() async {
        // Periodic cleanup every 2 minutes
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 120_000_000_000) // 120 seconds
            cleanupExpired()
            
            // Log statistics periodically
            let stats = statistics()
            if stats.hitCount + stats.missCount > 0 {
                logger.debug("""
                    Cache stats - Hit rate: \(String(format: "%.1f", stats.hitRate * 100))%, \
                    Size: \(stats.currentSize)/\(stats.maxSize)
                    """)
            }
        }
    }
    
    // MARK: - Batch Operations
    
    /// Pre-populate cache with multiple entities
    func warmup(with objects: [NSManagedObject]) {
        for object in objects {
            set(object)
        }
        
        logger.info("Warmed up cache with \(objects.count) entities")
    }
    
    /// Invalidate multiple entities
    func invalidate(objectIDs: [NSManagedObjectID]) {
        for objectID in objectIDs {
            cache.removeValue(forKey: objectID)
        }
        
        logger.debug("Invalidated \(objectIDs.count) entities")
    }
    
    /// Get multiple entities at once
    func getBatch(_ objectIDs: [NSManagedObjectID]) -> [NSManagedObjectID: NSManagedObject] {
        var results: [NSManagedObjectID: NSManagedObject] = [:]
        
        for objectID in objectIDs {
            if let object = get(objectID) {
                results[objectID] = object
            }
        }
        
        return results
    }
}

// MARK: - Cache Coordination

/// Coordinates between different cache layers
actor CacheCoordinator {
    private let queryCache: QueryCache
    private let entityCache: EntityCache
    private let logger = os.Logger(subsystem: "com.balli.diabetes", category: "CacheCoordinator")
    
    init(queryCache: QueryCache, entityCache: EntityCache) {
        self.queryCache = queryCache
        self.entityCache = entityCache
    }
    
    /// Invalidate all caches
    func invalidateAll() async {
        await queryCache.invalidateAll()
        await entityCache.clear()
        logger.info("All caches invalidated")
    }
    
    /// Invalidate caches for specific entity type
    func invalidate(entityName: String) async {
        await queryCache.invalidate(entityName: entityName)
        await entityCache.clear(entityName: entityName)
        logger.debug("Invalidated caches for entity: \(entityName)")
    }
    
    /// Handle memory pressure across all caches
    func handleMemoryPressure() async {
        await queryCache.invalidateAll()
        await entityCache.handleMemoryPressure()
        logger.warning("Handled memory pressure across all caches")
    }
    
    /// Get combined statistics
    func statistics() async -> (query: CacheStatistics, entity: CacheStatistics) {
        let queryStats = await queryCache.statistics()
        let entityStats = await entityCache.statistics()
        return (queryStats, entityStats)
    }
}