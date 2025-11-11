//
//  MockAnalyticsService.swift
//  balliTests
//
//  Mock implementation of AnalyticsServiceProtocol for testing
//

import Foundation
@testable import balli

actor MockAnalyticsService: AnalyticsServiceProtocol {

    // MARK: - Mock State

    private(set) var trackedEvents: [AnalyticsEvent] = []
    private(set) var trackedProperties: [[String: String]] = []
    private(set) var trackedErrors: [(AnalyticsEvent, Error)] = []
    private(set) var eventCounts: [String: Int] = [:]
    private(set) var lastEventTime: [String: Date] = [:]

    // MARK: - Call Tracking

    private(set) var trackCallCount = 0
    private(set) var trackErrorCallCount = 0
    private(set) var startTimedEventCallCount = 0

    // MARK: - Event Tracking

    func track(_ event: AnalyticsEvent, properties: [String: String] = [:]) {
        trackCallCount += 1
        trackedEvents.append(event)
        trackedProperties.append(properties)

        let eventName = event.rawValue
        eventCounts[eventName, default: 0] += 1
        lastEventTime[eventName] = Date()
    }

    func trackError(_ event: AnalyticsEvent, error: Error) {
        trackErrorCallCount += 1
        trackedErrors.append((event, error))
        // Track synchronously
        track(event, properties: ["error": error.localizedDescription])
    }

    func startTimedEvent(_ event: AnalyticsEvent) -> @Sendable () async -> Void {
        startTimedEventCallCount += 1
        let startTime = Date()

        return { [weak self] in
            let duration = Date().timeIntervalSince(startTime)
            await self?.track(event, properties: [
                "duration_ms": String(format: "%.0f", duration * 1000)
            ])
        }
    }

    // MARK: - Metrics

    func getEventCount(_ event: AnalyticsEvent) -> Int {
        eventCounts[event.rawValue] ?? 0
    }

    func getLastEventTime(_ event: AnalyticsEvent) -> Date? {
        lastEventTime[event.rawValue]
    }

    func getAllEventCounts() -> [String: Int] {
        eventCounts
    }

    func reset() {
        trackedEvents.removeAll()
        trackedProperties.removeAll()
        trackedErrors.removeAll()
        eventCounts.removeAll()
        lastEventTime.removeAll()
        trackCallCount = 0
        trackErrorCallCount = 0
        startTimedEventCallCount = 0
    }

    // MARK: - Convenience Methods

    func trackDexcomSync<T>(_ operation: @Sendable () async throws -> T) async throws -> T {
        track(.dexcomSyncStarted)
        let complete = startTimedEvent(.dexcomSyncSuccess)

        do {
            let result = try await operation()
            await complete()
            return result
        } catch {
            trackError(.dexcomSyncFailed, error: error)
            throw error
        }
    }

    func trackDexcomConnection<T>(_ operation: @Sendable () async throws -> T) async throws -> T {
        track(.dexcomConnectionStarted)

        do {
            let result = try await operation()
            track(.dexcomConnectionSuccess)
            return result
        } catch {
            trackError(.dexcomConnectionFailed, error: error)
            throw error
        }
    }

    // MARK: - Test Helpers

    /// Check if a specific event was tracked
    func wasEventTracked(_ event: AnalyticsEvent) -> Bool {
        trackedEvents.contains(event)
    }

    /// Get the number of times a specific event was tracked
    func getTrackCount(for event: AnalyticsEvent) -> Int {
        trackedEvents.filter { $0 == event }.count
    }

    /// Get all properties for a specific event
    func getProperties(for event: AnalyticsEvent) -> [[String: String]] {
        let indices = trackedEvents.enumerated().compactMap { index, trackedEvent in
            trackedEvent == event ? index : nil
        }
        return indices.map { trackedProperties[$0] }
    }
}
