//
//  DexcomServiceProtocol.swift
//  balli
//
//  Protocol definition for DexcomService
//  Enables dependency injection and testing
//

import Foundation
import AuthenticationServices

/// Protocol for Dexcom integration service
@MainActor
protocol DexcomServiceProtocol: AnyObject, ObservableObject {

    // MARK: - Published Properties

    var isConnected: Bool { get }
    var connectionStatus: String { get }
    var isLoading: Bool { get }
    var error: DexcomError? { get }
    var latestReading: HealthGlucoseReading? { get }
    var readings: [HealthGlucoseReading] { get }

    // MARK: - Connection Management

    /// Initiate OAuth connection flow with Dexcom
    /// - Parameter presentationAnchor: The window to present the web auth session in
    func connect(presentationAnchor: ASPresentationAnchor) async throws

    /// Disconnect from Dexcom and clear stored credentials
    func disconnect() async

    /// Check current connection status
    func checkConnectionStatus() async

    // MARK: - Data Synchronization

    /// Sync glucose readings from Dexcom API
    /// - Parameter force: Force sync even if recently synced
    func syncData(force: Bool) async throws

    /// Fetch recent glucose readings
    /// - Parameter days: Number of days to fetch (default 7)
    /// - Returns: Array of glucose readings
    func fetchRecentReadings(days: Int) async throws -> [HealthGlucoseReading]

    // MARK: - Token Management

    /// Refresh OAuth access token if needed
    func refreshTokenIfNeeded() async throws

    // MARK: - Background Operations

    /// Perform background data fetch
    /// - Returns: Boolean indicating if new data was fetched
    func performBackgroundFetch() async -> Bool
}
