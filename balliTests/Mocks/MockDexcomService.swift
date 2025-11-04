//
//  MockDexcomService.swift
//  balliTests
//
//  Mock implementation of DexcomServiceProtocol for testing
//

import Foundation
import AuthenticationServices
import Combine
@testable import balli

@MainActor
final class MockDexcomService: DexcomServiceProtocol {

    // MARK: - Published Properties

    @Published var isConnected = false
    @Published var connectionStatus = "Not Connected"
    @Published var isLoading = false
    @Published var error: DexcomError?
    @Published var latestReading: HealthGlucoseReading?
    @Published var readings: [HealthGlucoseReading] = []

    // MARK: - Mock Configuration

    var shouldSucceedConnection = true
    var shouldSucceedSync = true
    var shouldSucceedFetch = true
    var shouldSucceedTokenRefresh = true
    var shouldSucceedBackgroundFetch = true
    var mockError: DexcomError?
    var mockReadings: [HealthGlucoseReading] = []
    var hasNewDataInBackground = true

    // MARK: - Call Tracking

    var connectCallCount = 0
    var disconnectCallCount = 0
    var checkConnectionStatusCallCount = 0
    var syncDataCallCount = 0
    var fetchRecentReadingsCallCount = 0
    var refreshTokenIfNeededCallCount = 0
    var performBackgroundFetchCallCount = 0

    var lastSyncForce: Bool?
    var lastFetchDays: Int?

    // MARK: - Connection Management

    func connect(presentationAnchor: ASPresentationAnchor) async throws {
        connectCallCount += 1
        isLoading = true

        if let error = mockError {
            isLoading = false
            self.error = error
            throw error
        }

        guard shouldSucceedConnection else {
            isLoading = false
            let error = DexcomError.authenticationFailed
            self.error = error
            throw error
        }

        isConnected = true
        connectionStatus = "Connected"
        isLoading = false
    }

    func disconnect() async {
        disconnectCallCount += 1
        isConnected = false
        connectionStatus = "Not Connected"
        readings.removeAll()
        latestReading = nil
        error = nil
    }

    func checkConnectionStatus() async {
        checkConnectionStatusCallCount += 1

        if isConnected {
            connectionStatus = "Connected"
        } else {
            connectionStatus = "Not Connected"
        }
    }

    // MARK: - Data Synchronization

    func syncData(force: Bool = false) async throws {
        syncDataCallCount += 1
        lastSyncForce = force
        isLoading = true

        if let error = mockError {
            isLoading = false
            self.error = error
            throw error
        }

        guard shouldSucceedSync else {
            isLoading = false
            let error = DexcomError.networkError(NSError(domain: "MockDexcom", code: -1, userInfo: nil))
            self.error = error
            throw error
        }

        readings = mockReadings
        latestReading = mockReadings.first
        isLoading = false
    }

    func fetchRecentReadings(days: Int = 7) async throws -> [HealthGlucoseReading] {
        fetchRecentReadingsCallCount += 1
        lastFetchDays = days
        isLoading = true

        if let error = mockError {
            isLoading = false
            self.error = error
            throw error
        }

        guard shouldSucceedFetch else {
            isLoading = false
            let error = DexcomError.networkError(NSError(domain: "MockDexcom", code: -1, userInfo: nil))
            self.error = error
            throw error
        }

        isLoading = false
        return mockReadings
    }

    // MARK: - Token Management

    func refreshTokenIfNeeded() async throws {
        refreshTokenIfNeededCallCount += 1

        if let error = mockError {
            self.error = error
            throw error
        }

        guard shouldSucceedTokenRefresh else {
            let error = DexcomError.tokenRefreshFailed
            self.error = error
            throw error
        }
    }

    // MARK: - Background Operations

    func performBackgroundFetch() async -> Bool {
        performBackgroundFetchCallCount += 1

        if !shouldSucceedBackgroundFetch {
            return false
        }

        if hasNewDataInBackground {
            readings = mockReadings
            latestReading = mockReadings.first
        }

        return hasNewDataInBackground
    }

    // MARK: - Test Helpers

    /// Create a mock glucose reading
    static func mockGlucoseReading(
        value: Double = 120.0,
        timestamp: Date = Date(),
        trend: GlucoseTrend = .flat
    ) -> HealthGlucoseReading {
        return HealthGlucoseReading(
            id: UUID(),
            timestamp: timestamp,
            glucoseValue: value,
            unit: "mg/dL",
            source: .dexcom,
            trend: trend
        )
    }

    /// Reset all mock state
    func reset() {
        isConnected = false
        connectionStatus = "Not Connected"
        isLoading = false
        error = nil
        latestReading = nil
        readings = []
        shouldSucceedConnection = true
        shouldSucceedSync = true
        shouldSucceedFetch = true
        shouldSucceedTokenRefresh = true
        shouldSucceedBackgroundFetch = true
        mockError = nil
        mockReadings = []
        hasNewDataInBackground = true
        connectCallCount = 0
        disconnectCallCount = 0
        checkConnectionStatusCallCount = 0
        syncDataCallCount = 0
        fetchRecentReadingsCallCount = 0
        refreshTokenIfNeededCallCount = 0
        performBackgroundFetchCallCount = 0
        lastSyncForce = nil
        lastFetchDays = nil
    }
}
