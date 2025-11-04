//
//  AnalyticsServiceProtocol.swift
//  balli
//
//  Protocol definition for AnalyticsService
//  Enables dependency injection and testing
//

import Foundation

/// Protocol for analytics event tracking
protocol AnalyticsServiceProtocol: Actor {

    // MARK: - Event Tracking

    /// Track an analytics event
    /// - Parameters:
    ///   - event: The event type to track
    ///   - properties: Additional properties for the event
    func track(_ event: AnalyticsEvent, properties: [String: String])

    /// Track an error event
    /// - Parameters:
    ///   - event: The event type
    ///   - error: The error that occurred
    func trackError(_ event: AnalyticsEvent, error: Error)

    /// Track a timed event (measures duration)
    /// - Parameter event: The event type to track
    /// - Returns: An async completion handler to call when the event completes
    func startTimedEvent(_ event: AnalyticsEvent) -> @Sendable () async -> Void

    // MARK: - Metrics

    /// Get the count for a specific event
    /// - Parameter event: The event to get count for
    /// - Returns: Number of times the event occurred
    func getEventCount(_ event: AnalyticsEvent) -> Int

    /// Get the last time an event occurred
    /// - Parameter event: The event to check
    /// - Returns: Date of last occurrence, or nil if never occurred
    func getLastEventTime(_ event: AnalyticsEvent) -> Date?

    /// Get all event counts (for debugging)
    /// - Returns: Dictionary mapping event names to counts
    func getAllEventCounts() -> [String: Int]

    /// Reset all analytics data (for testing)
    func reset()

    // MARK: - Convenience Methods

    /// Track Dexcom sync with automatic success/failure
    /// - Parameter operation: The sync operation to track
    /// - Returns: Result of the operation
    func trackDexcomSync<T>(_ operation: @Sendable () async throws -> T) async throws -> T

    /// Track Dexcom connection with automatic success/failure
    /// - Parameter operation: The connection operation to track
    /// - Returns: Result of the operation
    func trackDexcomConnection<T>(_ operation: @Sendable () async throws -> T) async throws -> T
}
