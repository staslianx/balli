//
//  MemorySyncCoordinator.swift
//  balli
//
//  Coordinates memory sync operations across app lifecycle
//  Handles 3 sync triggers: app launch, background task, network restoration
//  Swift 6 strict concurrency compliant
//

import Foundation
import BackgroundTasks
import OSLog

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.anaxoniclabs.balli",
    category: "MemorySyncCoordinator"
)

// MARK: - Memory Sync Coordinator

/// @MainActor coordinator for memory sync operations
@MainActor
final class MemorySyncCoordinator {
    // MARK: - Singleton

    static let shared = MemorySyncCoordinator()

    // MARK: - Properties

    private let syncService: MemorySyncService
    private let persistence: MemoryPersistenceService

    // Configuration
    private let backgroundSyncInterval: TimeInterval = 30 * 60 // 30 minutes

    // State tracking
    private var isSyncing = false
    private var lastSyncTime: Date?

    // MARK: - Initialization

    private init() {
        self.persistence = MemoryPersistenceService()
        self.syncService = MemorySyncService()
        logger.info("MemorySyncCoordinator initialized")
    }

    // MARK: - Trigger 1: App Launch Sync

    /// Sync memory on app launch (non-blocking)
    func syncOnAppLaunch() async {
        guard !isSyncing else {
            logger.info("Sync already in progress, skipping app launch sync")
            return
        }

        logger.info("🚀 Starting app launch sync")
        isSyncing = true
        defer { isSyncing = false }

        do {
            // Get current user ID (replace with actual user ID from auth service)
            let userId = await getCurrentUserId()

            try await syncService.syncAll(userId: userId)

            lastSyncTime = Date()
            logger.info("✅ App launch sync completed successfully")
        } catch {
            logger.error("❌ App launch sync failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Trigger 2: Background Sync

    /// Register background task for periodic sync
    func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.anaxoniclabs.balli.memory-sync",
            using: nil
        ) { task in
            Task { @MainActor in
                guard let processingTask = task as? BGProcessingTask else {
                    logger.error("❌ Invalid task type received in background sync handler")
                    task.setTaskCompleted(success: false)
                    return
                }
                await self.handleBackgroundSync(task: processingTask)
            }
        }

        logger.info("📋 Background sync task registered")
    }

    /// Handle background sync task execution
    private func handleBackgroundSync(task: BGProcessingTask) async {
        logger.info("🌙 Background sync started")

        // Set expiration handler
        task.expirationHandler = {
            logger.warning("⏰ Background sync expired before completion")
            task.setTaskCompleted(success: false)
        }

        do {
            let userId = await getCurrentUserId()
            try await syncService.syncAll(userId: userId)

            lastSyncTime = Date()
            task.setTaskCompleted(success: true)
            logger.info("✅ Background sync completed successfully")
        } catch {
            logger.error("❌ Background sync failed: \(error.localizedDescription)")
            task.setTaskCompleted(success: false)
        }

        // Schedule next background sync
        scheduleNextBackgroundSync()
    }

    /// Schedule next background sync task
    func scheduleNextBackgroundSync() {
        let request = BGProcessingTaskRequest(
            identifier: "com.anaxoniclabs.balli.memory-sync"
        )
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        request.earliestBeginDate = Date(timeIntervalSinceNow: self.backgroundSyncInterval)

        do {
            try BGTaskScheduler.shared.submit(request)
            logger.info("📅 Next background sync scheduled in \(self.backgroundSyncInterval / 60) minutes")
        } catch {
            logger.error("❌ Failed to schedule background sync: \(error.localizedDescription)")
        }
    }

    // MARK: - Trigger 3: Network Restoration Sync

    /// Setup network observer for connectivity restoration
    func setupNetworkObserver() {
        NotificationCenter.default.addObserver(
            forName: .networkDidBecomeReachable,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.syncOnNetworkRestore()
            }
        }

        logger.info("📡 Network observer setup complete")
    }

    /// Sync when network becomes reachable after being offline
    private func syncOnNetworkRestore() async {
        guard !isSyncing else {
            logger.info("Sync already in progress, skipping network restore sync")
            return
        }

        logger.info("📡 Network restored, starting sync")
        isSyncing = true
        defer { isSyncing = false }

        do {
            let userId = await getCurrentUserId()
            try await syncService.syncAll(userId: userId)

            lastSyncTime = Date()
            logger.info("✅ Network restore sync completed successfully")
        } catch {
            logger.error("❌ Network restore sync failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Manual Sync

    /// Trigger manual sync (e.g., from UI or after data changes)
    func syncNow() async throws {
        guard !isSyncing else {
            logger.info("Sync already in progress, skipping manual sync")
            return
        }

        logger.info("🔄 Manual sync triggered")
        isSyncing = true
        defer { isSyncing = false }

        do {
            let userId = await getCurrentUserId()
            try await syncService.syncAll(userId: userId)

            lastSyncTime = Date()
            logger.info("✅ Manual sync completed successfully")
        } catch {
            logger.error("❌ Manual sync failed: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Helpers

    /// Get current user ID from authentication service
    private func getCurrentUserId() async -> String {
        // TODO: Replace with actual user ID from AuthenticationService
        // For now, return a placeholder
        return "test-user-id"
    }

    /// Check if sync is currently in progress
    func isSyncInProgress() -> Bool {
        return isSyncing
    }

    /// Get time of last successful sync
    func getLastSyncTime() -> Date? {
        return lastSyncTime
    }
}
