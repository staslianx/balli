//
//  MockDexcomService.swift
//  balliTests
//
//  Mock implementation of DexcomServiceProtocol for testing
//

import Foundation
import AuthenticationServices
import Combine
import HealthKit
@testable import balli

@MainActor
final class MockDexcomService: DexcomServiceProtocol {

    // MARK: - Published Properties

    @Published var isConnected = false
    @Published var connectionStatus: DexcomService.ConnectionStatus = .disconnected
    @Published var lastSync: Date?
    @Published var latestReading: DexcomGlucoseReading?
    @Published var currentDevice: DexcomDevice?
    @Published var error: DexcomError?

    // MARK: - Mock Configuration

    var shouldSucceedConnection = true
    var shouldSucceedSync = true
    var shouldSucceedFetch = true
    var shouldSucceedBackgroundFetch = true
    var mockError: DexcomError?
    var mockReadings: [HealthGlucoseReading] = []
    var mockDexcomReading: DexcomGlucoseReading?
    var mockDevices: [DexcomDevice] = []
    var hasNewDataInBackground = true

    // MARK: - Call Tracking

    var connectCallCount = 0
    var disconnectCallCount = 0
    var checkConnectionStatusCallCount = 0
    var syncDataCallCount = 0
    var fetchRecentReadingsCallCount = 0
    var fetchGlucoseReadingsCallCount = 0
    var fetchDevicesCallCount = 0

    var lastSyncIncludeHistorical: Bool?
    var lastFetchDays: Int?

    // MARK: - Connection Management

    func connect(presentationAnchor: ASPresentationAnchor) async throws {
        connectCallCount += 1

        if let error = mockError {
            self.error = error
            throw error
        }

        guard shouldSucceedConnection else {
            let error = DexcomError.networkError(NSError(domain: "MockDexcom", code: -1, userInfo: nil))
            self.error = error
            throw error
        }

        isConnected = true
        connectionStatus = .connected
    }

    func disconnect() async throws {
        disconnectCallCount += 1
        isConnected = false
        connectionStatus = .disconnected
        latestReading = nil
        error = nil
    }

    func checkConnectionStatus() async {
        checkConnectionStatusCallCount += 1

        if isConnected {
            connectionStatus = .connected
        } else {
            connectionStatus = .disconnected
        }
    }

    // MARK: - Data Synchronization

    func syncData(includeHistorical: Bool) async throws {
        syncDataCallCount += 1
        lastSyncIncludeHistorical = includeHistorical

        if let error = mockError {
            self.error = error
            throw error
        }

        guard shouldSucceedSync else {
            let error = DexcomError.networkError(NSError(domain: "MockDexcom", code: -1, userInfo: nil))
            self.error = error
            throw error
        }

        latestReading = mockDexcomReading
        lastSync = Date()
    }

    func fetchRecentReadings(days: Int = 7) async throws -> [HealthGlucoseReading] {
        fetchRecentReadingsCallCount += 1
        lastFetchDays = days

        if let error = mockError {
            self.error = error
            throw error
        }

        guard shouldSucceedFetch else {
            let error = DexcomError.networkError(NSError(domain: "MockDexcom", code: -1, userInfo: nil))
            self.error = error
            throw error
        }

        return mockReadings
    }

    func fetchGlucoseReadings(startDate: Date, endDate: Date?) async throws -> [HealthGlucoseReading] {
        fetchGlucoseReadingsCallCount += 1

        if let error = mockError {
            self.error = error
            throw error
        }

        guard shouldSucceedFetch else {
            let error = DexcomError.networkError(NSError(domain: "MockDexcom", code: -1, userInfo: nil))
            self.error = error
            throw error
        }

        return mockReadings
    }

    // MARK: - Device Management

    func fetchDevices() async throws -> [DexcomDevice] {
        fetchDevicesCallCount += 1

        if let error = mockError {
            self.error = error
            throw error
        }

        return mockDevices
    }

    // MARK: - Test Helpers

    /// Create a mock glucose reading for HealthKit
    static func mockHealthGlucoseReading(
        value: Double = 120.0,
        timestamp: Date = Date()
    ) -> HealthGlucoseReading {
        return HealthGlucoseReading(
            id: UUID(),
            value: value,
            unit: HKUnit(from: "mg/dL"),
            timestamp: timestamp,
            device: "Mock Dexcom",
            source: "Dexcom",
            metadata: nil
        )
    }

    /// Create a mock Dexcom API glucose reading
    static func mockDexcomGlucoseReading(
        value: Int = 120,
        timestamp: Date = Date()
    ) -> DexcomGlucoseReading {
        return DexcomGlucoseReading(
            recordId: UUID().uuidString,
            systemTime: timestamp,
            displayTime: timestamp,
            value: value,
            status: "ok",
            trend: "flat",
            trendRate: 0.0
        )
    }

    /// Reset all mock state
    func reset() {
        isConnected = false
        connectionStatus = .disconnected
        lastSync = nil
        error = nil
        latestReading = nil
        currentDevice = nil
        shouldSucceedConnection = true
        shouldSucceedSync = true
        shouldSucceedFetch = true
        shouldSucceedBackgroundFetch = true
        mockError = nil
        mockReadings = []
        mockDexcomReading = nil
        mockDevices = []
        hasNewDataInBackground = true
        connectCallCount = 0
        disconnectCallCount = 0
        checkConnectionStatusCallCount = 0
        syncDataCallCount = 0
        fetchRecentReadingsCallCount = 0
        fetchGlucoseReadingsCallCount = 0
        fetchDevicesCallCount = 0
        lastSyncIncludeHistorical = nil
        lastFetchDays = nil
    }
}
