//
//  EnhancedPersistenceCore.swift
//  balli
//
//  Core coordinator for enhanced persistence operations with SwiftUI integration
//

@preconcurrency import CoreData
import SwiftUI
import os.log
import Combine

/// Core persistence coordinator that manages all persistence components and SwiftUI integration
@MainActor
public final class EnhancedPersistenceCore: ObservableObject {
    private let logger = os.Logger(subsystem: "com.balli.diabetes", category: "EnhancedPersistenceCore")
    
    // MARK: - Core Data Stack
    public let container: NSPersistentContainer
    private let backgroundContext: NSManagedObjectContext
    
    // MARK: - Persistence Components
    private let cacheManager: PersistenceCacheManager
    private let healthMonitor: PersistenceHealthMonitor
    private let transactionManager: PersistenceTransactionManager
    
    // MARK: - SwiftUI Published Properties
    @Published public private(set) var isPerformingBackgroundWork = false
    @Published public private(set) var lastSyncDate: Date?
    @Published public private(set) var dataHealth: DataHealth = DataHealth()
    @Published public private(set) var cacheStatistics = CacheStatistics()

    /// Critical error encountered during initialization (if any)
    @Published public private(set) var catastrophicError: Error?

    /// Whether Core Data is ready for operations
    public var isReady: Bool {
        catastrophicError == nil
    }
    
    // MARK: - Operation Queues
    private let saveQueue: OperationQueue
    private let fetchQueue: OperationQueue
    
    // MARK: - Configuration
    private let configuration: PersistenceConfiguration
    
    // MARK: - Health Check Timer
    // Swift 6: nonisolated(unsafe) allows access from deinit for cleanup
    // Safe because: Timer is private, only accessed from MainActor methods and deinit
    nonisolated(unsafe) private var healthCheckTimer: Timer?
    
    // MARK: - Initialization
    
    public init(configuration: PersistenceConfiguration = .default) {
        self.configuration = configuration
        
        // Initialize Core Data container
        container = NSPersistentContainer(name: configuration.modelName)
        
        // Initialize components
        let cacheConfig = CacheConfiguration(
            queryCacheSize: configuration.queryCacheSize,
            entityCacheSize: configuration.entityCacheSize
        )
        
        self.cacheManager = PersistenceCacheManager(configuration: cacheConfig)
        self.healthMonitor = PersistenceHealthMonitor()
        self.transactionManager = PersistenceTransactionManager(persistentContainer: container)
        
        // Configure operation queues
        saveQueue = OperationQueue()
        saveQueue.maxConcurrentOperationCount = 1
        saveQueue.qualityOfService = .userInitiated
        saveQueue.name = "com.balli.persistence.save"
        
        fetchQueue = OperationQueue()
        fetchQueue.maxConcurrentOperationCount = 3
        fetchQueue.qualityOfService = .userInitiated
        fetchQueue.name = "com.balli.persistence.fetch"
        
        // Create background context
        backgroundContext = container.newBackgroundContext()
        backgroundContext.mergePolicy = getSafeMergePolicy()
        backgroundContext.undoManager = nil
        backgroundContext.name = "BackgroundContext"
        
        // Setup container and contexts
        configureContainer()
        loadPersistentStores()
        configureContexts()
        
        // Setup monitoring
        Task {
            await setupMonitoring()
        }
    }
    
    // MARK: - Core Data Stack Setup
    
    private func configureContainer() {
        guard let description = container.persistentStoreDescriptions.first else { return }
        
        if configuration.inMemory {
            description.url = URL(fileURLWithPath: "/dev/null")
        }
        
        // Enable persistent history tracking
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        
        // Performance optimizations
        description.setOption(true as NSNumber, forKey: NSSQLiteManualVacuumOption)
        description.setOption(true as NSNumber, forKey: NSSQLiteAnalyzeOption)
        
        // Security
        description.setOption(FileProtectionType.complete as NSObject, forKey: NSPersistentStoreFileProtectionKey)
        
        // Migration
        description.shouldMigrateStoreAutomatically = configuration.enableAutomaticMigration
        description.shouldInferMappingModelAutomatically = configuration.enableInferredMigration
    }
    
    private func loadPersistentStores() {
        container.loadPersistentStores { [weak self] description, error in
            if let error = error {
                self?.logger.critical("Core Data failed to load: \(error)")
                Task { @MainActor in
                    await self?.handleCatastrophicError(error)
                }
            } else {
                self?.logger.info("Core Data loaded successfully: \(description)")
                Task { @MainActor in
                    await self?.onStoreLoaded()
                }
            }
        }
    }
    
    private func configureContexts() {
        // View context configuration
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = getSafeMergePolicy()
        container.viewContext.shouldDeleteInaccessibleFaults = true
        container.viewContext.undoManager = nil
        container.viewContext.name = "ViewContext"
    }
    
    // MARK: - Public Interface
    
    /// View context for SwiftUI integration
    nonisolated public var viewContext: NSManagedObjectContext {
        container.viewContext
    }
    
    /// Fetch entities with caching support
    nonisolated public func fetch<T: NSManagedObject>(
        _ request: NSFetchRequest<T>,
        cachePolicy: CachePolicy = .useCache
    ) async throws -> [T] {
        let startTime = Date()
        
        // Check cache first if applicable
        if cachePolicy.shouldCheckCache {
            if let cached = await cacheManager.getCachedResults(for: request) {
                await healthMonitor.recordFetchOperation(
                    duration: Date().timeIntervalSince(startTime),
                    resultCount: cached.count,
                    fromCache: true,
                    success: true
                )
                await updateCacheStatistics()
                return cached
            }
        }
        
        // Perform fetch operation
        let results: [T] = try await withCheckedThrowingContinuation { continuation in
            fetchQueue.addOperation { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: PersistenceError.controllerDeallocated)
                    return
                }
                
                self.container.viewContext.perform {
                    do {
                        let results = try self.container.viewContext.fetch(request)
                        continuation.resume(returning: results)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
        
        // Update cache if needed
        if cachePolicy.shouldUpdateCache {
            await cacheManager.cacheResults(results, for: request)
        }
        
        // Record performance metrics
        await healthMonitor.recordFetchOperation(
            duration: Date().timeIntervalSince(startTime),
            resultCount: results.count,
            fromCache: false,
            success: true
        )
        
        await updateCacheStatistics()
        return results
    }
    
    /// Fetch single entity with caching support
    nonisolated public func fetchOne<T: NSManagedObject>(
        _ type: T.Type,
        predicate: NSPredicate,
        cachePolicy: CachePolicy = .useCache
    ) async throws -> T? {
        // Safely cast fetch request to the expected type
        guard let request = T.fetchRequest() as? NSFetchRequest<T> else {
            logger.error("Failed to cast fetch request for type \(String(describing: type))")
            throw PersistenceError.invalidRequest("Unable to create fetch request for \(String(describing: type))")
        }
        request.predicate = predicate
        request.fetchLimit = 1

        let results = try await fetch(request, cachePolicy: cachePolicy)
        return results.first
    }
    
    /// Save changes to view context
    @MainActor
    public func save() async throws {
        guard container.viewContext.hasChanges else {
            logger.debug("No changes to save")
            return
        }
        
        let startTime = Date()
        let objectCount = container.viewContext.insertedObjects.count + 
                         container.viewContext.updatedObjects.count +
                         container.viewContext.deletedObjects.count
        
        try await withCheckedThrowingContinuation { continuation in
            container.viewContext.perform { [weak self] in
                do {
                    try self?.container.viewContext.save()
                    self?.logger.info("View context saved successfully")
                    continuation.resume()
                } catch {
                    self?.logger.error("Failed to save: \(error)")
                    continuation.resume(throwing: PersistenceError.saveFailed(error))
                }
            }
        }
        
        // Record performance metrics
        let duration = Date().timeIntervalSince(startTime)
        await healthMonitor.recordSaveOperation(duration: duration, objectCount: objectCount, success: true)
        
        // Invalidate affected caches
        await cacheManager.invalidateAllCaches()
    }
    
    /// Perform background task with proper isolation
    nonisolated public func performBackgroundTask<T: Sendable>(
        _ block: @escaping @Sendable (NSManagedObjectContext) async throws -> T
    ) async throws -> T {
        await MainActor.run {
            self.isPerformingBackgroundWork = true
        }
        defer {
            Task { @MainActor in
                self.isPerformingBackgroundWork = false
            }
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            Task { @MainActor in
                self.backgroundContext.perform { [weak self] in
                    Task {
                        do {
                            guard let context = self?.backgroundContext else {
                                continuation.resume(throwing: PersistenceError.controllerDeallocated)
                                return
                            }
                            let result = try await block(context)
                            continuation.resume(returning: result)
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    }
                }
            }
        }
    }
    
    /// Execute transaction with automatic rollback
    nonisolated public func performTransaction<T: Sendable>(
        _ block: @escaping @Sendable (TransactionContext) async throws -> T
    ) async throws -> T {
        return try await transactionManager.executeTransaction { transaction in
            // Transaction already has the correct parent context from initialization
            
            let result = try await block(transaction)
            
            // Invalidate caches after successful transaction
            await self.cacheManager.invalidateAllCaches()
            
            return result
        }
    }
    
    // MARK: - Batch Operations
    
    /// Perform batch delete operation
    nonisolated public func batchDelete<T: NSManagedObject>(
        _ type: T.Type,
        predicateConfig: PredicateConfiguration
    ) async throws -> BatchOperationResult {
        logger.info("Performing batch delete for \(String(describing: type))")

        let result = try await transactionManager.executeBatchDelete(
            type,
            predicateConfig: predicateConfig,
            container: container
        )

        // Invalidate caches after batch operation
        await cacheManager.invalidateAllCaches()

        return result
    }
    
    // MARK: - Health and Monitoring
    
    /// Get current data health status
    nonisolated public func getDataHealth() async -> DataHealth {
        return await healthMonitor.getCurrentHealth()
    }
    
    /// Get cache statistics
    nonisolated public func getCacheStatistics() async -> CacheStatistics {
        return await cacheManager.getCurrentStatistics()
    }
    
    /// Perform database maintenance
    public func performMaintenance() async throws {
        logger.info("Starting database maintenance")
        
        try await performBackgroundTask { context in
            context.reset()
        }
        
        // Perform cache maintenance
        await cacheManager.performMaintenance()
        
        // Perform health monitoring maintenance
        try await healthMonitor.performAutoMaintenance(container: container)
        
        logger.info("Database maintenance completed")
    }
    
    // MARK: - Private Methods
    
    private func setupMonitoring() async {
        // Setup change notifications
        setupChangeNotifications()

        // Start health monitoring
        await healthMonitor.startMonitoring(container: container)

        // PERFORMANCE FIX: Removed periodic health check timer - this was a battery killer
        // that ran every 5 minutes forever. For a personal app with 2 users, this is overkill.
        // Health checks can be triggered manually if needed via performHealthCheck() or getDataHealth()

        // Initial health check only (no repeating timer)
        await performHealthCheck()
    }
    
    private func setupChangeNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePersistentStoreRemoteChange),
            name: .NSPersistentStoreRemoteChange,
            object: container.persistentStoreCoordinator
        )
    }
    
    @objc private func handlePersistentStoreRemoteChange(_ notification: Notification) {
        logger.debug("Remote store change detected")
        
        Task { @MainActor in
            await processRemoteChanges()
        }
    }
    
    private func processRemoteChanges() async {
        // Refresh view context
        container.viewContext.performAndWait {
            container.viewContext.refreshAllObjects()
        }
        
        // Clear caches as data may have changed
        await cacheManager.invalidateAllCaches()
        
        lastSyncDate = Date()
    }
    
    private func performHealthCheck() async {
        let health = await healthMonitor.performHealthCheck(container: container)
        dataHealth = health
        
        if health.hasIssues {
            logger.warning("Data health issues detected: \(health.issues)")
        }
    }
    
    private func updateCacheStatistics() async {
        cacheStatistics = await cacheManager.getCurrentStatistics()
    }
    
    private func onStoreLoaded() async {
        logger.info("Store loaded, performing initial setup")
        
        // Check if migration is needed
        if configuration.checkMigrationOnLoad {
            try? await migrateIfNeeded()
        }
        
        // Warm up caches with frequently accessed data
        await warmupCaches()
    }
    
    private func warmupCaches() async {
        logger.debug("Warming up caches")
        
        // Pre-fetch frequently accessed data
        let request = FoodItem.fetchRequest()
        request.predicate = NSPredicate(format: "isFavorite == YES")
        request.fetchLimit = 20
        
        _ = try? await fetch(request, cachePolicy: .reloadAndCache)
    }
    
    private func migrateIfNeeded() async throws {
        // Migration logic would go here
        logger.info("Checking for migrations")
    }
    
    private func handleCatastrophicError(_ error: Error) async {
        logger.critical("Catastrophic error: \(error)")

        // Store error for UI to display recovery options
        await MainActor.run {
            self.catastrophicError = error
        }

        #if DEBUG
        fatalError("Core Data failed: \(error)")
        #else
        // In production, log the error and allow the app to continue
        // UI can show recovery options based on catastrophicError property
        logger.error("App will continue with limited functionality")
        #endif
    }

    // MARK: - Cleanup

    // Note: deinit cannot access Timer in Swift 6 strict concurrency
    // Timers are automatically invalidated when deallocated, so explicit cleanup is not needed
}

// MARK: - SwiftUI Integration

public struct EnhancedPersistenceProvider: ViewModifier {
    let core: EnhancedPersistenceCore
    
    public func body(content: Content) -> some View {
        content
            .environment(\.managedObjectContext, core.viewContext)
            .environmentObject(core)
    }
}

public extension View {
    func withEnhancedPersistence(_ core: EnhancedPersistenceCore = .shared) -> some View {
        modifier(EnhancedPersistenceProvider(core: core))
    }
}

// MARK: - Singleton Access

public extension EnhancedPersistenceCore {
    static let shared = EnhancedPersistenceCore()
}

// MARK: - Helper Functions

private func getSafeMergePolicy() -> NSMergePolicy {
    return NSMergePolicy.mergeByPropertyObjectTrump
}