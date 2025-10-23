//
//  BatchDeleteOperation.swift
//  balli
//
//  Specialized actor for batch delete operations with Swift 6 concurrency
//

@preconcurrency import CoreData
import Foundation
import os.log

/// Actor responsible for batch delete operations
@PersistenceActor
public final class BatchDeleteOperation: BatchDeleteOperator {
    private let coordinator: BatchOperationCoordinator
    private let logger = os.Logger(subsystem: "com.balli.diabetes", category: "BatchDeleteOperation")
    
    public init(coordinator: BatchOperationCoordinator) {
        self.coordinator = coordinator
    }

    // Helper type for safely passing NSPredicate across Sendable boundaries
    private struct PredicateWrapper: @unchecked Sendable {
        let predicate: NSPredicate
    }

    /// Perform batch delete operation
    public func performBatchDelete<T: NSManagedObject>(
        entityType: T.Type,
        predicate: NSPredicate,
        configuration: BatchConfiguration = .default
    ) async throws -> BatchOperationResult {
        logger.info("Starting batch delete for \(String(describing: entityType))")

        let startTime = Date()

        return try await withTaskCancellationHandler {
            let fetchRequest = T.fetchRequest()
            fetchRequest.predicate = predicate
            let request = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            request.resultType = .resultTypeCount

            let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
            context.parent = await EnhancedPersistenceController.shared.viewContext

            return try await withCheckedThrowingContinuation { continuation in
                context.perform {
                    var result = BatchOperationResult()

                    do {
                        let batchResult = try context.execute(request) as? NSBatchDeleteResult
                        let deletedCount = batchResult?.result as? Int ?? 0

                        result.deleted = deletedCount
                        result.duration = Date().timeIntervalSince(startTime)

                        if configuration.autoSave && context.hasChanges {
                            try context.save()
                        }

                        self.logger.info("Batch delete completed: \(deletedCount) entities deleted")
                        continuation.resume(returning: result)

                    } catch {
                        self.logger.error("Batch delete failed: \(error)")
                        continuation.resume(throwing: PersistenceError.batchOperationFailed(error))
                    }
                }
            }
        } onCancel: {
            Task { @PersistenceActor in
                self.logger.warning("Batch delete operation cancelled")
            }
        }
    }
    
    /// Perform conditional batch delete with validation
    public func performConditionalBatchDelete<T: NSManagedObject>(
        entityType: T.Type,
        predicate: NSPredicate,
        configuration: BatchConfiguration = .default,
        validator: @escaping @Sendable (T) throws -> Bool
    ) async throws -> BatchOperationResult {
        logger.info("Starting conditional batch delete for \(String(describing: entityType))")

        let startTime = Date()

        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.parent = await EnhancedPersistenceController.shared.viewContext

        // Wrap predicate in @unchecked Sendable wrapper
        let predicateWrapper = PredicateWrapper(predicate: predicate)

        return try await withTaskCancellationHandler {
            return try await withCheckedThrowingContinuation { continuation in
                context.perform {
                    var result = BatchOperationResult()

                    do {
                        // Fetch entities to validate before deletion
                        let request = T.fetchRequest()
                        request.predicate = predicateWrapper.predicate

                        let entities = try context.fetch(request) as? [T] ?? []

                        for entity in entities {
                            do {
                                if try validator(entity) {
                                    context.delete(entity)
                                    result.deleted += 1
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

                        self.logger.info("Conditional batch delete completed: \(result.deleted) deleted, \(result.failed) failed")
                        continuation.resume(returning: result)

                    } catch {
                        self.logger.error("Conditional batch delete failed: \(error)")
                        continuation.resume(throwing: PersistenceError.batchOperationFailed(error))
                    }
                }
            }
        } onCancel: {
            Task { @PersistenceActor in
                self.logger.warning("Conditional batch delete operation cancelled")
            }
        }
    }
    
    /// Perform soft delete by updating a status field instead of actual deletion
    public func performSoftDelete<T: NSManagedObject>(
        entityType: T.Type,
        predicate: NSPredicate,
        deletedStatusField: String = "isDeleted",
        deletedAtField: String = "deletedAt",
        configuration: BatchConfiguration = .default
    ) async throws -> BatchOperationResult {
        logger.info("Starting soft delete for \(String(describing: entityType))")

        let updates: [String: Any] = [
            deletedStatusField: true,
            deletedAtField: Date()
        ]

        let request = NSBatchUpdateRequest(entityName: String(describing: entityType))
        request.predicate = predicate
        request.propertiesToUpdate = updates
        request.resultType = .updatedObjectIDsResultType
        request.includesSubentities = false

        let startTime = Date()

        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.parent = await EnhancedPersistenceController.shared.viewContext
        context.mergePolicy = configuration.mergePolicy

        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                var result = BatchOperationResult()

                do {
                    let batchResult = try context.execute(request) as? NSBatchUpdateResult
                    let updatedObjectIDs = batchResult?.result as? [NSManagedObjectID] ?? []

                    result.deleted = updatedObjectIDs.count  // Use deleted count for soft deletes
                    result.duration = Date().timeIntervalSince(startTime)

                    if configuration.autoSave && context.hasChanges {
                        try context.save()
                    }

                    self.logger.info("Soft delete completed: \(result.deleted) entities marked as deleted")
                    continuation.resume(returning: result)

                } catch {
                    self.logger.error("Soft delete failed: \(error)")
                    continuation.resume(throwing: PersistenceError.batchOperationFailed(error))
                }
            }
        }
    }
    
    /// Perform cascade delete with relationship handling
    public func performCascadeDelete<T: NSManagedObject>(
        entityType: T.Type,
        predicate: NSPredicate,
        configuration: BatchConfiguration = .default,
        relationshipKeys: [String] = []
    ) async throws -> BatchOperationResult {
        logger.info("Starting cascade delete for \(String(describing: entityType))")

        let startTime = Date()

        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.parent = await EnhancedPersistenceController.shared.viewContext

        // Wrap predicate in @unchecked Sendable wrapper
        let predicateWrapper = PredicateWrapper(predicate: predicate)

        return try await withTaskCancellationHandler {
            return try await withCheckedThrowingContinuation { continuation in
                context.perform {
                    var result = BatchOperationResult()

                    do {
                        // Fetch entities with relationships
                        let request = T.fetchRequest()
                        request.predicate = predicateWrapper.predicate
                        request.relationshipKeyPathsForPrefetching = relationshipKeys

                        let entities = try context.fetch(request) as? [T] ?? []

                        // Delete entities (Core Data will handle cascading based on model configuration)
                        for entity in entities {
                            context.delete(entity)
                            result.deleted += 1
                        }

                        result.duration = Date().timeIntervalSince(startTime)

                        if configuration.autoSave && context.hasChanges {
                            try context.save()
                        }

                        self.logger.info("Cascade delete completed: \(result.deleted) entities deleted")
                        continuation.resume(returning: result)

                    } catch {
                        self.logger.error("Cascade delete failed: \(error)")
                        continuation.resume(throwing: PersistenceError.batchOperationFailed(error))
                    }
                }
            }
        } onCancel: {
            Task { @PersistenceActor in
                self.logger.warning("Cascade delete operation cancelled")
            }
        }
    }
    
    /// Perform batch delete with backup/archive functionality
    public func performDeleteWithBackup<T: NSManagedObject>(
        entityType: T.Type,
        predicate: NSPredicate,
        configuration: BatchConfiguration = .default,
        backupHandler: @escaping @Sendable ([T]) throws -> Void
    ) async throws -> BatchOperationResult {
        logger.info("Starting delete with backup for \(String(describing: entityType))")

        let startTime = Date()

        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.parent = await EnhancedPersistenceController.shared.viewContext

        // Wrap predicate in @unchecked Sendable wrapper
        let predicateWrapper = PredicateWrapper(predicate: predicate)

        return try await withTaskCancellationHandler {
            return try await withCheckedThrowingContinuation { continuation in
                context.perform {
                    var result = BatchOperationResult()

                    do {
                        // Fetch entities to backup
                        let request = T.fetchRequest()
                        request.predicate = predicateWrapper.predicate

                        let entities = try context.fetch(request) as? [T] ?? []

                        // Create backup first
                        try backupHandler(entities)

                        // After successful backup, perform the actual deletion
                        for entity in entities {
                            context.delete(entity)
                            result.deleted += 1
                        }

                        result.duration = Date().timeIntervalSince(startTime)

                        if configuration.autoSave && context.hasChanges {
                            try context.save()
                        }

                        self.logger.info("Delete with backup completed: \(result.deleted) entities deleted")
                        continuation.resume(returning: result)

                    } catch {
                        self.logger.error("Delete with backup failed: \(error)")
                        continuation.resume(throwing: PersistenceError.batchOperationFailed(error))
                    }
                }
            }
        } onCancel: {
            Task { @PersistenceActor in
                self.logger.warning("Delete with backup operation cancelled")
            }
        }
    }
}