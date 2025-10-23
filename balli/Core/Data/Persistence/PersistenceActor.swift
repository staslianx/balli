//
//  PersistenceActor.swift
//  balli
//
//  Global actor for thread-safe Core Data operations with Swift 6
//

import Foundation
import CoreData

/// Global actor for ensuring thread-safe Core Data operations
/// This actor isolates all persistence operations to prevent data races
@globalActor
public actor PersistenceActor {
    public static let shared = PersistenceActor()
    
    private init() {}
    
    /// Convenience method to run code on the persistence actor
    public static func run<T: Sendable>(
        resultType: T.Type = T.self,
        body: @PersistenceActor () throws -> T
    ) async rethrows -> T {
        try await body()
    }
    
    /// Convenience method for non-throwing operations
    public static func run<T: Sendable>(
        resultType: T.Type = T.self,
        body: @PersistenceActor () async -> T
    ) async -> T {
        await body()
    }
}

/// Protocol for types that can be safely passed between actors
public protocol PersistenceSendable: Sendable {}

/// Wrapper for Core Data object IDs that can be safely passed between actors
public struct ManagedObjectReference: PersistenceSendable {
    public let objectID: NSManagedObjectID
    public let entityName: String
    
    public init(objectID: NSManagedObjectID, entityName: String) {
        self.objectID = objectID
        self.entityName = entityName
    }
}


/// Import progress that can be safely passed between actors
public struct ImportProgress: PersistenceSendable {
    public let totalItems: Int
    public let processedItems: Int
    public let failedItems: Int
    public let currentBatch: Int
    public let totalBatches: Int
    
    public var percentComplete: Double {
        guard totalItems > 0 else { return 0 }
        return Double(processedItems) / Double(totalItems)
    }
    
    public var isComplete: Bool {
        processedItems + failedItems >= totalItems
    }
    
    public init(
        totalItems: Int,
        processedItems: Int,
        failedItems: Int,
        currentBatch: Int = 0,
        totalBatches: Int = 0
    ) {
        self.totalItems = totalItems
        self.processedItems = processedItems
        self.failedItems = failedItems
        self.currentBatch = currentBatch
        self.totalBatches = totalBatches
    }
}

/// Cache statistics that can be safely passed between actors
public struct CacheStatistics: PersistenceSendable {
    public let hitCount: Int
    public let missCount: Int
    public let evictionCount: Int
    public let currentSize: Int
    public let maxSize: Int
    
    public var hitRate: Double {
        let total = hitCount + missCount
        guard total > 0 else { return 0 }
        return Double(hitCount) / Double(total)
    }
    
    public var utilizationRate: Double {
        guard maxSize > 0 else { return 0 }
        return Double(currentSize) / Double(maxSize)
    }
    
    public init(
        hitCount: Int = 0,
        missCount: Int = 0,
        evictionCount: Int = 0,
        currentSize: Int = 0,
        maxSize: Int = 100
    ) {
        self.hitCount = hitCount
        self.missCount = missCount
        self.evictionCount = evictionCount
        self.currentSize = currentSize
        self.maxSize = maxSize
    }
}

/// Health metrics that can be safely passed between actors
public struct HealthMetrics: PersistenceSendable {
    public let databaseSize: Int64
    public let entityCounts: [String: Int]
    public let lastVacuum: Date?
    public let lastAnalyze: Date?
    public let fragmentationLevel: Double
    public let orphanedObjectCount: Int
    public let inconsistentRelationshipCount: Int
    
    public var totalEntityCount: Int {
        entityCounts.values.reduce(0, +)
    }
    
    public var requiresMaintenance: Bool {
        fragmentationLevel > 0.3 || orphanedObjectCount > 100
    }
    
    public init(
        databaseSize: Int64 = 0,
        entityCounts: [String: Int] = [:],
        lastVacuum: Date? = nil,
        lastAnalyze: Date? = nil,
        fragmentationLevel: Double = 0,
        orphanedObjectCount: Int = 0,
        inconsistentRelationshipCount: Int = 0
    ) {
        self.databaseSize = databaseSize
        self.entityCounts = entityCounts
        self.lastVacuum = lastVacuum
        self.lastAnalyze = lastAnalyze
        self.fragmentationLevel = fragmentationLevel
        self.orphanedObjectCount = orphanedObjectCount
        self.inconsistentRelationshipCount = inconsistentRelationshipCount
    }
}