//
//  PersistenceProtocols.swift
//  balli
//
//  Protocol definitions for persistence components
//

import CoreData
import Foundation

// MARK: - Core Stack Protocol

/// Protocol for Core Data stack management
public protocol CoreDataStackProtocol: Sendable {
    var container: NSPersistentContainer { get }
    var viewContext: NSManagedObjectContext { get }
    
    func createBackgroundContext() -> NSManagedObjectContext
    func loadStores() async throws
    func configureContexts()
}

// MARK: - Migration Protocol

/// Protocol for migration operations
public protocol MigrationManagerProtocol: Sendable {
    func checkMigrationNeeded() async throws -> Bool
    func migrateStoreIfNeeded() async throws
    func recoverFromError(_ error: Error) async throws
    func configureStoreDescriptions(_ descriptions: [NSPersistentStoreDescription])
}

// MARK: - Monitoring Protocol

/// Protocol for persistence monitoring
public protocol PersistenceMonitorProtocol: Sendable {
    func logOperation(_ operation: String, success: Bool, duration: TimeInterval?)
    func checkHealth() async -> DataHealth
    func getMetrics() async -> HealthMetrics
    func handleMemoryPressure() async
}

// MARK: - Batch Operations Protocol

/// Protocol for batch operations
public protocol BatchOperationsProtocol: Sendable {
    func batchDelete<T: NSManagedObject>(
        _ type: T.Type,
        predicate: NSPredicate?
    ) async throws -> Int
    
    func batchImport<T: NSManagedObject>(
        _ type: T.Type,
        data: [[String: Any]],
        updateHandler: @escaping (T, [String: Any]) -> Void,
        progressHandler: ((ImportProgress) -> Void)?
    ) async throws
}

// MARK: - Context Operations Protocol

/// Protocol for context-specific operations
public protocol ContextOperationsProtocol {
    func fetch<T: NSManagedObject>(_ request: NSFetchRequest<T>) async throws -> [T]
    func save() async throws
    func performBackgroundTask<T: Sendable>(
        _ block: @escaping (NSManagedObjectContext) async throws -> T
    ) async throws -> T
}