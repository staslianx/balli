//
//  DexcomBackgroundRefreshManager.swift
//  balli
//
//  Background refresh manager for Dexcom connection health
//  Proactively checks and recovers connections before user notices
//  Swift 6 strict concurrency compliant
//

import Foundation
import BackgroundTasks
import OSLog

/// Manages background refresh for Dexcom connections
/// Ensures sessions stay alive and recovers before user opens app
@MainActor
final class DexcomBackgroundRefreshManager {

    // MARK: - Singleton

    static let shared = DexcomBackgroundRefreshManager()

    // MARK: - Properties

    private let logger = AppLoggers.Health.glucose
    private let taskIdentifier = "com.anaxoniclabs.balli.dexcom-refresh"

    // Services
    private let officialService: DexcomService
    private let shareService: DexcomShareService

    // MARK: - Initialization

    private init() {
        // Use shared instances or create new ones
        self.officialService = DexcomService.shared
        self.shareService = DexcomShareService.shared
    }

    // MARK: - Registration

    /// Register background task handler
    /// Call this from AppDelegate.didFinishLaunchingWithOptions
    func registerBackgroundTask() {
        logger.info("🔄 Registering Dexcom background refresh task")

        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: taskIdentifier,
            using: nil
        ) { [weak self] task in
            guard let self = self else {
                task.setTaskCompleted(success: false)
                return
            }

            guard let refreshTask = task as? BGAppRefreshTask else {
                self.logger.error("❌ Background task is not a BGAppRefreshTask")
                task.setTaskCompleted(success: false)
                return
            }

            Task { @MainActor in
                await self.handleBackgroundRefresh(refreshTask)
            }
        }

        logger.info("✅ Dexcom background refresh task registered")
    }

    /// Schedule next background refresh
    /// Call this when app enters background
    func scheduleBackgroundRefresh() {
        #if targetEnvironment(simulator)
        // Background tasks don't work in simulator
        logger.debug("📅 Skipping background refresh scheduling (simulator)")
        return
        #else

        logger.info("📅 Scheduling Dexcom background refresh")

        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)

        // Schedule for 4 hours from now (well before 24h Share session expiry)
        // This ensures we catch expired sessions before user notices
        request.earliestBeginDate = Date(timeIntervalSinceNow: 4 * 60 * 60)

        do {
            try BGTaskScheduler.shared.submit(request)
            logger.info("✅ Background refresh scheduled for 4 hours from now")
        } catch {
            logger.error("❌ Failed to schedule background refresh: \(error.localizedDescription)")
        }

        #endif
    }

    // MARK: - Background Refresh Handler

    private func handleBackgroundRefresh(_ task: BGAppRefreshTask) async {
        logger.info("🔄 Background refresh started")

        // Set expiration handler
        task.expirationHandler = { [weak self] in
            self?.logger.warning("⏰ Background refresh expired - iOS terminated task")
        }

        var success = false

        do {
            // Check and recover both connections
            success = try await performConnectionHealthCheck()

            logger.info("✅ Background refresh completed - success: \(success)")

        } catch {
            logger.error("❌ Background refresh failed: \(error.localizedDescription)")
        }

        // Schedule next refresh
        scheduleBackgroundRefresh()

        // Mark task complete
        task.setTaskCompleted(success: success)
    }

    /// Perform health check and recovery for both APIs
    /// Returns true if both APIs are healthy or recovered
    private func performConnectionHealthCheck() async throws -> Bool {
        logger.info("🏥 Performing connection health check")

        var officialHealthy = false
        var shareHealthy = false

        // Check Official API
        await officialService.checkConnectionStatus()
        officialHealthy = officialService.isConnected
        logger.info("Official API health: \(officialHealthy ? "✅ Connected" : "❌ Disconnected")")

        // Check Share API (includes auto-recovery)
        await shareService.checkConnectionStatus()
        shareHealthy = shareService.isConnected
        logger.info("Share API health: \(shareHealthy ? "✅ Connected" : "❌ Disconnected")")

        // If Share API was recovered, try to sync data
        if shareHealthy {
            do {
                try await shareService.syncData()
                logger.info("✅ Background sync completed successfully")
            } catch {
                logger.warning("⚠️ Background sync failed (connection still healthy): \(error.localizedDescription)")
                // Don't mark as failure - connection is healthy even if sync fails
            }
        }

        // Consider healthy if at least one API is connected
        let overallHealthy = officialHealthy || shareHealthy

        logger.info("📊 Overall health: \(overallHealthy ? "✅ Healthy" : "❌ Unhealthy")")

        return overallHealthy
    }

    // MARK: - Manual Refresh Trigger

    /// Manually trigger a connection health check
    /// Useful for testing or user-initiated refresh
    func performManualRefresh() async -> Bool {
        logger.info("🔄 Manual refresh triggered")

        do {
            let success = try await performConnectionHealthCheck()

            // Schedule next background refresh
            scheduleBackgroundRefresh()

            return success
        } catch {
            logger.error("❌ Manual refresh failed: \(error.localizedDescription)")
            return false
        }
    }
}
