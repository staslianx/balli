//
//  PersistenceCacheManager.swift
//  balli
//
//  Manages query and entity caching for persistence operations
//

@preconcurrency import CoreData
import Foundation
import os.log

/// Manages caching system including query cache, entity cache, and cache statistics
public actor PersistenceCacheManager {
    private let logger = os.Logger(subsystem: "com.balli.diabetes", category: "PersistenceCacheManager")
    
    // MARK: - Cache Components
    private let queryCache: QueryCache
    private let entityCache: EntityCache
    
    // MARK: - Statistics
    private var cacheStatistics = CacheStatistics()
    private var cacheHits = 0
    private var cacheMisses = 0
    
    // MARK: - Configuration
    private let configuration: CacheConfiguration
    
    public init(configuration: CacheConfiguration) {
        self.configuration = configuration
        self.queryCache = QueryCache(maxSize: configuration.queryCacheSize)
        self.entityCache = EntityCache(maxSize: configuration.entityCacheSize)
        
        logger.debug("Cache manager initialized - query: \(configuration.queryCacheSize), entity: \(configuration.entityCacheSize)")
    }
    
    // MARK: - Query Cache Operations
    
    /// Check if cached results exist for a fetch request
    public func getCachedResults<T: NSManagedObject>(for request: NSFetchRequest<T>) async -> [T]? {
        // Placeholder implementation until QueryCache is updated
        await recordCacheMiss()
        return nil
    }
    
    /// Store results in query cache
    public func cacheResults<T: NSManagedObject>(_ results: [T], for request: NSFetchRequest<T>) async {
        // Placeholder implementation until QueryCache is updated
        logger.debug("Cached \(results.count) results for entity: \(request.entityName ?? "unknown")")
    }
    
    /// Check if cache should be used based on policy
    public func shouldUseCache(for policy: CachePolicy) -> Bool {
        return policy.shouldCheckCache
    }
    
    /// Check if cache should be updated based on policy
    public func shouldUpdateCache(for policy: CachePolicy) -> Bool {
        return policy.shouldUpdateCache
    }
    
    // MARK: - Entity Cache Operations
    
    /// Get entity from entity cache
    public func getCachedEntity<T: NSManagedObject>(_ type: T.Type, id: NSManagedObjectID) async -> T? {
        // Placeholder implementation until EntityCache is updated
        return nil
    }
    
    /// Store entity in entity cache
    public func cacheEntity<T: NSManagedObject>(_ entity: T) async {
        // Placeholder implementation until EntityCache is updated
        logger.debug("Cached entity: \(T.self) with ID: \(entity.objectID)")
    }
    
    /// Remove entity from cache
    public func removeCachedEntity(id: NSManagedObjectID) async {
        // Placeholder implementation until EntityCache is updated
    }
    
    // MARK: - Cache Invalidation
    
    /// Invalidate all caches
    public func invalidateAllCaches() async {
        // Placeholder implementation until cache classes are updated
        logger.debug("All caches invalidated")
    }
    
    /// Invalidate caches for specific entity type
    public func invalidateCaches<T: NSManagedObject>(for type: T.Type) async {
        // Placeholder implementation until cache classes are updated
        logger.debug("Caches invalidated for entity type: \(T.self)")
    }
    
    /// Invalidate caches containing specific objects
    public func invalidateCaches(containing objectIDs: [NSManagedObjectID]) async {
        // Placeholder implementation until cache classes are updated
        logger.debug("Caches invalidated for \(objectIDs.count) objects")
    }
    
    // MARK: - Cache Maintenance
    
    /// Perform cache cleanup and optimization
    public func performMaintenance() async {
        let beforeStats = await getCurrentStatistics()
        
        // Placeholder implementation until cache classes are updated
        
        let afterStats = await getCurrentStatistics()
        
        logger.info("Cache maintenance completed - freed \(beforeStats.currentSize - afterStats.currentSize) bytes")
    }
    
    /// Warm up caches with frequently accessed data
    public func warmupCaches(with frequentRequests: [NSFetchRequest<NSManagedObject>]) async {
        logger.debug("Warming up caches with \(frequentRequests.count) frequent requests")

        for _ in frequentRequests {
            // Cache warming would be handled by the main controller
            // This method provides the interface for coordination
        }
    }
    
    // MARK: - Statistics and Monitoring
    
    /// Get current cache statistics
    public func getCurrentStatistics() async -> CacheStatistics {
        // For now, return basic statistics until cache implementations are updated
        return CacheStatistics(
            hitCount: cacheHits,
            missCount: cacheMisses,
            evictionCount: 0,
            currentSize: 0, // Will be calculated by actual cache
            maxSize: configuration.queryCacheSize + configuration.entityCacheSize
        )
    }
    
    /// Reset all cache statistics
    public func resetStatistics() async {
        cacheHits = 0
        cacheMisses = 0
        
        // Reset statistics in query and entity caches when methods are available
        
        logger.debug("Cache statistics reset")
    }
    
    /// Get cache health report
    public func getCacheHealthReport() async -> CacheHealthReport {
        let stats = await getCurrentStatistics()
        
        return CacheHealthReport(
            isHealthy: stats.hitRate > configuration.minimumHitRatio,
            hitRatio: stats.hitRate,
            memoryUsage: stats.currentSize,
            recommendations: generateOptimizationRecommendations(stats)
        )
    }
    
    // MARK: - Private Methods
    
    private func recordCacheHit() async {
        cacheHits += 1
        await updateCacheStatistics()
    }
    
    private func recordCacheMiss() async {
        cacheMisses += 1
        await updateCacheStatistics()
    }
    
    private func calculateHitRatio() -> Double {
        let total = cacheHits + cacheMisses
        guard total > 0 else { return 0.0 }
        return Double(cacheHits) / Double(total)
    }
    
    private func updateCacheStatistics() async {
        cacheStatistics = await getCurrentStatistics()
    }
    
    private func generateOptimizationRecommendations(_ stats: CacheStatistics) -> [CacheOptimizationRecommendation] {
        var recommendations: [CacheOptimizationRecommendation] = []
        
        if stats.hitRate < configuration.minimumHitRatio {
            recommendations.append(.increaseCacheSize)
        }
        
        if stats.currentSize > configuration.maxMemoryUsage {
            recommendations.append(.reduceCacheSize)
        }
        
        // Remove query cache specific check as it's not available in current stats
        
        return recommendations
    }
}

// MARK: - Cache Configuration

public struct CacheConfiguration: Sendable {
    public let queryCacheSize: Int
    public let entityCacheSize: Int
    public let minimumHitRatio: Double
    public let maxMemoryUsage: Int
    public let maxAccessTime: TimeInterval
    
    public init(
        queryCacheSize: Int = 100,
        entityCacheSize: Int = 500,
        minimumHitRatio: Double = 0.3,
        maxMemoryUsage: Int = 50_000_000, // 50MB
        maxAccessTime: TimeInterval = 0.1
    ) {
        self.queryCacheSize = queryCacheSize
        self.entityCacheSize = entityCacheSize
        self.minimumHitRatio = minimumHitRatio
        self.maxMemoryUsage = maxMemoryUsage
        self.maxAccessTime = maxAccessTime
    }
    
    public static let `default` = CacheConfiguration()
    
    public static let testing = CacheConfiguration(
        queryCacheSize: 10,
        entityCacheSize: 50,
        minimumHitRatio: 0.1,
        maxMemoryUsage: 10_000_000,
        maxAccessTime: 0.5
    )
}

// MARK: - Cache Statistics Extensions

// MARK: - Cache Statistics Types

public struct QueryCacheStatistics: Sendable {
    public let hitCount: Int
    public let missCount: Int
    public let memoryUsage: Int
    public let averageAccessTime: TimeInterval
    
    public init(hitCount: Int = 0, missCount: Int = 0, memoryUsage: Int = 0, averageAccessTime: TimeInterval = 0) {
        self.hitCount = hitCount
        self.missCount = missCount
        self.memoryUsage = memoryUsage
        self.averageAccessTime = averageAccessTime
    }
}

public struct EntityCacheStatistics: Sendable {
    public let entityCount: Int
    public let memoryUsage: Int
    public let averageAccessTime: TimeInterval
    
    public init(entityCount: Int = 0, memoryUsage: Int = 0, averageAccessTime: TimeInterval = 0) {
        self.entityCount = entityCount
        self.memoryUsage = memoryUsage
        self.averageAccessTime = averageAccessTime
    }
}

extension CacheStatistics {
    public init(
        queryCache: QueryCacheStatistics,
        entityCache: EntityCacheStatistics,
        totalHits: Int,
        totalMisses: Int,
        totalMemoryUsage: Int
    ) {
        self.init(
            hitCount: totalHits,
            missCount: totalMisses,
            evictionCount: 0,
            currentSize: totalMemoryUsage,
            maxSize: 100_000_000 // 100MB default max
        )
    }
}

// MARK: - Cache Health Reporting

public struct CacheHealthReport: Sendable {
    public let isHealthy: Bool
    public let hitRatio: Double
    public let memoryUsage: Int
    public let recommendations: [CacheOptimizationRecommendation]
    
    public var healthScore: Double {
        var score = hitRatio * 100
        
        // Penalize high memory usage
        if memoryUsage > 30_000_000 { // 30MB
            score *= 0.8
        }
        
        return min(100, max(0, score))
    }
}

public enum CacheOptimizationRecommendation: Sendable, CaseIterable {
    case increaseCacheSize
    case reduceCacheSize  
    case optimizeQueries
    case clearStaleEntries
    case adjustCachePolicy
    
    public var description: String {
        switch self {
        case .increaseCacheSize:
            return "Consider increasing cache size to improve hit ratio"
        case .reduceCacheSize:
            return "Consider reducing cache size to lower memory usage"
        case .optimizeQueries:
            return "Optimize queries to reduce access time"
        case .clearStaleEntries:
            return "Clear stale cache entries to free memory"
        case .adjustCachePolicy:
            return "Adjust cache policy for better performance"
        }
    }
}