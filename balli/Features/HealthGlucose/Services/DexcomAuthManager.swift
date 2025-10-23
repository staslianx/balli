//
//  DexcomAuthManager.swift
//  balli
//
//  OAuth 2.0 authentication manager for Dexcom API (EU region)
//  Swift 6 strict concurrency compliant
//  Prevents token refresh race conditions with actor isolation
//

import Foundation
import AuthenticationServices
import OSLog

/// OAuth 2.0 authentication manager for Dexcom API
actor DexcomAuthManager: NSObject {

    // MARK: - Properties

    private let configuration: DexcomConfiguration
    private let keychainStorage: DexcomKeychainStorage
    private let analytics = AnalyticsService.shared
    private let logger = AppLoggers.Auth.main

    private var isRefreshing = false
    private var refreshContinuations: [CheckedContinuation<String, Error>] = []

    // Retain authentication session during auth flow
    // nonisolated(unsafe) since ASWebAuthenticationSession must be used from main thread
    // and we carefully manage the lifecycle within @MainActor context
    nonisolated(unsafe) private static var currentAuthSession: ASWebAuthenticationSession?

    // CRITICAL: Retain presentation context provider during auth flow
    // ASWebAuthenticationSession holds a WEAK reference to presentationContextProvider
    // If we don't retain it, it gets deallocated immediately, causing error 2
    nonisolated(unsafe) private static var currentContextProvider: ASWebAuthenticationPresentationContextProviding?

    // MARK: - Initialization

    init(configuration: DexcomConfiguration) {
        self.configuration = configuration
        self.keychainStorage = DexcomKeychainStorage()
        super.init()
    }

    // MARK: - Authentication Status

    /// Check if user is authenticated with valid token
    func isAuthenticated() async -> Bool {
        do {
            guard let tokenInfo = try await keychainStorage.getTokenInfo() else {
                return false
            }
            return tokenInfo.isValid
        } catch {
            logger.error("Failed to check authentication status: \(error.localizedDescription)")
            return false
        }
    }

    /// Get current access token (refreshes if expired)
    func getAccessToken() async throws -> String {
        // Check if we have a valid token
        guard let tokenInfo = try await keychainStorage.getTokenInfo() else {
            throw DexcomError.notConnected
        }

        // If token is not expired, return it
        if !tokenInfo.isExpired {
            return tokenInfo.accessToken
        }

        // Token is expired, refresh it
        logger.info("Access token expired, refreshing...")
        return try await refreshAccessToken()
    }

    // MARK: - OAuth Authorization Flow

    /// Start OAuth authorization flow
    /// - Parameter presentationAnchor: Window for presenting the auth session
    /// - Returns: Authorization code
    @MainActor
    func startAuthorization(presentationAnchor: ASPresentationAnchor) async throws -> String {
        // Build authorization URL
        logger.info("🔍 DIAGNOSTIC: Starting authorization")
        logger.info("🔍 DIAGNOSTIC: Configuration.environment = '\(String(describing: self.configuration.environment))'")
        logger.info("🔍 DIAGNOSTIC: Configuration.baseURL = '\(self.configuration.baseURL)'")
        logger.info("🔍 DIAGNOSTIC: Configuration.authorizationURL = '\(self.configuration.authorizationURL)'")
        logger.info("🔍 DIAGNOSTIC: Configuration.clientId = '\(self.configuration.clientId)'")
        logger.info("🔍 DIAGNOSTIC: Configuration.clientSecret = '\(self.configuration.clientSecret.prefix(4))...'")
        logger.info("🔍 DIAGNOSTIC: Configuration.redirectURI = '\(self.configuration.redirectURI)'")

        guard var components = URLComponents(string: configuration.authorizationURL) else {
            logger.error("DIAGNOSTIC: Failed to create URLComponents from authorizationURL: '\(self.configuration.authorizationURL)'")
            throw DexcomError.invalidConfiguration
        }

        logger.info("DIAGNOSTIC: URLComponents created successfully")

        components.queryItems = [
            URLQueryItem(name: "client_id", value: configuration.clientId),
            URLQueryItem(name: "redirect_uri", value: configuration.redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: configuration.scopeString),
            URLQueryItem(name: "state", value: UUID().uuidString) // CSRF protection
        ]

        logger.info("DIAGNOSTIC: Query items set successfully")

        guard let authURL = components.url else {
            logger.error("DIAGNOSTIC: Failed to create URL from components. Components: \(components)")
            throw DexcomError.invalidConfiguration
        }

        logger.info("DIAGNOSTIC: Full auth URL created: '\(authURL.absoluteString)'")
        logger.info("Starting OAuth authorization flow...")

        // Present authentication session
        return try await withCheckedThrowingContinuation { continuation in
            logger.info("🔍 DIAGNOSTIC: Creating ASWebAuthenticationSession")
            logger.info("🔍 DIAGNOSTIC: Auth URL: \(authURL.absoluteString)")
            logger.info("🔍 DIAGNOSTIC: Callback scheme: com.anaxoniclabs.balli")

            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: "com.anaxoniclabs.balli"
            ) { [self] callbackURL, error in
                self.logger.info("🎯 DIAGNOSTIC: Completion handler CALLED")
                self.logger.info("🎯 DIAGNOSTIC: callbackURL: \(String(describing: callbackURL))")
                self.logger.info("🎯 DIAGNOSTIC: error: \(String(describing: error))")
                // Clear the session and context provider references when auth completes
                Self.currentAuthSession = nil
                Self.currentContextProvider = nil

                if let error = error {
                    let nsError = error as NSError
                    if nsError.code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                        continuation.resume(throwing: DexcomError.authorizationCancelled)
                    } else {
                        continuation.resume(throwing: DexcomError.authorizationFailed(reason: error.localizedDescription))
                    }
                    return
                }

                guard let callbackURL = callbackURL,
                      let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                      let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
                    continuation.resume(throwing: DexcomError.invalidAuthorizationCode)
                    return
                }

                continuation.resume(returning: code)
            }

            // Create and retain the presentation context provider
            // CRITICAL: ASWebAuthenticationSession holds only a WEAK reference to this
            // We must keep a strong reference or it will be deallocated immediately
            let contextProvider = PresentationContextProvider(anchor: presentationAnchor)
            logger.info("🔍 DIAGNOSTIC: Created context provider with anchor: \(presentationAnchor)")
            logger.info("🔍 DIAGNOSTIC: Anchor isKeyWindow: \(presentationAnchor.isKeyWindow)")
            logger.info("🔍 DIAGNOSTIC: Anchor windowScene: \(String(describing: presentationAnchor.windowScene))")

            session.presentationContextProvider = contextProvider
            session.prefersEphemeralWebBrowserSession = false // Allow SSO
            logger.info("🔍 DIAGNOSTIC: Configured session with context provider and preferences")

            // Retain both the session AND context provider to prevent premature deallocation
            // This must happen synchronously before start() is called
            Self.currentContextProvider = contextProvider
            Self.currentAuthSession = session

            // Start the session - returns true if successfully started
            // CRITICAL: If start() returns false, the completion handler will NEVER be called
            let started = session.start()
            logger.info("🔍 DIAGNOSTIC: session.start() returned: \(started)")

            if !started {
                logger.error("❌ CRITICAL: ASWebAuthenticationSession.start() returned false - session failed to start")
                logger.error("❌ This means the completion handler will NEVER be called")
                logger.error("❌ Likely causes:")
                logger.error("   1. Presentation context provider is nil or deallocated")
                logger.error("   2. Presentation anchor window is invalid")
                logger.error("   3. Another auth session is already active")

                // Clean up
                Self.currentAuthSession = nil
                Self.currentContextProvider = nil

                // Resume with error since completion handler won't be called
                continuation.resume(throwing: DexcomError.authorizationFailed(reason: "Failed to start authentication session"))
            } else {
                logger.info("✅ Auth session started successfully, waiting for user interaction...")
            }
        }
    }

    /// Exchange authorization code for tokens
    func exchangeCodeForTokens(authorizationCode: String) async throws {
        logger.info("Exchanging authorization code for tokens...")

        // Build token request
        guard let tokenURL = URL(string: configuration.tokenURL) else {
            throw DexcomError.invalidConfiguration
        }

        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyParams = [
            "client_id": configuration.clientId,
            "client_secret": configuration.clientSecret,
            "code": authorizationCode,
            "grant_type": "authorization_code",
            "redirect_uri": configuration.redirectURI
        ]

        request.httpBody = bodyParams
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
            .joined(separator: "&")
            .data(using: .utf8)

        // Execute request
        let (data, response) = try await URLSession.shared.data(for: request)

        // Check response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DexcomError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw DexcomError.from(httpStatusCode: httpResponse.statusCode, data: data)
        }

        // Decode token response
        let decoder = JSONDecoder()
        let tokenResponse = try decoder.decode(DexcomTokenResponse.self, from: data)

        // Store tokens securely
        try await keychainStorage.storeTokens(
            accessToken: tokenResponse.accessToken,
            refreshToken: tokenResponse.refreshToken,
            expiresIn: TimeInterval(tokenResponse.expiresIn)
        )

        logger.info("Tokens successfully stored")
    }

    // MARK: - Token Refresh

    /// Refresh access token using refresh token
    /// Prevents race conditions by serializing refresh requests
    private func refreshAccessToken() async throws -> String {
        // If already refreshing, wait for the ongoing refresh
        if isRefreshing {
            return try await withCheckedThrowingContinuation { continuation in
                refreshContinuations.append(continuation)
            }
        }

        // Mark as refreshing
        isRefreshing = true
        defer {
            isRefreshing = false
        }

        do {
            // Get refresh token
            guard let refreshToken = try await keychainStorage.getRefreshToken() else {
                throw DexcomError.notConnected
            }

            logger.info("Refreshing access token...")

            // Build refresh request
            guard let tokenURL = URL(string: configuration.tokenURL) else {
                throw DexcomError.invalidConfiguration
            }

            var request = URLRequest(url: tokenURL)
            request.httpMethod = "POST"
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

            let bodyParams = [
                "client_id": configuration.clientId,
                "client_secret": configuration.clientSecret,
                "refresh_token": refreshToken,
                "grant_type": "refresh_token"
            ]

            request.httpBody = bodyParams
                .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
                .joined(separator: "&")
                .data(using: .utf8)

            // Execute request
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw DexcomError.invalidResponse
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                // If refresh fails with 401/403, tokens are invalid
                if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                    try await disconnect() // Clear invalid tokens
                }
                throw DexcomError.tokenRefreshFailed
            }

            // Decode token response
            let decoder = JSONDecoder()
            let tokenResponse = try decoder.decode(DexcomTokenResponse.self, from: data)

            // Store new tokens
            try await keychainStorage.storeTokens(
                accessToken: tokenResponse.accessToken,
                refreshToken: tokenResponse.refreshToken,
                expiresIn: TimeInterval(tokenResponse.expiresIn)
            )

            logger.info("Access token successfully refreshed")

            let newAccessToken = tokenResponse.accessToken

            // Track successful refresh
            await analytics.track(.dexcomTokenRefresh)

            // Resume all waiting continuations with success
            for continuation in refreshContinuations {
                continuation.resume(returning: newAccessToken)
            }
            refreshContinuations.removeAll()

            return newAccessToken

        } catch {
            // Track failed refresh
            await analytics.trackError(.dexcomTokenRefreshFailed, error: error)

            // Resume all waiting continuations with error
            for continuation in refreshContinuations {
                continuation.resume(throwing: error)
            }
            refreshContinuations.removeAll()

            throw error
        }
    }

    // MARK: - Disconnect

    /// Disconnect from Dexcom (clear all tokens)
    func disconnect() async throws {
        logger.info("Disconnecting from Dexcom...")

        // Clear all tokens from keychain
        try await keychainStorage.clearAllTokens()

        logger.info("Successfully disconnected from Dexcom")
    }

    // MARK: - Complete Authorization Flow

    /// Complete authorization flow (start auth + exchange tokens)
    @MainActor
    func authorize(presentationAnchor: ASPresentationAnchor) async throws {
        logger.info("DIAGNOSTIC [DexcomAuthManager]: authorize() called")
        logger.info("DIAGNOSTIC [DexcomAuthManager]: PresentationAnchor received: \(presentationAnchor)")

        // Step 1: Start OAuth flow and get authorization code
        logger.info("DIAGNOSTIC [DexcomAuthManager]: Calling startAuthorization()")
        let authorizationCode = try await startAuthorization(presentationAnchor: presentationAnchor)

        // Step 2: Exchange code for tokens
        logger.info("DIAGNOSTIC [DexcomAuthManager]: Authorization code received, exchanging for tokens")
        try await exchangeCodeForTokens(authorizationCode: authorizationCode)

        logger.info("Authorization flow completed successfully")
    }
}

// MARK: - Presentation Context Provider

/// Helper for providing presentation context to ASWebAuthenticationSession
private class PresentationContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    let anchor: ASPresentationAnchor

    init(anchor: ASPresentationAnchor) {
        self.anchor = anchor
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return anchor
    }
}

// MARK: - Helper Extensions

extension DexcomAuthManager {
    /// Get token information for debugging
    func getTokenInfo() async throws -> TokenInfo? {
        try await keychainStorage.getTokenInfo()
    }

    /// Check if tokens need refresh soon (within 5 minutes)
    func needsRefreshSoon() async -> Bool {
        do {
            guard let tokenInfo = try await keychainStorage.getTokenInfo() else {
                return false
            }

            guard let timeUntilExpiry = tokenInfo.timeUntilExpiry else {
                return true
            }

            // Refresh if expiring within 5 minutes
            return timeUntilExpiry < 300
        } catch {
            return false
        }
    }
}