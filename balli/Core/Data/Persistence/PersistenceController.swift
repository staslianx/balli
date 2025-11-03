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

    // MARK: - Singleton

    public static let shared = PersistenceController()

    // MARK: - Properties

    private let logger = AppLoggers.Data.coredata
    private let coreDataStack: CoreDataStack
    private var migrationManager: MigrationManager!
    private var monitor: PersistenceMonitor!
    private var operations: PersistenceOperations!
    private var lifecycleManager: PersistenceLifecycleManager!
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

        // Initialize operations first (no dependencies)
        self.operations = PersistenceOperations(coreDataStack: self.coreDataStack)

        // Initialize migration manager and monitor
        let container = self.coreDataStack.container

        await Task { @PersistenceActor in
            self.migrationManager = MigrationManager(container: container)
            self.monitor = PersistenceMonitor(container: container)
        }.value

        // Initialize lifecycle manager (depends on monitor)
        self.lifecycleManager = PersistenceLifecycleManager(
            coreDataStack: self.coreDataStack,
            monitor: self.monitor,
            errorHandler: self.errorHandler
        )

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
        lifecycleManager.setupNotifications(
            onRemoteChange: { [weak self] in
                await self?.processRemoteChanges()
            },
            viewContext: viewContext
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

        // CRITICAL FIX: Fetch in background context but return objects faulted into viewContext
        // This prevents EXC_BAD_ACCESS when objects are accessed after the background context is deallocated
        let objectIDs = try await performBackgroundTask { context in
            // Execute fetch in the background context
            let results = try context.fetch(request)

            // Extract object IDs for thread-safe transfer
            return results.map { $0.objectID }
        }

        // Fault objects into viewContext on main thread so they remain valid
        return await MainActor.run {
            return objectIDs.compactMap { objectID in
                // Get object in viewContext - this ensures objects remain valid
                viewContext.object(with: objectID) as? T
            }
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

        return try await operations.performBackgroundTask(block)
    }
    
    // MARK: - Batch Operations

    public func batchDelete<T: NSManagedObject>(
        _ type: T.Type,
        predicate: NSPredicate? = nil
    ) async throws -> Int {
        return try await operations.batchDelete(
            type,
            predicate: predicate,
            viewContext: viewContext,
            onLogOperation: { [weak self] operation, success in
                await self?.logOperation(operation, success: success)
            }
        )
    }
    
    // MARK: - State Management

    public func prepareForBackground() async {
        await lifecycleManager.prepareForBackground(
            viewContext: viewContext,
            isBackgroundWorkInProgress: operations.isBackgroundWorkInProgress,
            onSave: { [weak self] in
                try await self?.save()
            },
            onWaitForBackgroundOperations: { [weak self] in
                await self?.operations.waitForBackgroundOperations()
            }
        )
    }
    
    public func handleMemoryPressure() async {
        guard await isReady else {
            logger.warning("handleMemoryPressure called before Core Data ready")
            return
        }

        await Task { @PersistenceActor in
            await self.lifecycleManager.handleMemoryPressure(viewContext: self.viewContext)
        }.value
    }
    
    // MARK: - Health Monitoring
    
    public func checkHealth() async -> DataHealth {
        guard await isReady else {
            logger.warning("checkHealth called before Core Data ready")
            return DataHealth(isHealthy: false)
        }

        return await Task { @PersistenceActor in
            await self.monitor.checkHealth()
        }.value
    }
    
    public func getMetrics() async -> HealthMetrics {
        guard await isReady else {
            logger.warning("getMetrics called before Core Data ready")
            return HealthMetrics()
        }

        return await Task { @PersistenceActor in
            await self.monitor.getMetrics()
        }.value
    }
    
    // MARK: - Migration
    
    public func checkMigrationNeeded() async throws -> Bool {
        guard await isReady else {
            logger.warning("checkMigrationNeeded called before Core Data ready")
            throw CoreDataError.contextUnavailable
        }

        return try await Task { @PersistenceActor in
            try await self.migrationManager.checkMigrationNeeded()
        }.value
    }
    
    public func migrateStoreIfNeeded() async throws {
        guard await isReady else {
            logger.warning("migrateStoreIfNeeded called before Core Data ready")
            throw CoreDataError.contextUnavailable
        }

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