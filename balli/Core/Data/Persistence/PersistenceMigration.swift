//
//  PersistenceMigration.swift
//  balli
//
//  Handles Core Data migration operations and schema compatibility
//

import CoreData
import OSLog

/// Handles Core Data migration operations and schema compatibility checks
@PersistenceActor
public final class PersistenceMigration {
    private let logger = AppLoggers.Data.migration
    private let container: NSPersistentContainer
    
    public init(container: NSPersistentContainer) {
        self.container = container
    }
    
    // MARK: - Migration Support
    
    /// Checks if migration is needed
    public func checkMigrationNeeded() async throws -> Bool {
        guard let storeURL = container.persistentStoreDescriptions.first?.url else {
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
            
            logger.info("Store compatibility check: \(isCompatible ? "compatible" : "migration needed")")
            return !isCompatible
            
        } catch {
            logger.error("Failed to check store metadata: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Performs heavyweight migration if needed
    public func migrateStoreIfNeeded() async throws {
        let needsMigration = try await checkMigrationNeeded()
        
        if needsMigration {
            logger.info("Store migration required")
            
            // For now, we rely on lightweight migration
            // In the future, implement custom migration logic here
            logger.warning("Custom migration not implemented, relying on lightweight migration")
        }
    }
    
    /// Recovers from migration errors
    public func recoverFromError(_ error: Error) async throws {
        logger.error("Attempting recovery from: \(error.localizedDescription)")
        
        let nsError = error as NSError
        
        switch nsError.code {
        case NSMigrationMissingMappingModelError:
            // Handle migration errors
            logger.error("Migration required but mapping model missing")
            throw CoreDataError.migrationRequired
            
        case NSPersistentStoreIncompatibleSchemaError:
            // Handle schema mismatch
            logger.error("Store schema incompatible")
            throw CoreDataError.storeCorrupted
            
        case NSPersistentStoreIncompleteSaveError:
            // Handle incomplete save
            logger.error("Incomplete save detected")
            // Contexts will be rolled back by the caller
            
        default:
            // Reset contexts and retry handled by caller
            logger.info("Resetting contexts after error")
        }
    }
    
    /// Configures store descriptions for migration
    public func configureStoreDescriptions() {
        container.persistentStoreDescriptions.forEach { storeDescription in
            // Enable persistent history tracking for better sync
            storeDescription.setOption(true as NSNumber, 
                                      forKey: NSPersistentHistoryTrackingKey)
            storeDescription.setOption(true as NSNumber, 
                                      forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            
            // Enable lightweight migration
            storeDescription.shouldMigrateStoreAutomatically = true
            storeDescription.shouldInferMappingModelAutomatically = true
            
            // Set other performance options
            storeDescription.type = NSSQLiteStoreType
            storeDescription.setOption(FileProtectionType.complete as NSObject,
                                      forKey: NSPersistentStoreFileProtectionKey)
        }
    }
    
    /// Gets the store URL for migration operations
    public var storeURL: URL {
        let storeDirectory = NSPersistentContainer.defaultDirectoryURL()
        return storeDirectory.appendingPathComponent("balli.sqlite")
    }
}

// MARK: - Error Types
public enum CoreDataError: LocalizedError {
    case saveFailed(Error)
    case migrationRequired
    case storeCorrupted
    case insufficientStorage
    case validationFailed(String)
    case contextUnavailable
    
    public var errorDescription: String? {
        switch self {
        case .saveFailed(let error):
            return "Failed to save data: \(error.localizedDescription)"
        case .migrationRequired:
            return "Database migration required"
        case .storeCorrupted:
            return "Database appears corrupted"
        case .insufficientStorage:
            return "Insufficient storage space"
        case .validationFailed(let reason):
            return "Validation failed: \(reason)"
        case .contextUnavailable:
            return "Database context not available"
        }
    }
}