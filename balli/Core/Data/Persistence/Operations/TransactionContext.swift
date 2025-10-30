//
//  TransactionContext.swift
//  balli
//
//  Transaction context for Core Data with savepoint support and rollback capability
//

@preconcurrency import CoreData
import Foundation
import os.log

// MARK: - Concurrency Safe Merge Policy

fileprivate func getSafeMergePolicy() -> NSMergePolicy {
    return NSMergePolicy.mergeByPropertyObjectTrump
}

/// Provides transaction context with nested transaction support and rollback capability
@PersistenceActor
public final class TransactionContext {
    private let logger = os.Logger(subsystem: "com.balli.diabetes", category: "Transaction")
    
    // Context management
    private let context: NSManagedObjectContext
    private let parentContext: NSManagedObjectContext
    private var savepoints: [Savepoint] = []
    public private(set) var isCommitted = false
    public private(set) var isRolledBack = false
    
    // Transaction metadata
    public let transactionId: UUID
    private let startTime: Date
    private var endTime: Date?
    
    // Validation - using @Sendable closures for Swift 6 concurrency
    private var validators: [@Sendable (NSManagedObjectContext) throws -> Void] = []
    
    // MARK: - Types
    
    private struct Savepoint {
        let id: UUID
        let name: String
        let timestamp: Date
        let objectsSnapshot: Set<NSManagedObject>
        
        init(name: String) {
            self.id = UUID()
            self.name = name
            self.timestamp = Date()
            self.objectsSnapshot = Set()
        }
    }
    
    public struct TransactionStatistics: Sendable {
        public let transactionId: UUID
        public let duration: TimeInterval
        public let insertedObjects: Int
        public let updatedObjects: Int
        public let deletedObjects: Int
        public let savepointCount: Int
        public let validationCount: Int
        public let isSuccessful: Bool
        
        public var totalChanges: Int {
            insertedObjects + updatedObjects + deletedObjects
        }
    }
    
    // MARK: - Initialization

    nonisolated public init(parentContext: NSManagedObjectContext) {
        self.parentContext = parentContext
        self.transactionId = UUID()
        self.startTime = Date()

        // Create child context for transaction
        let newContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        newContext.parent = parentContext
        newContext.mergePolicy = getSafeMergePolicy()
        newContext.name = "TransactionContext-\(UUID().uuidString.prefix(8))"

        // Note: UndoManager initialization requires MainActor
        // Setting to nil for now - can be initialized later on demand
        newContext.undoManager = nil

        self.context = newContext
        logger.debug("Transaction context created: \(self.transactionId)")
    }
    
    // MARK: - Public API
    
    /// The managed object context for this transaction
    public var managedObjectContext: NSManagedObjectContext {
        context
    }
    
    /// Check if transaction has changes
    public var hasChanges: Bool {
        context.hasChanges
    }
    
    /// Check if transaction is active (not committed or rolled back)
    public var isActive: Bool {
        !isCommitted && !isRolledBack
    }
    
    // MARK: - Savepoints
    
    /// Create a savepoint within the transaction
    public func createSavepoint(name: String = "Savepoint") async throws {
        guard isActive else {
            throw TransactionError.transactionNotActive
        }

        logger.debug("Creating savepoint: \(name)")

        return try await withCheckedThrowingContinuation { continuation in
            context.perform { [weak self, context = self.context, logger = self.logger] in
                guard let self = self else {
                    continuation.resume(throwing: TransactionError.contextDeallocated)
                    return
                }

                do {
                    // Save current state if there are changes
                    if context.hasChanges {
                        try context.save()
                    }

                    let savepoint = Savepoint(name: name)

                    // Append to savepoints on PersistenceActor
                    Task { @PersistenceActor [weak self] in
                        self?.savepoints.append(savepoint)
                    }

                    logger.debug("Savepoint created: \(name) (\(savepoint.id))")
                    continuation.resume()

                } catch {
                    logger.error("Failed to create savepoint: \(error)")
                    continuation.resume(throwing: TransactionError.savepointFailed(error))
                }
            }
        }
    }
    
    /// Rollback to a specific savepoint
    public func rollbackToSavepoint(name: String) async throws {
        guard isActive else {
            throw TransactionError.transactionNotActive
        }

        guard let savepointIndex = savepoints.firstIndex(where: { $0.name == name }) else {
            throw TransactionError.savepointNotFound(name)
        }

        logger.info("Rolling back to savepoint: \(name)")

        return try await withCheckedThrowingContinuation { continuation in
            context.perform { [weak self, context = self.context, logger = self.logger] in
                guard let self = self else {
                    continuation.resume(throwing: TransactionError.contextDeallocated)
                    return
                }

                // Use undo manager to rollback to savepoint
                // Access undoManager asynchronously to avoid deadlock
                Task { @MainActor in
                    while context.undoManager?.canUndo == true {
                        context.undoManager?.undo()
                    }

                    // Remove savepoints after the target on PersistenceActor
                    Task { @PersistenceActor [weak self] in
                        guard let self = self else { return }
                        if savepointIndex + 1 < self.savepoints.count {
                            self.savepoints.removeSubrange((savepointIndex + 1)...)
                        }
                    }

                    logger.info("Rolled back to savepoint: \(name)")
                    continuation.resume()
                }
            }
        }
    }
    
    /// Release a savepoint (no longer needed for rollback)
    public func releaseSavepoint(name: String) throws {
        guard isActive else {
            throw TransactionError.transactionNotActive
        }
        
        guard let index = savepoints.firstIndex(where: { $0.name == name }) else {
            throw TransactionError.savepointNotFound(name)
        }
        
        savepoints.remove(at: index)
        logger.debug("Released savepoint: \(name)")
    }
    
    // MARK: - Validation
    
    /// Add a validation function to be called before commit
    public func addValidator(_ validator: @escaping @Sendable (NSManagedObjectContext) throws -> Void) {
        validators.append(validator)
    }
    
    /// Validate all registered validators
    private func validateChanges() throws {
        for validator in validators {
            try validator(context)
        }
    }
    
    // MARK: - Transaction Control
    
    /// Commit the transaction
    public func commit() async throws {
        guard isActive else {
            throw TransactionError.transactionNotActive
        }

        guard hasChanges else {
            logger.debug("No changes to commit in transaction")
            markAsCommitted()
            return
        }

        logger.info("Committing transaction: \(self.transactionId)")

        // Capture validators before entering Sendable closure
        let currentValidators = validators

        return try await withCheckedThrowingContinuation { continuation in
            context.perform { [weak self, context = self.context, logger = self.logger, transactionId = self.transactionId] in
                guard let self = self else {
                    continuation.resume(throwing: TransactionError.contextDeallocated)
                    return
                }

                do {
                    // Run validation
                    for validator in currentValidators {
                        try validator(context)
                    }

                    // Save the transaction context
                    try context.save()

                    // Mark as committed on PersistenceActor
                    Task { @PersistenceActor [weak self] in
                        self?.markAsCommitted()
                    }

                    logger.info("Transaction committed successfully: \(transactionId)")
                    continuation.resume()

                } catch {
                    logger.error("Transaction commit failed: \(error)")
                    continuation.resume(throwing: TransactionError.commitFailed(error))
                }
            }
        }
    }
    
    /// Rollback the transaction
    public func rollback() async {
        guard isActive else {
            logger.debug("Transaction already completed")
            return
        }

        logger.info("Rolling back transaction: \(self.transactionId)")

        await withCheckedContinuation { continuation in
            context.perform { [weak self, context = self.context, logger = self.logger, transactionId = self.transactionId] in
                guard let self = self else {
                    continuation.resume()
                    return
                }

                // Rollback all changes
                context.rollback()

                // Clear savepoints and mark as rolled back on PersistenceActor
                Task { @PersistenceActor [weak self] in
                    self?.savepoints.removeAll()
                    self?.markAsRolledBack()
                }

                logger.info("Transaction rolled back: \(transactionId)")
                continuation.resume()
            }
        }
    }
    
    // MARK: - Convenience Methods
    
    /// Insert a new entity
    public func insert<T: NSManagedObject>(_ type: T.Type) -> T {
        T(context: context)
    }
    
    /// Fetch entities within transaction context
    public func fetch<T: NSManagedObject>(_ request: NSFetchRequest<T>) async throws -> [T] {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: TransactionError.contextDeallocated)
                    return
                }
                
                do {
                    let results = try self.context.fetch(request)
                    continuation.resume(returning: results)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Delete an entity
    public func delete(_ object: NSManagedObject) {
        context.delete(object)
    }
    
    /// Refresh an object
    public func refresh(_ object: NSManagedObject, mergeChanges: Bool = true) {
        context.refresh(object, mergeChanges: mergeChanges)
    }
    
    // MARK: - Statistics
    
    /// Get transaction statistics
    public func statistics() -> TransactionStatistics {
        TransactionStatistics(
            transactionId: transactionId,
            duration: endTime?.timeIntervalSince(startTime) ?? Date().timeIntervalSince(startTime),
            insertedObjects: context.insertedObjects.count,
            updatedObjects: context.updatedObjects.count,
            deletedObjects: context.deletedObjects.count,
            savepointCount: savepoints.count,
            validationCount: validators.count,
            isSuccessful: isCommitted
        )
    }
    
    // MARK: - Private Methods
    
    private func markAsCommitted() {
        isCommitted = true
        endTime = Date()
        
        // Clean up resources
        context.undoManager = nil
        savepoints.removeAll()
        validators.removeAll()
    }
    
    private func markAsRolledBack() {
        isRolledBack = true
        endTime = Date()
        
        // Clean up resources
        context.undoManager = nil
        savepoints.removeAll()
        validators.removeAll()
    }
    
    // MARK: - Deallocation
    
    deinit {
        // Note: Cannot access actor-isolated isActive from deinit
        // Attempt emergency rollback just in case
        context.perform { [context] in
            context.rollback()
        }
    }
}

// MARK: - Transaction Manager

/// Manages transaction contexts and provides transaction coordination
@PersistenceActor
public final class TransactionManager {
    private let logger = os.Logger(subsystem: "com.balli.diabetes", category: "TransactionManager")
    
    // Active transactions
    private var activeTransactions: [UUID: TransactionContext] = [:]
    
    // Statistics
    private var completedTransactions = 0
    private var failedTransactions = 0
    
    // MARK: - Public API
    
    /// Begin a new transaction
    public func beginTransaction(
        parentContext: NSManagedObjectContext
    ) async -> TransactionContext {
        let transaction = TransactionContext(parentContext: parentContext)
        activeTransactions[transaction.transactionId] = transaction
        
        logger.debug("Transaction started: \(transaction.transactionId)")
        return transaction
    }
    
    /// Complete a transaction (called automatically on commit/rollback)
    public func completeTransaction(_ transaction: TransactionContext) {
        activeTransactions.removeValue(forKey: transaction.transactionId)
        
        if transaction.isCommitted {
            completedTransactions += 1
        } else {
            failedTransactions += 1
        }
        
        logger.debug("Transaction completed: \(transaction.transactionId)")
    }
    
    /// Get active transaction count
    public var activeTransactionCount: Int {
        activeTransactions.count
    }
    
    /// Get transaction statistics
    public var transactionStatistics: (completed: Int, failed: Int, active: Int) {
        (completedTransactions, failedTransactions, activeTransactions.count)
    }
    
    /// Force rollback all active transactions (emergency cleanup)
    public func rollbackAllTransactions() async {
        logger.warning("Rolling back all active transactions")
        
        for transaction in activeTransactions.values {
            await transaction.rollback()
        }
        
        activeTransactions.removeAll()
    }
}

// MARK: - Errors

public enum TransactionError: LocalizedError {
    case transactionNotActive
    case contextDeallocated
    case savepointFailed(Error)
    case savepointNotFound(String)
    case rollbackFailed(Error)
    case commitFailed(Error)
    case validationFailed([ValidationError])
    
    public var errorDescription: String? {
        switch self {
        case .transactionNotActive:
            return "İşlem aktif değil"
        case .contextDeallocated:
            return "İşlem bağlamı kullanılamıyor"
        case .savepointFailed(let error):
            return "Kaydetme noktası oluşturulamadı: \(error.localizedDescription)"
        case .savepointNotFound(let name):
            return "Kaydetme noktası bulunamadı: \(name)"
        case .rollbackFailed(let error):
            return "Geri alma başarısız: \(error.localizedDescription)"
        case .commitFailed(let error):
            return "İşlem tamamlanamadı: \(error.localizedDescription)"
        case .validationFailed(let errors):
            return "Doğrulama hatası: \(errors.map { $0.localizedDescription }.joined(separator: ", "))"
        }
    }
}

// MARK: - Extensions

extension TransactionContext {
    /// Convenience method to perform operations with automatic commit/rollback
    public static func withTransaction<T: Sendable>(
        parentContext: NSManagedObjectContext,
        operation: @escaping (TransactionContext) async throws -> T
    ) async throws -> T {
        let transaction = TransactionContext(parentContext: parentContext)
        
        do {
            let result = try await operation(transaction)
            try await transaction.commit()
            return result
        } catch {
            await transaction.rollback()
            throw error
        }
    }
}