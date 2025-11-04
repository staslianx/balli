//
//  MockKeychainStorageService.swift
//  balliTests
//
//  Mock implementation of KeychainStorageServiceProtocol for testing
//

import Foundation
import LocalAuthentication
@testable import balli

final class MockKeychainStorageService: KeychainStorageServiceProtocol, @unchecked Sendable {

    // MARK: - Mock Storage

    private var storage: [String: Data] = [:]
    private let lock = NSLock()

    // MARK: - Mock Configuration

    var shouldThrowOnStore = false
    var shouldThrowOnRetrieve = false
    var shouldThrowOnDelete = false
    var isBiometricAvailable = true
    var biometryType: LABiometryType = .faceID
    var shouldFailIntegrityCheck = false
    var mockError: Error?

    // MARK: - Call Tracking

    private(set) var storeCallCount = 0
    private(set) var retrieveCallCount = 0
    private(set) var deleteCallCount = 0
    private(set) var clearAllAuthDataCallCount = 0
    private(set) var getStorageStatisticsCallCount = 0
    private(set) var validateKeychainIntegrityCallCount = 0

    // MARK: - Storage Operations

    func store<T: Codable & Sendable>(
        _ item: T,
        for key: String,
        itemType: KeychainItemType,
        requiresBiometrics: Bool? = nil
    ) async throws {
        storeCallCount += 1

        if let error = mockError {
            throw error
        }

        if shouldThrowOnStore {
            throw KeychainError.unknownError(-1)
        }

        let data = try JSONEncoder().encode(item)
        let storageKey = "\(itemType.rawValue).\(key)"

        lock.lock()
        storage[storageKey] = data
        lock.unlock()
    }

    func retrieve<T: Codable & Sendable>(
        _ type: T.Type,
        for key: String,
        itemType: KeychainItemType
    ) async throws -> T? {
        retrieveCallCount += 1

        if let error = mockError {
            throw error
        }

        if shouldThrowOnRetrieve {
            throw KeychainError.unknownError(-1)
        }

        let storageKey = "\(itemType.rawValue).\(key)"

        lock.lock()
        let data = storage[storageKey]
        lock.unlock()

        guard let data = data else {
            return nil
        }

        return try JSONDecoder().decode(type, from: data)
    }

    func delete(key: String, itemType: KeychainItemType) async throws {
        deleteCallCount += 1

        if let error = mockError {
            throw error
        }

        if shouldThrowOnDelete {
            throw KeychainError.unknownError(-1)
        }

        let storageKey = "\(itemType.rawValue).\(key)"

        lock.lock()
        storage.removeValue(forKey: storageKey)
        lock.unlock()
    }

    // MARK: - Biometric Authentication

    func isBiometricAuthenticationAvailable() -> (Bool, LABiometryType) {
        return (isBiometricAvailable, biometryType)
    }

    // MARK: - Bulk Operations

    func clearAllAuthData() async throws {
        clearAllAuthDataCallCount += 1

        if let error = mockError {
            throw error
        }

        lock.lock()
        storage.removeAll()
        lock.unlock()
    }

    // MARK: - Monitoring and Debug

    func getStorageStatistics() async -> [String: Any] {
        getStorageStatisticsCallCount += 1

        lock.lock()
        let count = storage.count
        lock.unlock()

        return [
            "total_items": count,
            "last_checked": Date().timeIntervalSince1970
        ]
    }

    func validateKeychainIntegrity() async -> Bool {
        validateKeychainIntegrityCallCount += 1
        return !shouldFailIntegrityCheck
    }

    // MARK: - Test Helpers

    /// Get the number of items in storage
    var itemCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return storage.count
    }

    /// Check if a key exists in storage
    func hasItem(for key: String, itemType: KeychainItemType) -> Bool {
        let storageKey = "\(itemType.rawValue).\(key)"
        lock.lock()
        defer { lock.unlock() }
        return storage[storageKey] != nil
    }

    /// Reset all mock state
    func reset() {
        lock.lock()
        storage.removeAll()
        lock.unlock()

        shouldThrowOnStore = false
        shouldThrowOnRetrieve = false
        shouldThrowOnDelete = false
        isBiometricAvailable = true
        biometryType = .faceID
        shouldFailIntegrityCheck = false
        mockError = nil
        storeCallCount = 0
        retrieveCallCount = 0
        deleteCallCount = 0
        clearAllAuthDataCallCount = 0
        getStorageStatisticsCallCount = 0
        validateKeychainIntegrityCallCount = 0
    }
}
