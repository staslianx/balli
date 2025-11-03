//
//  MemorySyncBackgroundManager.swift
//  balli
//
//  Manages background task scheduling and network monitoring for memory sync
//  Extracted from MemorySyncCoordinator for single responsibility
//  Swift 6 strict concurrency compliant
//

import Foundation
import BackgroundTasks
import OSLog

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.anaxoniclabs.balli",
    category: "MemorySyncBackgroundManager"
)

/// Manages background task registration and network monitoring
@MainActor
final class MemorySyncBackgroundManager {
    // MARK: - Properties

    private let backgroundSyncInterval: TimeInterval

    // Observer cleanup
    nonisolated(unsafe) private var networkObserver: (any NSObjectProtocol)?

    // Callback for sync execution
    private var onSyncRequested: (@MainActor () async -> Void)?

    // MARK: - Initialization

    init(backgroundSyncInterval: TimeInterval = 30 * 60) {
        self.backgroundSyncInterval = backgroundSyncInterval
        logger.info("MemorySyncBackgroundManager initialized")
    }

    // MARK: - Background Task Registration

    /// Register background task for periodic sync
    func registerBackgroundTasks(onSyncRequested: @escaping @MainActor () async -> Void) {
        self.onSyncRequested = onSyncRequested

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

        // Execute sync callback
        if let callback = onSyncRequested {
            await callback()
            task.setTaskCompleted(success: true)
            logger.info("✅ Background sync completed successfully")
        } else {
            logger.error("❌ No sync callback registered")
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
        request.earliestBeginDate = Date(timeIntervalSinceNow: backgroundSyncInterval)

        do {
            try BGTaskScheduler.shared.submit(request)
            logger.info("📅 Next background sync scheduled in \(self.backgroundSyncInterval / 60) minutes")
        } catch {
            logger.error("❌ Failed to schedule background sync: \(error.localizedDescription)")
        }
    }

    // MARK: - Network Monitoring

    /// Setup network observer for connectivity restoration
    func setupNetworkObserver(onNetworkRestored: @escaping @MainActor () async -> Void) {
        networkObserver = NotificationCenter.default.addObserver(
            forName: .networkDidBecomeReachable,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                await onNetworkRestored()
            }
        }

        logger.info("📡 Network observer setup complete")
    }

    // MARK: - Cleanup

    deinit {
        if let observer = networkObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}
