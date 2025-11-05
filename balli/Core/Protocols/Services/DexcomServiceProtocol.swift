//
//  DexcomServiceProtocol.swift
//  balli
//
//  Protocol definition for DexcomService
//  Enables dependency injection and testing
//  Swift 6 strict concurrency compliant
//

import Foundation
import CoreData
import AuthenticationServices

/// Protocol for Dexcom CGM integration service
@MainActor
protocol DexcomServiceProtocol: ObservableObject {
    // MARK: - Published State
    var isConnected: Bool { get }
    var connectionStatus: DexcomService.ConnectionStatus { get }
    var lastSync: Date? { get }
    var latestReading: DexcomGlucoseReading? { get }
    var currentDevice: DexcomDevice? { get }
    var error: DexcomError? { get }

    // MARK: - Connection Management
    func connect(presentationAnchor: ASPresentationAnchor) async throws
    func disconnect() async throws
    func checkConnectionStatus() async

    // MARK: - Data Fetching
    func syncData(includeHistorical: Bool) async throws
    func fetchRecentReadings(days: Int) async throws -> [HealthGlucoseReading]
    func fetchGlucoseReadings(startDate: Date, endDate: Date?) async throws -> [HealthGlucoseReading]

    // MARK: - Device Management
    func fetchDevices() async throws -> [DexcomDevice]
}
