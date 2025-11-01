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
final class MealSyncCoordinator: ObservableObject {

    // MARK: - Published State

    @Published var isSyncing: Bool = false
    @Published var lastSyncTime: Date?
    @Published var syncError: Error?
    @Published private(set) var pendingChangesCount: Int = 0

    // MARK: - Properties

    private let mealService: MealFirestoreService
    private let conflictResolver: MealSyncConflictResolver
    private let persistenceController: Persistence.PersistenceController
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.balli", category: "SyncCoordinator")

    // Observers
    nonisolated(unsafe) private var coreDataObserver: NSObjectProtocol?

    // Sync control
    private var syncTask: Task<Void, Never>?
    private var autoSyncEnabled: Bool = true
    private let syncDebounceInterval: TimeInterval = 5.0 // Wait 5s after last change

    // MARK: - Initialization

    init(
        mealService: MealFirestoreService,
        persistenceController: Persistence.PersistenceController = .shared
    ) {
        self.mealService = mealService
        self.conflictResolver = MealSyncConflictResolver()
        self.persistenceController = persistenceController

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

        // Mark meals as pending sync
        for meal in mealChanges {
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
        logger.info("🔄 Manual sync triggered")
        await performSync()
    }

    /// Sync when app becomes active (call this from SwiftUI using .onChange(of: scenePhase))
    func syncOnAppActivation() async {
        logger.info("🔄 App activated - checking for sync")

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
            logger.debug("Skipping sync - no pending changes and recent sync")
        }
    }

    /// Perform the actual sync operation
    private func performSync() async {
        guard !isSyncing else {
            logger.debug("Sync already in progress")
            return
        }

        isSyncing = true
        syncError = nil

        do {
            logger.info("Starting bidirectional sync...")

            try await mealService.performBidirectionalSync()

            lastSyncTime = Date()
            updatePendingChangesCount()

            logger.info("✅ Sync completed successfully")

        } catch {
            logger.error("❌ Sync failed: \(error.localizedDescription)")
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

    private func updatePendingChangesCount() {
        Task {
            do {
                let count = try await fetchPendingMealsCount()
                await MainActor.run {
                    self.pendingChangesCount = count
                }
            } catch {
                logger.error("Failed to fetch pending count: \(error.localizedDescription)")
            }
        }
    }

    private func fetchPendingMealsCount() async throws -> Int {
        try await persistenceController.performBackgroundTask { context in
            let request = MealEntry.fetchRequest()
            request.predicate = NSPredicate(format: "firestoreSyncStatus == %@", "pending")
            return try context.count(for: request)
        }
    }

    // MARK: - Control

    /// Enable or disable automatic sync
    func setAutoSync(enabled: Bool) {
        autoSyncEnabled = enabled
        logger.info("Auto-sync \(enabled ? "enabled" : "disabled")")
    }

    /// Force sync all meals (useful for initial setup or recovery)
    func forceSyncAll() async throws {
        logger.info("🔄 Force syncing all meals")

        let allMeals = try await fetchAllMeals()

        // Mark all as pending
        for meal in allMeals {
            meal.markAsPendingSync()
        }

        try persistenceController.viewContext.save()

        // Perform sync
        await performSync()
    }

    private func fetchAllMeals() async throws -> [MealEntry] {
        try await persistenceController.performBackgroundTask { context in
            let request = MealEntry.fetchRequest()
            return try context.fetch(request)
        }
    }
}

// MARK: - Sync Status View

extension MealSyncCoordinator {
    /// Get a user-friendly sync status message
    var syncStatusMessage: String {
        if isSyncing {
            return "Senkronize ediliyor..."
        } else if let error = syncError {
            return "Hata: \(error.localizedDescription)"
        } else if pendingChangesCount > 0 {
            return "\(pendingChangesCount) değişiklik bekliyor"
        } else if let lastSync = lastSyncTime {
            let formatter = RelativeDateTimeFormatter()
            return "Son senkronizasyon: \(formatter.localizedString(for: lastSync, relativeTo: Date()))"
        } else {
            return "Henüz senkronize edilmedi"
        }
    }

    /// Get sync status icon name
    var syncStatusIcon: String {
        if isSyncing {
            return "arrow.triangle.2.circlepath"
        } else if syncError != nil {
            return "exclamationmark.triangle.fill"
        } else if pendingChangesCount > 0 {
            return "clock.fill"
        } else {
            return "checkmark.circle.fill"
        }
    }

    /// Get sync status color
    var syncStatusColor: String {
        if isSyncing {
            return "blue"
        } else if syncError != nil {
            return "red"
        } else if pendingChangesCount > 0 {
            return "orange"
        } else {
            return "green"
        }
    }
}
