//
//  BatchOperationProtocol.swift
//  balli
//
//  Protocol definitions and shared types for batch operations with Swift 6 concurrency
//

@preconcurrency import CoreData
import Foundation

// MARK: - Core Protocols

/// Protocol for batch operation coordinators
@PersistenceActor
public protocol BatchOperationCoordinator: Sendable {
    /// Check if any operation is currently running
    var isRunning: Bool { get }
    
    /// Current operation progress
    var progress: BatchProgress? { get }
    
    /// Calculate estimated time remaining
    func calculateEstimatedTime(
        startTime: Date,
        processedCount: Int,
        totalCount: Int
    ) -> TimeInterval
    
    /// Check memory usage and perform cleanup if needed
    func checkMemoryUsage() async
}

/// Protocol for insert operations
@PersistenceActor
public protocol BatchInsertOperator: Sendable {
    /// Perform batch insert operation
    func performBatchInsert<T: NSManagedObject>(
        entityType: T.Type,
        data: [[String: Any]],
        conflictResolution: ConflictResolution,
        configuration: BatchConfiguration,
        progressHandler: (@Sendable (BatchProgress) -> Void)?
    ) async throws -> BatchOperationResult
}

/// Protocol for update operations
@PersistenceActor
public protocol BatchUpdateOperator: Sendable {
    /// Perform batch update operation
    func performBatchUpdate<T: NSManagedObject>(
        entityType: T.Type,
        predicate: NSPredicate,
        updates: [String: Any],
        configuration: BatchConfiguration
    ) async throws -> BatchOperationResult
    
    /// Perform batch upsert operation
    func performBatchUpsert<T: NSManagedObject>(
        entityType: T.Type,
        data: [[String: Any]],
        uniqueKeys: [String],
        configuration: BatchConfiguration,
        progressHandler: (@Sendable (BatchProgress) -> Void)?
    ) async throws -> BatchOperationResult
}

/// Protocol for delete operations
@PersistenceActor
public protocol BatchDeleteOperator: Sendable {
    /// Perform batch delete operation
    func performBatchDelete<T: NSManagedObject>(
        entityType: T.Type,
        predicate: NSPredicate,
        configuration: BatchConfiguration
    ) async throws -> BatchOperationResult
}

/// Protocol for operation queue management
@PersistenceActor
public protocol BatchOperationQueue: Sendable {
    /// Add operation to queue
    func addOperation(_ operation: BatchQueuedOperation) async
    
    /// Process queued operations
    func processQueue() async throws
    
    /// Cancel all queued operations
    func cancelAllOperations() async
    
    /// Check if queue is empty
    var isEmpty: Bool { get async }
    
    /// Number of operations in queue
    var count: Int { get async }
}

// MARK: - Supporting Types

/// Represents a queued batch operation
public struct BatchQueuedOperation: Sendable {
    public let id: UUID
    public let type: OperationType
    public let priority: Priority
    public let createdAt: Date
    public let operation: @Sendable () async throws -> BatchOperationResult
    
    public enum Priority: Int, Sendable, Comparable {
        case low = 1
        case normal = 2
        case high = 3
        case critical = 4
        
        public static func < (lhs: Priority, rhs: Priority) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }
    
    public init(
        type: OperationType,
        priority: Priority = .normal,
        operation: @escaping @Sendable () async throws -> BatchOperationResult
    ) {
        self.id = UUID()
        self.type = type
        self.priority = priority
        self.createdAt = Date()
        self.operation = operation
    }
}

/// Progress tracking for batch operations
public struct BatchProgress: Sendable {
    public let operationType: OperationType
    public let totalItems: Int
    public let processedItems: Int
    public let failedItems: Int
    public let currentBatch: Int
    public let totalBatches: Int
    public let estimatedTimeRemaining: TimeInterval
    
    public var completionPercentage: Double {
        totalItems > 0 ? Double(processedItems) / Double(totalItems) : 0
    }
    
    public var isComplete: Bool {
        processedItems + failedItems >= totalItems
    }
    
    public init(
        operationType: OperationType,
        totalItems: Int,
        processedItems: Int,
        failedItems: Int,
        currentBatch: Int,
        totalBatches: Int,
        estimatedTimeRemaining: TimeInterval
    ) {
        self.operationType = operationType
        self.totalItems = totalItems
        self.processedItems = processedItems
        self.failedItems = failedItems
        self.currentBatch = currentBatch
        self.totalBatches = totalBatches
        self.estimatedTimeRemaining = estimatedTimeRemaining
    }
}

/// Types of batch operations
public enum OperationType: String, Sendable {
    case insert = "insert"
    case update = "update"
    case delete = "delete"
    case upsert = "upsert"
}

/// Configuration for batch operations
public struct BatchConfiguration: Sendable {
    public let batchSize: Int
    public let memoryThreshold: Int64
    public let maxRetries: Int
    public let enableProgressTracking: Bool
    public let autoSave: Bool
    public let mergePolicy: NSMergePolicy
    
    public init(
        batchSize: Int = 100,
        memoryThreshold: Int64 = 50_000_000,
        maxRetries: Int = 3,
        enableProgressTracking: Bool = true,
        autoSave: Bool = true,
        mergePolicy: NSMergePolicy
    ) {
        self.batchSize = batchSize
        self.memoryThreshold = memoryThreshold
        self.maxRetries = maxRetries
        self.enableProgressTracking = enableProgressTracking
        self.autoSave = autoSave
        self.mergePolicy = mergePolicy
    }
    
    public static let `default` = BatchConfiguration(
        mergePolicy: NSMergePolicy.mergeByPropertyObjectTrump
    )
    
    public static let highPerformance = BatchConfiguration(
        batchSize: 500,
        memoryThreshold: 100_000_000,
        maxRetries: 1,
        enableProgressTracking: false,
        autoSave: false,
        mergePolicy: NSMergePolicy.overwrite
    )
}

/// Result of batch operations
public struct BatchOperationResult: Sendable {
    public var inserted: Int = 0
    public var updated: Int = 0
    public var deleted: Int = 0
    public var failed: Int = 0
    public var duration: TimeInterval = 0
    
    public var total: Int {
        inserted + updated + deleted + failed
    }
    
    public var successRate: Double {
        let successful = inserted + updated + deleted
        return total > 0 ? Double(successful) / Double(total) : 0
    }
    
    public mutating func merge(with other: BatchOperationResult) {
        inserted += other.inserted
        updated += other.updated
        deleted += other.deleted
        failed += other.failed
    }
    
    public init() {}
}

/// Conflict resolution strategies
public enum ConflictResolution: Sendable {
    case overwrite
    case merge
    case ignore
    case fail
}

// MARK: - Error Extensions

extension PersistenceError {
    // Note: batchOperationFailed is now a proper enum case in PersistenceSharedTypes.swift

    public static func queueOperationFailed(_ reason: String) -> PersistenceError {
        .transactionFailed(NSError(
            domain: "com.balli.batch.queue",
            code: 1001,
            userInfo: [NSLocalizedDescriptionKey: reason]
        ))
    }
}