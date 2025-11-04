//
//  KeychainStorageService.swift
//  balli
//
//  Secure Keychain storage service for sensitive authentication data
//  HIPAA-compliant with AES-256 encryption and biometric protection
//  Swift 6 strict concurrency compliant
//

import Foundation
import Security
import LocalAuthentication
import CryptoKit
import os

// MARK: - Keychain Item Types
public enum KeychainItemType: String, CaseIterable, Sendable {
    case accessToken = "access_token"
    case refreshToken = "refresh_token"
    case userCredentials = "user_credentials"
    case biometricKey = "biometric_key"
    case encryptionKey = "encryption_key"
    
    var accessibility: CFString {
        switch self {
        case .accessToken, .refreshToken:
            return kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        case .userCredentials:
            return kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly
        case .biometricKey:
            return kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly
        case .encryptionKey:
            return kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        }
    }
    
    var requiresBiometrics: Bool {
        switch self {
        case .userCredentials, .biometricKey:
            return true
        default:
            return false
        }
    }
}

// MARK: - Keychain Errors
public enum KeychainError: LocalizedError, Sendable {
    case itemNotFound
    case duplicateItem
    case invalidData
    case authenticationFailed
    case biometricsNotAvailable
    case biometricsNotEnrolled
    case userCancel
    case encryptionFailed
    case decryptionFailed
    case unknownError(OSStatus)
    
    public var errorDescription: String? {
        switch self {
        case .itemNotFound:
            return "Keychain item not found"
        case .duplicateItem:
            return "Keychain item already exists"
        case .invalidData:
            return "Invalid data format"
        case .authenticationFailed:
            return "Authentication failed"
        case .biometricsNotAvailable:
            return "Biometric authentication not available"
        case .biometricsNotEnrolled:
            return "No biometric data enrolled"
        case .userCancel:
            return "User cancelled authentication"
        case .encryptionFailed:
            return "Encryption failed"
        case .decryptionFailed:
            return "Decryption failed"
        case .unknownError(let status):
            return "Keychain error: \(status)"
        }
    }
}

// MARK: - Keychain Storage Service
public final class KeychainStorageService: KeychainStorageServiceProtocol {
    public static let shared = KeychainStorageService()
    
    private let serviceIdentifier = "com.balli.diabetes.keychain"
    private let logger = os.Logger(subsystem: "com.balli.diabetes", category: "Security")
    
    // Encryption key for additional security layer
    private let encryptionKeyTag = "com.balli.diabetes.encryption.key"
    
    private init() {}
    
    // MARK: - Public Interface

    private func executeOffMain<T: Sendable>(
        priority: TaskPriority = .userInitiated,
        _ operation: @Sendable @escaping () async throws -> T
    ) async throws -> T {
        try await Task.detached(priority: priority) {
            try await operation()
        }.value
    }
    
    /// Store data securely in keychain with optional encryption
    public func store<T: Codable & Sendable>(
        _ item: T,
        for key: String,
        itemType: KeychainItemType = .userCredentials,
        requiresBiometrics: Bool? = nil
    ) async throws {

        try await executeOffMain { [weak self] in
            guard let self = self else { throw KeychainError.invalidData }
            self.logger.info("Storing keychain item: \(key) of type: \(itemType.rawValue)")

            do {
                // Serialize the item
                let jsonData = try JSONEncoder().encode(item)

                // Encrypt sensitive data
                let encryptedData = try await self.encryptData(jsonData, for: itemType)

                // Create keychain query
                var query = self.baseQuery(for: key, itemType: itemType)
                query[kSecValueData as String] = encryptedData

                // Add biometric protection if required
                let needsBiometrics = requiresBiometrics ?? itemType.requiresBiometrics
                if needsBiometrics {
                    try self.addBiometricProtection(to: &query)
                }

                // Delete existing item first
                let deleteQuery = self.baseQuery(for: key, itemType: itemType)
                SecItemDelete(deleteQuery as CFDictionary)

                // Add new item
                let status = SecItemAdd(query as CFDictionary, nil)

                if status == errSecSuccess {
                    self.logger.info("Successfully stored keychain item: \(key)")
                } else {
                    self.logger.error("Failed to store keychain item: \(key), status: \(status)")
                    throw self.keychainError(from: status)
                }

            } catch {
                self.logger.error("Error storing keychain item: \(error.localizedDescription)")
                throw error
            }
        }
    }

    /// Retrieve and decrypt data from keychain
    public func retrieve<T: Codable & Sendable>(
        _ type: T.Type,
        for key: String,
        itemType: KeychainItemType = .userCredentials
    ) async throws -> T? {
        try await executeOffMain { [weak self] in
            guard let self = self else { throw KeychainError.invalidData }
            self.logger.info("Retrieving keychain item: \(key) of type: \(itemType.rawValue)")

            do {
                var query = self.baseQuery(for: key, itemType: itemType)
                query[kSecReturnData as String] = true
                query[kSecMatchLimit as String] = kSecMatchLimitOne

                // Add biometric authentication if required
                if itemType.requiresBiometrics {
                    try self.addBiometricAuthentication(to: &query)
                }

                var item: CFTypeRef?
                let status = SecItemCopyMatching(query as CFDictionary, &item)

                switch status {
                case errSecSuccess:
                    guard let data = item as? Data else {
                        throw KeychainError.invalidData
                    }

                    // Decrypt data
                    let decryptedData = try await self.decryptData(data, for: itemType)

                    // Deserialize
                    let decodedItem = try JSONDecoder().decode(type, from: decryptedData)

                    self.logger.info("Successfully retrieved keychain item: \(key)")
                    return decodedItem

                case errSecItemNotFound:
                    self.logger.info("Keychain item not found: \(key)")
                    return nil

                default:
                    self.logger.error("Failed to retrieve keychain item: \(key), status: \(status)")
                    throw self.keychainError(from: status)
                }

            } catch {
                self.logger.error("Error retrieving keychain item: \(error.localizedDescription)")
                throw error
            }
        }
    }

    /// Delete item from keychain
    public func delete(key: String, itemType: KeychainItemType = .userCredentials) async throws {
        try await executeOffMain { [weak self] in
            guard let self = self else { throw KeychainError.invalidData }
            self.logger.info("Deleting keychain item: \(key)")

            let query = self.baseQuery(for: key, itemType: itemType)
            let status = SecItemDelete(query as CFDictionary)

            switch status {
            case errSecSuccess, errSecItemNotFound:
                self.logger.info("Successfully deleted keychain item: \(key)")
            default:
                self.logger.error("Failed to delete keychain item: \(key), status: \(status)")
                throw self.keychainError(from: status)
            }
        }
    }
    
    /// Check if biometric authentication is available
    public func isBiometricAuthenticationAvailable() -> (Bool, LABiometryType) {
        let context = LAContext()
        var error: NSError?
        
        let isAvailable = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        let biometryType = context.biometryType
        
        logger.info("Biometric availability: \(isAvailable), type: \(biometryType.rawValue)")
        
        return (isAvailable, biometryType)
    }
    
    /// Clear all authentication data
    public func clearAllAuthData() async throws {
        try await executeOffMain { [weak self] in
            guard let self = self else { throw KeychainError.invalidData }
            self.logger.info("Clearing all authentication data")

            let authKeys = [
                "cloud_access_token",
                "cloud_refresh_token",
                "authenticated_user_data",
                "user_session_data"
            ]

            try await withThrowingTaskGroup(of: Void.self) { group in
                for key in authKeys {
                    group.addTask { [weak self] in
                        try? await self?.delete(key: key, itemType: .accessToken)
                        try? await self?.delete(key: key, itemType: .refreshToken)
                        try? await self?.delete(key: key, itemType: .userCredentials)
                    }
                }

                try await group.waitForAll()
            }

            self.logger.info("Successfully cleared all authentication data")
        }
    }
}

// MARK: - Private Methods
extension KeychainStorageService {
    
    private func baseQuery(for key: String, itemType: KeychainItemType) -> [String: Any] {
        return [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: "\(itemType.rawValue).\(key)",
            kSecAttrAccessible as String: itemType.accessibility,
            kSecAttrSynchronizable as String: false // Never sync sensitive data
        ]
    }
    
    private func addBiometricProtection(to query: inout [String: Any]) throws {
        let (isAvailable, _) = isBiometricAuthenticationAvailable()
        
        guard isAvailable else {
            throw KeychainError.biometricsNotAvailable
        }
        
        // Create access control for biometric authentication
        var error: Unmanaged<CFError>?
        guard let accessControl = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
            [.biometryCurrentSet, .or, .devicePasscode],
            &error
        ) else {
            if let error = error?.takeRetainedValue() {
                logger.error("Failed to create access control: \(CFErrorCopyDescription(error))")
            }
            throw KeychainError.biometricsNotAvailable
        }
        
        query[kSecAttrAccessControl as String] = accessControl
        query.removeValue(forKey: kSecAttrAccessible as String)
    }
    
    private func addBiometricAuthentication(to query: inout [String: Any]) throws {
        let (isAvailable, biometryType) = isBiometricAuthenticationAvailable()
        
        guard isAvailable else {
            throw KeychainError.biometricsNotAvailable
        }
        
        let context = LAContext()
        context.localizedFallbackTitle = "Şifre Kullan"
        
        let reason: String
        switch biometryType {
        case .faceID:
            reason = "Güvenli verilerine erişmek için Face ID kullan"
        case .touchID:
            reason = "Güvenli verilerine erişmek için Touch ID kullan"
        default:
            reason = "Güvenli verilerine erişmek için kimlik doğrulama yap"
        }
        
        context.localizedReason = reason
        query[kSecUseAuthenticationContext as String] = context
    }
    
    private func keychainError(from status: OSStatus) -> KeychainError {
        switch status {
        case errSecItemNotFound:
            return .itemNotFound
        case errSecDuplicateItem:
            return .duplicateItem
        case errSecAuthFailed:
            return .authenticationFailed
        case errSecUserCanceled:
            return .userCancel
        default:
            return .unknownError(status)
        }
    }
}

// MARK: - Encryption/Decryption
extension KeychainStorageService {
    
    private func encryptData(_ data: Data, for itemType: KeychainItemType) async throws -> Data {
        // For highly sensitive data, add an additional encryption layer
        guard itemType == .userCredentials || itemType == .biometricKey else {
            return data // Return as-is for less sensitive data
        }
        
        let key = try await getOrCreateEncryptionKey()
        let sealedData = try AES.GCM.seal(data, using: key)
        
        guard let encryptedData = sealedData.combined else {
            throw KeychainError.encryptionFailed
        }
        
        logger.debug("Successfully encrypted data for item type: \(itemType.rawValue)")
        return encryptedData
    }
    
    private func decryptData(_ encryptedData: Data, for itemType: KeychainItemType) async throws -> Data {
        // For highly sensitive data, decrypt the additional encryption layer
        guard itemType == .userCredentials || itemType == .biometricKey else {
            return encryptedData // Return as-is for less sensitive data
        }
        
        let key = try await getOrCreateEncryptionKey()
        
        guard let sealedBox = try? AES.GCM.SealedBox(combined: encryptedData) else {
            throw KeychainError.decryptionFailed
        }
        
        let decryptedData = try AES.GCM.open(sealedBox, using: key)
        
        logger.debug("Successfully decrypted data for item type: \(itemType.rawValue)")
        return decryptedData
    }
    
    private func getOrCreateEncryptionKey() async throws -> SymmetricKey {
        // Check if encryption key exists in keychain
        let keyQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: encryptionKeyTag,
            kSecReturnData as String: true
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(keyQuery as CFDictionary, &item)
        
        if status == errSecSuccess, let keyData = item as? Data {
            return SymmetricKey(data: keyData)
        }
        
        // Create new encryption key
        let newKey = SymmetricKey(size: .bits256)
        let keyData = newKey.withUnsafeBytes { Data($0) }
        
        // Store key in keychain
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: encryptionKeyTag,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw KeychainError.unknownError(addStatus)
        }
        
        logger.info("Created new encryption key")
        return newKey
    }
}

// MARK: - Biometric Authentication Helper
extension LABiometryType {
    var displayName: String {
        switch self {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        case .opticID:
            return "Optic ID"
        default:
            return "Biometric Authentication"
        }
    }
}

// MARK: - Keychain Debug and Monitoring
public extension KeychainStorageService {
    
    /// Get keychain storage statistics
    func getStorageStatistics() async -> [String: Any] {
        var stats: [String: Any] = [:]
        
        for itemType in KeychainItemType.allCases {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: serviceIdentifier,
                kSecMatchLimit as String: kSecMatchLimitAll,
                kSecReturnAttributes as String: true
            ]
            
            var items: CFTypeRef?
            let status = SecItemCopyMatching(query as CFDictionary, &items)
            
            if status == errSecSuccess, let itemsArray = items as? [[String: Any]] {
                let filteredItems = itemsArray.filter { item in
                    if let account = item[kSecAttrAccount as String] as? String {
                        return account.hasPrefix(itemType.rawValue)
                    }
                    return false
                }
                stats[itemType.rawValue] = filteredItems.count
            } else {
                stats[itemType.rawValue] = 0
            }
        }
        
        stats["total_items"] = stats.values.compactMap { $0 as? Int }.reduce(0, +)
        stats["last_checked"] = Date().timeIntervalSince1970
        
        return stats
    }
    
    /// Validate keychain integrity
    func validateKeychainIntegrity() async -> Bool {
        logger.info("Validating keychain integrity")
        
        do {
            // Test encryption/decryption
            guard let testData = "integrity_test_\(UUID().uuidString)".data(using: .utf8) else {
                logger.error("Keychain integrity validation failed: unable to create test data")
                return false
            }
            let encryptedData = try await encryptData(testData, for: .userCredentials)
            let decryptedData = try await decryptData(encryptedData, for: .userCredentials)
            
            guard testData == decryptedData else {
                logger.error("Keychain integrity validation failed: encryption/decryption mismatch")
                return false
            }
            
            logger.info("Keychain integrity validation successful")
            return true
        } catch {
            logger.error("Keychain integrity validation failed: \(error.localizedDescription)")
            return false
        }
    }
}
