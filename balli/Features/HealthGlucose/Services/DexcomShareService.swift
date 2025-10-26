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

    // MARK: - Singleton

    static let shared = DexcomShareService()

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
    private let glucoseRepository: GlucoseReadingRepository

    // MARK: - Initialization

    init(server: DexcomShareServer = .international, glucoseRepository: GlucoseReadingRepository = GlucoseReadingRepository()) {
        self.server = server
        self.authManager = DexcomShareAuthManager(server: server)
        self.apiClient = DexcomShareAPIClient(server: server, authManager: authManager)
        self.glucoseRepository = glucoseRepository

        Task {
            await checkConnectionStatus()
        }
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

                // Auto-save to CoreData with SHARE source identifier
                Task {
                    do {
                        let healthReading = reading.toHealthGlucoseReading()
                        self.logger.info("💾 SHARE API: Attempting to save reading to CoreData - \(healthReading.value) mg/dL at \(healthReading.timestamp)")
                        let saved = try await self.glucoseRepository.saveReading(from: healthReading)
                        if saved != nil {
                            self.logger.info("✅ SHARE API: Saved to CoreData with source: dexcom_share")
                        } else {
                            self.logger.debug("⚠️ SHARE API: Reading already exists in CoreData (duplicate)")
                        }
                    } catch {
                        self.logger.error("❌ SHARE API: Failed to save to CoreData: \(error.localizedDescription)")
                        // Don't throw - CoreData save failure shouldn't block sync
                    }
                }

                // Notify that new glucose data is available
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

                    // Notify that new glucose data is available
                    if reading != nil {
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
