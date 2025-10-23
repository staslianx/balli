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

        // Build request
        var components = URLComponents(url: server.glucoseURL, resolvingAgainstBaseURL: false)!

        // Get session ID
        let sessionId = try await authManager.getSessionId()

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
        let readings = try await fetchGlucoseReadings(maxCount: 1, minutes: 10)
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
                    logger.debug("Raw SHARE JSON response: \(jsonString.prefix(500))...")
                }

                // SHARE API returns plain JSON arrays, not wrapped objects
                let decoder = JSONDecoder()
                return try decoder.decode(T.self, from: data)
            } catch {
                logger.error("SHARE decoding error: \(error.localizedDescription)")

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
            return "SHARE API yapılandırması geçersiz"
        case .invalidCredentials:
            return "Dexcom SHARE kullanıcı adı veya şifresi yanlış"
        case .sessionExpired:
            return "Dexcom SHARE oturumu sona erdi. Lütfen tekrar giriş yapın."
        case .serverError:
            return "Dexcom SHARE sunucu hatası. Lütfen daha sonra tekrar deneyin."
        case .noDataAvailable:
            return "SHARE API'den veri alınamıyor"
        case .decodingError(let error):
            return "SHARE veri formatı hatası: \(error.localizedDescription)"
        case .apiError(let message):
            return "SHARE API hatası: \(message)"
        case .httpError(let code, let message):
            return "SHARE HTTP hatası (\(code)): \(message)"
        case .invalidResponse:
            return "SHARE'den geçersiz yanıt alındı"
        case .networkError(let error):
            return "Ağ hatası: \(error.localizedDescription)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .invalidCredentials:
            return "Ayarlardan Dexcom SHARE kullanıcı adı ve şifrenizi kontrol edin"
        case .sessionExpired:
            return "Uygulama otomatik olarak yeniden bağlanmayı dener"
        case .serverError:
            return "Birkaç dakika sonra tekrar deneyin"
        case .noDataAvailable:
            return "Dexcom CGM'nizin düzgün çalıştığından emin olun"
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
