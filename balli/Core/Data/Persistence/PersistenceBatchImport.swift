//
//  PersistenceBatchImport.swift
//  balli
//
//  Handles efficient batch import operations with progress tracking
//

import CoreData
import OSLog

/// Handles efficient batch import operations with progress tracking and memory optimization
@PersistenceActor
public final class PersistenceBatchImport {
    private let logger = AppLoggers.Data.coredata
    private let container: NSPersistentContainer
    
    public init(container: NSPersistentContainer) {
        self.container = container
    }
    
    // MARK: - Batch Import Types

    public struct ImportProgress: Sendable {
        public let totalItems: Int
        public let processedItems: Int
        public let failedItems: Int
        public var percentComplete: Double {
            guard totalItems > 0 else { return 0 }
            return Double(processedItems) / Double(totalItems)
        }
    }

    // Helper type for safely passing data arrays across Sendable boundaries
    private struct DataWrapper: @unchecked Sendable {
        let data: [[String: Any]]
    }
    
    // MARK: - Batch Import Operations
    
    /// Performs efficient batch import with progress tracking and memory optimization
    public func batchImport<T: NSManagedObject>(
        _ type: T.Type,
        data: [[String: Any]],
        updateHandler: @escaping @Sendable (T, [String: Any]) -> Void,
        progressHandler: (@Sendable (ImportProgress) -> Void)? = nil
    ) async throws {
        let totalItems = data.count

        logger.info("Starting batch import of \(totalItems) items")

        // Create a task context for batch processing
        let taskContext = container.newBackgroundContext()
        taskContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        taskContext.undoManager = nil
        taskContext.shouldDeleteInaccessibleFaults = true
        taskContext.automaticallyMergesChangesFromParent = true

        // Process in batches for memory efficiency
        let batchSize = 100

        // Wrap data in @unchecked Sendable wrapper
        let dataWrapper = DataWrapper(data: data)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            taskContext.perform {
                do {
                    var processedItems = 0
                    let failedItems = 0

                    for batchStart in stride(from: 0, to: dataWrapper.data.count, by: batchSize) {
                        let batchEnd = min(batchStart + batchSize, dataWrapper.data.count)
                        let batch = Array(dataWrapper.data[batchStart..<batchEnd])

                        try autoreleasepool {
                            for item in batch {
                                let object = T(context: taskContext)
                                updateHandler(object, item)
                                processedItems += 1
                            }

                            // Save periodically
                            if taskContext.hasChanges {
                                try taskContext.save()
                                self.logger.debug("Saved batch of \(batch.count) items")
                            }

                            // Report progress
                            let progress = ImportProgress(
                                totalItems: totalItems,
                                processedItems: processedItems,
                                failedItems: failedItems
                            )
                            progressHandler?(progress)
                        }
                    }

                    self.logger.info("Batch import completed: \(processedItems) successful, \(failedItems) failed")
                    continuation.resume()
                    
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Performs a background task with proper context management
    private func performBackgroundTask<T>(
        _ block: @escaping @Sendable (NSManagedObjectContext) async throws -> T
    ) async throws -> T where T: Sendable {
        logger.debug("Starting background import task")
        
        // Create a new background context for each task to avoid contention
        let taskContext = container.newBackgroundContext()
        taskContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        taskContext.undoManager = nil
        
        // Configure for batch processing
        taskContext.shouldDeleteInaccessibleFaults = true
        taskContext.automaticallyMergesChangesFromParent = true
        
        return try await block(taskContext)
    }
}