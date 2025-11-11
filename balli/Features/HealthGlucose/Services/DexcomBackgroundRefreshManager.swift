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
final class DexcomBackgroundRefreshManager: DexcomBackgroundRefreshManagerProtocol {

    // MARK: - Properties

    private let logger = AppLoggers.Health.glucose
    private let taskIdentifier = "com.anaxoniclabs.balli.dexcom-refresh"

    // Services - injected via dependency injection
    private let officialService: any DexcomServiceProtocol
    private let shareService: any DexcomShareServiceProtocol

    // MARK: - Initialization

    /// Public initializer for dependency injection
    /// - Parameters:
    ///   - officialService: Official Dexcom OAuth API service
    ///   - shareService: Unofficial Dexcom Share API service
    init(
        officialService: any DexcomServiceProtocol,
        shareService: any DexcomShareServiceProtocol
    ) {
        self.officialService = officialService
        self.shareService = shareService
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

        // P0 FIX: Adaptive scheduling based on system state
        // PREVIOUS: Fixed 4-hour interval (too aggressive, iOS may throttle)
        // NEW: 6-8 hour interval respecting Low Power Mode
        // RATIONALE:
        // - Dexcom Share session expires after 24 hours (not 4 hours)
        // - iOS throttles apps that request frequent background refresh
        // - User gets fresh data when app foregrounds anyway
        // - Low Power Mode users explicitly want less background activity
        // Audit Issue: P0.5 - Background refresh interval optimization
        let interval = calculateNextRefreshInterval()
        request.earliestBeginDate = Date(timeIntervalSinceNow: interval)

        do {
            try BGTaskScheduler.shared.submit(request)
            let hours = interval / 3600
            logger.info("✅ Background refresh scheduled for \(String(format: "%.1f", hours)) hours from now")
        } catch {
            logger.error("❌ Failed to schedule background refresh: \(error.localizedDescription)")
        }

        #endif
    }

    // MARK: - Private Helpers

    /// Calculate next refresh interval based on system state
    /// - Returns: Time interval in seconds (6 or 8 hours)
    private func calculateNextRefreshInterval() -> TimeInterval {
        // Check if Low Power Mode is enabled
        if ProcessInfo.processInfo.isLowPowerModeEnabled {
            logger.info("📱 Low Power Mode enabled - using 8-hour interval")
            return 8 * 60 * 60 // 8 hours
        }

        // Default: 6 hours (well within 24-hour Dexcom Share session lifetime)
        logger.info("📱 Normal power mode - using 6-hour interval")
        return 6 * 60 * 60 // 6 hours
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
