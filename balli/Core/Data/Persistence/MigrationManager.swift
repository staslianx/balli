//
//  MigrationManager.swift
//  balli
//
//  Enhanced migration management for Core Data
//

import CoreData
import OSLog

/// Enhanced migration manager with versioning and strategy support
@PersistenceActor
public final class MigrationManager {

    // MARK: - Properties

    private let logger = AppLoggers.Data.migration
    private let container: NSPersistentContainer
    private var migrationStrategies: [String: MigrationStrategy] = [:]
    
    // MARK: - Types
    
    public struct MigrationStrategy {
        let fromVersion: String
        let toVersion: String
        let migrationBlock: (NSManagedObjectContext) async throws -> Void
    }
    
    // MARK: - Initialization
    
    public init(container: NSPersistentContainer) {
        self.container = container
        setupMigrationStrategies()
    }
    
    // MARK: - Migration Strategies
    
    private func setupMigrationStrategies() {
        // Register custom migration strategies here
        // Example:
        // migrationStrategies["v1_to_v2"] = MigrationStrategy(
        //     fromVersion: "1.0",
        //     toVersion: "2.0",
        //     migrationBlock: { context in
        //         // Custom migration logic
        //     }
        // )
    }
    
    // MARK: - Migration Check
    
    public func checkMigrationNeeded() async throws -> Bool {
        guard let storeURL = container.persistentStoreDescriptions.first?.url else {
            logger.debug("No store URL found, migration not needed")
            return false
        }

        do {
            let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
                type: .sqlite,
                at: storeURL
            )

            let isCompatible = container.managedObjectModel.isConfiguration(
                withName: nil,
                compatibleWithStoreMetadata: metadata
            )

            logger.info("Store compatibility: \(isCompatible ? "compatible" : "migration needed")")
            return !isCompatible

        } catch {
            logger.error("Failed to check store metadata: \(error.localizedDescription)")
            throw CoreDataError.migrationRequired
        }
    }
    
    // MARK: - Migration Execution
    
    public func migrateStoreIfNeeded() async throws {
        let needsMigration = try await checkMigrationNeeded()

        guard needsMigration else {
            logger.debug("No migration needed")
            return
        }

        logger.info("Starting store migration")

        // Check for custom migration
        if let customMigration = findApplicableMigration() {
            try await performCustomMigration(customMigration)
        } else {
            // Fall back to lightweight migration
            logger.info("Using lightweight migration")
            try await performLightweightMigration()
        }
    }
    
    // MARK: - Custom Migration
    
    private func findApplicableMigration() -> MigrationStrategy? {
        // In a real implementation, check current version and find matching strategy
        return nil
    }
    
    private func performCustomMigration(_ strategy: MigrationStrategy) async throws {
        logger.info("Performing custom migration from \(strategy.fromVersion) to \(strategy.toVersion)")

        let context = container.newBackgroundContext()
        try await strategy.migrationBlock(context)

        if context.hasChanges {
            try context.save()
        }

        logger.info("Custom migration completed successfully")
    }

    // MARK: - Lightweight Migration

    private func performLightweightMigration() async throws {
        // Lightweight migration is handled automatically by Core Data
        // This is a placeholder for any additional logic needed
        logger.info("Lightweight migration will be performed automatically")
    }
    
    // MARK: - Error Recovery
    
    public func recoverFromError(_ error: Error) async throws {
        logger.error("Attempting recovery from: \(error.localizedDescription)")

        let nsError = error as NSError

        switch nsError.code {
        case NSMigrationMissingMappingModelError:
            logger.error("Migration mapping model missing")
            throw CoreDataError.migrationRequired

        case NSPersistentStoreIncompatibleSchemaError:
            logger.error("Store schema incompatible")
            try await attemptSchemaRecovery()

        case NSPersistentStoreIncompleteSaveError:
            logger.error("Incomplete save detected")
            // Context rollback handled by caller

        default:
            logger.info("Attempting generic recovery")
        }
    }
    
    // MARK: - Schema Recovery
    
    private func attemptSchemaRecovery() async throws {
        logger.info("Attempting schema recovery")

        // Try to backup current store
        try await backupStore()

        // Attempt to recreate store with new model
        // This is a destructive operation and should be used carefully
        throw CoreDataError.storeCorrupted
    }

    // MARK: - Backup

    private func backupStore() async throws {
        guard let storeURL = container.persistentStoreDescriptions.first?.url else {
            return
        }

        let backupURL = storeURL.appendingPathExtension("backup")
        let fileManager = FileManager.default

        if fileManager.fileExists(atPath: backupURL.path) {
            try fileManager.removeItem(at: backupURL)
        }

        try fileManager.copyItem(at: storeURL, to: backupURL)
        logger.info("Store backed up to: \(backupURL.path)")
    }
    
    // MARK: - Store Configuration
    
    public func configureStoreDescriptions(_ descriptions: [NSPersistentStoreDescription]) {
        descriptions.forEach { storeDescription in
            // Enable migration options
            storeDescription.shouldMigrateStoreAutomatically = true
            storeDescription.shouldInferMappingModelAutomatically = true
            
            // Enable history tracking
            storeDescription.setOption(true as NSNumber,
                                      forKey: NSPersistentHistoryTrackingKey)
            
            // Set performance options
            storeDescription.setOption(true as NSNumber,
                                      forKey: NSSQLitePragmasOption)
        }
    }
}