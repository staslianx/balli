//
//  KeychainStorageServiceProtocol.swift
//  balli
//
//  Protocol definition for KeychainStorageService
//  Enables dependency injection and testing
//

import Foundation
import LocalAuthentication

/// Protocol for secure keychain storage operations
protocol KeychainStorageServiceProtocol: Sendable {

    // MARK: - Storage Operations

    /// Store data securely in keychain with optional encryption
    /// - Parameters:
    ///   - item: The item to store (must be Codable and Sendable)
    ///   - key: The key to store the item under
    ///   - itemType: The type of keychain item
    ///   - requiresBiometrics: Whether biometric authentication is required
    func store<T: Codable & Sendable>(
        _ item: T,
        for key: String,
        itemType: KeychainItemType,
        requiresBiometrics: Bool?
    ) async throws

    /// Retrieve and decrypt data from keychain
    /// - Parameters:
    ///   - type: The type to decode the data as
    ///   - key: The key the item was stored under
    ///   - itemType: The type of keychain item
    /// - Returns: The decoded item, or nil if not found
    func retrieve<T: Codable & Sendable>(
        _ type: T.Type,
        for key: String,
        itemType: KeychainItemType
    ) async throws -> T?

    /// Delete item from keychain
    /// - Parameters:
    ///   - key: The key of the item to delete
    ///   - itemType: The type of keychain item
    func delete(key: String, itemType: KeychainItemType) async throws

    // MARK: - Biometric Authentication

    /// Check if biometric authentication is available
    /// - Returns: Tuple of availability boolean and biometry type
    func isBiometricAuthenticationAvailable() -> (Bool, LABiometryType)

    // MARK: - Bulk Operations

    /// Clear all authentication data
    func clearAllAuthData() async throws

    // MARK: - Monitoring and Debug

    /// Get keychain storage statistics
    /// - Returns: Dictionary with storage statistics
    func getStorageStatistics() async -> [String: Any]

    /// Validate keychain integrity
    /// - Returns: Boolean indicating if keychain is functioning correctly
    func validateKeychainIntegrity() async -> Bool
}
