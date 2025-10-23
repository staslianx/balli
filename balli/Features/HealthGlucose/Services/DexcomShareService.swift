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
final class DexcomShareService: ObservableObject {

    // MARK: - Published State

    @Published var isConnected: Bool = false
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

    // MARK: - Initialization

    init(server: DexcomShareServer = .international) {
        self.server = server
        self.authManager = DexcomShareAuthManager(server: server)
        self.apiClient = DexcomShareAPIClient(server: server, authManager: authManager)

        Task {
            await checkConnectionStatus()
        }
    }

    // MARK: - Connection Management

    /// Connect to Dexcom SHARE with credentials
    func connect(username: String, password: String) async throws {
        logger.info("Connecting to Dexcom SHARE...")
        connectionStatus = .connecting
        await analytics.track(.dexcomShareConnectionStarted, properties: [
            "server": server.regionName
        ])

        do {
            // Test credentials and authenticate
            try await authManager.testCredentials(username: username, password: password)

            // Update connection status
            isConnected = true
            connectionStatus = .connected

            // Fetch initial data
            try await syncData()

            await analytics.track(.dexcomShareConnectionSuccess, properties: [
                "server": server.regionName
            ])
            logger.info("✅ Successfully connected to Dexcom SHARE")

        } catch {
            connectionStatus = .error(error as? DexcomShareError ?? .serverError)
            isConnected = false
            await analytics.trackError(.dexcomShareConnectionFailed, error: error, properties: [
                "server": server.regionName
            ])
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

        await analytics.track(.dexcomShareDisconnected)
        logger.info("Disconnected from Dexcom SHARE")
    }

    /// Check if connected and update status
    func checkConnectionStatus() async {
        let hasCredentials = await authManager.hasCredentials()
        let authenticated = await authManager.isAuthenticated()
        isConnected = hasCredentials && authenticated
        connectionStatus = isConnected ? .connected : .disconnected
    }

    // MARK: - Data Fetching

    /// Sync latest glucose data from SHARE API
    func syncData() async throws {
        guard isConnected else {
            logger.error("SHARE sync failed: Not connected")
            throw DexcomShareError.sessionExpired
        }

        logger.info("Starting SHARE data sync...")
        await analytics.track(.dexcomShareSyncStarted)
        let startTime = Date()

        do {
            // Fetch latest reading
            let reading = try await apiClient.fetchLatestGlucoseReading()

            // Update state
            latestReading = reading
            lastSync = Date()

            let duration = Date().timeIntervalSince(startTime)
            await analytics.track(.dexcomShareSyncCompleted, properties: [
                "duration": duration,
                "has_reading": reading != nil
            ])

            if let reading = reading {
                logger.info("✅ SHARE sync complete: \(reading.Value) mg/dL at \(reading.displayTime)")
            } else {
                logger.info("✅ SHARE sync complete: No recent data")
            }

        } catch {
            await analytics.trackError(.dexcomShareSyncFailed, error: error)
            logger.error("SHARE sync failed: \(error.localizedDescription)")
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
}

// MARK: - Analytics Events

extension AnalyticsEvent {
    static let dexcomShareConnectionStarted = AnalyticsEvent("dexcom_share_connection_started")
    static let dexcomShareConnectionSuccess = AnalyticsEvent("dexcom_share_connection_success")
    static let dexcomShareConnectionFailed = AnalyticsEvent("dexcom_share_connection_failed")
    static let dexcomShareDisconnected = AnalyticsEvent("dexcom_share_disconnected")
    static let dexcomShareSyncStarted = AnalyticsEvent("dexcom_share_sync_started")
    static let dexcomShareSyncCompleted = AnalyticsEvent("dexcom_share_sync_completed")
    static let dexcomShareSyncFailed = AnalyticsEvent("dexcom_share_sync_failed")
}

// MARK: - Preview Support

#if DEBUG
extension DexcomShareService {
    static var preview: DexcomShareService {
        let service = DexcomShareService(server: .international)
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
        let service = DexcomShareService(server: .international)
        service.isConnected = false
        service.connectionStatus = .disconnected
        return service
    }

    static var previewError: DexcomShareService {
        let service = DexcomShareService(server: .international)
        service.isConnected = false
        service.connectionStatus = .error(.invalidCredentials)
        return service
    }
}
#endif
