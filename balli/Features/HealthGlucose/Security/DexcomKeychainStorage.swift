//
//  DexcomKeychainStorage.swift
//  balli
//
//  Secure keychain storage for Dexcom OAuth tokens
//  Swift 6 strict concurrency compliant
//  GDPR-compliant with device-locked access
//

import Foundation
import Security

/// Secure storage for Dexcom OAuth tokens using iOS Keychain
actor DexcomKeychainStorage {

    // MARK: - Storage Keys

    private enum KeychainKey: String {
        case accessToken = "com.anaxoniclabs.balli.dexcom.accessToken"
        case refreshToken = "com.anaxoniclabs.balli.dexcom.refreshToken"
        case tokenExpiry = "com.anaxoniclabs.balli.dexcom.tokenExpiry"
        case clientId = "com.anaxoniclabs.balli.dexcom.clientId"
        case clientSecret = "com.anaxoniclabs.balli.dexcom.clientSecret"
    }

    // MARK: - Token Storage

    /// Store access token securely
    func storeAccessToken(_ token: String) throws {
        try store(token, for: .accessToken)
    }

    /// Retrieve access token
    func getAccessToken() throws -> String? {
        try retrieve(for: .accessToken)
    }

    /// Store refresh token securely
    func storeRefreshToken(_ token: String) throws {
        try store(token, for: .refreshToken)
    }

    /// Retrieve refresh token
    func getRefreshToken() throws -> String? {
        try retrieve(for: .refreshToken)
    }

    /// Store token expiry date
    func storeTokenExpiry(_ date: Date) throws {
        let timestamp = date.timeIntervalSince1970
        guard let data = String(timestamp).data(using: .utf8) else {
            throw KeychainError.invalidData
        }
        try storeData(data, for: .tokenExpiry)
    }

    /// Retrieve token expiry date
    func getTokenExpiry() throws -> Date? {
        guard let data = try retrieveData(for: .tokenExpiry),
              let timestampString = String(data: data, encoding: .utf8),
              let timestamp = TimeInterval(timestampString) else {
            return nil
        }
        return Date(timeIntervalSince1970: timestamp)
    }

    /// Check if access token is expired
    func isTokenExpired() throws -> Bool {
        guard let expiry = try getTokenExpiry() else {
            return true // No expiry means no valid token
        }

        // Consider token expired 5 minutes before actual expiry for safety
        let bufferTime: TimeInterval = 5 * 60
        return Date().addingTimeInterval(bufferTime) >= expiry
    }

    // MARK: - Credentials Storage

    /// Store client ID
    func storeClientId(_ clientId: String) throws {
        try store(clientId, for: .clientId)
    }

    /// Retrieve client ID
    func getClientId() throws -> String? {
        try retrieve(for: .clientId)
    }

    /// Store client secret
    func storeClientSecret(_ secret: String) throws {
        try store(secret, for: .clientSecret)
    }

    /// Retrieve client secret
    func getClientSecret() throws -> String? {
        try retrieve(for: .clientSecret)
    }

    // MARK: - Cleanup

    /// Delete all stored tokens (on logout or disconnect)
    func clearAllTokens() throws {
        try delete(for: .accessToken)
        try delete(for: .refreshToken)
        try delete(for: .tokenExpiry)
    }

    /// Delete all credentials (complete cleanup)
    func clearAll() throws {
        try clearAllTokens()
        try delete(for: .clientId)
        try delete(for: .clientSecret)
    }

    // MARK: - Private Helpers

    /// Store string value securely in keychain
    private func store(_ value: String, for key: KeychainKey) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.invalidData
        }
        try storeData(data, for: key)
    }

    /// Store data securely in keychain
    private func storeData(_ data: Data, for key: KeychainKey) throws {
        // First, delete any existing item
        try? delete(for: key)

        // Create query dictionary
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly, // GDPR-compliant
            kSecValueData as String: data
        ]

        // Add to keychain
        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            if status == errSecDuplicateItem {
                throw KeychainError.duplicateItem
            }
            throw KeychainError.unknownError(status)
        }
    }

    /// Retrieve string value from keychain
    private func retrieve(for key: KeychainKey) throws -> String? {
        guard let data = try retrieveData(for: key) else {
            return nil
        }

        guard let value = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidData
        }

        return value
    }

    /// Retrieve data from keychain
    private func retrieveData(for key: KeychainKey) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess else {
            throw KeychainError.unknownError(status)
        }

        guard let data = result as? Data else {
            throw KeychainError.invalidData
        }

        return data
    }

    /// Delete item from keychain
    private func delete(for key: KeychainKey) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue
        ]

        let status = SecItemDelete(query as CFDictionary)

        // Success or item not found are both acceptable
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unknownError(status)
        }
    }
}

// Note: KeychainError is defined in KeychainStorageService.swift

// MARK: - Token Info Helper

extension DexcomKeychainStorage {
    /// Get comprehensive token information
    func getTokenInfo() async throws -> TokenInfo? {
        guard let accessToken = try getAccessToken(),
              let refreshToken = try getRefreshToken() else {
            return nil
        }

        let expiry = try getTokenExpiry()
        let isExpired = try isTokenExpired()

        return TokenInfo(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiry: expiry,
            isExpired: isExpired
        )
    }

    /// Store complete token set
    func storeTokens(accessToken: String, refreshToken: String, expiresIn: TimeInterval) throws {
        let expiryDate = Date().addingTimeInterval(expiresIn)

        // Log token storage event (without exposing token values)
        let logger = AppLoggers.Auth.main
        logger.info("🔐 Storing new tokens - expires in \(expiresIn)s at \(expiryDate)")

        try storeAccessToken(accessToken)
        try storeRefreshToken(refreshToken)
        try storeTokenExpiry(expiryDate)

        logger.info("✅ Tokens stored successfully")
    }
}

// MARK: - Token Info Model

struct TokenInfo: Sendable {
    let accessToken: String
    let refreshToken: String
    let expiry: Date?
    let isExpired: Bool

    var timeUntilExpiry: TimeInterval? {
        guard let expiry = expiry else { return nil }
        return expiry.timeIntervalSinceNow
    }

    var isValid: Bool {
        return !isExpired && !accessToken.isEmpty
    }
}