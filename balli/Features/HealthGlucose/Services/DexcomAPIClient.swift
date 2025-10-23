//
//  DexcomAPIClient.swift
//  balli
//
//  Network client for Dexcom API (EU region)
//  Swift 6 strict concurrency compliant
//  Automatic token refresh on 401 errors
//

import Foundation
import OSLog

/// Network client for Dexcom API with automatic token management
actor DexcomAPIClient {

    // MARK: - Properties

    private let configuration: DexcomConfiguration
    private let authManager: DexcomAuthManager
    private let analytics = AnalyticsService.shared
    private let logger = AppLoggers.Health.glucose

    private let session: URLSession

    // MARK: - Initialization

    init(configuration: DexcomConfiguration, authManager: DexcomAuthManager) {
        self.configuration = configuration
        self.authManager = authManager

        // Configure URLSession with TLS 1.3
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.tlsMinimumSupportedProtocolVersion = .TLSv13
        sessionConfig.timeoutIntervalForRequest = 30
        sessionConfig.timeoutIntervalForResource = 60

        self.session = URLSession(configuration: sessionConfig)
    }

    // MARK: - API Methods

    /// Fetch glucose readings (EGVs) for date range
    func fetchGlucoseReadings(
        startDate: Date,
        endDate: Date? = nil,
        userId: String = "self"
    ) async throws -> [DexcomGlucoseReading] {
        // Validate time window
        let actualEndDate = endDate ?? Date()
        try configuration.validateTimeWindow(startDate: startDate, endDate: actualEndDate)

        // Build request
        guard var components = URLComponents(string: configuration.egvsEndpoint(userId: userId)) else {
            throw DexcomError.invalidConfiguration
        }

        components.queryItems = configuration.buildEGVQueryParameters(
            startDate: startDate,
            endDate: actualEndDate
        )

        guard let url = components.url else {
            throw DexcomError.invalidConfiguration
        }

        // Execute request
        let response: DexcomEGVResponse = try await executeRequest(url: url)

        logger.info("Fetched \(response.records.count) glucose readings")

        return response.records
    }

    /// Fetch user devices
    func fetchDevices(userId: String = "self") async throws -> [DexcomDevice] {
        guard let url = URL(string: configuration.devicesEndpoint(userId: userId)) else {
            throw DexcomError.invalidConfiguration
        }

        let response: DexcomDevicesResponse = try await executeRequest(url: url)

        logger.info("Fetched \(response.records.count) devices")

        return response.records
    }

    /// Fetch user events (carbs, insulin, exercise)
    func fetchEvents(
        startDate: Date,
        endDate: Date? = nil,
        userId: String = "self"
    ) async throws -> [DexcomUserEvent] {
        let actualEndDate = endDate ?? Date()
        try configuration.validateTimeWindow(startDate: startDate, endDate: actualEndDate)

        guard var components = URLComponents(string: configuration.eventsEndpoint(userId: userId)) else {
            throw DexcomError.invalidConfiguration
        }

        components.queryItems = configuration.buildEGVQueryParameters(
            startDate: startDate,
            endDate: actualEndDate
        )

        guard let url = components.url else {
            throw DexcomError.invalidConfiguration
        }

        let response: DexcomEventsResponse = try await executeRequest(url: url)

        logger.info("Fetched \(response.records.count) user events")

        return response.records
    }

    /// Fetch available data range
    func fetchDataRange(userId: String = "self") async throws -> DexcomDataRange {
        guard let url = URL(string: configuration.dataRangeEndpoint(userId: userId)) else {
            throw DexcomError.invalidConfiguration
        }

        let dataRange: DexcomDataRange = try await executeRequest(url: url)

        logger.info("Fetched data range")

        return dataRange
    }

    /// Fetch glucose statistics
    func fetchStatistics(
        startDate: Date,
        endDate: Date,
        userId: String = "self"
    ) async throws -> DexcomStatistics {
        try configuration.validateTimeWindow(startDate: startDate, endDate: endDate)

        guard var components = URLComponents(string: configuration.statisticsEndpoint(userId: userId)) else {
            throw DexcomError.invalidConfiguration
        }

        components.queryItems = configuration.buildEGVQueryParameters(
            startDate: startDate,
            endDate: endDate
        )

        guard let url = components.url else {
            throw DexcomError.invalidConfiguration
        }

        let stats: DexcomStatistics = try await executeRequest(url: url)

        logger.info("Fetched statistics: mean=\(stats.mean), stdDev=\(stats.stdDev)")

        return stats
    }

    // MARK: - Core Request Execution

    /// Execute authenticated API request with automatic token refresh
    private func executeRequest<T: Decodable>(
        url: URL,
        maxRetries: Int = 1
    ) async throws -> T {
        // Get access token
        let accessToken = try await authManager.getAccessToken()

        // Build request
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        logger.debug("Executing request: \(url.absoluteString)")

        // Execute request
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DexcomError.invalidResponse
        }

        logger.debug("Response status: \(httpResponse.statusCode)")

        // Handle response codes
        switch httpResponse.statusCode {
        case 200...299:
            // Success - decode response
            do {
                // Log raw JSON for debugging
                if let jsonString = String(data: data, encoding: .utf8) {
                    logger.debug("Raw JSON response: \(jsonString)")
                }

                // Use Dexcom-specific decoder that handles multiple date formats
                let decoder = JSONDecoder.dexcomDecoder()
                return try decoder.decode(T.self, from: data)
            } catch {
                logger.error("Decoding error: \(error.localizedDescription)")
                logger.error("Error details: \(error)")
                throw DexcomError.decodingError(error)
            }

        case 401:
            // Token expired - retry with refresh if we haven't exceeded max retries
            if maxRetries > 0 {
                logger.info("Token expired (401), refreshing and retrying...")
                // The authManager will handle token refresh automatically
                // Just retry the request
                return try await executeRequest(url: url, maxRetries: maxRetries - 1)
            } else {
                throw DexcomError.tokenExpired
            }

        case 429:
            // Rate limit exceeded
            logger.notice("Rate limit exceeded (429)")
            await analytics.track(.dexcomRateLimitHit, properties: [
                "url": url.path
            ])
            throw DexcomError.rateLimitExceeded

        case 404:
            // No data available
            logger.info("No data available (404)")
            throw DexcomError.noDataAvailable

        default:
            // Other error
            throw DexcomError.from(httpStatusCode: httpResponse.statusCode, data: data)
        }
    }

    // MARK: - Helper Methods

    /// Fetch latest glucose reading
    func fetchLatestGlucoseReading(userId: String = "self") async throws -> DexcomGlucoseReading? {
        // Get readings from last 24 hours
        let endDate = DexcomConfiguration.mostRecentAvailableDate()
        let startDate = Calendar.current.date(byAdding: .hour, value: -24, to: endDate) ?? endDate

        let readings = try await fetchGlucoseReadings(
            startDate: startDate,
            endDate: endDate,
            userId: userId
        )

        return readings.first // Readings are returned in descending order
    }

    /// Fetch today's glucose readings
    func fetchTodayGlucoseReadings(userId: String = "self") async throws -> [DexcomGlucoseReading] {
        let calendar = Calendar.current
        let endDate = DexcomConfiguration.mostRecentAvailableDate()
        let startDate = calendar.startOfDay(for: endDate)

        return try await fetchGlucoseReadings(
            startDate: startDate,
            endDate: endDate,
            userId: userId
        )
    }

    /// Fetch glucose readings for last N days
    func fetchRecentGlucoseReadings(
        days: Int,
        userId: String = "me"
    ) async throws -> [DexcomGlucoseReading] {
        let endDate = DexcomConfiguration.mostRecentAvailableDate()
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: endDate) ?? endDate

        return try await fetchGlucoseReadings(
            startDate: startDate,
            endDate: endDate,
            userId: userId
        )
    }
}

// MARK: - Debug Helpers

#if DEBUG
extension DexcomAPIClient {
    /// Get configuration for debugging
    nonisolated func getConfiguration() -> DexcomConfiguration {
        configuration
    }

    /// Check authentication status
    func isAuthenticated() async -> Bool {
        await authManager.isAuthenticated()
    }
}
#endif