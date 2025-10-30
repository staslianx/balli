//
//  AnalyticsService.swift
//  balli
//
//  Analytics service for monitoring app health and usage
//  Swift 6 strict concurrency compliant
//

import Foundation
import OSLog

/// Analytics event types
enum AnalyticsEvent: String, Sendable {
    // Dexcom Integration Events
    case dexcomConnectionStarted = "dexcom_connection_started"
    case dexcomConnectionSuccess = "dexcom_connection_success"
    case dexcomConnectionFailed = "dexcom_connection_failed"
    case dexcomSyncStarted = "dexcom_sync_started"
    case dexcomSyncSuccess = "dexcom_sync_success"
    case dexcomSyncFailed = "dexcom_sync_failed"
    case dexcomTokenRefresh = "dexcom_token_refresh"
    case dexcomTokenRefreshFailed = "dexcom_token_refresh_failed"
    case dexcomRateLimitHit = "dexcom_rate_limit_hit"
    case dexcomDisconnected = "dexcom_disconnected"

    // Dexcom Share API Events
    case dexcomShareAutoRecovery = "dexcom_share_auto_recovery"
    case dexcomShareAutoRecoveryFailed = "dexcom_share_auto_recovery_failed"
    case dexcomShareCredentialsInvalid = "dexcom_share_credentials_invalid"

    // General Health Events
    case healthDataFetched = "health_data_fetched"
    case healthDataSaved = "health_data_saved"
    case healthKitAuthorizationRequested = "healthkit_authorization_requested"
    case healthKitAuthorizationGranted = "healthkit_authorization_granted"
    case healthKitAuthorizationDenied = "healthkit_authorization_denied"
}

/// Analytics service for tracking events and metrics
actor AnalyticsService {

    // MARK: - Properties

    private let logger = AppLoggers.Performance.main
    private var eventCounts: [String: Int] = [:]
    private var lastEventTime: [String: Date] = [:]

    // MARK: - Singleton

    static let shared = AnalyticsService()

    private init() {}

    // MARK: - Event Tracking

    /// Track an analytics event
    /// - Parameters:
    ///   - event: The event type to track
    ///   - properties: Additional properties for the event
    func track(_ event: AnalyticsEvent, properties: [String: String] = [:]) {
        let eventName = event.rawValue

        // Update event count
        eventCounts[eventName, default: 0] += 1
        lastEventTime[eventName] = Date()

        // Log the event
        var logMessage = "Analytics: \(eventName)"
        if !properties.isEmpty {
            let propsString = properties.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
            logMessage += " [\(propsString)]"
        }

        logger.info("\(logMessage)")

        // In production, send to analytics backend (Firebase Analytics, Mixpanel, etc.)
        // Example: Analytics.logEvent(eventName, parameters: properties)
    }

    /// Track an error event
    /// - Parameters:
    ///   - event: The event type
    ///   - error: The error that occurred
    func trackError(_ event: AnalyticsEvent, error: Error) {
        let errorDescription = error.localizedDescription
        track(event, properties: [
            "error": errorDescription,
            "error_type": String(describing: type(of: error))
        ])
    }

    /// Track a timed event (measures duration)
    /// - Parameter event: The event type to track
    /// - Returns: An async completion handler to call when the event completes
    func startTimedEvent(_ event: AnalyticsEvent) -> @Sendable () async -> Void {
        let startTime = Date()
        let eventName = event.rawValue

        logger.debug("Analytics: Started timing \(eventName)")

        return {
            let duration = Date().timeIntervalSince(startTime)
            await AnalyticsService.shared.track(event, properties: [
                "duration_ms": String(format: "%.0f", duration * 1000)
            ])
        }
    }

    // MARK: - Metrics

    /// Get the count for a specific event
    func getEventCount(_ event: AnalyticsEvent) -> Int {
        eventCounts[event.rawValue] ?? 0
    }

    /// Get the last time an event occurred
    func getLastEventTime(_ event: AnalyticsEvent) -> Date? {
        lastEventTime[event.rawValue]
    }

    /// Get all event counts (for debugging)
    func getAllEventCounts() -> [String: Int] {
        eventCounts
    }

    /// Reset all analytics data (for testing)
    func reset() {
        eventCounts.removeAll()
        lastEventTime.removeAll()
        logger.info("Analytics: Reset all data")
    }
}

// MARK: - Convenience Extensions

extension AnalyticsService {
    /// Track Dexcom sync with automatic success/failure
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

    /// Track Dexcom connection with automatic success/failure
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
}