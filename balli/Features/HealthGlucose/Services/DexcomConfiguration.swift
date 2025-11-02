//
//  DexcomConfiguration.swift
//  balli
//
//  Dexcom API EU region configuration
//  Swift 6 strict concurrency compliant
//

import Foundation
import OSLog

/// Dexcom API configuration for EU region
struct DexcomConfiguration: Sendable {

    // MARK: - Environment

    enum Environment: String, Sendable {
        case production
        case sandbox

        var baseURL: String {
            switch self {
            case .production:
                return "https://api.dexcom.eu"
            case .sandbox:
                return "https://sandbox-api.dexcom.com"
            }
        }
    }

    // MARK: - Properties

    let environment: Environment
    let clientId: String
    let clientSecret: String
    let redirectURI: String

    // MARK: - Initialization

    init(
        environment: Environment = .production,
        clientId: String,
        clientSecret: String,
        redirectURI: String = "com.anaxoniclabs.balli://oauth-callback"
    ) {
        self.environment = environment
        self.clientId = clientId
        self.clientSecret = clientSecret
        self.redirectURI = redirectURI
    }

    // MARK: - Computed Properties

    /// Base URL for API requests
    var baseURL: String {
        environment.baseURL
    }

    /// OAuth authorization URL
    var authorizationURL: String {
        "\(baseURL)/v2/oauth2/login"
    }

    /// OAuth token endpoint
    var tokenURL: String {
        "\(baseURL)/v2/oauth2/token"
    }

    // MARK: - API Endpoints (v3)

    /// Get estimated glucose values (EGVs)
    /// - Parameter userId: User ID (must be "self" for Dexcom API v3)
    /// - Returns: Full endpoint URL
    func egvsEndpoint(userId: String = "self") -> String {
        "\(baseURL)/v3/users/\(userId)/egvs"
    }

    /// Get user devices
    /// - Parameter userId: User ID (must be "self" for Dexcom API v3)
    /// - Returns: Full endpoint URL
    func devicesEndpoint(userId: String = "self") -> String {
        "\(baseURL)/v3/users/\(userId)/devices"
    }

    /// Get user events (carbs, insulin, exercise)
    /// - Parameter userId: User ID (must be "self" for Dexcom API v3)
    /// - Returns: Full endpoint URL
    func eventsEndpoint(userId: String = "self") -> String {
        "\(baseURL)/v3/users/\(userId)/events"
    }

    /// Get calibration events
    /// - Parameter userId: User ID (must be "self" for Dexcom API v3)
    /// - Returns: Full endpoint URL
    func calibrationsEndpoint(userId: String = "self") -> String {
        "\(baseURL)/v3/users/\(userId)/calibrations"
    }

    /// Get data range (available data dates)
    /// - Parameter userId: User ID (must be "self" for Dexcom API v3)
    /// - Returns: Full endpoint URL
    func dataRangeEndpoint(userId: String = "self") -> String {
        "\(baseURL)/v3/users/\(userId)/dataRange"
    }

    /// Get statistics
    /// - Parameter userId: User ID (must be "self" for Dexcom API v3)
    /// - Returns: Full endpoint URL
    func statisticsEndpoint(userId: String = "self") -> String {
        "\(baseURL)/v3/users/\(userId)/statistics"
    }

    // MARK: - OAuth Scopes

    /// Required OAuth scopes for Dexcom API
    static let requiredScopes = [
        "offline_access" // Enables refresh tokens
    ]

    /// OAuth scope string for authorization
    var scopeString: String {
        Self.requiredScopes.joined(separator: " ")
    }

    // MARK: - API Constraints

    /// Maximum time window for single API request (30 days)
    static let maxTimeWindowDays = 30

    /// EU data delay in hours (3 hours for EU region)
    static let euDataDelayHours = 3

    /// Rate limit: API calls per hour (enforced by Dexcom, not client-side)
    /// Dexcom API will return 429 if this limit is exceeded
    static let rateLimitPerHour = 60_000

    // MARK: - Date Formatting

    /// Date formatter for Dexcom API query parameters
    /// Dexcom expects: "2025-02-18T18:30:05.561" (NO 'Z' timezone indicator)
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
        formatter.timeZone = TimeZone(secondsFromGMT: 0) // UTC
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    /// Format date for API request
    func formatDate(_ date: Date) -> String {
        Self.dateFormatter.string(from: date)
    }

    /// Parse date from API response
    func parseDate(_ dateString: String) -> Date? {
        Self.dateFormatter.date(from: dateString)
    }

    // MARK: - Data Delay Helper

    /// Get the most recent date that has available data (accounting for 3-hour EU delay)
    static func mostRecentAvailableDate() -> Date {
        Date().addingTimeInterval(-TimeInterval(euDataDelayHours * 3600))
    }

    /// Check if a date is within the available data range
    static func isDateAvailable(_ date: Date) -> Bool {
        date <= mostRecentAvailableDate()
    }

    // MARK: - Query Parameters Helper

    /// Build query parameters for EGV request
    func buildEGVQueryParameters(
        startDate: Date,
        endDate: Date? = nil
    ) -> [URLQueryItem] {
        var params = [
            URLQueryItem(name: "startDate", value: formatDate(startDate))
        ]

        if let endDate = endDate {
            params.append(URLQueryItem(name: "endDate", value: formatDate(endDate)))
        }

        return params
    }

    // MARK: - Validation

    /// Validate time window for API request
    func validateTimeWindow(startDate: Date, endDate: Date) throws {
        let calendar = Calendar.current
        let daysDifference = calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 0

        if daysDifference > Self.maxTimeWindowDays {
            throw DexcomConfigurationError.timeWindowTooLarge(days: daysDifference)
        }

        if startDate > endDate {
            throw DexcomConfigurationError.invalidDateRange
        }

        if !Self.isDateAvailable(endDate) {
            throw DexcomConfigurationError.dateNotYetAvailable(delay: Self.euDataDelayHours)
        }
    }
}

// MARK: - Configuration Errors

enum DexcomConfigurationError: LocalizedError {
    case timeWindowTooLarge(days: Int)
    case invalidDateRange
    case dateNotYetAvailable(delay: Int)
    case missingCredentials

    var errorDescription: String? {
        switch self {
        case .timeWindowTooLarge(let days):
            return "Time window too large (\(days) days). Maximum is \(DexcomConfiguration.maxTimeWindowDays) days."
        case .invalidDateRange:
            return "Invalid date range: start date must be before end date."
        case .dateNotYetAvailable(let delay):
            return "Data not yet available. EU region has a \(delay)-hour delay."
        case .missingCredentials:
            return "Dexcom API credentials are missing. Please configure clientId and clientSecret."
        }
    }
}

// MARK: - SHARE API Credentials (Hardcoded for Personal App)

extension DexcomConfiguration {
    /// Hardcoded SHARE API credentials
    /// SECURITY NOTE: This is safe for a personal app with 2 users that is never distributed.
    /// These credentials enable automatic SHARE API connection without manual entry.
    struct ShareCredentials: Sendable {
        let username: String
        let password: String
        let server: String // "international" or "us"

        static let personal = ShareCredentials(
            username: "dilaraturann21@icloud.com", // TODO: Replace with actual Dexcom username
            password: "FafaTuka2117", // TODO: Replace with actual Dexcom password
            server: "international" // EU region uses international server
        )
    }

    /// Get hardcoded SHARE credentials
    static var shareCredentials: ShareCredentials {
        .personal
    }
}

// MARK: - Default Configuration

extension DexcomConfiguration {
    /// Create configuration from environment or defaults
    /// In production, credentials should come from secure storage or environment variables
    static func `default`() -> DexcomConfiguration {
        // Using hardcoded credentials for development
        let clientId = "vmWWRLyONNvdXQUDGd7PB9M5RclN9BeL"
        let clientSecret = "G0dxbxOprGi13TGT"
        // This matches what was registered with Dexcom Developer Portal
        // CRITICAL: This MUST exactly match the registered redirect URI at https://developer.dexcom.com
        let redirectURI = "com.anaxoniclabs.balli://callback"

        #if DEBUG
        // Log configuration warning
        Task {
            await ConfigurationLogger.shared.logOnce(clientId: clientId, redirectURI: redirectURI)
        }
        #endif

        return DexcomConfiguration(
            environment: .production,
            clientId: clientId,
            clientSecret: clientSecret,
            redirectURI: redirectURI
        )
    }

    /// Sandbox configuration for testing
    static func sandbox(clientId: String, clientSecret: String) -> DexcomConfiguration {
        DexcomConfiguration(
            environment: .sandbox,
            clientId: clientId,
            clientSecret: clientSecret
        )
    }
}

// MARK: - Debug Helpers

#if DEBUG
extension DexcomConfiguration {
    /// Mock configuration for SwiftUI previews and testing
    static var mock: DexcomConfiguration {
        DexcomConfiguration(
            environment: .sandbox,
            clientId: "mock-client-id",
            clientSecret: "mock-client-secret",
            redirectURI: "com.anaxoniclabs.balli://oauth-callback"
        )
    }
}

/// Actor for thread-safe configuration logging
private actor ConfigurationLogger {
    private var hasLogged = false

    static let shared = ConfigurationLogger()

    func logOnce(clientId: String, redirectURI: String) {
        guard !hasLogged else { return }

        let logger = AppLoggers.Health.glucose
        logger.debug("Dexcom configuration initialized - clientId: \(String(clientId.prefix(8)))..., redirectURI: \(redirectURI)")
        logger.warning("⚠️ Redirect URI must EXACTLY match Dexcom Developer Portal: \(redirectURI)")

        hasLogged = true
    }
}
#endif