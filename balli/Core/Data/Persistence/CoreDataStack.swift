//
//  CoreDataStack.swift
//  balli
//
//  Core Data stack initialization and configuration
//

import CoreData
import OSLog

/// Manages Core Data stack initialization and configuration
public final class CoreDataStack: @unchecked Sendable {

    // MARK: - Properties

    private let logger = AppLoggers.Data.coredata
    public let container: NSPersistentContainer
    public let viewContext: NSManagedObjectContext
    private var backgroundContext: NSManagedObjectContext?
    private let inMemory: Bool
    
    // MARK: - Initialization
    
    public init(modelName: String = "balli", inMemory: Bool = false) {
        self.inMemory = inMemory
        self.container = NSPersistentContainer(name: modelName)
        
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        
        // Set viewContext but defer background context creation until stores are loaded
        self.viewContext = container.viewContext
        // Don't create background context until stores are loaded
        self.backgroundContext = nil
        
        // Configure store descriptions
        configureStoreDescriptions()
    }
    
    // MARK: - Store Configuration
    
    private func configureStoreDescriptions() {
        container.persistentStoreDescriptions.forEach { storeDescription in
            // Enable persistent history tracking
            storeDescription.setOption(true as NSNumber, 
                                      forKey: NSPersistentHistoryTrackingKey)
            storeDescription.setOption(true as NSNumber, 
                                      forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            
            // Enable lightweight migration
            storeDescription.shouldMigrateStoreAutomatically = true
            storeDescription.shouldInferMappingModelAutomatically = true
            
            // Set performance and security options
            storeDescription.type = NSSQLiteStoreType
            storeDescription.setOption(FileProtectionType.complete as NSObject,
                                      forKey: NSPersistentStoreFileProtectionKey)
        }
    }
    
    // MARK: - Store Loading
    
    public func loadStores() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            container.loadPersistentStores { [weak self] storeDescription, error in
                if let error = error {
                    self?.logger.fault("Core Data failed to load: \(error.localizedDescription)")

                    if let nsError = error as NSError? {
                        self?.logger.error("Error Code: \(nsError.code)")
                        self?.logger.error("Error Domain: \(nsError.domain)")
                    }

                    continuation.resume(throwing: error)
                } else {
                    self?.logger.info("Core Data store loaded successfully")
                    self?.logger.debug("Store URL: \(storeDescription.url?.absoluteString ?? "unknown")")
                    continuation.resume()
                }
            }
        }
    }
    
    // MARK: - Context Configuration
    
    public func configureContexts() {
        // View context configuration
        viewContext.automaticallyMergesChangesFromParent = true
        viewContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        viewContext.undoManager = nil
        viewContext.shouldDeleteInaccessibleFaults = true
        viewContext.name = "ViewContext"
        viewContext.stalenessInterval = 0.0
        
        // Now that stores are loaded, create and configure background context
        self.backgroundContext = container.newBackgroundContext()
        backgroundContext?.automaticallyMergesChangesFromParent = false
        backgroundContext?.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        backgroundContext?.undoManager = nil
        backgroundContext?.name = "BackgroundContext"
        backgroundContext?.stalenessInterval = -1

        logger.debug("Contexts configured successfully")
    }
    
    // MARK: - Context Creation
    
    public func createBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        context.undoManager = nil
        context.shouldDeleteInaccessibleFaults = true
        context.automaticallyMergesChangesFromParent = true
        return context
    }
    
    // MARK: - Notification Setup
    
    public func setupNotifications(
        remoteChangeHandler: @escaping @Sendable (Notification) -> Void,
        backgroundSaveHandler: @escaping @Sendable (Notification) -> Void
    ) {
        // Remote changes
        NotificationCenter.default.addObserver(
            forName: .NSPersistentStoreRemoteChange,
            object: container.persistentStoreCoordinator,
            queue: .main
        ) { @Sendable notification in
            remoteChangeHandler(notification)
        }
        
        // Background saves (only if background context exists)
        if let backgroundContext = self.backgroundContext {
            NotificationCenter.default.addObserver(
                forName: .NSManagedObjectContextDidSave,
                object: backgroundContext,
                queue: .main
            ) { @Sendable notification in
                backgroundSaveHandler(notification)
            }
        }

        logger.debug("Notification handlers configured")
    }
    
    // MARK: - Accessors
    
    public func getBackgroundContext() -> NSManagedObjectContext? {
        return backgroundContext
    }
}