//
//  MealSyncCoordinator.swift
//  balli
//
//  Coordinates bidirectional meal synchronization between CoreData and Firestore
//  Listens to changes and triggers sync automatically
//  Swift 6 strict concurrency compliant
//

import Foundation
import CoreData
import SwiftUI
import OSLog

/// Coordinates automatic synchronization of meal entries
@MainActor
final class MealSyncCoordinator: MealSyncCoordinatorProtocol {

    // MARK: - Singleton

    static let shared = MealSyncCoordinator()

    // MARK: - Published State

    @Published var isSyncing: Bool = false
    @Published var lastSyncTime: Date?
    @Published var syncError: Error?
    @Published private(set) var pendingChangesCount: Int = 0

    // MARK: - Properties

    private let mealService: MealFirestoreService
    private let persistenceController: Persistence.PersistenceController
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.balli", category: "MealSyncCoordinator")

    // Observers - stored on MainActor for proper isolation
    private var coreDataObserver: NSObjectProtocol?

    // Sync control
    private var syncTask: Task<Void, Never>?
    private var autoSyncEnabled: Bool = true
    private let syncDebounceInterval: TimeInterval = 5.0 // Wait 5s after last change

    // MARK: - Initialization

    private init() {
        self.mealService = MealFirestoreService()
        self.persistenceController = .shared

        setupObservers()
        updatePendingChangesCount()
    }

    deinit {
        syncTask?.cancel()
        // Cleanup observer - safe because we're accessing from MainActor-isolated context
        // The observer is stored as NSObjectProtocol which doesn't require Sendable
        // We use assumeIsolated to explicitly verify we're on MainActor during deinit
        MainActor.assumeIsolated {
            if let observer = coreDataObserver {
                NotificationCenter.default.removeObserver(observer)
            }
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
            let mealChanges = inserted.union(updated).compactMap { $0 as? MealEntry }

            Task { @MainActor [weak self] in
                await self?.handleCoreDataChange(mealChanges: mealChanges)
            }
        }
    }

    // MARK: - CoreData Change Handling

    private func handleCoreDataChange(mealChanges: [MealEntry]) async {
        guard autoSyncEnabled else { return }
        guard !mealChanges.isEmpty else { return }

        logger.info("Detected \(mealChanges.count) meal changes")

        // CRITICAL FIX: Filter out changes that are ONLY sync metadata updates
        // This prevents infinite loops when markAsPendingSync() triggers another notification
        let mealsNeedingSync = mealChanges.filter { meal in
            // Check if this is a real content change or just sync metadata
            let changedKeys = Set(meal.changedValues().keys)

            // Sync-only fields that shouldn't retrigger the sync coordinator
            let syncOnlyFields: Set<String> = ["firestoreSyncStatus", "lastModified", "deviceId", "lastSyncAttempt"]

            // If ONLY sync fields changed, skip this meal
            let nonSyncChanges = changedKeys.subtracting(syncOnlyFields)
            return !nonSyncChanges.isEmpty
        }

        // If no real changes (only sync metadata changed), ignore to prevent loop
        guard !mealsNeedingSync.isEmpty else {
            logger.debug("⏭️ Ignoring save notification - only sync metadata changed")
            return
        }

        logger.info("Processing \(mealsNeedingSync.count) meals with real content changes")

        // Mark meals as pending sync
        for meal in mealsNeedingSync {
            meal.markAsPendingSync()
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
        logger.info("🔄 Manual meal sync triggered")
        await performSync()
    }

    /// Sync when app becomes active (call this from SwiftUI using .onChange(of: scenePhase))
    func syncOnAppActivation() async {
        logger.info("🔄 App activated - checking for meal sync")

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
            logger.debug("Skipping meal sync - no pending changes and recent sync")
        }
    }

    /// Perform the actual sync operation
    private func performSync() async {
        guard !isSyncing else {
            logger.debug("Meal sync already in progress")
            return
        }

        isSyncing = true
        syncError = nil

        do {
            logger.info("Starting bidirectional meal sync...")

            try await mealService.performBidirectionalSync()

            lastSyncTime = Date()
            syncError = nil
            updatePendingChangesCount()

            logger.info("✅ Meal sync completed successfully")

        } catch {
            logger.error("❌ Meal sync failed: \(error.localizedDescription)")
            syncError = error
        }

        isSyncing = false
    }

    /// Schedule a debounced sync (waits for changes to settle)
    private func scheduleDebouncedSync() {
        // Cancel existing sync task
        syncTask?.cancel()

        // Create new debounced task
        syncTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(syncDebounceInterval * 1_000_000_000))

            guard !Task.isCancelled else { return }

            await performSync()
        }
    }

    // MARK: - Pending Changes

    /// Update the count of pending changes
    private func updatePendingChangesCount() {
        let request = MealEntry.fetchRequest()
        // For now, count all meals as we don't have sync status tracking yet
        // In the future, add: request.predicate = NSPredicate(format: "syncStatus == %@", "pending")

        do {
            pendingChangesCount = try persistenceController.viewContext.count(for: request)
        } catch {
            logger.error("Failed to count pending meals: \(error.localizedDescription)")
            pendingChangesCount = 0
        }
    }

    // MARK: - Manual Controls

    /// Enable auto-sync
    func enableAutoSync() {
        autoSyncEnabled = true
        logger.info("Auto-sync enabled for meals")
    }

    /// Disable auto-sync
    func disableAutoSync() {
        autoSyncEnabled = false
        syncTask?.cancel()
        logger.info("Auto-sync disabled for meals")
    }
}
