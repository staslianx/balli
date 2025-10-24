//
//  DexcomShareAuthManager.swift
//  balli
//
//  Session authentication manager for Dexcom SHARE API (unofficial)
//  Swift 6 strict concurrency compliant
//  Simple username/password authentication with 24-hour session tokens
//
//  IMPORTANT: This is an unofficial API used by Nightscout, Loop, xDrip
//  For personal use only - provides ~5 min delay vs 3-hour official API delay
//

import Foundation
import OSLog

/// Session authentication manager for Dexcom SHARE API
/// Much simpler than OAuth - just username/password with 24-hour session tokens
actor DexcomShareAuthManager {

    // MARK: - Properties

    private let server: DexcomShareServer
    private let applicationId: DexcomShareApplicationID
    private let keychainStorage: DexcomShareKeychainStorage
    private let analytics = AnalyticsService.shared
    private let logger = AppLoggers.Auth.main

    private var currentSessionId: String?
    private var sessionExpiry: Date?
    private var isAuthenticating = false
    private var authContinuations: [CheckedContinuation<String, Error>] = []

    private let session: URLSession

    // MARK: - Initialization

    init(
        server: DexcomShareServer,
        applicationId: DexcomShareApplicationID = .default
    ) {
        self.server = server
        self.applicationId = applicationId
        self.keychainStorage = DexcomShareKeychainStorage()

        // Configure URLSession with TLS 1.3
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.tlsMinimumSupportedProtocolVersion = .TLSv13
        sessionConfig.timeoutIntervalForRequest = 30
        sessionConfig.timeoutIntervalForResource = 60

        self.session = URLSession(configuration: sessionConfig)
    }

    // MARK: - Authentication Status

    /// Check if user has stored credentials
    func hasCredentials() async -> Bool {
        do {
            return try await keychainStorage.hasCredentials()
        } catch {
            logger.error("Failed to check credentials: \(error.localizedDescription)")
            return false
        }
    }

    /// Check if currently authenticated with valid session
    func isAuthenticated() async -> Bool {
        // Check if we have a session ID
        if currentSessionId == nil {
            // Try to load from keychain
            do {
                if let session = try await keychainStorage.getSessionInfo() {
                    currentSessionId = session.sessionId
                    sessionExpiry = session.expiry
                }
            } catch {
                return false
            }
        }

        // Check if session is still valid
        guard let expiry = sessionExpiry else {
            return false
        }

        return Date() < expiry
    }

    /// Get current session ID (authenticates if needed)
    func getSessionId() async throws -> String {
        // Check if we have a valid session
        if await isAuthenticated(), let sessionId = currentSessionId {
            return sessionId
        }

        // Need to authenticate
        logger.info("No valid SHARE session, authenticating...")
        return try await authenticate()
    }

    // MARK: - Authentication

    /// Authenticate with username and password
    func authenticate() async throws -> String {
        // Prevent multiple simultaneous auth attempts
        if isAuthenticating {
            logger.info("Authentication already in progress, waiting...")
            return try await withCheckedThrowingContinuation { continuation in
                authContinuations.append(continuation)
            }
        }

        isAuthenticating = true
        defer { isAuthenticating = false }

        do {
            // Get credentials from keychain
            guard let credentials = try await keychainStorage.getCredentials() else {
                throw DexcomShareError.invalidCredentials
            }

            logger.info("Authenticating with SHARE API...")

            // Build auth request
            let authRequest = DexcomShareAuthRequest(
                accountName: credentials.username,
                password: credentials.password,
                applicationId: applicationId.rawValue
            )

            let encoder = JSONEncoder()
            let requestBody = try encoder.encode(authRequest)

            // Step 1: AuthenticatePublisherAccount to get accountId
            var authURLRequest = URLRequest(url: self.server.authURL)
            authURLRequest.httpMethod = "POST"
            authURLRequest.httpBody = requestBody
            authURLRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            authURLRequest.setValue("application/json", forHTTPHeaderField: "Accept")
            authURLRequest.setValue("Dexcom Share/3.0.2.11 CFNetwork/672.0.2 Darwin/14.0.0", forHTTPHeaderField: "User-Agent")

            logger.debug("Step 1: Getting accountId from: \(self.server.authURL.absoluteString)")

            // Execute auth request to get accountId
            let (authData, authResponse) = try await session.data(for: authURLRequest)

            guard let httpAuthResponse = authResponse as? HTTPURLResponse else {
                throw DexcomShareError.invalidResponse
            }

            guard httpAuthResponse.statusCode == 200 else {
                logger.error("Step 1 failed with status: \(httpAuthResponse.statusCode)")
                throw DexcomShareError.invalidCredentials
            }

            guard let accountId = String(data: authData, encoding: .utf8)?.trimmingCharacters(in: CharacterSet(charactersIn: "\"")) else {
                throw DexcomShareError.invalidResponse
            }

            logger.debug("Received accountId: \(accountId)")

            // Step 2: LoginPublisherAccountById with accountId to get session
            let loginRequest = DexcomShareLoginByIdRequest(
                accountId: accountId,
                password: credentials.password,
                applicationId: applicationId.rawValue
            )

            let loginBody = try encoder.encode(loginRequest)

            var request = URLRequest(url: self.server.loginByIdURL)
            request.httpMethod = "POST"
            request.httpBody = loginBody
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("Dexcom Share/3.0.2.11 CFNetwork/672.0.2 Darwin/14.0.0", forHTTPHeaderField: "User-Agent")

            logger.debug("Step 2: Getting session from: \(self.server.loginByIdURL.absoluteString)")

            // Execute login request to get session ID
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw DexcomShareError.invalidResponse
            }

            logger.debug("SHARE auth response status: \(httpResponse.statusCode)")

            // Handle response
            switch httpResponse.statusCode {
            case 200...299:
                // Success - extract session ID from response
                // SHARE returns plain string like "00000000-0000-0000-0000-000000000000"
                // But it might be wrapped in quotes
                guard let responseString = String(data: data, encoding: .utf8) else {
                    throw DexcomShareError.invalidResponse
                }

                // Remove quotes if present
                let sessionId = responseString.trimmingCharacters(in: CharacterSet(charactersIn: "\""))

                logger.debug("Received session ID: \(sessionId)")

                // Validate UUID format
                guard UUID(uuidString: sessionId) != nil else {
                    logger.error("Invalid session ID format: \(responseString)")
                    throw DexcomShareError.invalidResponse
                }

                logger.info("✅ SHARE authentication successful")

                // Store session (24-hour expiry based on community knowledge)
                currentSessionId = sessionId
                sessionExpiry = Date().addingTimeInterval(24 * 60 * 60) // 24 hours

                // Save to keychain
                try await keychainStorage.saveSessionInfo(sessionId: sessionId, expiry: sessionExpiry!)

                // Track successful auth
                logger.info("SHARE authenticated: \(self.server.regionName)")

                // Resume any waiting continuations
                for continuation in authContinuations {
                    continuation.resume(returning: sessionId)
                }
                authContinuations.removeAll()

                return sessionId

            case 401, 403:
                // Invalid credentials
                logger.error("SHARE authentication failed: Invalid credentials")
                throw DexcomShareError.invalidCredentials

            case 500:
                // Server error (common with SHARE API)
                let errorMessage = String(data: data, encoding: .utf8) ?? "Server error"
                logger.error("SHARE server error: \(errorMessage)")
                throw DexcomShareError.serverError

            default:
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                logger.error("SHARE auth failed (\(httpResponse.statusCode)): \(errorMessage)")
                throw DexcomShareError.httpError(httpResponse.statusCode, errorMessage)
            }
        } catch {
            // Fail any waiting continuations
            for continuation in authContinuations {
                continuation.resume(throwing: error)
            }
            authContinuations.removeAll()

            throw error
        }
    }

    /// Save user credentials
    func saveCredentials(username: String, password: String) async throws {
        try await keychainStorage.saveCredentials(username: username, password: password)
        logger.info("SHARE credentials saved")

        // Clear current session since we have new credentials
        await clearSession()
    }

    /// Clear current session (force re-authentication)
    func clearSession() async {
        currentSessionId = nil
        sessionExpiry = nil

        do {
            try await keychainStorage.clearSession()
            logger.info("SHARE session cleared")
        } catch {
            logger.error("Failed to clear SHARE session: \(error.localizedDescription)")
        }
    }

    /// Delete all stored credentials and session
    func deleteCredentials() async throws {
        await clearSession()
        try await keychainStorage.deleteAll()
        logger.info("SHARE credentials deleted")
    }

    // MARK: - Helper Methods

    /// Test credentials by attempting authentication
    func testCredentials(username: String, password: String) async throws {
        // Temporarily save credentials
        try await saveCredentials(username: username, password: password)

        // Try to authenticate
        do {
            _ = try await authenticate()
            logger.info("✅ SHARE credentials test successful")
        } catch {
            // Delete invalid credentials
            try await deleteCredentials()
            throw error
        }
    }
}

// MARK: - Keychain Storage for SHARE

/// Keychain storage for Dexcom SHARE credentials and session
actor DexcomShareKeychainStorage {
    private let logger = AppLoggers.Security.keychain

    private let service = "com.anaxoniclabs.balli.dexcom.share"
    private let usernameKey = "share.username"
    private let passwordKey = "share.password"
    private let sessionKey = "share.session"
    private let sessionExpiryKey = "share.session.expiry"

    // MARK: - Credentials

    struct ShareCredentials: Sendable {
        let username: String
        let password: String
    }

    func hasCredentials() async throws -> Bool {
        let username = try await KeychainHelper.getValue(forKey: usernameKey, service: service)
        let password = try await KeychainHelper.getValue(forKey: passwordKey, service: service)
        return username != nil && password != nil
    }

    func getCredentials() async throws -> ShareCredentials? {
        guard let username = try await KeychainHelper.getValue(forKey: usernameKey, service: service),
              let password = try await KeychainHelper.getValue(forKey: passwordKey, service: service) else {
            return nil
        }

        return ShareCredentials(username: username, password: password)
    }

    func saveCredentials(username: String, password: String) async throws {
        try await KeychainHelper.setValue(username, forKey: usernameKey, service: service)
        try await KeychainHelper.setValue(password, forKey: passwordKey, service: service)
        logger.info("Saved SHARE credentials to keychain")
    }

    // MARK: - Session

    struct SessionInfo: Sendable {
        let sessionId: String
        let expiry: Date
    }

    func getSessionInfo() async throws -> SessionInfo? {
        guard let sessionId = try await KeychainHelper.getValue(forKey: sessionKey, service: service),
              let expiryString = try await KeychainHelper.getValue(forKey: sessionExpiryKey, service: service),
              let expiryTimestamp = Double(expiryString) else {
            return nil
        }

        return SessionInfo(
            sessionId: sessionId,
            expiry: Date(timeIntervalSince1970: expiryTimestamp)
        )
    }

    func saveSessionInfo(sessionId: String, expiry: Date) async throws {
        try await KeychainHelper.setValue(sessionId, forKey: sessionKey, service: service)
        try await KeychainHelper.setValue(String(expiry.timeIntervalSince1970), forKey: sessionExpiryKey, service: service)
        logger.info("Saved SHARE session to keychain")
    }

    func clearSession() async throws {
        try await KeychainHelper.deleteValue(forKey: sessionKey, service: service)
        try await KeychainHelper.deleteValue(forKey: sessionExpiryKey, service: service)
        logger.info("Cleared SHARE session from keychain")
    }

    // MARK: - Cleanup

    func deleteAll() async throws {
        try await KeychainHelper.deleteValue(forKey: usernameKey, service: service)
        try await KeychainHelper.deleteValue(forKey: passwordKey, service: service)
        try await clearSession()
        logger.info("Deleted all SHARE data from keychain")
    }
}
