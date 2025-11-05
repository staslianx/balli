//
//  PersistenceOperations.swift
//  balli
//
//  Handles background task execution and batch operations for persistence
//  Extracted from PersistenceController for single responsibility
//

@preconcurrency import CoreData
import OSLog

/// Handles background task execution and batch operations
final class PersistenceOperations: @unchecked Sendable {
    private let logger = AppLoggers.Data.coredata
    private let coreDataStack: CoreDataStack
    private var isPerformingBackgroundWork = false

    private enum Constants {
        static let backgroundOperationTimeoutNanoseconds: UInt64 = 5_000_000_000  // 5 seconds
        static let backgroundCheckIntervalNanoseconds: UInt64 = 100_000_000       // 0.1 seconds
    }

    init(coreDataStack: CoreDataStack) {
        self.coreDataStack = coreDataStack
    }

    // MARK: - Background Task Execution

    func performBackgroundTask<T>(
        _ block: @escaping @Sendable (NSManagedObjectContext) async throws -> T
    ) async throws -> T where T: Sendable {
        isPerformingBackgroundWork = true
        defer { isPerformingBackgroundWork = false }

        logger.debug("Starting background task")

        let taskContext = coreDataStack.createBackgroundContext()

        guard let coordinator = taskContext.persistentStoreCoordinator,
              !coordinator.persistentStores.isEmpty else {
            logger.error("Background context not ready")
            throw CoreDataError.contextUnavailable
        }

        // Get viewContext for merging changes on main thread
        let viewContext = coreDataStack.viewContext

        // Execute block with proper async handling
        return try await withCheckedThrowingContinuation { continuation in
            // Run the async block in a detached task to avoid capturing actor context
            Task.detached {
                do {
                    let result = try await block(taskContext)

                    // CRITICAL FIX: Merge changes to viewContext on main thread
                    // This prevents "Publishing changes from background threads" warnings
                    if taskContext.hasChanges {
                        await MainActor.run {
                            viewContext.refreshAllObjects()
                        }
                    }

                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Batch Operations

    func batchDelete<T: NSManagedObject>(
        _ type: T.Type,
        predicate: NSPredicate? = nil,
        viewContext: NSManagedObjectContext,
        onLogOperation: @escaping @Sendable (String, Bool) async -> Void
    ) async throws -> Int {
        logger.info("Performing batch delete for \(String(describing: type))")

        // Create a sendable representation of the predicate
        let predicateFormat = predicate?.predicateFormat
        return try await performBackgroundTask { context in
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: String(describing: type))
            if let format = predicateFormat {
                fetchRequest.predicate = NSPredicate(format: format)
            }

            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            deleteRequest.resultType = .resultTypeCount

            let result = try context.execute(deleteRequest) as? NSBatchDeleteResult
            let count = result?.result as? Int ?? 0

            // Merge changes
            let changes: [AnyHashable: Any] = [
                NSDeletedObjectsKey: [result?.result ?? NSManagedObjectID()]
            ]
            NSManagedObjectContext.mergeChanges(
                fromRemoteContextSave: changes,
                into: [viewContext]
            )

            await onLogOperation("Batch delete \(type)", true)

            return count
        }
    }

    // MARK: - Background Work State

    func waitForBackgroundOperations() async {
        let timeout = Task {
            try? await Task.sleep(nanoseconds: Constants.backgroundOperationTimeoutNanoseconds)
            return false
        }

        let completed = Task {
            while self.isPerformingBackgroundWork {
                try? await Task.sleep(nanoseconds: Constants.backgroundCheckIntervalNanoseconds)
            }
            return true
        }

        let result = await withTaskGroup(of: Bool.self) { group in
            group.addTask { await timeout.value }
            group.addTask { await completed.value }

            if let firstResult = await group.next() {
                group.cancelAll()
                return firstResult
            }
            return false
        }

        if !result {
            logger.warning("Background operations timed out")
        }
    }

    var isBackgroundWorkInProgress: Bool {
        isPerformingBackgroundWork
    }
}
