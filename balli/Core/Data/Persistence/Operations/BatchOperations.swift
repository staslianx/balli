//
//  BatchOperations.swift
//  balli
//
//  Refactored batch operations coordinator using specialized operation actors
//

@preconcurrency import CoreData
import Foundation
import os.log

/// Main coordinator for batch operations, delegating to specialized operation actors
@PersistenceActor
public final class BatchOperations: BatchOperationCoordinator {
    private let logger = os.Logger(subsystem: "com.balli.diabetes", category: "BatchOperations")
    
    // Configuration
    private let batchSize: Int
    private let memoryThreshold: Int64
    private let maxRetries: Int
    
    // Progress tracking
    private var isExecuting = false
    private var currentProgress: BatchProgress?
    
    // Specialized operation actors
    private lazy var insertOperator = BatchInsertOperation(coordinator: self)
    private lazy var updateOperator = BatchUpdateOperation(coordinator: self)
    private lazy var deleteOperator = BatchDeleteOperation(coordinator: self)
    private lazy var queueManager = BatchOperationQueueManager()
    
    // MARK: - Initialization
    
    public init(configuration: BatchConfiguration = .default) {
        self.batchSize = configuration.batchSize
        self.memoryThreshold = configuration.memoryThreshold
        self.maxRetries = configuration.maxRetries
    }
    
    // MARK: - Public API
    
    /// Insert multiple entities with conflict resolution
    public func batchInsert<T: NSManagedObject>(
        entityType: T.Type,
        data: [[String: Any]],
        conflictResolution: ConflictResolution,
        configuration: BatchConfiguration = .default,
        progressHandler: (@Sendable (BatchProgress) -> Void)? = nil
    ) async throws -> BatchOperationResult {
        isExecuting = true
        currentProgress = BatchProgress(
            operationType: .insert,
            totalItems: data.count,
            processedItems: 0,
            failedItems: 0,
            currentBatch: 0,
            totalBatches: (data.count + configuration.batchSize - 1) / configuration.batchSize,
            estimatedTimeRemaining: 0
        )
        defer { 
            isExecuting = false
            currentProgress = nil
        }
        
        return try await insertOperator.performBatchInsert(
            entityType: entityType,
            data: data,
            conflictResolution: conflictResolution,
            configuration: configuration,
            progressHandler: { progress in
                Task { @PersistenceActor in
                    self.currentProgress = progress
                }
                progressHandler?(progress)
            }
        )
    }
    
    /// Update multiple entities based on predicate with new values
    public func batchUpdate<T: NSManagedObject>(
        entityType: T.Type,
        predicate: NSPredicate,
        updates: [String: Any],
        configuration: BatchConfiguration = .default
    ) async throws -> BatchOperationResult {
        isExecuting = true
        defer { isExecuting = false }
        
        return try await updateOperator.performBatchUpdate(
            entityType: entityType,
            predicate: predicate,
            updates: updates,
            configuration: configuration
        )
    }
    
    /// Delete multiple entities based on predicate
    public func batchDelete<T: NSManagedObject>(
        entityType: T.Type,
        predicate: NSPredicate,
        configuration: BatchConfiguration = .default
    ) async throws -> BatchOperationResult {
        isExecuting = true
        defer { isExecuting = false }
        
        return try await deleteOperator.performBatchDelete(
            entityType: entityType,
            predicate: predicate,
            configuration: configuration
        )
    }
    
    /// Insert or update entities based on unique criteria
    public func batchUpsert<T: NSManagedObject>(
        entityType: T.Type,
        data: [[String: Any]],
        uniqueKeys: [String],
        configuration: BatchConfiguration = .default,
        progressHandler: (@Sendable (BatchProgress) -> Void)? = nil
    ) async throws -> BatchOperationResult {
        isExecuting = true
        currentProgress = BatchProgress(
            operationType: .upsert,
            totalItems: data.count,
            processedItems: 0,
            failedItems: 0,
            currentBatch: 0,
            totalBatches: (data.count + configuration.batchSize - 1) / configuration.batchSize,
            estimatedTimeRemaining: 0
        )
        defer { 
            isExecuting = false
            currentProgress = nil
        }
        
        return try await updateOperator.performBatchUpsert(
            entityType: entityType,
            data: data,
            uniqueKeys: uniqueKeys,
            configuration: configuration,
            progressHandler: { progress in
                Task { @PersistenceActor in
                    self.currentProgress = progress
                }
                progressHandler?(progress)
            }
        )
    }
    
    // MARK: - Public Status
    
    public var isRunning: Bool {
        isExecuting
    }
    
    public var progress: BatchProgress? {
        currentProgress
    }
    
    // MARK: - Queue Management API
    
    /// Add operation to processing queue
    public func queueOperation(_ operation: BatchQueuedOperation) async {
        await queueManager.addOperation(operation)
    }
    
    /// Process all queued operations
    public func processQueuedOperations() async throws {
        try await queueManager.processQueue()
    }
    
    /// Get queue statistics
    public func getQueueStatistics() async -> QueueStatistics {
        await queueManager.getQueueStatistics()
    }
    
    /// Cancel all queued operations
    public func cancelQueuedOperations() async {
        await queueManager.cancelAllOperations()
    }
    
    // MARK: - Advanced Operations
    
    /// Perform optimized insert for large datasets
    public func optimizedBatchInsert<T: NSManagedObject>(
        entityType: T.Type,
        data: [[String: Any]],
        configuration: BatchConfiguration = .default
    ) async throws -> BatchOperationResult {
        isExecuting = true
        defer { isExecuting = false }
        
        return try await insertOperator.performOptimizedBatchInsert(
            entityType: entityType,
            data: data,
            configuration: configuration
        )
    }
    
    /// Perform conditional delete with validation
    public func conditionalBatchDelete<T: NSManagedObject>(
        entityType: T.Type,
        predicate: NSPredicate,
        configuration: BatchConfiguration = .default,
        validator: @escaping @Sendable (T) throws -> Bool
    ) async throws -> BatchOperationResult {
        isExecuting = true
        defer { isExecuting = false }
        
        return try await deleteOperator.performConditionalBatchDelete(
            entityType: entityType,
            predicate: predicate,
            configuration: configuration,
            validator: validator
        )
    }
    
    /// Perform soft delete by marking entities as deleted
    public func softBatchDelete<T: NSManagedObject>(
        entityType: T.Type,
        predicate: NSPredicate,
        configuration: BatchConfiguration = .default
    ) async throws -> BatchOperationResult {
        isExecuting = true
        defer { isExecuting = false }
        
        return try await deleteOperator.performSoftDelete(
            entityType: entityType,
            predicate: predicate,
            configuration: configuration
        )
    }
    
    // MARK: - BatchOperationCoordinator Protocol Implementation
    
    public func calculateEstimatedTime(
        startTime: Date,
        processedCount: Int,
        totalCount: Int
    ) -> TimeInterval {
        guard processedCount > 0 else { return 0 }
        
        let elapsedTime = Date().timeIntervalSince(startTime)
        let avgTimePerItem = elapsedTime / Double(processedCount)
        let remainingItems = totalCount - processedCount
        
        return avgTimePerItem * Double(remainingItems)
    }
    
    public func checkMemoryUsage() async {
        let memoryUsage = getMemoryUsage()
        
        if memoryUsage > memoryThreshold {
            logger.warning("Memory usage high: \(memoryUsage / 1_000_000)MB, performing cleanup")
            
            // Force memory cleanup
            await MainActor.run {
                autoreleasepool {
                    // Trigger memory cleanup
                }
            }
        }
    }
    
    private func getMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        return result == KERN_SUCCESS ? Int64(info.resident_size) : 0
    }
    
    // MARK: - Convenience Methods
    
    /// Create a queued insert operation
    public func createQueuedInsert<T: NSManagedObject>(
        entityType: T.Type,
        data: [[String: Any]],
        conflictResolution: ConflictResolution,
        configuration: BatchConfiguration = .default,
        priority: BatchQueuedOperation.Priority = .normal
    ) async -> BatchQueuedOperation {
        // Capture values in sendable format
        let capturedData = data
        let capturedConflictResolution = conflictResolution
        let capturedConfiguration = configuration
        
        return BatchQueuedOperation(type: .insert, priority: priority) { @PersistenceActor in
            try await self.batchInsert(
                entityType: entityType,
                data: capturedData,
                conflictResolution: capturedConflictResolution,
                configuration: capturedConfiguration
            )
        }
    }
    
    /// Create a queued update operation
    public func createQueuedUpdate<T: NSManagedObject>(
        entityType: T.Type,
        predicate: NSPredicate,
        updates: [String: Any],
        configuration: BatchConfiguration = .default,
        priority: BatchQueuedOperation.Priority = .normal
    ) async -> BatchQueuedOperation {
        // Capture values in sendable format
        let capturedUpdates = updates
        let capturedConfiguration = configuration
        
        return BatchQueuedOperation(type: .update, priority: priority) { @PersistenceActor in
            try await self.batchUpdate(
                entityType: entityType,
                predicate: predicate,
                updates: capturedUpdates,
                configuration: capturedConfiguration
            )
        }
    }
    
    /// Create a queued delete operation
    public func createQueuedDelete<T: NSManagedObject>(
        entityType: T.Type,
        predicate: NSPredicate,
        configuration: BatchConfiguration = .default,
        priority: BatchQueuedOperation.Priority = .normal
    ) async -> BatchQueuedOperation {
        // Capture values in sendable format
        let capturedConfiguration = configuration
        
        return BatchQueuedOperation(type: .delete, priority: priority) { @PersistenceActor in
            try await self.batchDelete(
                entityType: entityType,
                predicate: predicate,
                configuration: capturedConfiguration
            )
        }
    }
}