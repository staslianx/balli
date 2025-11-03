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
    private let backgroundManager: MemorySyncBackgroundManager

    // State tracking
    private var isSyncing = false
    private var lastSyncTime: Date?

    // MARK: - Initialization

    private init() {
        self.persistence = MemoryPersistenceService()
        self.syncService = MemorySyncService()
        self.backgroundManager = MemorySyncBackgroundManager()
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
        backgroundManager.registerBackgroundTasks {
            await self.performBackgroundSync()
        }
    }

    /// Schedule next background sync task
    func scheduleNextBackgroundSync() {
        backgroundManager.scheduleNextBackgroundSync()
    }

    /// Perform sync for background task
    private func performBackgroundSync() async {
        do {
            let userId = await getCurrentUserId()
            try await syncService.syncAll(userId: userId)
            lastSyncTime = Date()
        } catch {
            logger.error("❌ Background sync failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Trigger 3: Network Restoration Sync

    /// Setup network observer for connectivity restoration
    func setupNetworkObserver() {
        backgroundManager.setupNetworkObserver {
            await self.syncOnNetworkRestore()
        }
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
        // Get user ID from UserSession
        if let user = UserSession.shared.currentUser {
            // Use email as the userId for Firestore paths (consistent with firestoreUserId)
            return user.firestoreUserId
        }

        // Fallback: If no user is logged in, use a default identifier
        // This should rarely happen as the app should always have a user
        logger.warning("⚠️ No user logged in, using fallback userId")
        return "anonymous-user"
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
