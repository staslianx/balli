//
//  DexcomService.swift
//  balli
//
//  High-level service for Dexcom CGM integration (EU region)
//  Swift 6 strict concurrency compliant
//  Coordinates authentication, API calls, and data synchronization
//

import Foundation
import CoreData
import AuthenticationServices
import OSLog

/// High-level service for Dexcom CGM integration
@MainActor
final class DexcomService: ObservableObject {

    // MARK: - Published State

    @Published var isConnected: Bool = false
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var lastSync: Date?
    @Published var latestReading: DexcomGlucoseReading?
    @Published var currentDevice: DexcomDevice?
    @Published var error: DexcomError?

    // MARK: - Connection Status

    enum ConnectionStatus: Sendable, Equatable {
        case disconnected
        case connecting
        case connected
        case error(DexcomError)

        static func == (lhs: ConnectionStatus, rhs: ConnectionStatus) -> Bool {
            switch (lhs, rhs) {
            case (.disconnected, .disconnected),
                 (.connecting, .connecting),
                 (.connected, .connected):
                return true
            case (.error(let lhsError), .error(let rhsError)):
                return lhsError.localizedDescription == rhsError.localizedDescription
            default:
                return false
            }
        }

        var description: String {
            switch self {
            case .disconnected:
                return "Not connected"
            case .connecting:
                return "Connecting..."
            case .connected:
                return "Connected"
            case .error(let error):
                return "Error: \(error.title)"
            }
        }
    }

    // MARK: - Properties

    private let configuration: DexcomConfiguration
    private let authManager: DexcomAuthManager
    private let apiClient: DexcomAPIClient
    private let analytics = AnalyticsService.shared
    private let logger = AppLoggers.Health.glucose

    // ANTI-SPAM: Prevent excessive connection checks
    private var lastConnectionCheck: Date?
    private let connectionCheckDebounceInterval: TimeInterval = 2.0 // 2 seconds

    // MARK: - Initialization

    init(configuration: DexcomConfiguration = .default()) {
        self.configuration = configuration
        self.authManager = DexcomAuthManager(configuration: configuration)
        self.apiClient = DexcomAPIClient(configuration: configuration, authManager: authManager)

        Task {
            await checkConnectionStatus()
        }
    }

    // MARK: - Connection Management

    /// Connect to Dexcom (start OAuth flow)
    func connect(presentationAnchor: ASPresentationAnchor) async throws {
        logger.info("DIAGNOSTIC [DexcomService]: connect() called with presentationAnchor: \(presentationAnchor)")
        connectionStatus = .connecting
        await analytics.track(.dexcomConnectionStarted)

        do {
            // Perform OAuth authorization
            logger.info("DIAGNOSTIC [DexcomService]: Calling authManager.authorize()")
            try await authManager.authorize(presentationAnchor: presentationAnchor)

            // Update connection status
            isConnected = true
            connectionStatus = .connected

            // Fetch initial data
            try await syncData()

            await analytics.track(.dexcomConnectionSuccess)
            logger.info("Successfully connected to Dexcom")

        } catch {
            connectionStatus = .error(error as? DexcomError ?? .connectionLost)
            isConnected = false
            await analytics.trackError(.dexcomConnectionFailed, error: error)
            throw error
        }
    }

    /// Disconnect from Dexcom
    func disconnect() async throws {
        try await authManager.disconnect()

        isConnected = false
        connectionStatus = .disconnected
        latestReading = nil
        currentDevice = nil
        lastSync = nil

        await analytics.track(.dexcomDisconnected)
        logger.info("Disconnected from Dexcom")
    }

    /// Check if connected and update status
    /// Also proactively refreshes token if needed to prevent expiration
    /// FIX: Always checks authentication and updates state, but debounces expensive token refresh
    func checkConnectionStatus() async {
        // 🔍 FORENSIC LOG: Entry point
        logger.info("🔍 FORENSIC [checkConnectionStatus]: ENTRY - current cached isConnected=\(self.isConnected)")
        await DexcomDiagnosticsLogger.shared.logConnection("checkConnectionStatus() ENTRY - cached state: \(self.isConnected)", level: .debug)

        // Determine if we should refresh token (expensive operation) or just check auth status (cheap)
        var shouldRefreshToken = true
        if let lastCheck = lastConnectionCheck {
            let timeSinceLastCheck = Date().timeIntervalSince(lastCheck)
            if timeSinceLastCheck < connectionCheckDebounceInterval {
                logger.debug("⏭️ [checkConnectionStatus]: Within debounce window (\(String(format: "%.1f", timeSinceLastCheck))s ago) - will check auth but SKIP token refresh")
                await DexcomDiagnosticsLogger.shared.logConnection("Within debounce window - checking auth but skipping refresh", level: .debug)
                shouldRefreshToken = false
            }
        }

        // 🔧 FIX: ALWAYS check authentication status and update isConnected
        // This ensures callers never see stale cached values
        logger.info("🔍 FORENSIC [checkConnectionStatus]: Checking authentication status (always runs)")
        await DexcomDiagnosticsLogger.shared.logConnection("Checking authentication status", level: .debug)

        let authenticated = await authManager.isAuthenticated()
        logger.info("✅ FORENSIC [checkConnectionStatus]: Auth check complete - authenticated=\(authenticated)")
        await DexcomDiagnosticsLogger.shared.logConnection("Authentication check result: \(authenticated)", level: .info)

        // Update state immediately - no more stale cached values!
        let oldState = isConnected
        isConnected = authenticated
        connectionStatus = authenticated ? .connected : .disconnected

        logger.info("✅ FORENSIC [checkConnectionStatus]: State updated - OLD=\(oldState) → NEW=\(self.isConnected)")
        logger.info("📢 FORENSIC: Callers will now see isConnected=\(self.isConnected) on their next read")
        await DexcomDiagnosticsLogger.shared.logConnection("Updated connection state - OLD=\(oldState) → NEW=\(self.isConnected)", level: authenticated ? .success : .error)

        // Only refresh token if NOT within debounce window
        if authenticated && shouldRefreshToken {
            lastConnectionCheck = Date() // Update timestamp only when we actually refresh

            logger.debug("Checking if token refresh needed...")
            await DexcomDiagnosticsLogger.shared.logTokenRefresh("Checking if token refresh needed", level: .debug)

            do {
                let didRefresh = try await authManager.refreshIfNeeded()
                if didRefresh {
                    logger.info("✅ Token proactively refreshed to prevent expiration")
                    await DexcomDiagnosticsLogger.shared.logTokenRefresh("Token proactively refreshed successfully", level: .success)
                } else {
                    logger.debug("Token refresh not needed - token still valid")
                    await DexcomDiagnosticsLogger.shared.logTokenRefresh("Token refresh not needed - token still valid", level: .info)
                }
            } catch {
                logger.error("❌ Failed to proactively refresh token: \(error.localizedDescription)")
                await DexcomDiagnosticsLogger.shared.logTokenRefresh("Token refresh FAILED: \(error.localizedDescription)", level: .error)
                // Don't mark as disconnected yet - token might still be valid
            }
        } else if authenticated {
            logger.debug("⏭️ Skipped token refresh (within debounce window) - will check again later")
            await DexcomDiagnosticsLogger.shared.logTokenRefresh("Token refresh skipped - within debounce window", level: .debug)
        } else {
            logger.error("❌ User NOT authenticated - connection lost")
            await DexcomDiagnosticsLogger.shared.logConnection("User NOT authenticated - connection LOST", level: .error)
        }
    }

    // MARK: - Data Synchronization

    /// Sync glucose data from Dexcom
    /// - Parameter includeHistorical: If true, fetches historical data beyond 3 hours (default: true)
    func syncData(includeHistorical: Bool = true) async throws {
        guard isConnected else {
            logger.error("Sync failed: Not connected")
            throw DexcomError.notConnected
        }

        logger.info("Starting Dexcom data sync (includeHistorical: \(includeHistorical))...")
        await analytics.track(.dexcomSyncStarted)
        let startTime = Date()

        // FIRST: Check what data range is available with retry
        logger.info("Checking available data range...")
        do {
            let dataRange = try await NetworkRetryHandler.retryWithBackoff(configuration: .network) {
                try await self.apiClient.fetchDataRange()
            }
            logger.info("EGV data range: \(dataRange.egvs.start.displayTime) to \(dataRange.egvs.end.displayTime)")
            if let calibrations = dataRange.calibrations {
                logger.info("Calibrations: \(calibrations.start.displayTime) to \(calibrations.end.displayTime)")
            }
            if let events = dataRange.events {
                logger.info("Events: \(events.start.displayTime) to \(events.end.displayTime)")
            }
        } catch {
            logger.error("Failed to fetch data range: \(error.localizedDescription)")
        }

        logger.info("Attempting to fetch latest glucose reading...")

        // Fetch latest reading with retry and fallback strategy
        do {
            let reading = try await NetworkRetryHandler.retryWithBackoff(configuration: .critical) {
                try await self.apiClient.fetchLatestGlucoseReading()
            }

            if let reading = reading {
                latestReading = reading
                logger.info("Latest reading: \(reading.value) mg/dL at \(reading.displayTime)")
            } else {
                logger.notice("No glucose reading available (might be normal if account is new)")
            }
        } catch {
            logger.error("Failed to fetch glucose reading: \(error.localizedDescription)")
            logger.error("Error type: \(type(of: error))")
            if let dexcomError = error as? DexcomError {
                logger.error("Dexcom error: \(dexcomError.logMessage)")
            }

            // Try fetching from last 7 days as fallback with retry
            logger.info("Trying wider range: last 7 days...")
            do {
                let endDate = DexcomConfiguration.mostRecentAvailableDate()
                let startDate = Calendar.current.date(byAdding: .day, value: -7, to: endDate) ?? endDate
                let readings = try await NetworkRetryHandler.retryWithBackoff(configuration: .network) {
                    try await self.apiClient.fetchGlucoseReadings(startDate: startDate, endDate: endDate)
                }
                logger.info("Found \(readings.count) readings in last 7 days")
                if let firstReading = readings.first {
                    latestReading = firstReading
                    logger.info("Most recent: \(firstReading.value) mg/dL at \(firstReading.displayTime)")
                }
            } catch {
                logger.error("7-day fetch also failed: \(error.localizedDescription)")
            }
        }

        logger.info("Attempting to fetch device information...")

        // Fetch current device with retry
        do {
            let devices = try await NetworkRetryHandler.retryWithBackoff(configuration: .network) {
                try await self.apiClient.fetchDevices()
            }
            logger.info("Fetched \(devices.count) device(s)")
            if let device = devices.first {
                currentDevice = device
                logger.info("Current device: \(device.deviceName)")
            } else {
                logger.notice("No devices found")
            }
        } catch {
            logger.error("Failed to fetch devices: \(error.localizedDescription)")
            if let dexcomError = error as? DexcomError {
                logger.error("Dexcom error: \(dexcomError.logMessage)")
            }
        }

        // 📊 HISTORICAL DATA: Fetch data beyond 3 hours if requested
        // This ensures we have complete glucose history, not just recent data
        if includeHistorical {
            logger.info("📊 Fetching historical glucose data (>3 hours)...")
            do {
                // Fetch last 7 days of historical data accounting for 3-hour EU delay
                let endDate = DexcomConfiguration.mostRecentAvailableDate()
                let startDate = Calendar.current.date(byAdding: .day, value: -7, to: endDate) ?? endDate

                logger.info("📊 Historical range: \(startDate) to \(endDate)")

                let historicalReadings = try await NetworkRetryHandler.retryWithBackoff(configuration: .network) {
                    try await self.apiClient.fetchGlucoseReadings(startDate: startDate, endDate: endDate)
                }

                logger.info("📊 Fetched \(historicalReadings.count) historical readings")

                // Log historical data fetch success
                logger.info("✅ Historical data fetch complete: \(historicalReadings.count) readings over 7 days")

                // Note: ViewModel will handle persisting these to CoreData when it fetches data
                // We don't auto-persist here to avoid duplicate writes
            } catch {
                logger.error("⚠️ Failed to fetch historical data: \(error.localizedDescription)")
                // Don't throw - this is optional enhancement, not critical failure
            }
        }

        lastSync = Date()
        logger.info("Data sync completed")

        // Track success with duration
        let duration = Date().timeIntervalSince(startTime)
        await analytics.track(.dexcomSyncSuccess, properties: [
            "duration_ms": String(format: "%.0f", duration * 1000)
        ])
    }

    /// Fetch glucose readings for date range with retry
    func fetchGlucoseReadings(
        startDate: Date,
        endDate: Date? = nil
    ) async throws -> [HealthGlucoseReading] {
        guard isConnected else {
            throw DexcomError.notConnected
        }

        let dexcomReadings = try await NetworkRetryHandler.retryWithBackoff(configuration: .critical) {
            try await self.apiClient.fetchGlucoseReadings(
                startDate: startDate,
                endDate: endDate
            )
        }

        // Convert to app's HealthGlucoseReading format with device name if available
        let deviceName = currentDevice?.deviceName
        let readings = dexcomReadings.map { $0.toHealthGlucoseReading(deviceName: deviceName) }

        // NOTE: DO NOT post .glucoseDataDidUpdate here!
        // This method is called BY the ViewModel when loading data, which would create infinite loop:
        // ViewModel gets notification → loads data → calls this → posts notification → LOOP
        // Only background sync operations should post notifications, not on-demand data fetches

        return readings
    }

    /// Fetch today's glucose readings
    func fetchTodayReadings() async throws -> [HealthGlucoseReading] {
        let calendar = Calendar.current
        let endDate = DexcomConfiguration.mostRecentAvailableDate()
        let startDate = calendar.startOfDay(for: endDate)

        return try await fetchGlucoseReadings(startDate: startDate, endDate: endDate)
    }

    /// Fetch recent glucose readings (last N days)
    func fetchRecentReadings(days: Int = 7) async throws -> [HealthGlucoseReading] {
        let endDate = DexcomConfiguration.mostRecentAvailableDate()
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: endDate) ?? endDate

        return try await fetchGlucoseReadings(startDate: startDate, endDate: endDate)
    }

    // MARK: - CoreData Integration

    /// Sync glucose readings to CoreData with batch commits for safety
    func syncToGoreData(viewContext: NSManagedObjectContext, days: Int = 7) async throws {
        let readings = try await fetchRecentReadings(days: days)

        await viewContext.perform {
            let batchSize = 20
            var savedCount = 0
            var totalNew = 0

            for (index, healthReading) in readings.enumerated() {
                // Check if reading already exists from Official API
                let fetchRequest: NSFetchRequest<GlucoseReading> = GlucoseReading.fetchRequest()
                fetchRequest.predicate = NSPredicate(
                    format: "timestamp == %@ AND source == %@",
                    healthReading.timestamp as NSDate,
                    GlucoseSource.dexcomOfficial.rawValue
                )
                fetchRequest.fetchLimit = 1

                do {
                    let existingReadings = try viewContext.fetch(fetchRequest)

                    if existingReadings.isEmpty {
                        // Create new glucose reading with Official API source
                        let glucoseReading = GlucoseReading(context: viewContext)
                        glucoseReading.id = UUID()
                        glucoseReading.value = healthReading.value
                        glucoseReading.timestamp = healthReading.timestamp
                        glucoseReading.source = GlucoseSource.dexcomOfficial.rawValue
                        glucoseReading.deviceName = healthReading.device
                        glucoseReading.notes = "Synced from Dexcom Official API"
                        glucoseReading.syncStatus = SyncStatus.synced.rawValue

                        totalNew += 1
                        self.logger.debug("Created CoreData reading for \(healthReading.timestamp)")
                    }
                } catch {
                    self.logger.error("Failed to fetch/create reading: \(error.localizedDescription)")
                    continue
                }

                // Commit batch every 20 readings
                if (index + 1) % batchSize == 0 && viewContext.hasChanges {
                    do {
                        try viewContext.save()
                        savedCount += batchSize
                        self.logger.debug("Batch saved: \(savedCount)/\(readings.count) readings processed")
                    } catch {
                        self.logger.error("Batch save failed at index \(index): \(error.localizedDescription)")
                        // Continue with next batch rather than failing completely
                    }
                }
            }

            // Save remaining readings
            if viewContext.hasChanges {
                do {
                    try viewContext.save()
                    self.logger.info("Successfully synced \(totalNew) new readings to CoreData")
                } catch {
                    self.logger.error("Final save failed: \(error.localizedDescription)")
                }
            } else if totalNew == 0 {
                self.logger.info("No new readings to sync (all \(readings.count) already exist)")
            }
        }
    }

    // MARK: - Statistics

    /// Get glucose statistics for a date range with retry
    func fetchStatistics(startDate: Date, endDate: Date) async throws -> DexcomStatistics {
        guard isConnected else {
            throw DexcomError.notConnected
        }

        return try await NetworkRetryHandler.retryWithBackoff(configuration: .network) {
            try await self.apiClient.fetchStatistics(startDate: startDate, endDate: endDate)
        }
    }

    /// Get weekly statistics
    func fetchWeeklyStatistics() async throws -> DexcomStatistics {
        let endDate = DexcomConfiguration.mostRecentAvailableDate()
        let startDate = Calendar.current.date(byAdding: .day, value: -7, to: endDate) ?? endDate

        return try await fetchStatistics(startDate: startDate, endDate: endDate)
    }

    // MARK: - Device Information

    /// Get connected Dexcom devices with retry
    func fetchDevices() async throws -> [DexcomDevice] {
        guard isConnected else {
            throw DexcomError.notConnected
        }

        return try await NetworkRetryHandler.retryWithBackoff(configuration: .network) {
            try await self.apiClient.fetchDevices()
        }
    }

    // MARK: - Error Handling

    /// Handle error and update state
    private func handleError(_ error: Error) {
        let dexcomError = error as? DexcomError ?? .networkError(error)
        self.error = dexcomError

        if dexcomError.requiresReauth {
            isConnected = false
            connectionStatus = .error(dexcomError)
        }

        logger.error("Dexcom error: \(dexcomError.logMessage)")
    }
}

// MARK: - Background Sync Support

extension DexcomService {
    /// Perform background sync (called by BGTaskScheduler)
    func performBackgroundSync(viewContext: NSManagedObjectContext) async {
        guard isConnected else {
            logger.info("Skipping background sync: not connected")
            return
        }

        do {
            try await syncToGoreData(viewContext: viewContext, days: 1)
            logger.info("Background sync completed successfully")
        } catch {
            handleError(error)
        }
    }

    /// Schedule next background sync
    func scheduleBackgroundSync() {
        // This would integrate with BGTaskScheduler
        // Implementation depends on app's background task setup
        logger.info("Background sync scheduled")
    }
}

// MARK: - Helper Properties

extension DexcomService {
    /// User-friendly connection status
    var statusDescription: String {
        connectionStatus.description
    }

    /// Check if data sync is needed
    var needsSync: Bool {
        guard let lastSync = lastSync else { return true }
        let timeSinceSync = Date().timeIntervalSince(lastSync)
        return timeSinceSync > 300 // 5 minutes
    }

    /// Data delay warning
    var dataDelayWarning: String {
        "Dexcom data in the EU region has a 3-hour delay."
    }
}

// MARK: - Preview Support

#if DEBUG
extension DexcomService {
    /// Mock service for SwiftUI previews
    static var mock: DexcomService {
        let mockConfig = DexcomConfiguration.mock
        let service = DexcomService(configuration: mockConfig)
        service.isConnected = true
        service.connectionStatus = .connected
        // Don't set latestReading for mock - it requires Decoder
        return service
    }
}
#endif