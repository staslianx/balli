//
//  BatchInsertOperation.swift
//  balli
//
//  Specialized actor for batch insert operations with Swift 6 concurrency
//

@preconcurrency import CoreData
import Foundation
import os.log

/// Actor responsible for batch insert operations
@PersistenceActor
public final class BatchInsertOperation: BatchInsertOperator {
    private let coordinator: BatchOperationCoordinator
    private let logger = os.Logger(subsystem: "com.balli.diabetes", category: "BatchInsertOperation")
    
    public init(coordinator: BatchOperationCoordinator) {
        self.coordinator = coordinator
    }

    // Helper type for safely passing data arrays across Sendable boundaries
    private struct DataArrayWrapper: @unchecked Sendable {
        let data: [[String: Any]]
    }

    /// Perform batch insert operation with progress tracking
    public func performBatchInsert<T: NSManagedObject>(
        entityType: T.Type,
        data: [[String: Any]],
        conflictResolution: ConflictResolution,
        configuration: BatchConfiguration = .default,
        progressHandler: (@Sendable (BatchProgress) -> Void)? = nil
    ) async throws -> BatchOperationResult {
        logger.info("Starting batch insert of \(data.count) \(String(describing: entityType)) entities")
        
        let startTime = Date()
        var result = BatchOperationResult()
        let batchSize = configuration.batchSize
        let totalBatches = (data.count + batchSize - 1) / batchSize
        
        return try await withTaskCancellationHandler {
            var processedCount = 0
            var currentBatch = 0
            
            for batchStart in stride(from: 0, to: data.count, by: batchSize) {
                try Task.checkCancellation()
                
                currentBatch += 1
                let batchEnd = min(batchStart + batchSize, data.count)
                let batch = Array(data[batchStart..<batchEnd])
                
                let batchResult = try await processBatch(
                    entityType: entityType,
                    batch: batch,
                    conflictResolution: conflictResolution,
                    configuration: configuration
                )
                
                result.merge(with: batchResult)
                processedCount += batch.count
                
                // Update progress
                if configuration.enableProgressTracking {
                    let estimatedTimeRemaining = coordinator.calculateEstimatedTime(
                        startTime: startTime,
                        processedCount: processedCount,
                        totalCount: data.count
                    )
                    
                    let progress = BatchProgress(
                        operationType: .insert,
                        totalItems: data.count,
                        processedItems: processedCount,
                        failedItems: result.failed,
                        currentBatch: currentBatch,
                        totalBatches: totalBatches,
                        estimatedTimeRemaining: estimatedTimeRemaining
                    )
                    
                    progressHandler?(progress)
                }
                
                await coordinator.checkMemoryUsage()
            }
            
            result.duration = Date().timeIntervalSince(startTime)
            logger.info("Batch insert completed: \(result.inserted) inserted, \(result.failed) failed")
            
            return result
        } onCancel: {
            Task { @PersistenceActor in
                self.logger.warning("Batch insert operation cancelled")
            }
        }
    }
    
    /// Process a single batch of entities
    private func processBatch<T: NSManagedObject>(
        entityType: T.Type,
        batch: [[String: Any]],
        conflictResolution: ConflictResolution,
        configuration: BatchConfiguration
    ) async throws -> BatchOperationResult {

        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.parent = await EnhancedPersistenceController.shared.viewContext
        context.mergePolicy = configuration.mergePolicy

        // Wrap batch in @unchecked Sendable as it contains simple value types
        let wrapper = DataArrayWrapper(data: batch)

        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                var result = BatchOperationResult()

                try? autoreleasepool {
                    for (_, data) in wrapper.data.enumerated() {
                        let entity = T(context: context)

                        // Apply data to entity
                        for (key, value) in data {
                            if entity.responds(to: NSSelectorFromString("set\(key.capitalized):")) {
                                entity.setValue(value, forKey: key)
                            }
                        }

                        result.inserted += 1
                    }
                    
                    // Save batch
                    if configuration.autoSave && context.hasChanges {
                        try context.save()
                    }
                }
                
                continuation.resume(returning: result)
            }
        }
    }
    
    /// Optimized batch insert using Core Data's NSBatchInsertRequest for large datasets
    public func performOptimizedBatchInsert<T: NSManagedObject>(
        entityType: T.Type,
        data: [[String: Any]],
        configuration: BatchConfiguration = .default
    ) async throws -> BatchOperationResult {
        logger.info("Starting optimized batch insert of \(data.count) \(String(describing: entityType)) entities")

        let startTime = Date()

        // Wrap data in @unchecked Sendable as it contains simple value types
        let wrapper = DataArrayWrapper(data: data)

        return try await withTaskCancellationHandler {
            let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
            context.parent = await EnhancedPersistenceController.shared.viewContext

            return try await withCheckedThrowingContinuation { continuation in
                context.perform {
                    var result = BatchOperationResult()

                    do {
                        let request = NSBatchInsertRequest(
                            entityName: String(describing: entityType),
                            objects: wrapper.data
                        )
                        request.resultType = .count

                        if let batchResult = try context.execute(request) as? NSBatchInsertResult,
                           let insertedCount = batchResult.result as? Int {
                            result.inserted = insertedCount
                        }

                        result.duration = Date().timeIntervalSince(startTime)

                        if configuration.autoSave && context.hasChanges {
                            try context.save()
                        }

                        self.logger.info("Optimized batch insert completed: \(result.inserted) inserted")
                        continuation.resume(returning: result)

                    } catch {
                        self.logger.error("Optimized batch insert failed: \(error)")
                        continuation.resume(throwing: PersistenceError.batchOperationFailed(error))
                    }
                }
            }
        } onCancel: {
            Task { @PersistenceActor in
                self.logger.warning("Optimized batch insert operation cancelled")
            }
        }
    }
}