//
//  BatchOperationQueue.swift
//  balli
//
//  Queue management for batch operations with priority and scheduling
//

@preconcurrency import CoreData
import Foundation
import os.log

/// Actor responsible for managing queued batch operations
@PersistenceActor
public final class BatchOperationQueueManager: BatchOperationQueue {
    private var operations: [BatchQueuedOperation] = []
    private var isProcessing = false
    private let logger = os.Logger(subsystem: "com.balli.diabetes", category: "BatchOperationQueue")
    
    /// Add operation to the queue
    public func addOperation(_ operation: BatchQueuedOperation) async {
        operations.append(operation)
        operations.sort { $0.priority > $1.priority } // Higher priority first
        
        logger.info("Added \(operation.type.rawValue) operation to queue with priority \(String(describing: operation.priority))")
        
        // Auto-start processing if not already running
        if !isProcessing {
            Task { @PersistenceActor in
                try? await self.processQueue()
            }
        }
    }
    
    /// Process all queued operations in priority order
    public func processQueue() async throws {
        guard !isProcessing else {
            logger.info("Queue processing already in progress")
            return
        }
        
        isProcessing = true
        defer { isProcessing = false }
        
        logger.info("Starting queue processing with \(self.operations.count) operations")
        
        while !operations.isEmpty {
            let operation = self.operations.removeFirst()
            
            do {
                logger.info("Processing \(operation.type.rawValue) operation (ID: \(operation.id))")
                let result = try await operation.operation()
                logger.info("Operation completed: \(result.inserted) inserted, \(result.updated) updated, \(result.deleted) deleted, \(result.failed) failed")
            } catch {
                logger.error("Operation failed: \(error)")
                
                // For critical operations, we might want to retry
                if operation.priority == .critical {
                    logger.info("Retrying critical operation")
                    self.operations.insert(operation, at: 0) // Add back to front for immediate retry
                }
                
                throw error
            }
        }
        
        logger.info("Queue processing completed")
    }
    
    /// Cancel all queued operations
    public func cancelAllOperations() async {
        let cancelledCount = operations.count
        operations.removeAll()
        isProcessing = false
        
        logger.info("Cancelled \(cancelledCount) queued operations")
    }
    
    /// Check if queue is empty
    public var isEmpty: Bool {
        get async {
            operations.isEmpty
        }
    }
    
    /// Number of operations in queue
    public var count: Int {
        get async {
            operations.count
        }
    }
    
    /// Get operations by priority
    public func getOperations(withPriority priority: BatchQueuedOperation.Priority) async -> [BatchQueuedOperation] {
        operations.filter { $0.priority == priority }
    }
    
    /// Remove specific operation from queue
    public func removeOperation(withId id: UUID) async -> Bool {
        if let index = operations.firstIndex(where: { $0.id == id }) {
            operations.remove(at: index)
            logger.info("Removed operation with ID: \(id)")
            return true
        }
        return false
    }
    
    /// Get queue statistics
    public func getQueueStatistics() async -> QueueStatistics {
        let priorityCounts = Dictionary(grouping: operations, by: { $0.priority })
            .mapValues { $0.count }
        
        let oldestOperation = operations.min(by: { $0.createdAt < $1.createdAt })
        let averageAge = operations.isEmpty ? 0 : 
            operations.map { Date().timeIntervalSince($0.createdAt) }.reduce(0, +) / Double(operations.count)
        
        return QueueStatistics(
            totalOperations: operations.count,
            priorityCounts: priorityCounts,
            isProcessing: isProcessing,
            oldestOperationAge: oldestOperation?.createdAt.timeIntervalSinceNow ?? 0,
            averageOperationAge: averageAge
        )
    }
    
    /// Process operations with specific priority first
    public func processPriorityOperations(priority: BatchQueuedOperation.Priority) async throws {
        guard !isProcessing else {
            logger.info("Queue processing already in progress")
            return
        }
        
        isProcessing = true
        defer { isProcessing = false }
        
        let priorityOps = operations.filter { $0.priority == priority }
        operations.removeAll { $0.priority == priority }
        
        logger.info("Processing \(priorityOps.count) operations with priority \(String(describing: priority))")
        
        for operation in priorityOps {
            do {
                logger.info("Processing priority \(operation.type.rawValue) operation (ID: \(operation.id))")
                let result = try await operation.operation()
                logger.info("Priority operation completed: \(result.inserted) inserted, \(result.updated) updated, \(result.deleted) deleted, \(result.failed) failed")
            } catch {
                logger.error("Priority operation failed: \(error)")
                throw error
            }
        }
        
        logger.info("Priority queue processing completed")
    }
    
    /// Schedule operation to run at specific time
    public func scheduleOperation(_ operation: BatchQueuedOperation, at date: Date) async {
        let delay = date.timeIntervalSinceNow
        
        if delay <= 0 {
            // Run immediately
            await addOperation(operation)
        } else {
            // Schedule for later
            Task { @PersistenceActor in
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                await self.addOperation(operation)
            }
        }
    }
}

// MARK: - Supporting Types

/// Statistics about the operation queue
public struct QueueStatistics: Sendable {
    public let totalOperations: Int
    public let priorityCounts: [BatchQueuedOperation.Priority: Int]
    public let isProcessing: Bool
    public let oldestOperationAge: TimeInterval
    public let averageOperationAge: TimeInterval
    
    public var hasHighPriorityOperations: Bool {
        (priorityCounts[.high] ?? 0) > 0 || (priorityCounts[.critical] ?? 0) > 0
    }
    
    public var needsAttention: Bool {
        totalOperations > 100 || oldestOperationAge > 300 // 5 minutes
    }
    
    public init(
        totalOperations: Int,
        priorityCounts: [BatchQueuedOperation.Priority: Int],
        isProcessing: Bool,
        oldestOperationAge: TimeInterval,
        averageOperationAge: TimeInterval
    ) {
        self.totalOperations = totalOperations
        self.priorityCounts = priorityCounts
        self.isProcessing = isProcessing
        self.oldestOperationAge = oldestOperationAge
        self.averageOperationAge = averageOperationAge
    }
}