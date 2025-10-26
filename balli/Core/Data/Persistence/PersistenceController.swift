//
//  PersistenceController.swift
//  balli
//
//  Main persistence controller coordinating all components
//

@preconcurrency import CoreData
import OSLog

// Define within the Persistence namespace for organization
public enum Persistence {}

extension Persistence {
/// Refactored persistence controller that coordinates between specialized components
public final class PersistenceController: @unchecked Sendable {

    // MARK: - Constants

    private enum Constants {
        static let backgroundOperationTimeoutNanoseconds: UInt64 = 5_000_000_000  // 5 seconds
        static let backgroundCheckIntervalNanoseconds: UInt64 = 100_000_000       // 0.1 seconds
    }

    // MARK: - Singleton

    public static let shared = PersistenceController()

    // MARK: - Properties

    private let logger = AppLoggers.Data.coredata
    private let coreDataStack: CoreDataStack
    private var migrationManager: MigrationManager!
    private var monitor: PersistenceMonitor!
    private let isReadyStorage = AtomicBool(false)
    private let errorHandler = PersistenceErrorHandler()
    
    public var viewContext: NSManagedObjectContext {
        coreDataStack.viewContext
    }
    
    public var container: NSPersistentContainer {
        coreDataStack.container
    }
    
    /// Indicates if Core Data stores are loaded and ready
    public var isReady: Bool {
        get async {
            return await isReadyStorage.value
        }
    }
    
    // State tracking
    private var saveTask: Task<Void, Never>?
    private var isPerformingBackgroundWork = false
    
    // MARK: - Initialization

    /// Initializes PersistenceController
    /// - Parameters:
    ///   - inMemory: If true, uses in-memory store (for testing)
    ///   - waitForReady: If true, blocks until Core Data is ready (for testing only)
    public init(inMemory: Bool = false, waitForReady: Bool = false) {
        // Initialize components
        self.coreDataStack = CoreDataStack(inMemory: inMemory)

        if waitForReady {
            // Synchronous initialization for testing
            // This blocks until Core Data is fully ready
            let semaphore = DispatchSemaphore(value: 0)

            Task { [weak self] in
                guard let self = self else {
                    semaphore.signal()
                    return
                }

                do {
                    try await self.performInitialization()
                    semaphore.signal()
                } catch {
                    self.logger.critical("Failed to load Core Data stores: \(error)")
                    semaphore.signal()
                    #if DEBUG
                    fatalError("Core Data failed to load: \(error)")
                    #endif
                }
            }

            // Wait for initialization to complete
            semaphore.wait()
        } else {
            // Defer store loading to avoid blocking init
            Task { [weak self] in
                guard let self = self else { return }

                do {
                    try await self.performInitialization()
                } catch {
                    self.logger.critical("Failed to load Core Data stores: \(error)")
                    #if DEBUG
                    fatalError("Core Data failed to load: \(error)")
                    #endif
                }
            }
        }
    }

    /// Performs the actual initialization steps
    private func performInitialization() async throws {
        // Load stores asynchronously
        try await self.coreDataStack.loadStores()

        // Configure contexts after stores are loaded
        self.coreDataStack.configureContexts()

        // Initialize migration manager and monitor
        let container = self.coreDataStack.container

        await Task { @PersistenceActor in
            self.migrationManager = MigrationManager(container: container)
            self.monitor = PersistenceMonitor(container: container)
        }.value

        // Setup notifications
        await MainActor.run {
            self.setupNotifications()
        }

        // Mark as ready
        await self.isReadyStorage.setValue(true)

        self.logger.info("Core Data initialization completed")

        // Post notification that Core Data is ready (on main thread for UI safety)
        await MainActor.run {
            NotificationCenter.default.post(
                name: .coreDataReady,
                object: nil
            )
        }
    }
    
    // MARK: - Notification Handling
    
    private func setupNotifications() {
        coreDataStack.setupNotifications(
            remoteChangeHandler: { [weak self] notification in
                Task {
                    await self?.processRemoteChanges()
                }
            },
            backgroundSaveHandler: { [weak self] notification in
                guard let self = self else { return }
                // Merge changes immediately
                // Note: Notification is not Sendable but safe here because it's used immediately
                nonisolated(unsafe) let capturedNotification = notification
                self.viewContext.perform {
                    // Merge directly from notification within perform block
                    self.viewContext.mergeChanges(fromContextDidSave: capturedNotification)
                }
            }
        )
    }
    
    private func processRemoteChanges() async {
        logger.debug("Processing remote changes")
        await MainActor.run {
            viewContext.refreshAllObjects()
        }
    }
    
    // MARK: - Public API
    
    public func fetch<T: NSManagedObject>(_ request: NSFetchRequest<T>) async throws -> [T] {
        // Ensure Core Data is ready before fetching
        guard await isReady else {
            logger.warning("Fetch attempted before Core Data is ready")
            throw CoreDataError.contextUnavailable
        }
        
        request.returnsObjectsAsFaults = false
        request.includesPropertyValues = true
        
        // CRITICAL FIX: Use background context for async operations to prevent threading crashes
        // This prevents EXC_BAD_ACCESS when called from background threads (e.g., after AI API)
        return try await performBackgroundTask { context in
            // Execute fetch in the background context
            let results = try context.fetch(request)
            
            // Convert to object IDs for thread safety
            let objectIDs = results.map { $0.objectID }
            
            // Return the objects by fetching them in the background context
            // This ensures they're properly registered with the context
            return objectIDs.compactMap { context.object(with: $0) as? T }
        }
    }
    
    public func save() async throws {
        logger.debug("Saving context")

        saveTask?.cancel()

        // Check if there are changes to save
        guard viewContext.hasChanges else {
            logger.debug("No changes to save")
            return
        }

        // Use error handler with automatic retry and notification
        do {
            try await errorHandler.saveWithRetry(context: viewContext)
            await logOperation("Save context", success: true)
            logger.info("Context saved successfully")
        } catch {
            await logOperation("Save context", success: false)
            logger.error("Failed to save context after retries: \(error.localizedDescription)")
            throw error
        }
    }
    
    public func performBackgroundTask<T>(
        _ block: @escaping @Sendable (NSManagedObjectContext) async throws -> T
    ) async throws -> T where T: Sendable {
        // Ensure Core Data is ready
        guard await isReady else {
            logger.warning("Background task attempted before Core Data is ready")
            throw CoreDataError.contextUnavailable
        }
        
        isPerformingBackgroundWork = true
        defer { isPerformingBackgroundWork = false }
        
        logger.debug("Starting background task")
        
        let taskContext = coreDataStack.createBackgroundContext()
        
        guard let coordinator = taskContext.persistentStoreCoordinator,
              !coordinator.persistentStores.isEmpty else {
            logger.error("Background context not ready")
            throw CoreDataError.contextUnavailable
        }
        
        // Execute block with proper async handling
        return try await withCheckedThrowingContinuation { continuation in
            // Run the async block in a detached task to avoid capturing actor context
            Task.detached {
                do {
                    let result = try await block(taskContext)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Batch Operations
    
    public func batchDelete<T: NSManagedObject>(
        _ type: T.Type,
        predicate: NSPredicate? = nil
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
                into: [self.viewContext]
            )
            
            await self.logOperation("Batch delete \(type)", success: true)
            
            return count
        }
    }
    
    // MARK: - State Management
    
    public func prepareForBackground() async {
        logger.info("Preparing for background")
        
        if viewContext.hasChanges {
            try? await save()
        }
        
        if isPerformingBackgroundWork {
            await waitForBackgroundOperations()
        }
        
        viewContext.refreshAllObjects()
    }
    
    public func handleMemoryPressure() async {
        await Task { @PersistenceActor in
            await self.monitor.handleMemoryPressure()
        }.value
        
        viewContext.refreshAllObjects()
    }
    
    // MARK: - Health Monitoring
    
    public func checkHealth() async -> DataHealth {
        await Task { @PersistenceActor in
            await self.monitor.checkHealth()
        }.value
    }
    
    public func getMetrics() async -> HealthMetrics {
        await Task { @PersistenceActor in
            await self.monitor.getMetrics()
        }.value
    }
    
    // MARK: - Migration
    
    public func checkMigrationNeeded() async throws -> Bool {
        try await Task { @PersistenceActor in
            try await self.migrationManager.checkMigrationNeeded()
        }.value
    }
    
    public func migrateStoreIfNeeded() async throws {
        try await Task { @PersistenceActor in
            try await self.migrationManager.migrateStoreIfNeeded()
        }.value
    }
    
    // MARK: - Private Helpers
    
    private func saveContext(_ context: NSManagedObjectContext) async throws {
        guard context.hasChanges else {
            logger.debug("No changes to save")
            return
        }
        
        try await context.performAsync {
            try context.save()
        }
    }
    
    /// Safe method to create a background context for async operations
    /// Use this when you need to ensure thread safety in Core Data operations
    public func createSafeContext() -> NSManagedObjectContext {
        // Always create a new background context for safety in async operations
        return coreDataStack.createBackgroundContext()
    }
    
    private func waitForBackgroundOperations() async {
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
    
    private func logOperation(_ operation: String, success: Bool) async {
        await Task { @PersistenceActor in
            self.monitor.logOperation(operation, success: success)
        }.value
    }
}
}

// MARK: - Notification Names

extension Notification.Name {
    static let coreDataReady = Notification.Name("coreDataReady")
}

// MARK: - Thread-Safe Atomic Boolean

/// Swift 6 actor-based atomic boolean for thread-safe access
private actor AtomicBool {
    private var _value: Bool

    init(_ value: Bool) {
        self._value = value
    }

    var value: Bool {
        get {
            return _value
        }
    }

    func setValue(_ newValue: Bool) {
        _value = newValue
    }
}