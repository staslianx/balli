//
//  PersistenceLifecycleManager.swift
//  balli
//
//  Handles persistence lifecycle concerns: notifications, background transitions, memory pressure
//  Extracted from PersistenceController for single responsibility
//

@preconcurrency import CoreData
import OSLog

/// Handles persistence lifecycle events and state transitions
final class PersistenceLifecycleManager: @unchecked Sendable {
    private let logger = AppLoggers.Data.coredata
    private let coreDataStack: CoreDataStack
    private let monitor: PersistenceMonitor
    private let errorHandler: PersistenceErrorHandler

    init(
        coreDataStack: CoreDataStack,
        monitor: PersistenceMonitor,
        errorHandler: PersistenceErrorHandler
    ) {
        self.coreDataStack = coreDataStack
        self.monitor = monitor
        self.errorHandler = errorHandler
    }

    // MARK: - Notification Setup

    func setupNotifications(
        onRemoteChange: @escaping @Sendable () async -> Void,
        viewContext: NSManagedObjectContext
    ) {
        coreDataStack.setupNotifications(
            remoteChangeHandler: { _ in
                Task {
                    await onRemoteChange()
                }
            },
            backgroundSaveHandler: { notification in
                // Merge changes immediately
                // Note: Notification is not Sendable but safe here because it's used immediately
                nonisolated(unsafe) let capturedNotification = notification
                viewContext.perform {
                    // Merge directly from notification within perform block
                    viewContext.mergeChanges(fromContextDidSave: capturedNotification)
                }
            }
        )
    }

    // MARK: - Background Transition

    func prepareForBackground(
        viewContext: NSManagedObjectContext,
        isBackgroundWorkInProgress: Bool,
        onSave: () async throws -> Void,
        onWaitForBackgroundOperations: () async -> Void
    ) async {
        logger.info("Preparing for background")

        if viewContext.hasChanges {
            try? await onSave()
        }

        if isBackgroundWorkInProgress {
            await onWaitForBackgroundOperations()
        }

        viewContext.refreshAllObjects()
    }

    // MARK: - Memory Pressure

    @PersistenceActor
    func handleMemoryPressure(viewContext: NSManagedObjectContext) async {
        await monitor.handleMemoryPressure()

        await MainActor.run {
            viewContext.refreshAllObjects()
        }
    }
}
