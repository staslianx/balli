//
//  AppSyncCoordinator.swift
//  balli
//
//  Centralized app initialization sync coordinator
//  Ensures all critical operations complete before showing main UI
//  Swift 6 strict concurrency compliant
//

import Foundation
import SwiftUI
import OSLog
@preconcurrency import ObjectiveC

// MARK: - Sync State

enum SyncState: Equatable {
    case idle
    case syncing
    case completed
    case failed(SyncError)

    static func == (lhs: SyncState, rhs: SyncState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.syncing, .syncing), (.completed, .completed):
            return true
        case (.failed(let lhsError), .failed(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
}

// MARK: - Sync Error

enum SyncError: LocalizedError, Equatable {
    case coreDataTimeout
    case coreDataFailed(String)
    case appConfigurationFailed(String)
    case timeout
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .coreDataTimeout:
            return "Veritabanı başlatılamadı. Lütfen uygulamayı yeniden başlatın."
        case .coreDataFailed(let reason):
            return "Veritabanı hatası: \(reason)"
        case .appConfigurationFailed(let reason):
            return "Uygulama ayarları yüklenemedi: \(reason)"
        case .timeout:
            return "Başlatma zaman aşımına uğradı. Lütfen tekrar deneyin."
        case .unknown(let reason):
            return "Beklenmeyen hata: \(reason)"
        }
    }

    var isCritical: Bool {
        switch self {
        case .coreDataTimeout, .coreDataFailed:
            return true
        case .appConfigurationFailed, .timeout, .unknown:
            return false
        }
    }

    static func == (lhs: SyncError, rhs: SyncError) -> Bool {
        lhs.localizedDescription == rhs.localizedDescription
    }
}

// MARK: - App Sync Coordinator

@MainActor
final class AppSyncCoordinator: ObservableObject {

    // MARK: - Singleton

    static let shared = AppSyncCoordinator()

    // MARK: - Published State

    @Published private(set) var state: SyncState = .idle
    @Published private(set) var progress: Double = 0.0
    @Published private(set) var currentOperation: String = ""

    // MARK: - Properties

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.anaxoniclabs.balli",
        category: "AppSync"
    )

    private let maxSyncTime: TimeInterval = 30.0  // 30 second timeout
    private let coreDataTimeout: TimeInterval = 10.0  // 10 second Core Data timeout
    private let minimumDisplayTime: TimeInterval = 1.5  // Minimum loading screen display for smooth logo animation

    private var syncStartTime: Date?
    private var isSyncing = false

    // Emergency bypass flag (can be set in Settings for rollback)
    private let bypassSyncKey = "BYPASS_SYNC_COORDINATOR"

    // MARK: - Initialization

    private init() {
        logger.info("AppSyncCoordinator initialized")
    }

    // MARK: - Public API

    /// Perform initial app synchronization
    func performInitialSync() async {
        // Check emergency bypass
        if UserDefaults.standard.bool(forKey: bypassSyncKey) {
            logger.warning("⚠️ SYNC BYPASS ENABLED - Skipping sync coordinator")
            state = .completed
            return
        }

        // Prevent concurrent sync attempts
        guard !isSyncing else {
            logger.warning("Sync already in progress, ignoring duplicate request")
            return
        }

        isSyncing = true
        syncStartTime = Date()
        state = .syncing

        logger.info("🚀 Starting app initialization sync")
        logger.info("📱 App version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown")")
        logger.info("📱 Device: \(UIDevice.current.model), iOS \(UIDevice.current.systemVersion)")

        // Create timeout task
        let timeoutTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(maxSyncTime * 1_000_000_000))
            if case .syncing = state {
                logger.error("⏰ Sync timeout after \(self.maxSyncTime) seconds")
                await handleTimeout()
            }
        }

        do {
            // Execute sync operations
            try await executeSyncSequence()

            // Ensure minimum display time
            if let startTime = syncStartTime {
                let elapsed = Date().timeIntervalSince(startTime)
                if elapsed < minimumDisplayTime {
                    let remaining = minimumDisplayTime - elapsed
                    logger.debug("⏱️ Enforcing minimum display time: \(remaining)s")
                    try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
                }
            }

            // Complete successfully
            timeoutTask.cancel()
            await completeSync()

        } catch {
            timeoutTask.cancel()
            await failSync(with: error)
        }

        isSyncing = false
    }

    /// Retry sync after failure
    func retrySync() async {
        logger.info("🔄 Retrying sync")
        state = .idle
        progress = 0.0
        currentOperation = ""
        await performInitialSync()
    }

    // MARK: - Sync Sequence

    private func executeSyncSequence() async throws {
        // Step 1: Load User Profile (fast, synchronous)
        try await syncUserProfile()

        // Step 2: Parallel execution - Core Data + App Configuration
        try await syncCriticalServices()

        // Step 3: Check HealthKit authorization status
        await checkHealthKitStatus()

        // Step 4: Final preparation
        await finalizeSync()
    }

    // MARK: - Sync Operations

    private func syncUserProfile() async throws {
        await updateProgress(0.05, "Kullanıcı profili yükleniyor...")

        let startTime = Date()

        // Load user profile from UserDefaults (synchronous, fast)
        UserProfileSelector.shared.loadCurrentUser()

        let elapsed = Date().timeIntervalSince(startTime)
        logger.info("⏱️ [0.0s] User profile loaded in \(String(format: "%.3f", elapsed))s")
    }

    private func syncCriticalServices() async throws {
        await updateProgress(0.10, "Kritik servisler hazırlanıyor...")

        // Execute Core Data and App Configuration in parallel
        async let coreDataReady = waitForCoreData()
        async let appConfigReady = configureAppServices()

        // Wait for both to complete
        let (coreDataSuccess, appConfigSuccess) = try await (coreDataReady, appConfigReady)

        if !coreDataSuccess {
            throw SyncError.coreDataFailed("Core Data stores failed to load")
        }

        if !appConfigSuccess {
            logger.warning("⚠️ App configuration failed, continuing with degraded functionality")
            // Don't throw - app can work with degraded config
        }

        await updateProgress(0.50, "Temel servisler hazır...")
    }

    private func waitForCoreData() async throws -> Bool {
        logger.info("⏳ Waiting for Core Data stores to load...")

        let startTime = Date()
        let maxWait = coreDataTimeout

        // Check if already ready using Task to properly handle async property
        let persistenceReady = await Task {
            await Persistence.PersistenceController.shared.isReady
        }.value

        if persistenceReady {
            let elapsed = Date().timeIntervalSince(startTime)
            logger.info("✅ Core Data already ready (checked in \(String(format: "%.3f", elapsed))s)")
            return true
        }

        // Wait for Core Data ready notification with timeout
        return try await withCheckedThrowingContinuation { continuation in
            var observer: NSObjectProtocol?
            var timeoutTask: Task<Void, Never>?
            var hasResumed = false

            // Setup notification observer
            observer = NotificationCenter.default.addObserver(
                forName: .coreDataReady,
                object: nil,
                queue: .main
            ) { _ in
                guard !hasResumed else { return }
                hasResumed = true

                if let observer = observer {
                    NotificationCenter.default.removeObserver(observer)
                }
                timeoutTask?.cancel()

                let elapsed = Date().timeIntervalSince(startTime)
                self.logger.info("✅ Core Data ready in \(String(format: "%.3f", elapsed))s")
                continuation.resume(returning: true)
            }

            // Setup timeout
            timeoutTask = Task {
                try? await Task.sleep(nanoseconds: UInt64(maxWait * 1_000_000_000))

                guard !hasResumed else { return }
                hasResumed = true

                if let observer = observer {
                    NotificationCenter.default.removeObserver(observer)
                }

                self.logger.error("❌ Core Data timeout after \(maxWait)s")
                continuation.resume(throwing: SyncError.coreDataTimeout)
            }
        }
    }

    private func configureAppServices() async throws -> Bool {
        logger.info("⚙️ Configuring app services...")

        let startTime = Date()

        do {
            // Get UIApplication instance
            guard let app = await UIApplication.shared as UIApplication? else {
                throw SyncError.appConfigurationFailed("Could not access UIApplication")
            }

            // Configure app (this runs at userInitiated priority now, not background)
            try await AppConfigurationManager.shared.configure(application: app)

            let elapsed = Date().timeIntervalSince(startTime)
            logger.info("✅ App configuration completed in \(String(format: "%.3f", elapsed))s")

            return true

        } catch {
            logger.error("❌ App configuration failed: \(error.localizedDescription)")
            return false
        }
    }

    private func checkHealthKitStatus() async {
        await updateProgress(0.60, "Sağlık izinleri kontrol ediliyor...")

        let startTime = Date()

        // Check current HealthKit authorization status
        let healthKitManager = HealthKitPermissionManager.shared
        let isAuthorized = await healthKitManager.hasAllRequiredPermissions()

        if isAuthorized {
            logger.info("✅ HealthKit permissions already granted")
        } else {
            logger.info("ℹ️ HealthKit permissions not granted (will request later)")

            // Request permissions in background (don't wait)
            Task.detached(priority: .userInitiated) {
                do {
                    try await healthKitManager.requestAllPermissions()
                } catch {
                    // Non-critical - app works without HealthKit
                    await self.logger.warning("HealthKit permission request failed: \(error.localizedDescription)")
                }
            }
        }

        let elapsed = Date().timeIntervalSince(startTime)
        logger.info("⏱️ HealthKit status check completed in \(String(format: "%.3f", elapsed))s")
    }

    private func finalizeSync() async {
        await updateProgress(0.90, "Hazırlanıyor...")

        logger.info("🔧 Finalizing sync...")

        // Small delay to ensure all operations settle
        try? await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds

        await updateProgress(1.0, "Hazır!")
    }

    // MARK: - Helper Methods

    private func updateProgress(_ value: Double, _ operation: String) async {
        progress = value
        currentOperation = operation

        let percentage = Int(value * 100)
        logger.debug("📊 \(percentage)% - \(operation)")
    }

    private func completeSync() async {
        if let startTime = syncStartTime {
            let totalTime = Date().timeIntervalSince(startTime)
            logger.info("✅ App initialization completed in \(String(format: "%.2f", totalTime))s")
        }

        state = .completed
    }

    private func failSync(with error: Error) async {
        let syncError: SyncError

        if let error = error as? SyncError {
            syncError = error
        } else {
            syncError = .unknown(error.localizedDescription)
        }

        logger.error("❌ App initialization failed: \(syncError.localizedDescription)")

        if let startTime = syncStartTime {
            let elapsed = Date().timeIntervalSince(startTime)
            logger.error("❌ Failed after \(String(format: "%.2f", elapsed))s")
        }

        state = .failed(syncError)
    }

    private func handleTimeout() async {
        // Check what completed before timeout using Task to handle async property
        let coreDataReady = await Task {
            await Persistence.PersistenceController.shared.isReady
        }.value

        if coreDataReady {
            logger.warning("⚠️ Timeout but Core Data ready - continuing with partial sync")
            await completeSync()
        } else {
            logger.error("❌ Timeout and Core Data not ready - cannot continue")
            await failSync(with: SyncError.timeout)
        }
    }

    // MARK: - Debug Helpers

    /// Enable emergency bypass (for debugging or rollback)
    func enableBypass() {
        UserDefaults.standard.set(true, forKey: bypassSyncKey)
        logger.warning("⚠️ Emergency bypass ENABLED")
    }

    /// Disable emergency bypass
    func disableBypass() {
        UserDefaults.standard.set(false, forKey: bypassSyncKey)
        logger.info("✅ Emergency bypass DISABLED")
    }

    /// Check if bypass is enabled
    var isBypassEnabled: Bool {
        UserDefaults.standard.bool(forKey: bypassSyncKey)
    }
}
