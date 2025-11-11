//
//  DexcomShareServiceProtocol.swift
//  balli
//
//  Protocol for Dexcom SHARE API service to enable dependency injection and testing
//  Swift 6 strict concurrency compliant
//

import Foundation

/// Protocol defining the interface for Dexcom SHARE API service
@MainActor
protocol DexcomShareServiceProtocol: ObservableObject {
    // MARK: - Published State
    var isConnected: Bool { get }
    var connectionStatus: DexcomShareService.ConnectionStatus { get }
    var lastSync: Date? { get }
    var latestReading: DexcomShareGlucoseReading? { get }
    var error: DexcomShareError? { get }

    // MARK: - Connection Management
    func connect(username: String, password: String) async throws
    func disconnect() async throws
    func checkConnectionStatus(trustCache: Bool) async

    // P1 FIX (Issue #6): Extension provides default parameter for backward compatibility
    func checkConnectionStatus() async

    // MARK: - Data Fetching
    func syncData() async throws
    func fetchGlucoseReadings(startDate: Date, endDate: Date) async throws -> [DexcomShareGlucoseReading]
    func fetchLatestReading() async throws -> DexcomShareGlucoseReading?
    func fetchRecentReadings(hours: Int) async throws -> [DexcomShareGlucoseReading]

    // MARK: - Helper Methods
    func testConnection() async throws
    nonisolated func getServer() -> DexcomShareServer
    func convertToHealthReadings(_ shareReadings: [DexcomShareGlucoseReading]) -> [HealthGlucoseReading]
}

// P1 FIX (Issue #6): Default implementation for backward compatibility
extension DexcomShareServiceProtocol {
    func checkConnectionStatus() async {
        await checkConnectionStatus(trustCache: false)
    }
}
