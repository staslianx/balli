//
//  DexcomShareService.swift
//  balli
//
//  High-level service for Dexcom SHARE API integration (unofficial)
//  Swift 6 strict concurrency compliant
//  Coordinates authentication, API calls, and real-time data access
//
//  IMPORTANT: This is an unofficial API used by Nightscout, Loop, xDrip
//  For personal use only - provides ~5 min delay vs 3-hour official API delay
//

import Foundation
import OSLog

/// High-level service for Dexcom SHARE API integration
@MainActor
final class DexcomShareService: DexcomShareServiceProtocol {

    // MARK: - Published State

    @Published var isConnected: Bool = false {
        didSet {
            if oldValue != isConnected {
                logger.info("📡 [SHARE STATE] isConnected changed: \(oldValue) → \(self.isConnected)")
            }
        }
    }
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var lastSync: Date?
    @Published var latestReading: DexcomShareGlucoseReading?
    @Published var error: DexcomShareError?

    // MARK: - Connection Status

    enum ConnectionStatus: Sendable {
        case disconnected
        case connecting
        case connected
        case error(DexcomShareError)

        var description: String {
            switch self {
            case .disconnected:
                return "Bağlı değil"
            case .connecting:
                return "Bağlanıyor..."
            case .connected:
                return "Bağlandı"
            case .error(let error):
                return "Hata: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Properties

    private let server: DexcomShareServer
    private let authManager: DexcomShareAuthManager
    private let apiClient: DexcomShareAPIClient
    private let analytics = AnalyticsService.shared
    private let logger = AppLoggers.Health.glucose
    private let glucoseRepository: GlucoseReadingRepository

    // ANTI-SPAM: Prevent excessive connection checks
    private var lastConnectionCheck: Date?
    private let connectionCheckDebounceInterval: TimeInterval = 2.0 // 2 seconds

    // RACE CONDITION FIX: Ensure only one connection check runs at a time
    private var connectionCheckTask: Task<Void, Never>?

    // RETRY LOGIC: Exponential backoff for auto-recovery
    private var recoveryAttempts: Int = 0
    private var lastRecoveryAttempt: Date?
    private let maxRecoveryAttempts: Int = 3

    // MARK: - Initialization

    /// Public initializer for dependency injection
    /// - Parameters:
    ///   - server: Dexcom Share server region (US or International)
    ///   - glucoseRepository: Repository for saving glucose readings to CoreData
    init(
        server: DexcomShareServer = .international,
        glucoseRepository: GlucoseReadingRepository = GlucoseReadingRepository()
    ) {
        self.server = server
        self.authManager = DexcomShareAuthManager(server: server)
        self.apiClient = DexcomShareAPIClient(server: server, authManager: authManager)
        self.glucoseRepository = glucoseRepository

        // PERFORMANCE FIX: Don't check connection on init - let views call it explicitly when needed
        // This prevents 4+ simultaneous connection checks on app launch
    }

    // MARK: - Connection Management

    /// Connect to Dexcom SHARE with credentials
    func connect(username: String, password: String) async throws {
        logger.info("Connecting to Dexcom SHARE...")
        connectionStatus = .connecting
        logger.info("SHARE connection started: \(self.server.regionName)")

        do {
            // Test credentials and authenticate
            try await authManager.testCredentials(username: username, password: password)

            // Update connection status
            isConnected = true
            connectionStatus = .connected

            // Fetch initial data
            try await syncData()

            logger.info("✅ SHARE connection success: \(self.server.regionName)")
            logger.info("✅ Successfully connected to Dexcom SHARE")

        } catch {
            connectionStatus = .error(error as? DexcomShareError ?? .serverError)
            isConnected = false
            logger.error("❌ SHARE connection failed: \(error.localizedDescription)")
            throw error
        }
    }

    /// Disconnect from Dexcom SHARE
    func disconnect() async throws {
        try await authManager.deleteCredentials()

        isConnected = false
        connectionStatus = .disconnected
        latestReading = nil
        lastSync = nil

        logger.info("Disconnected from Dexcom SHARE")
    }

    /// Check if connected and update status
    /// ENHANCED: Auto-recovers expired sessions using stored credentials
    /// ENHANCED: Debounced to prevent excessive EXPENSIVE checks (max once per 2 seconds)
    /// BUT always returns current cached state immediately
    /// This ensures users stay connected without re-entering credentials
    /// RACE CONDITION FIX: Cancels previous check and runs only one at a time
    func checkConnectionStatus() async {
        // Cancel any existing connection check task to prevent race conditions
        connectionCheckTask?.cancel()

        // Create new task for this connection check
        connectionCheckTask = Task { @MainActor in
            logger.info("🔍 [DexcomShareService]: checkConnectionStatus() called - current cached state: \(self.isConnected)")

            // ANTI-SPAM: Debounce EXPENSIVE checks (keychain, session validation, recovery)
            // But still allow caller to read current cached state immediately
            var shouldPerformExpensiveCheck = true
            if let lastCheck = lastConnectionCheck {
                let timeSinceLastCheck = Date().timeIntervalSince(lastCheck)
                if timeSinceLastCheck < connectionCheckDebounceInterval {
                    logger.debug("⏭️ [DexcomShareService]: Within debounce window (\(String(format: "%.1f", timeSinceLastCheck))s) - returning cached state without expensive check")
                    shouldPerformExpensiveCheck = false
                    // Don't return early! Let caller observe current cached isConnected value
                }
            }

            if !shouldPerformExpensiveCheck {
                // Debounced - but isConnected is already set to current state
                // Caller can read it immediately
                return
            }

            // Check if task was cancelled
            guard !Task.isCancelled else {
                logger.debug("Connection check cancelled - newer check in progress")
                return
            }

            lastConnectionCheck = Date()

            logger.info("🔍 [DexcomShareService]: checkConnectionStatus() called")

            // Check if we have stored credentials
            let hasCredentials = await authManager.hasCredentials()

            // Check cancellation after async work
            guard !Task.isCancelled else {
                logger.debug("Connection check cancelled after credentials check")
                return
            }

            if !hasCredentials {
                // No credentials stored - truly disconnected
                logger.info("ℹ️ No Share credentials stored - user needs to connect")
                isConnected = false
                connectionStatus = .disconnected
                return
            }

            logger.info("✅ Share credentials found in keychain")

            // Check if session is still valid
            let authenticated = await authManager.isAuthenticated()

            // Check cancellation after async work
            guard !Task.isCancelled else {
                logger.debug("Connection check cancelled after auth check")
                return
            }

            if authenticated {
                // Session still valid - we're good
                logger.info("✅ Share session is valid")
                isConnected = true
                connectionStatus = .connected
                return
            }

            // Session expired but we have credentials - AUTO-RECOVER WITH RETRY
            logger.info("⚠️ Share session expired, attempting automatic recovery...")

            // Check if we should apply backoff
            if let lastAttempt = lastRecoveryAttempt {
                let timeSinceLastAttempt = Date().timeIntervalSince(lastAttempt)
                let backoffInterval = calculateBackoffInterval(attempt: recoveryAttempts)

                if timeSinceLastAttempt < backoffInterval {
                    logger.warning("⏱️ Recovery backoff active - wait \(String(format: "%.0f", backoffInterval - timeSinceLastAttempt))s more")
                    isConnected = false
                    connectionStatus = .error(.serverError)
                    return
                }
            }

            // Check cancellation before recovery attempt
            guard !Task.isCancelled else {
                logger.debug("Connection check cancelled before recovery")
                return
            }

            // Increment recovery attempt counter
            recoveryAttempts += 1
            lastRecoveryAttempt = Date()

            if recoveryAttempts > maxRecoveryAttempts {
                logger.error("❌ Max recovery attempts exceeded (\(self.maxRecoveryAttempts)) - giving up")
                isConnected = false
                connectionStatus = .error(.serverError)
                await analytics.trackError(.dexcomShareAutoRecoveryFailed, error: DexcomShareError.serverError)
                return
            }

            logger.info("🔄 Recovery attempt \(self.recoveryAttempts)/\(self.maxRecoveryAttempts)")
            connectionStatus = .connecting

            do {
                // Clear expired session
                await authManager.clearSession()

                // Check cancellation after async work
                guard !Task.isCancelled else {
                    logger.debug("Connection check cancelled after session clear")
                    return
                }

                logger.info("🔄 Cleared expired session, re-authenticating...")

                // Trigger re-authentication using stored credentials
                // This calls DexcomShareAuthManager.authenticate() internally
                _ = try await authManager.getSessionId()

                // Check cancellation after async work
                guard !Task.isCancelled else {
                    logger.debug("Connection check cancelled after session recovery")
                    return
                }

                // Success - session recovered
                isConnected = true
                connectionStatus = .connected
                recoveryAttempts = 0 // Reset counter on success
                lastRecoveryAttempt = nil
                logger.info("✅ Share session automatically recovered - user stays connected")

                // Track successful auto-recovery
                await analytics.track(.dexcomShareAutoRecovery)

            } catch DexcomShareError.invalidCredentials {
                // Credentials are no longer valid (password changed, account disabled)
                logger.error("❌ Auto-recovery failed: Credentials invalid (password changed?)")
                isConnected = false
                connectionStatus = .error(.invalidCredentials)

                // Track credential failure
                await analytics.trackError(.dexcomShareCredentialsInvalid, error: DexcomShareError.invalidCredentials)

            } catch DexcomShareError.serverError {
                // Server error - keep credentials, try again later
                logger.error("⚠️ Auto-recovery failed: Server error (will retry)")
                isConnected = false
                connectionStatus = .error(.serverError)

                // Don't delete credentials - might be temporary server issue

            } catch {
                // Other error - log but keep credentials for retry
                logger.error("❌ Auto-recovery failed: \(error.localizedDescription)")
                isConnected = false
                connectionStatus = .error(error as? DexcomShareError ?? .serverError)

                // Track auto-recovery failure
                await analytics.trackError(.dexcomShareAutoRecoveryFailed, error: error)
            }
        }

        // Wait for the task to complete
        await connectionCheckTask?.value
    }

    // MARK: - Data Fetching

    /// Sync latest glucose data from SHARE API
    func syncData() async throws {
        guard isConnected else {
            logger.error("SHARE sync failed: Not connected")
            throw DexcomShareError.sessionExpired
        }

        logger.info("Starting SHARE data sync...")
        let startTime = Date()

        do {
            // Fetch latest reading
            let reading = try await apiClient.fetchLatestGlucoseReading()

            // Update state
            latestReading = reading
            lastSync = Date()
            connectionStatus = .connected // Ensure status is updated on successful sync

            let duration = Date().timeIntervalSince(startTime)
            logger.info("SHARE sync completed in \(String(format: "%.2f", duration))s")

            if let reading = reading {
                logger.info("✅ SHARE sync complete: \(reading.Value) mg/dL at \(reading.displayTime)")

                // CRITICAL FIX: Auto-save to CoreData BEFORE posting notification
                // This prevents race condition where UI refreshes before data is saved
                do {
                    let healthReading = reading.toHealthGlucoseReading()
                    logger.info("💾 SHARE API: Attempting to save reading to CoreData - \(healthReading.value) mg/dL at \(healthReading.timestamp)")
                    let saved = try await glucoseRepository.saveReading(from: healthReading)
                    if saved != nil {
                        logger.info("✅ SHARE API: Saved to CoreData with source: dexcom_share")
                    } else {
                        logger.debug("⚠️ SHARE API: Reading already exists in CoreData (duplicate)")
                    }
                } catch {
                    logger.error("❌ SHARE API: Failed to save to CoreData: \(error.localizedDescription)")
                    // Don't throw - CoreData save failure shouldn't block sync
                }

                // Notify that new glucose data is available (AFTER CoreData save completes)
                NotificationCenter.default.post(name: .glucoseDataDidUpdate, object: nil)
            } else {
                logger.info("✅ SHARE sync complete: No recent data")
            }

        } catch DexcomShareError.noDataAvailable {
            // No data available is not an error - just means CGM hasn't sent data yet
            logger.info("⚠️ SHARE sync: No glucose data available (CGM may not be transmitting)")
            latestReading = nil
            lastSync = Date()
            // Don't throw - this is a valid state
        } catch DexcomShareError.sessionExpired {
            // Session expired - try to re-authenticate automatically
            logger.info("⚠️ SHARE session expired during sync, attempting automatic re-authentication...")

            do {
                // Get stored credentials and re-authenticate
                let hasCredentials = await authManager.hasCredentials()
                if hasCredentials {
                    logger.info("Credentials found, re-authenticating...")
                    // Clear session first
                    await authManager.clearSession()
                    // This will trigger re-authentication
                    _ = try await authManager.getSessionId()

                    // Retry the sync once
                    logger.info("Re-authentication successful, retrying sync...")
                    let reading = try await apiClient.fetchLatestGlucoseReading()
                    latestReading = reading
                    lastSync = Date()
                    connectionStatus = .connected

                    logger.info("✅ SHARE sync successful after re-authentication")

                    // CRITICAL FIX: Save to CoreData BEFORE posting notification
                    if let reading = reading {
                        do {
                            let healthReading = reading.toHealthGlucoseReading()
                            logger.info("💾 SHARE API (re-auth): Saving reading to CoreData...")
                            let saved = try await glucoseRepository.saveReading(from: healthReading)
                            if saved != nil {
                                logger.info("✅ SHARE API (re-auth): Saved to CoreData")
                            }
                        } catch {
                            logger.error("❌ SHARE API (re-auth): Failed to save to CoreData: \(error.localizedDescription)")
                        }

                        // Notify that new glucose data is available (AFTER save completes)
                        NotificationCenter.default.post(name: .glucoseDataDidUpdate, object: nil)
                    }
                    return
                } else {
                    logger.error("❌ No credentials available for re-authentication")
                    isConnected = false
                    connectionStatus = .error(.sessionExpired)
                    throw DexcomShareError.sessionExpired
                }
            } catch {
                logger.error("❌ Automatic re-authentication failed: \(error.localizedDescription)")
                isConnected = false
                connectionStatus = .error(error as? DexcomShareError ?? .serverError)
                throw error
            }
        } catch {
            logger.error("❌ SHARE sync failed: \(error.localizedDescription)")
            connectionStatus = .error(error as? DexcomShareError ?? .serverError)
            throw error
        }
    }

    /// Fetch glucose readings for time range
    func fetchGlucoseReadings(
        startDate: Date,
        endDate: Date = Date()
    ) async throws -> [DexcomShareGlucoseReading] {
        guard isConnected else {
            logger.error("Fetch failed: Not connected")
            throw DexcomShareError.sessionExpired
        }

        logger.info("Fetching SHARE readings from \(startDate) to \(endDate)...")

        do {
            let readings = try await apiClient.fetchGlucoseReadings(
                startDate: startDate,
                endDate: endDate
            )

            logger.info("Fetched \(readings.count) SHARE readings")

            // Auto-save batch readings to CoreData
            if !readings.isEmpty {
                Task {
                    do {
                        let healthReadings = readings.map { $0.toHealthGlucoseReading() }
                        let savedCount = try await self.glucoseRepository.saveReadings(from: healthReadings)
                        self.logger.info("Auto-saved \(savedCount)/\(readings.count) readings to CoreData")
                    } catch {
                        self.logger.error("Failed to batch save readings to CoreData: \(error.localizedDescription)")
                    }
                }

                // NOTE: DO NOT post .glucoseDataDidUpdate here!
                // This method is called BY the ViewModel when loading data, which would create infinite loop:
                // ViewModel gets notification → loads data → calls this → posts notification → LOOP
                // Only syncData() should post notifications (background sync, not on-demand fetch)
            }

            return readings

        } catch {
            logger.error("Failed to fetch SHARE readings: \(error.localizedDescription)")
            throw error
        }
    }

    /// Fetch latest glucose reading
    func fetchLatestReading() async throws -> DexcomShareGlucoseReading? {
        guard isConnected else {
            logger.error("Fetch failed: Not connected")
            throw DexcomShareError.sessionExpired
        }

        do {
            let reading = try await apiClient.fetchLatestGlucoseReading()
            latestReading = reading
            return reading
        } catch {
            logger.error("Failed to fetch latest SHARE reading: \(error.localizedDescription)")
            throw error
        }
    }

    /// Fetch recent glucose readings (last N hours)
    func fetchRecentReadings(hours: Int = 24) async throws -> [DexcomShareGlucoseReading] {
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .hour, value: -hours, to: endDate) ?? endDate

        return try await fetchGlucoseReadings(startDate: startDate, endDate: endDate)
    }

    // MARK: - Helper Methods

    /// Test SHARE API connection
    func testConnection() async throws {
        logger.info("Testing SHARE API connection...")

        do {
            try await apiClient.testConnection()
            logger.info("✅ SHARE connection test successful")
        } catch {
            logger.error("❌ SHARE connection test failed: \(error.localizedDescription)")
            throw error
        }
    }

    /// Get current server
    nonisolated func getServer() -> DexcomShareServer {
        server
    }

    /// Convert SHARE readings to app's HealthGlucoseReading format
    func convertToHealthReadings(_ shareReadings: [DexcomShareGlucoseReading]) -> [HealthGlucoseReading] {
        shareReadings.map { $0.toHealthGlucoseReading() }
    }

    // MARK: - Retry Logic

    /// Calculate exponential backoff interval for retry attempts
    /// Attempt 1: 30 seconds
    /// Attempt 2: 60 seconds
    /// Attempt 3: 120 seconds
    private func calculateBackoffInterval(attempt: Int) -> TimeInterval {
        let baseInterval: TimeInterval = 30.0 // 30 seconds
        let maxInterval: TimeInterval = 120.0 // 2 minutes

        let interval = baseInterval * pow(2.0, Double(attempt - 1))
        return min(interval, maxInterval)
    }
}

// MARK: - Preview Support

#if DEBUG
extension DexcomShareService {
    static var preview: DexcomShareService {
        let service = DexcomShareService(server: .international, glucoseRepository: GlucoseReadingRepository())
        service.isConnected = true
        service.connectionStatus = .connected
        service.latestReading = DexcomShareGlucoseReading(
            WT: "/Date(1706711400000)/",
            ST: "/Date(1706711400000)/",
            DT: "/Date(1706711400000)/",
            Value: 120,
            Trend: "Flat"
        )
        service.lastSync = Date()
        return service
    }

    static var previewDisconnected: DexcomShareService {
        let service = DexcomShareService(server: .international, glucoseRepository: GlucoseReadingRepository())
        service.isConnected = false
        service.connectionStatus = .disconnected
        return service
    }

    static var previewError: DexcomShareService {
        let service = DexcomShareService(server: .international, glucoseRepository: GlucoseReadingRepository())
        service.isConnected = false
        service.connectionStatus = .error(.invalidCredentials)
        return service
    }
}
#endif
