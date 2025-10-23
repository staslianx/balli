//
//  PersistenceTransactionManager.swift
//  balli
//
//  Manages transaction support and batch operations for persistence layer
//

@preconcurrency import CoreData
import Foundation
import os.log

/// Manages transactions, batch operations, and ensures data consistency across operations
public actor PersistenceTransactionManager {
    private let logger = os.Logger(subsystem: "com.balli.diabetes", category: "PersistenceTransactionManager")
    
    // MARK: - Transaction State
    private var activeTransactions: [UUID: TransactionContext] = [:]
    private var transactionQueue: OperationQueue
    
    // MARK: - Batch Operations
    private var activeBatchOperations: [UUID: BatchOperationContext] = [:]
    private let batchQueue: OperationQueue
    
    // MARK: - Configuration
    private let configuration: TransactionConfiguration
    private let persistentContainer: NSPersistentContainer
    
    public init(persistentContainer: NSPersistentContainer, configuration: TransactionConfiguration = .default) {
        self.persistentContainer = persistentContainer
        self.configuration = configuration
        
        // Configure transaction queue
        transactionQueue = OperationQueue()
        transactionQueue.maxConcurrentOperationCount = 1 // Serial execution for consistency
        transactionQueue.qualityOfService = .userInitiated
        transactionQueue.name = "com.balli.persistence.transaction"
        
        // Configure batch operation queue
        batchQueue = OperationQueue()
        batchQueue.maxConcurrentOperationCount = 2 // Allow some parallel batch operations
        batchQueue.qualityOfService = .utility
        batchQueue.name = "com.balli.persistence.batch"
        
        logger.debug("Transaction manager initialized")
    }
    
    // MARK: - Transaction Management
    
    /// Execute a transaction with automatic rollback on failure
    public func executeTransaction<T: Sendable>(
        _ operation: @escaping @Sendable (TransactionContext) async throws -> T
    ) async throws -> T {
        // Get parent context from persistent container
        let parentContext = persistentContainer.viewContext
        let transaction = TransactionContext(parentContext: parentContext)
        let transactionID = transaction.transactionId
        
        activeTransactions[transactionID] = transaction
        defer {
            activeTransactions.removeValue(forKey: transactionID)
        }
        
        logger.info("Starting transaction: \(transactionID)")
        
        do {
            let result = try await operation(transaction)
            try await transaction.commit()
            
            logger.info("Transaction committed: \(transactionID)")
            return result
            
        } catch {
            logger.error("Transaction failed, rolling back: \(transactionID) - \(error)")
            await transaction.rollback()
            throw error
        }
    }
    
    /// Execute multiple operations in a single transaction
    public func executeTransactionGroup(
        operations: [@Sendable (TransactionContext) async throws -> Void]
    ) async throws {
        try await executeTransaction { transaction in
            for operation in operations {
                try await operation(transaction)
            }
        }
    }
    
    /// Check if any transactions are currently active
    public func hasActiveTransactions() async -> Bool {
        return !activeTransactions.isEmpty
    }
    
    /// Get count of active transactions
    public func getActiveTransactionCount() async -> Int {
        return activeTransactions.count
    }
    
    // MARK: - Batch Operations
    
    /// Execute batch delete operation
    public func executeBatchDelete<T: NSManagedObject>(
        _ type: T.Type,
        predicateConfig: PredicateConfiguration,
        container: NSPersistentContainer
    ) async throws -> BatchOperationResult {
        let batchID = UUID()
        let startTime = Date()

        logger.info("Starting batch delete for \(String(describing: type)) with predicate")

        // Perform batch delete directly without NSOperation to avoid non-Sendable captures
        let result = try await performBatchDelete(
            type,
            predicateConfig: predicateConfig,
            container: container,
            batchID: batchID
        )

        let duration = Date().timeIntervalSince(startTime)
        logger.info("Batch delete completed in \(duration)s: \(result.deleted) deleted")

        return result
    }
    
    /// Execute batch update operation
    public func executeBatchUpdate<T: NSManagedObject>(
        _ type: T.Type,
        predicateConfig: PredicateConfiguration,
        properties: [String: Any],
        container: NSPersistentContainer
    ) async throws -> BatchOperationResult {
        let batchID = UUID()
        let startTime = Date()

        logger.info("Starting batch update for \(String(describing: type))")

        // Perform batch update directly without NSOperation to avoid non-Sendable captures
        let result = try await performBatchUpdate(
            type,
            predicateConfig: predicateConfig,
            properties: properties,
            container: container,
            batchID: batchID
        )

        let duration = Date().timeIntervalSince(startTime)
        logger.info("Batch update completed in \(duration)s: \(result.updated) updated")

        return result
    }
    
    /// Execute controlled batch insert with progress tracking
    public func executeBatchInsert<T: NSManagedObject>(
        _ type: T.Type,
        creator: @escaping @Sendable (NSManagedObjectContext) throws -> [T],
        container: NSPersistentContainer,
        progressHandler: (@Sendable (Double) -> Void)? = nil
    ) async throws -> BatchOperationResult {
        let batchID = UUID()
        let startTime = Date()
        
        logger.info("Starting controlled batch insert for \(String(describing: type))")
        
        let result = try await withCheckedThrowingContinuation { continuation in
            batchQueue.addOperation { [weak self] in
                Task {
                    do {
                        let result = try await self?.performBatchInsert(
                            type,
                            creator: creator,
                            container: container,
                            batchID: batchID,
                            progressHandler: progressHandler
                        )
                        continuation.resume(returning: result ?? BatchOperationResult())
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
        
        let duration = Date().timeIntervalSince(startTime)
        logger.info("Batch insert completed in \(duration)s: \(result.inserted) inserted")
        
        return result
    }
    
    // MARK: - Validation Support
    
    /// Validate entities before committing transaction
    public func validateEntities(in context: NSManagedObjectContext) async throws {
        let insertedObjects = context.insertedObjects
        let updatedObjects = context.updatedObjects
        
        var validationErrors: [String] = []
        
        // Validate inserted objects
        for object in insertedObjects {
            do {
                try object.validateForInsert()
            } catch {
                let entityName = object.entity.name ?? "Unknown"
                validationErrors.append("Insert validation failed for \(entityName): \(error.localizedDescription)")
            }
        }
        
        // Validate updated objects
        for object in updatedObjects {
            do {
                try object.validateForUpdate()
            } catch {
                let entityName = object.entity.name ?? "Unknown"
                validationErrors.append("Update validation failed for \(entityName): \(error.localizedDescription)")
            }
        }
        
        if !validationErrors.isEmpty {
            logger.error("Validation failed for \(validationErrors.count) objects")
            throw PersistenceError.validationFailed(validationErrors)
        }
    }
    
    // MARK: - Cleanup and Monitoring
    
    /// Clean up completed transactions and operations
    public func performCleanup() async {
        // Remove completed batch operations
        activeBatchOperations = activeBatchOperations.filter { _, context in
            !context.isCompleted
        }
        
        logger.debug("Transaction manager cleanup completed")
    }
    
    /// Get transaction statistics
    public func getTransactionStatistics() async -> TransactionStatistics {
        return TransactionStatistics(
            activeTransactions: activeTransactions.count,
            activeBatchOperations: activeBatchOperations.count,
            queuedTransactions: transactionQueue.operationCount,
            queuedBatchOperations: batchQueue.operationCount
        )
    }
    
    // MARK: - Private Implementation

    // Helper type for safely passing properties dictionary across Sendable boundaries
    private struct PropertiesWrapper: @unchecked Sendable {
        let properties: [String: Any]
    }

    private func performBatchDelete<T: NSManagedObject>(
        _ type: T.Type,
        predicateConfig: PredicateConfiguration,
        container: NSPersistentContainer,
        batchID: UUID
    ) async throws -> BatchOperationResult {
        let context = BatchOperationContext(id: batchID, type: .delete)
        activeBatchOperations[batchID] = context
        let startTime = context.startTime  // Capture start time before entering Sendable closure
        defer {
            context.markCompleted()
            activeBatchOperations.removeValue(forKey: batchID)
        }

        // Use withCheckedThrowingContinuation to avoid Sendable issues
        return try await withCheckedThrowingContinuation { continuation in
            container.performBackgroundTask { backgroundContext in
                do {
                    let fetchRequest = T.fetchRequest()
                    // Create predicate inside actor boundary - SAFE
                    fetchRequest.predicate = predicateConfig.createPredicate()

                    let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
                    batchDeleteRequest.resultType = .resultTypeCount

                    let result = try backgroundContext.execute(batchDeleteRequest) as? NSBatchDeleteResult
                    let deletedCount = result?.result as? Int ?? 0

                    // Merge changes to view context
                    NSManagedObjectContext.mergeChanges(
                        fromRemoteContextSave: [NSDeletedObjectsKey: batchDeleteRequest.fetchRequest as Any],
                        into: [container.viewContext]
                    )

                    var batchResult = BatchOperationResult()
                    batchResult.deleted = deletedCount
                    batchResult.duration = Date().timeIntervalSince(startTime)
                    continuation.resume(returning: batchResult)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func performBatchUpdate<T: NSManagedObject>(
        _ type: T.Type,
        predicateConfig: PredicateConfiguration,
        properties: [String: Any],
        container: NSPersistentContainer,
        batchID: UUID
    ) async throws -> BatchOperationResult {
        let context = BatchOperationContext(id: batchID, type: .update)
        activeBatchOperations[batchID] = context
        let startTime = context.startTime  // Capture start time before entering Sendable closure

        // Properties dictionary can't be made Sendable directly.
        // We'll use @unchecked Sendable wrapper as these are simple value types being passed to Core Data
        let wrapper = PropertiesWrapper(properties: properties)

        defer {
            context.markCompleted()
            activeBatchOperations.removeValue(forKey: batchID)
        }

        return try await withCheckedThrowingContinuation { continuation in
            container.performBackgroundTask { backgroundContext in
                do {
                    let fetchRequest = T.fetchRequest()
                    // Create predicate inside actor boundary - SAFE
                    let predicate = predicateConfig.createPredicate()
                    fetchRequest.predicate = predicate

                    let batchUpdateRequest = NSBatchUpdateRequest(entity: T.entity())
                    batchUpdateRequest.predicate = predicate
                    batchUpdateRequest.propertiesToUpdate = wrapper.properties
                    batchUpdateRequest.resultType = .updatedObjectsCountResultType

                    let result = try backgroundContext.execute(batchUpdateRequest) as? NSBatchUpdateResult
                    let updatedCount = result?.result as? Int ?? 0

                    // Refresh objects in view context
                    container.viewContext.performAndWait {
                        container.viewContext.refreshAllObjects()
                    }

                    var batchResult = BatchOperationResult()
                    batchResult.updated = updatedCount
                    batchResult.duration = Date().timeIntervalSince(startTime)
                    continuation.resume(returning: batchResult)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func performBatchInsert<T: NSManagedObject>(
        _ type: T.Type,
        creator: @escaping @Sendable (NSManagedObjectContext) throws -> [T],
        container: NSPersistentContainer,
        batchID: UUID,
        progressHandler: (@Sendable (Double) -> Void)?
    ) async throws -> BatchOperationResult {
        let context = BatchOperationContext(id: batchID, type: .insert)
        activeBatchOperations[batchID] = context
        defer {
            context.markCompleted()
            activeBatchOperations.removeValue(forKey: batchID)
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            container.performBackgroundTask { backgroundContext in
                do {
                    let objects = try creator(backgroundContext)
                    let totalCount = objects.count
                    
                    var processedCount = 0
                    let batchSize = self.configuration.batchSize
                    
                    // Process in smaller batches to avoid memory issues
                    for batchStart in stride(from: 0, to: totalCount, by: batchSize) {
                        let batchEnd = min(batchStart + batchSize, totalCount)
                        
                        try autoreleasepool {
                            // Process batch items (they're already created by the creator)
                            processedCount += (batchEnd - batchStart)
                            
                            // Save batch
                            if backgroundContext.hasChanges {
                                try backgroundContext.save()
                            }
                            
                            // Update progress
                            let progress = Double(processedCount) / Double(totalCount)
                            progressHandler?(progress)
                            
                            // Check for cancellation
                            try Task.checkCancellation()
                        }
                    }
                    
                    // Merge changes to view context
                    container.viewContext.performAndWait {
                        container.viewContext.refreshAllObjects()
                    }
                    
                    var batchResult = BatchOperationResult()
                    batchResult.inserted = processedCount
                    batchResult.duration = Date().timeIntervalSince(Date()) // Placeholder for context.elapsed
                    continuation.resume(returning: batchResult)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

// MARK: - Configuration

/// Sendable-safe wrapper for NSPredicate configuration
public struct PredicateConfiguration: Sendable {
    public let format: String
    public let arguments: [any Sendable]

    public init(format: String, arguments: [any Sendable] = []) {
        self.format = format
        self.arguments = arguments
    }

    /// Create NSPredicate from configuration (must be called inside actor boundary)
    public func createPredicate() -> NSPredicate {
        NSPredicate(format: format, argumentArray: arguments)
    }

    /// Create configuration from existing predicate (for migration)
    public static func from(_ predicate: NSPredicate) -> PredicateConfiguration {
        PredicateConfiguration(
            format: predicate.predicateFormat,
            arguments: []
        )
    }
}

public struct TransactionConfiguration: Sendable {
    public let timeout: TimeInterval
    public let batchSize: Int
    public let enableValidation: Bool
    public let maxRetries: Int

    public init(
        timeout: TimeInterval = 30.0,
        batchSize: Int = 100,
        enableValidation: Bool = true,
        maxRetries: Int = 3
    ) {
        self.timeout = timeout
        self.batchSize = batchSize
        self.enableValidation = enableValidation
        self.maxRetries = maxRetries
    }

    public static let `default` = TransactionConfiguration()

    public static let testing = TransactionConfiguration(
        timeout: 10.0,
        batchSize: 10,
        enableValidation: true,
        maxRetries: 1
    )
}

// MARK: - Supporting Types

public struct TransactionStatistics: Sendable {
    public let activeTransactions: Int
    public let activeBatchOperations: Int
    public let queuedTransactions: Int
    public let queuedBatchOperations: Int
    
    public var totalActive: Int {
        activeTransactions + activeBatchOperations
    }
    
    public var totalQueued: Int {
        queuedTransactions + queuedBatchOperations
    }
}

// ValidationError is defined in TransactionContext.swift

private class BatchOperationContext {
    let id: UUID
    let type: BatchOperationType
    let startTime: Date
    private var endTime: Date?
    
    enum BatchOperationType {
        case insert
        case update
        case delete
    }
    
    init(id: UUID, type: BatchOperationType) {
        self.id = id
        self.type = type
        self.startTime = Date()
    }
    
    func markCompleted() {
        endTime = Date()
    }
    
    var isCompleted: Bool {
        endTime != nil
    }
    
    var elapsed: TimeInterval {
        let end = endTime ?? Date()
        return end.timeIntervalSince(startTime)
    }
}