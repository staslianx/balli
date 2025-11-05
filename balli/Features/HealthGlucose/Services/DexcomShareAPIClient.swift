//
//  DexcomShareAPIClient.swift
//  balli
//
//  Network client for Dexcom SHARE API (unofficial)
//  Swift 6 strict concurrency compliant
//  Automatic session token management
//
//  IMPORTANT: This is an unofficial API used by Nightscout, Loop, xDrip
//  For personal use only - provides ~5 min delay vs 3-hour official API delay
//

import Foundation
import OSLog

/// Network client for Dexcom SHARE API with automatic session management
actor DexcomShareAPIClient {

    // MARK: - Properties

    private let server: DexcomShareServer
    private let applicationId: DexcomShareApplicationID
    private let authManager: DexcomShareAuthManager
    private let analytics = AnalyticsService.shared
    private let logger = AppLoggers.Health.glucose

    private let session: URLSession

    // MARK: - Initialization

    init(
        server: DexcomShareServer,
        applicationId: DexcomShareApplicationID = .default,
        authManager: DexcomShareAuthManager
    ) {
        self.server = server
        self.applicationId = applicationId
        self.authManager = authManager

        // Configure URLSession with TLS 1.3
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.tlsMinimumSupportedProtocolVersion = .TLSv13
        sessionConfig.timeoutIntervalForRequest = 30
        sessionConfig.timeoutIntervalForResource = 60

        self.session = URLSession(configuration: sessionConfig)
    }

    // MARK: - API Methods

    /// Fetch latest glucose readings from SHARE API
    /// - Parameter maxCount: Maximum number of readings to fetch (1-288)
    /// - Parameter minutes: How many minutes of history to fetch (alternative to maxCount)
    /// - Returns: Array of glucose readings in descending order (newest first)
    func fetchGlucoseReadings(
        maxCount: Int = DexcomShareServer.defaultReadings,
        minutes: Int? = nil
    ) async throws -> [DexcomShareGlucoseReading] {
        // Validate maxCount
        let validatedCount = min(max(maxCount, DexcomShareServer.minReadings), DexcomShareServer.maxReadings)

        // Build request - safely unwrap URLComponents
        guard var components = URLComponents(url: server.glucoseURL, resolvingAgainstBaseURL: false) else {
            // Swift 6: Explicit self required when capturing actor property in closure (string interpolation)
            logger.error("Failed to create URLComponents from glucose URL: \(self.server.glucoseURL)")
            throw DexcomShareError.invalidConfiguration
        }

        // Get session ID
        let sessionId = try await authManager.getSessionId()

        logger.debug("Using session ID for data fetch: \(sessionId)")

        // Add query parameters
        components.queryItems = [
            URLQueryItem(name: "sessionId", value: sessionId),
            URLQueryItem(name: "minutes", value: String(minutes ?? 1440)), // Default 24 hours
            URLQueryItem(name: "maxCount", value: String(validatedCount))
        ]

        guard let url = components.url else {
            throw DexcomShareError.invalidConfiguration
        }

        logger.debug("Fetching SHARE glucose readings: maxCount=\(validatedCount)")

        // Execute request
        let readings: [DexcomShareGlucoseReading] = try await executeRequest(url: url)

        logger.info("Fetched \(readings.count) SHARE glucose readings")

        return readings
    }

    /// Fetch most recent glucose reading
    func fetchLatestGlucoseReading() async throws -> DexcomShareGlucoseReading? {
        // Request last 60 minutes to be more reliable (CGM readings are every 5 min)
        // This gives us up to 12 readings to find the latest
        let readings = try await fetchGlucoseReadings(maxCount: 12, minutes: 60)
        return readings.first
    }

    /// Fetch readings for specific time range
    /// - Parameter startDate: Start of time range
    /// - Parameter endDate: End of time range
    /// - Returns: Filtered glucose readings within time range
    func fetchGlucoseReadings(
        startDate: Date,
        endDate: Date = Date()
    ) async throws -> [DexcomShareGlucoseReading] {
        // Calculate minutes difference
        let minutes = Int(endDate.timeIntervalSince(startDate) / 60)

        // Calculate expected number of readings (one per 5 minutes)
        let expectedReadings = min(minutes / 5, DexcomShareServer.maxReadings)

        // Fetch readings
        let allReadings = try await fetchGlucoseReadings(
            maxCount: expectedReadings,
            minutes: minutes
        )

        // Filter to exact time range (SHARE might return slightly more)
        return allReadings.filter { reading in
            reading.displayTime >= startDate && reading.displayTime <= endDate
        }
    }

    // MARK: - Core Request Execution

    /// Execute authenticated SHARE API request with automatic session refresh
    private func executeRequest<T: Decodable>(
        url: URL,
        maxRetries: Int = 1
    ) async throws -> T {
        // Build request
        var request = URLRequest(url: url)
        request.httpMethod = "POST" // SHARE API uses POST even for reads
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Dexcom Share/3.0.2.11 CFNetwork/672.0.2 Darwin/14.0.0", forHTTPHeaderField: "User-Agent")

        logger.debug("Executing SHARE request: \(url.absoluteString)")

        // Execute request
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DexcomShareError.invalidResponse
        }

        logger.debug("SHARE response status: \(httpResponse.statusCode)")

        // Handle response codes
        switch httpResponse.statusCode {
        case 200...299:
            // Success - decode response
            do {
                // Log raw JSON for debugging
                if let jsonString = String(data: data, encoding: .utf8) {
                    logger.debug("Raw SHARE JSON response: \(jsonString)")

                    // Handle empty response (no data available)
                    if jsonString.isEmpty || jsonString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        logger.info("⚠️ SHARE API returned empty response (no glucose data available)")

                        // For array types, return empty array
                        if T.self == [DexcomShareGlucoseReading].self {
                            guard let emptyArray = [] as? T else {
                                logger.error("Type mismatch: Cannot cast empty array to \(T.self)")
                                throw DexcomShareError.invalidResponse
                            }
                            return emptyArray
                        }

                        // For optional types, this will be handled by caller
                        throw DexcomShareError.noDataAvailable
                    }
                }

                // SHARE API returns plain JSON arrays, not wrapped objects
                let decoder = JSONDecoder()
                return try decoder.decode(T.self, from: data)
            } catch let error as DexcomShareError {
                // Re-throw our custom errors
                throw error
            } catch {
                logger.error("SHARE decoding error: \(error.localizedDescription)")

                // Log detailed decoding error
                if let decodingError = error as? DecodingError {
                    switch decodingError {
                    case .keyNotFound(let key, let context):
                        logger.error("Missing key '\(key.stringValue)' - \(context.debugDescription)")
                    case .typeMismatch(let type, let context):
                        logger.error("Type mismatch for \(type) - \(context.debugDescription)")
                    case .valueNotFound(let type, let context):
                        logger.error("Value not found for \(type) - \(context.debugDescription)")
                    case .dataCorrupted(let context):
                        logger.error("Data corrupted - \(context.debugDescription)")
                    @unknown default:
                        logger.error("Unknown decoding error: \(error.localizedDescription)")
                    }
                }

                // Try to decode error response
                if let errorResponse = try? JSONDecoder().decode(DexcomShareErrorResponse.self, from: data) {
                    throw DexcomShareError.apiError(errorResponse.message ?? "Unknown error")
                }

                throw DexcomShareError.decodingError(error)
            }

        case 401:
            // Session expired - retry with refresh if we haven't exceeded max retries
            if maxRetries > 0 {
                logger.info("SHARE session expired (401), refreshing and retrying...")
                // Clear session and retry
                await authManager.clearSession()
                return try await executeRequest(url: url, maxRetries: maxRetries - 1)
            } else {
                throw DexcomShareError.sessionExpired
            }

        case 500:
            // SHARE API sometimes returns 500 for invalid session
            if maxRetries > 0 {
                logger.info("SHARE server error (500), clearing session and retrying...")
                await authManager.clearSession()
                return try await executeRequest(url: url, maxRetries: maxRetries - 1)
            } else {
                throw DexcomShareError.serverError
            }

        case 404:
            // No data available
            logger.info("No SHARE data available (404)")
            throw DexcomShareError.noDataAvailable

        default:
            // Other error
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            logger.error("SHARE API error (\(httpResponse.statusCode)): \(errorMessage)")
            throw DexcomShareError.httpError(httpResponse.statusCode, errorMessage)
        }
    }

    // MARK: - Helper Methods

    /// Test connection to SHARE API
    func testConnection() async throws {
        logger.info("Testing SHARE API connection...")

        // Try to fetch 1 reading
        _ = try await fetchGlucoseReadings(maxCount: 1, minutes: 10)

        logger.info("✅ SHARE API connection successful")
    }

    /// Get current server configuration
    nonisolated func getServer() -> DexcomShareServer {
        server
    }

    /// Check if authenticated
    func isAuthenticated() async -> Bool {
        await authManager.isAuthenticated()
    }
}

// MARK: - SHARE API Errors

enum DexcomShareError: LocalizedError, Sendable {
    case invalidConfiguration
    case invalidCredentials
    case sessionExpired
    case serverError
    case noDataAvailable
    case decodingError(Error)
    case apiError(String)
    case httpError(Int, String)
    case invalidResponse
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidConfiguration:
            return NSLocalizedString("error.dexcom.invalidConfiguration", comment: "Invalid configuration")
        case .invalidCredentials:
            return NSLocalizedString("error.dexcom.invalidCredentials", comment: "Invalid credentials")
        case .sessionExpired:
            return NSLocalizedString("error.dexcom.sessionExpired", comment: "Session expired")
        case .serverError:
            return NSLocalizedString("error.dexcom.serverError", comment: "Server error")
        case .noDataAvailable:
            return NSLocalizedString("error.dexcom.noDataAvailable", comment: "No data available")
        case .decodingError(let error):
            return String(format: NSLocalizedString("error.dexcom.decodingError", comment: "Decoding error"), error.localizedDescription)
        case .apiError(let message):
            return String(format: NSLocalizedString("error.dexcom.apiError", comment: "API error"), message)
        case .httpError(let code, let message):
            return String(format: NSLocalizedString("error.dexcom.httpError", comment: "HTTP error"), code, message)
        case .invalidResponse:
            return NSLocalizedString("error.dexcom.invalidResponse", comment: "Invalid response")
        case .networkError(let error):
            return String(format: NSLocalizedString("error.dexcom.networkError", comment: "Network error"), error.localizedDescription)
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .invalidCredentials:
            return NSLocalizedString("recovery.dexcom.invalidCredentials", comment: "Check credentials")
        case .sessionExpired:
            return NSLocalizedString("recovery.dexcom.sessionExpired", comment: "Auto reconnect")
        case .serverError:
            return NSLocalizedString("recovery.dexcom.serverError", comment: "Try later")
        case .noDataAvailable:
            return NSLocalizedString("recovery.dexcom.noDataAvailable", comment: "Check CGM")
        default:
            return nil
        }
    }
}

// MARK: - Debug Helpers

#if DEBUG
extension DexcomShareAPIClient {
    /// Get current session status for debugging
    func getSessionStatus() async -> String {
        if await authManager.isAuthenticated() {
            return "Authenticated"
        } else {
            return "Not authenticated"
        }
    }
}
#endif
