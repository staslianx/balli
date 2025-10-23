//
//  EnhancedPersistenceController.swift
//  balli
//
//  Enhanced persistence controller that coordinates specialized persistence components
//  with Swift 6 actor-based concurrency, caching, health monitoring, and performance optimization
//

@preconcurrency import CoreData
import SwiftUI
import os.log
import Combine

/// Enhanced persistence controller that delegates to specialized components for comprehensive data management
@MainActor
public final class EnhancedPersistenceController: ObservableObject {
    
    // MARK: - Singleton
    public static let shared = EnhancedPersistenceController()
    
    // MARK: - Core Component
    private let core: EnhancedPersistenceCore
    
    // MARK: - SwiftUI Published Properties (delegated from core)
    @Published public private(set) var isPerformingBackgroundWork = false
    @Published public private(set) var lastSyncDate: Date?
    @Published public private(set) var dataHealth: DataHealth = DataHealth()
    @Published public private(set) var cacheStatistics = CacheStatistics()
    
    // MARK: - Configuration
    private let configuration: PersistenceConfiguration
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    internal init(configuration: PersistenceConfiguration = .default) {
        self.configuration = configuration
        self.core = EnhancedPersistenceCore(configuration: configuration)
        
        // Bind core's published properties to our published properties
        setupPropertyBinding()
    }
    
    /// Setup property binding from core to this controller's published properties
    private func setupPropertyBinding() {
        core.$isPerformingBackgroundWork
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in
                self?.isPerformingBackgroundWork = value
            }
            .store(in: &cancellables)
        
        core.$lastSyncDate
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in
                self?.lastSyncDate = value
            }
            .store(in: &cancellables)
        
        core.$dataHealth
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in
                self?.dataHealth = value
            }
            .store(in: &cancellables)
        
        core.$cacheStatistics
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in
                self?.cacheStatistics = value
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Core Data Stack Access (delegated to core)
    
    /// View context for SwiftUI integration
    nonisolated public var viewContext: NSManagedObjectContext {
        core.viewContext
    }
    
    /// Core Data container access
    public var container: NSPersistentContainer {
        core.container
    }
    
    // MARK: - Fetch Operations (delegated to core)
    
    nonisolated public func fetch<T: NSManagedObject>(
        _ request: NSFetchRequest<T>,
        cachePolicy: CachePolicy = .useCache
    ) async throws -> [T] {
        return try await core.fetch(request, cachePolicy: cachePolicy)
    }
    
    nonisolated public func fetchOne<T: NSManagedObject>(
        _ type: T.Type,
        predicate: NSPredicate,
        cachePolicy: CachePolicy = .useCache
    ) async throws -> T? {
        return try await core.fetchOne(type, predicate: predicate, cachePolicy: cachePolicy)
    }
    
    // MARK: - Save Operations (delegated to core)
    
    @MainActor
    public func save() async throws {
        try await core.save()
    }
    
    // MARK: - Background Operations (delegated to core)
    
    nonisolated public func performBackgroundTask<T: Sendable>(
        _ block: @escaping @Sendable (NSManagedObjectContext) async throws -> T
    ) async throws -> T {
        return try await core.performBackgroundTask(block)
    }
    
    // MARK: - Batch Operations (delegated to core)

    nonisolated public func batchDelete<T: NSManagedObject>(
        _ type: T.Type,
        predicateConfig: PredicateConfiguration
    ) async throws -> BatchOperationResult {
        return try await core.batchDelete(type, predicateConfig: predicateConfig)
    }
    
    // MARK: - Transaction Support (delegated to core)
    
    nonisolated public func performTransaction<T: Sendable>(
        _ block: @escaping @Sendable (TransactionContext) async throws -> T
    ) async throws -> T {
        return try await core.performTransaction(block)
    }
    
    // MARK: - Health and Monitoring (delegated to core)
    
    nonisolated public func getDataHealth() async -> DataHealth {
        return await core.getDataHealth()
    }
    
    nonisolated public func getCacheStatistics() async -> CacheStatistics {
        return await core.getCacheStatistics()
    }
    
    // MARK: - Maintenance (delegated to core)
    
    public func performMaintenance() async throws {
        try await core.performMaintenance()
    }
}