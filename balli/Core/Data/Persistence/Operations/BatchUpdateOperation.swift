//
//  BatchUpdateOperation.swift
//  balli
//
//  Specialized actor for batch update and upsert operations with Swift 6 concurrency
//

@preconcurrency import CoreData
import Foundation
import os.log

/// Actor responsible for batch update and upsert operations
@PersistenceActor
public final class BatchUpdateOperation: BatchUpdateOperator {
    private let coordinator: BatchOperationCoordinator
    private let logger = os.Logger(subsystem: "com.balli.diabetes", category: "BatchUpdateOperation")
    
    public init(coordinator: BatchOperationCoordinator) {
        self.coordinator = coordinator
    }
    
    /// Perform batch update operation
    public func performBatchUpdate<T: NSManagedObject>(
        entityType: T.Type,
        predicate: NSPredicate,
        updates: [String: Any],
        configuration: BatchConfiguration = .default
    ) async throws -> BatchOperationResult {
        logger.info("Starting batch update for \(String(describing: entityType))")
        
        let startTime = Date()

        return try await withTaskCancellationHandler {
            let request = NSBatchUpdateRequest(entityName: String(describing: entityType))
            request.predicate = predicate
            request.propertiesToUpdate = updates
            request.resultType = .updatedObjectIDsResultType
            request.includesSubentities = false

            let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
            context.parent = await EnhancedPersistenceController.shared.viewContext
            context.mergePolicy = configuration.mergePolicy

            return try await withCheckedThrowingContinuation { continuation in
                context.perform {
                    do {
                        let batchResult = try context.execute(request) as? NSBatchUpdateResult
                        let updatedObjectIDs = batchResult?.result as? [NSManagedObjectID] ?? []

                        var result = BatchOperationResult()
                        result.updated = updatedObjectIDs.count
                        result.duration = Date().timeIntervalSince(startTime)

                        if configuration.autoSave && context.hasChanges {
                            try context.save()
                        }

                        self.logger.info("Batch update completed: \(result.updated) entities updated")
                        continuation.resume(returning: result)

                    } catch {
                        self.logger.error("Batch update failed: \(error)")
                        continuation.resume(throwing: PersistenceError.batchOperationFailed(error))
                    }
                }
            }
        } onCancel: {
            Task { @PersistenceActor in
                self.logger.warning("Batch update operation cancelled")
            }
        }
    }
    
    /// Perform batch upsert operation with progress tracking
    public func performBatchUpsert<T: NSManagedObject>(
        entityType: T.Type,
        data: [[String: Any]],
        uniqueKeys: [String],
        configuration: BatchConfiguration = .default,
        progressHandler: (@Sendable (BatchProgress) -> Void)? = nil
    ) async throws -> BatchOperationResult {
        logger.info("Starting batch upsert of \(data.count) \(String(describing: entityType)) entities")
        
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
                
                let batchResult = try await processUpsertBatch(
                    entityType: entityType,
                    batch: batch,
                    uniqueKeys: uniqueKeys,
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
                        operationType: .upsert,
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
            logger.info("Batch upsert completed: \(result.inserted) inserted, \(result.updated) updated, \(result.failed) failed")
            
            return result
        } onCancel: {
            Task { @PersistenceActor in
                self.logger.warning("Batch upsert operation cancelled")
            }
        }
    }
    
    /// Process a single batch for upsert operation
    private func processUpsertBatch<T: NSManagedObject>(
        entityType: T.Type,
        batch: [[String: Any]],
        uniqueKeys: [String],
        configuration: BatchConfiguration
    ) async throws -> BatchOperationResult {

        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.parent = await EnhancedPersistenceController.shared.viewContext
        context.mergePolicy = configuration.mergePolicy

        // Core Data KVC requires [String: Any], which is not Sendable
        // Safe to capture since context.perform runs on a serial queue
        nonisolated(unsafe) let batchData = batch

        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                var result = BatchOperationResult()

                try? autoreleasepool {
                    for data in batchData {
                        do {
                            // Build predicate for existing entity lookup
                            var predicates: [NSPredicate] = []
                            for key in uniqueKeys {
                                if let value = data[key] {
                                    // Safely cast to NSObject - skip if cast fails
                                    guard let nsValue = value as? NSObject else {
                                        self.logger.warning("Unable to cast value for key '\(key)' to NSObject, skipping predicate")
                                        continue
                                    }
                                    predicates.append(NSPredicate(format: "%K == %@", key, nsValue))
                                }
                            }
                            
                            let compound = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
                            
                            // Check if entity exists
                            let request = T.fetchRequest()
                            request.predicate = compound
                            request.fetchLimit = 1
                            
                            let existing = try context.fetch(request) as? [T]
                            
                            let entity: T
                            if let existingEntity = existing?.first {
                                // Update existing
                                entity = existingEntity
                                result.updated += 1
                            } else {
                                // Create new
                                entity = T(context: context)
                                result.inserted += 1
                            }
                            
                            // Apply data
                            for (key, value) in data {
                                if entity.responds(to: NSSelectorFromString("set\(key.capitalized):")) {
                                    entity.setValue(value, forKey: key)
                                }
                            }
                            
                        } catch {
                            self.logger.error("Failed to upsert entity: \(error)")
                            result.failed += 1
                        }
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
    
    /// Batch update entities with custom validation
    public func performValidatedBatchUpdate<T: NSManagedObject>(
        entityType: T.Type,
        predicate: NSPredicate,
        updates: [String: Any],
        configuration: BatchConfiguration = .default,
        validator: @escaping @Sendable (T, [String: Any]) throws -> Bool
    ) async throws -> BatchOperationResult {
        logger.info("Starting validated batch update for \(String(describing: entityType))")

        let startTime = Date()

        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.parent = await EnhancedPersistenceController.shared.viewContext
        context.mergePolicy = configuration.mergePolicy

        // NSPredicate and Core Data types are not Sendable, but safe to capture
        // since context.perform runs on a serial queue preventing data races
        nonisolated(unsafe) let searchPredicate = predicate
        nonisolated(unsafe) let updateValues = updates

        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    var result = BatchOperationResult()

                    // Fetch entities to update
                    let request = T.fetchRequest()
                    request.predicate = searchPredicate

                    let entities = try context.fetch(request) as? [T] ?? []

                    for entity in entities {
                        do {
                            // Validate before updating
                            if try validator(entity, updateValues) {
                                // Apply updates
                                for (key, value) in updateValues {
                                    if entity.responds(to: NSSelectorFromString("set\(key.capitalized):")) {
                                        entity.setValue(value, forKey: key)
                                    }
                                }
                                result.updated += 1
                            } else {
                                result.failed += 1
                            }
                        } catch {
                            self.logger.error("Validation failed for entity: \(error)")
                            result.failed += 1
                        }
                    }

                    result.duration = Date().timeIntervalSince(startTime)

                    if configuration.autoSave && context.hasChanges {
                        try context.save()
                    }

                    self.logger.info("Validated batch update completed: \(result.updated) updated, \(result.failed) failed")
                    continuation.resume(returning: result)

                } catch {
                    self.logger.error("Validated batch update failed: \(error)")
                    continuation.resume(throwing: PersistenceError.batchOperationFailed(error))
                }
            }
        }
    }
}