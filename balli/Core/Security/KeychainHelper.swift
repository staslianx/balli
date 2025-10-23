//
//  KeychainHelper.swift
//  balli
//
//  Simple keychain helper for generic string storage
//  Swift 6 strict concurrency compliant
//

import Foundation
import Security

/// Simple helper for storing/retrieving strings from keychain
/// Used by SHARE API auth manager for username/password storage
actor KeychainHelper {

    /// Store a string value in keychain
    static func setValue(_ value: String, forKey key: String, service: String) async throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.invalidData
        }

        // Delete any existing item first
        try? await deleteValue(forKey: key, service: service)

        // Create query dictionary
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
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

    /// Retrieve a string value from keychain
    static func getValue(forKey key: String, service: String) async throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
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

        guard let value = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidData
        }

        return value
    }

    /// Delete a value from keychain
    static func deleteValue(forKey key: String, service: String) async throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)

        // Success or item not found are both acceptable
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unknownError(status)
        }
    }
}
