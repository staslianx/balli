//
//  DexcomSyncCoordinator.swift
//  balli
//
//  Persistent service for Dexcom glucose data synchronization
//  Survives view lifecycle and ensures continuous real-time updates
//  Swift 6 strict concurrency compliant
//

import Foundation
import OSLog

/// Coordinates periodic Dexcom data synchronization independent of view lifecycle
/// This service ensures real-time glucose data continues updating even when views disappear
@MainActor
final class DexcomSyncCoordinator: ObservableObject {

    // MARK: - Singleton

    static let shared = DexcomSyncCoordinator()

    // MARK: - Published State

    @Published var isActive: Bool = false
    @Published var lastSyncTime: Date?
    @Published var syncError: Error?

    // MARK: - Properties

    private let logger = AppLoggers.Health.glucose
    private let syncInterval: TimeInterval = 300 // 5 minutes (matches Dexcom CGM update frequency)
    private var syncTask: Task<Void, Never>?

    // Dependencies - Use protocol types for proper dependency injection
    private let dexcomService: any DexcomServiceProtocol
    private let dexcomShareService: any DexcomShareServiceProtocol

    // MARK: - Initialization

    private init(
        dexcomService: any DexcomServiceProtocol = DependencyContainer.shared.dexcomService,
        dexcomShareService: any DexcomShareServiceProtocol = DependencyContainer.shared.dexcomShareService
    ) {
        self.dexcomService = dexcomService
        self.dexcomShareService = dexcomShareService
        logger.info("🔄 DexcomSyncCoordinator initialized")
    }

    // MARK: - Public Methods

    /// Start continuous glucose data synchronization
    /// Call this when app launches or enters foreground
    func startContinuousSync() {
        guard !isActive else {
            logger.debug("⏭️ Sync already active, skipping start")
            return
        }

        isActive = true
        logger.info("✅ Starting continuous Dexcom sync (interval: \(self.syncInterval)s)")

        // Cancel any existing task
        syncTask?.cancel()

        // Create new continuous sync task
        syncTask = Task { @MainActor in
            // Immediate sync on start
            await performSync()

            // Then continue with periodic sync
            while !Task.isCancelled && isActive {
                do {
                    // Wait for interval
                    try await Task.sleep(for: .seconds(syncInterval))

                    // Check if still active (might have stopped while sleeping)
                    guard !Task.isCancelled && isActive else { break }

                    // Perform sync
                    await performSync()

                } catch is CancellationError {
                    logger.info("🛑 Sync task cancelled")
                    break
                } catch {
                    logger.error("❌ Sync task error: \(error.localizedDescription)")
                    syncError = error
                    // Continue syncing despite error
                }
            }

            logger.info("🛑 Continuous sync loop ended")
        }
    }

    /// Stop continuous synchronization
    /// Call this when app goes to background (iOS will suspend anyway)
    func stopContinuousSync() {
        guard isActive else {
            logger.debug("⏭️ Sync not active, skipping stop")
            return
        }

        logger.info("🛑 Stopping continuous Dexcom sync")
        isActive = false
        syncTask?.cancel()
        syncTask = nil
    }

    /// Perform an immediate sync (outside the periodic schedule)
    /// Used when user explicitly requests refresh or connection status changes
    func syncNow() async {
        logger.info("🔄 Explicit sync requested")
        await performSync()
    }

    // MARK: - Private Methods

    /// Perform actual data synchronization from both services
    private func performSync() async {
        logger.debug("🔄 Performing sync cycle...")

        let startTime = Date()
        var successfulSources: [String] = []

        // Try Dexcom Official API sync
        if dexcomService.isConnected {
            do {
                try await dexcomService.syncData(includeHistorical: false)
                successfulSources.append("Official")
                logger.debug("✅ Official API sync successful")
            } catch {
                logger.debug("⚠️ Official API sync failed: \(error.localizedDescription)")
                // Don't set syncError - this is expected when offline
            }
        }

        // Try Dexcom SHARE API sync
        if dexcomShareService.isConnected {
            do {
                try await dexcomShareService.syncData()
                successfulSources.append("SHARE")
                logger.debug("✅ SHARE API sync successful")
            } catch {
                logger.debug("⚠️ SHARE API sync failed: \(error.localizedDescription)")
                // Don't set syncError - this is expected when offline
            }
        }

        // Update state
        if !successfulSources.isEmpty {
            lastSyncTime = Date()
            syncError = nil
            let duration = Date().timeIntervalSince(startTime)
            logger.info("✅ Sync complete (\(successfulSources.joined(separator: ", "))) in \(String(format: "%.2f", duration))s")

            // Notify observers that new data is available
            NotificationCenter.default.post(name: .glucoseDataDidUpdate, object: nil)
        } else if !dexcomService.isConnected && !dexcomShareService.isConnected {
            logger.debug("⏭️ No Dexcom services connected, skipping sync")
        } else {
            logger.warning("⚠️ Sync attempted but all sources failed (possibly offline)")
        }
    }
}
