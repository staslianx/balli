//
//  MedicationSyncCoordinator.swift
//  balli
//
//  Coordinates bidirectional medication synchronization between CoreData and Firestore
//  Listens to changes and triggers sync automatically for standalone medications (basal insulin)
//  Swift 6 strict concurrency compliant
//

import Foundation
import CoreData
import SwiftUI
import OSLog

/// Coordinates automatic synchronization of medication entries
@MainActor
final class MedicationSyncCoordinator: ObservableObject {

    // MARK: - Singleton

    static let shared = MedicationSyncCoordinator()

    // MARK: - Published State

    @Published var isSyncing: Bool = false
    @Published var lastSyncTime: Date?
    @Published var syncError: Error?
    @Published private(set) var pendingChangesCount: Int = 0

    // MARK: - Properties

    private let medicationService: MedicationFirestoreService
    private let persistenceController: Persistence.PersistenceController
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.balli", category: "MedicationSyncCoordinator")

    // Observers
    nonisolated(unsafe) private var coreDataObserver: NSObjectProtocol?

    // Sync control
    private var syncTask: Task<Void, Never>?
    private var autoSyncEnabled: Bool = true
    private let syncDebounceInterval: TimeInterval = 5.0 // Wait 5s after last change

    // MARK: - Initialization

    private init() {
        self.medicationService = MedicationFirestoreService()
        self.persistenceController = .shared

        setupObservers()
        updatePendingChangesCount()
    }

    deinit {
        syncTask?.cancel()
        if let observer = coreDataObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Setup

    private func setupObservers() {
        // Observe CoreData changes
        coreDataObserver = NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextObjectsDidChange,
            object: persistenceController.viewContext,
            queue: .main
        ) { [weak self] notification in
            // Extract data from notification immediately on main thread
            let inserted = (notification.userInfo?[NSInsertedObjectsKey] as? Set<NSManagedObject>) ?? []
            let updated = (notification.userInfo?[NSUpdatedObjectsKey] as? Set<NSManagedObject>) ?? []
            let medicationChanges = inserted.union(updated).compactMap { $0 as? MedicationEntry }

            Task { @MainActor [weak self] in
                await self?.handleCoreDataChange(medicationChanges: medicationChanges)
            }
        }
    }

    // MARK: - CoreData Change Handling

    private func handleCoreDataChange(medicationChanges: [MedicationEntry]) async {
        guard autoSyncEnabled else { return }
        guard !medicationChanges.isEmpty else { return }

        logger.info("Detected \(medicationChanges.count) medication changes")

        // Mark medications as pending sync
        for medication in medicationChanges {
            medication.markAsPendingSync()
        }

        // Save context
        do {
            try persistenceController.viewContext.save()
        } catch {
            logger.error("Failed to save pending sync status: \(error.localizedDescription)")
        }

        // Update pending count
        updatePendingChangesCount()

        // Trigger debounced sync
        scheduleDebouncedSync()
    }

    // MARK: - Sync Operations

    /// Manually trigger a sync
    func manualSync() async {
        logger.info("🔄 Manual medication sync triggered")
        await performSync()
    }

    /// Sync when app becomes active (call this from SwiftUI using .onChange(of: scenePhase))
    func syncOnAppActivation() async {
        logger.info("🔄 App activated - checking for medication sync")

        // Only sync if there are pending changes or it's been a while
        let shouldSync: Bool
        if let lastSync = lastSyncTime {
            shouldSync = pendingChangesCount > 0 || Date().timeIntervalSince(lastSync) > 300 // 5 minutes
        } else {
            shouldSync = true // No previous sync
        }

        if shouldSync {
            await performSync()
        } else {
            logger.debug("Skipping medication sync - no pending changes and recent sync")
        }
    }

    /// Perform the actual sync operation
    private func performSync() async {
        guard !isSyncing else {
            logger.debug("Medication sync already in progress")
            return
        }

        isSyncing = true
        syncError = nil

        do {
            logger.info("Starting bidirectional medication sync...")

            try await medicationService.performBidirectionalSync()

            lastSyncTime = Date()
            syncError = nil
            updatePendingChangesCount()

            logger.info("✅ Medication sync completed successfully")

        } catch {
            logger.error("❌ Medication sync failed: \(error.localizedDescription)")
            syncError = error
        }

        isSyncing = false
    }

    // MARK: - Debouncing

    /// Schedule a debounced sync (waits for changes to stop before syncing)
    private func scheduleDebouncedSync() {
        // Cancel existing sync task
        syncTask?.cancel()

        // Schedule new sync after debounce interval
        syncTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(syncDebounceInterval))

            // Check if task was cancelled
            guard !Task.isCancelled else { return }

            await performSync()
        }
    }

    // MARK: - Pending Changes

    /// Update the count of pending changes
    private func updatePendingChangesCount() {
        let request = MedicationEntry.fetchRequest()
        // For now, count all medications as we don't have sync status tracking yet
        // In the future, add: request.predicate = NSPredicate(format: "syncStatus == %@", "pending")

        do {
            pendingChangesCount = try persistenceController.viewContext.count(for: request)
        } catch {
            logger.error("Failed to count pending medications: \(error.localizedDescription)")
            pendingChangesCount = 0
        }
    }

    // MARK: - Manual Controls

    /// Enable auto-sync
    func enableAutoSync() {
        autoSyncEnabled = true
        logger.info("Auto-sync enabled for medications")
    }

    /// Disable auto-sync
    func disableAutoSync() {
        autoSyncEnabled = false
        syncTask?.cancel()
        logger.info("Auto-sync disabled for medications")
    }
}
