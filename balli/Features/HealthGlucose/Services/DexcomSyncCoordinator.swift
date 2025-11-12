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

    // P0 FIX: Optimization properties for smart syncing
    // RATIONALE: Keep 5-min interval (Dexcom refresh rate) but skip unnecessary syncs
    // 1. Network check: Skip if offline (no point trying)
    // 2. Race protection: Skip if synced < 5 min ago (prevents rapid foreground/background cycles)
    // 3. Exponential backoff: Don't hammer API on errors (5→10→15→20 min intervals)
    private var lastSuccessfulSync: Date?
    private var consecutiveErrors: Int = 0

    // THERMAL FIX: Auto-stop continuous sync after max duration to prevent sustained CPU load
    private let maxSyncDuration: TimeInterval = 30 * 60 // 30 minutes maximum
    private let maxConsecutiveErrors = 3 // Stop after 3 consecutive errors
    private var syncStartTime: Date?

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
        syncStartTime = Date()
        logger.info("✅ Starting continuous Dexcom sync (interval: \(self.syncInterval)s, max duration: \(Int(self.maxSyncDuration/60))min)")

        // Cancel any existing task
        syncTask?.cancel()

        // Create new continuous sync task with smart optimizations
        syncTask = Task { @MainActor in
            // Immediate sync on start (but with smart checks)
            await performSyncIfNeeded()

            // Then continue with periodic sync
            while !Task.isCancelled && isActive {
                // THERMAL FIX: Check if max duration exceeded
                if let startTime = self.syncStartTime {
                    let elapsed = Date().timeIntervalSince(startTime)
                    if elapsed > self.maxSyncDuration {
                        self.logger.info("⏱️ [THERMAL] Max sync duration (\(Int(self.maxSyncDuration/60))min) reached - auto-stopping to prevent sustained CPU load")
                        self.stopContinuousSync()
                        break
                    }
                }

                do {
                    // Wait for interval (with exponential backoff on errors)
                    let waitInterval = calculateWaitInterval()
                    try await Task.sleep(for: .seconds(waitInterval))

                    // Check if still active (might have stopped while sleeping)
                    guard !Task.isCancelled && isActive else { break }

                    // THERMAL FIX: Stop after too many consecutive errors
                    if self.consecutiveErrors >= self.maxConsecutiveErrors {
                        self.logger.error("🛑 [THERMAL] Too many consecutive errors (\(self.consecutiveErrors)) - stopping to prevent wasted CPU cycles")
                        self.stopContinuousSync()
                        break
                    }

                    // Perform sync with optimizations
                    await performSyncIfNeeded()

                } catch is CancellationError {
                    logger.info("🛑 Sync task cancelled")
                    break
                } catch {
                    logger.error("❌ Sync task error: \(error.localizedDescription)")
                    syncError = error
                    // Continue syncing despite error (unless consecutive error limit reached)
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
        syncStartTime = nil
    }

    /// Perform an immediate sync (outside the periodic schedule)
    /// Used when user explicitly requests refresh or connection status changes
    func syncNow() async {
        logger.info("🔄 Explicit sync requested")
        await performSync()
    }

    // MARK: - Private Methods

    /// Smart sync with optimizations: network check, race protection, and skip if recently synced
    private func performSyncIfNeeded() async {
        // OPTIMIZATION 1: Skip if no network connection
        guard NetworkMonitor.shared.isConnected else {
            logger.debug("⏭️ [OPTIMIZATION] Skipping sync - no network connection")
            return
        }

        // OPTIMIZATION 2: Skip if synced < 5 min ago (race condition protection)
        // This prevents rapid foreground/background/foreground cycles from causing multiple syncs
        if let lastSync = lastSuccessfulSync,
           Date().timeIntervalSince(lastSync) < self.syncInterval {
            let elapsed = Int(Date().timeIntervalSince(lastSync))
            logger.debug("⏭️ [OPTIMIZATION] Skipping sync - last successful sync was \(elapsed)s ago (< \(Int(self.syncInterval))s)")
            return
        }

        // OPTIMIZATION 3: Skip if neither service is connected (no point trying)
        guard dexcomService.isConnected || dexcomShareService.isConnected else {
            logger.debug("⏭️ [OPTIMIZATION] Skipping sync - no Dexcom services connected")
            return
        }

        // Perform actual sync
        await performSync()
    }

    /// Calculate wait interval with exponential backoff on errors
    private func calculateWaitInterval() -> TimeInterval {
        // OPTIMIZATION 4: Exponential backoff on errors
        // Normal: 5 min | 1 error: 10 min | 2 errors: 15 min | 3+ errors: 20 min
        // This prevents hammering the API when it's failing
        if self.consecutiveErrors == 0 {
            return syncInterval
        } else {
            let backoffMultiplier = min(Double(self.consecutiveErrors + 1), 4.0)
            let interval = syncInterval * backoffMultiplier
            logger.debug("⏱️ [BACKOFF] Using \(Int(interval))s interval due to \(self.consecutiveErrors) consecutive errors")
            return interval
        }
    }

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

        // Update state and track success/failure for exponential backoff
        if !successfulSources.isEmpty {
            // SUCCESS: Reset error counter and update timestamps
            lastSyncTime = Date()
            lastSuccessfulSync = Date()
            syncError = nil
            consecutiveErrors = 0  // Reset on success

            let duration = Date().timeIntervalSince(startTime)
            logger.info("✅ Sync complete (\(successfulSources.joined(separator: ", "))) in \(String(format: "%.2f", duration))s")

            // Notify observers that new data is available
            NotificationCenter.default.post(name: .glucoseDataDidUpdate, object: nil)
        } else if !dexcomService.isConnected && !dexcomShareService.isConnected {
            // NOT AN ERROR: No services connected (expected state)
            logger.debug("⏭️ No Dexcom services connected, skipping sync")
        } else {
            // ERROR: Services connected but sync failed (network issue, API down, etc.)
            consecutiveErrors += 1  // Increment for exponential backoff
            logger.warning("⚠️ Sync attempted but all sources failed (possibly offline) - consecutive errors: \(self.consecutiveErrors)")
        }
    }
}
