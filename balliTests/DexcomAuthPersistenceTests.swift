//
//  DexcomAuthPersistenceTests.swift
//  balliTests
//
//  Comprehensive tests for Dexcom OAuth authentication persistence
//  Tests token storage, expiration detection, and connection status behavior
//  Focuses on debugging auto-logout issues
//

import XCTest
@testable import balli

/// Test Suite 1: Authentication Persistence
/// Tests DexcomAuthManager and DexcomKeychainStorage behavior
@MainActor
final class DexcomAuthPersistenceTests: XCTestCase {

    var authManager: DexcomAuthManager!
    var keychainStorage: DexcomKeychainStorage!
    var mockConfiguration: DexcomConfiguration!

    override func setUp() async throws {
        // Create mock configuration for testing
        mockConfiguration = DexcomConfiguration.mock
        authManager = DexcomAuthManager(configuration: mockConfiguration)
        keychainStorage = DexcomKeychainStorage()

        // Clean keychain before each test
        try await keychainStorage.clearAll()
    }

    override func tearDown() async throws {
        // Clean keychain after each test
        try await keychainStorage.clearAll()
        authManager = nil
        keychainStorage = nil
        mockConfiguration = nil
    }

    // MARK: - Token Storage and Retrieval Tests

    func testTokenStorageAndRetrieval_Success() async throws {
        // Given: Valid tokens
        let accessToken = "test_access_token_12345"
        let refreshToken = "test_refresh_token_67890"
        let expiresIn: TimeInterval = 3600 // 1 hour

        // When: Store tokens
        try await keychainStorage.storeTokens(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresIn: expiresIn
        )

        // Then: Retrieve tokens successfully
        let tokenInfo = try await keychainStorage.getTokenInfo()
        XCTAssertNotNil(tokenInfo, "Token info should be retrieved")
        XCTAssertEqual(tokenInfo?.accessToken, accessToken, "Access token should match")
        XCTAssertEqual(tokenInfo?.refreshToken, refreshToken, "Refresh token should match")
        XCTAssertFalse(tokenInfo?.isExpired ?? true, "Token should not be expired")
        XCTAssertTrue(tokenInfo?.isValid ?? false, "Token should be valid")
    }

    func testTokenExpiration_DetectedCorrectly() async throws {
        // Given: Expired token (1 second expiry)
        let accessToken = "test_access_token"
        let refreshToken = "test_refresh_token"
        let expiresIn: TimeInterval = 1 // 1 second

        // When: Store tokens
        try await keychainStorage.storeTokens(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresIn: expiresIn
        )

        // Wait for token to expire
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds

        // Then: Token should be detected as expired
        let tokenInfo = try await keychainStorage.getTokenInfo()
        XCTAssertNotNil(tokenInfo, "Token info should exist")
        XCTAssertTrue(tokenInfo?.isExpired ?? false, "Token should be expired")
        XCTAssertFalse(tokenInfo?.isValid ?? true, "Token should not be valid")
    }

    func testIsAuthenticated_WithValidToken_ReturnsTrue() async throws {
        // Given: Valid token stored
        try await keychainStorage.storeTokens(
            accessToken: "valid_token",
            refreshToken: "refresh_token",
            expiresIn: 3600
        )

        // When: Check authentication status
        let isAuthenticated = await authManager.isAuthenticated()

        // Then: Should be authenticated
        XCTAssertTrue(isAuthenticated, "User should be authenticated with valid token")
    }

    func testIsAuthenticated_WithExpiredToken_ReturnsFalse() async throws {
        // Given: Expired token stored
        try await keychainStorage.storeTokens(
            accessToken: "expired_token",
            refreshToken: "refresh_token",
            expiresIn: -1 // Already expired
        )

        // When: Check authentication status
        let isAuthenticated = await authManager.isAuthenticated()

        // Then: Should NOT be authenticated
        XCTAssertFalse(isAuthenticated, "User should NOT be authenticated with expired token")
    }

    // MARK: - Keychain Empty State Tests

    func testIsAuthenticated_WithEmptyKeychain_ReturnsFalse() async throws {
        // Given: Empty keychain (no tokens)
        // (setUp already clears keychain)

        // When: Check authentication status
        let isAuthenticated = await authManager.isAuthenticated()

        // Then: Should NOT be authenticated
        XCTAssertFalse(isAuthenticated, "User should NOT be authenticated with empty keychain")
    }

    func testGetTokenInfo_WithEmptyKeychain_ReturnsNil() async throws {
        // Given: Empty keychain
        // (setUp already clears keychain)

        // When: Get token info
        let tokenInfo = try await keychainStorage.getTokenInfo()

        // Then: Should return nil
        XCTAssertNil(tokenInfo, "Token info should be nil when keychain is empty")
    }

    // MARK: - Token Expiry Time Tests

    func testTokenTimeUntilExpiry_CalculatedCorrectly() async throws {
        // Given: Token expiring in 1 hour
        let expiresIn: TimeInterval = 3600 // 1 hour
        try await keychainStorage.storeTokens(
            accessToken: "token",
            refreshToken: "refresh",
            expiresIn: expiresIn
        )

        // When: Get token info
        let tokenInfo = try await keychainStorage.getTokenInfo()

        // Then: Time until expiry should be close to 1 hour
        let timeUntilExpiry = tokenInfo?.timeUntilExpiry ?? 0
        XCTAssertGreaterThan(timeUntilExpiry, 3500, "Should have ~1 hour until expiry")
        XCTAssertLessThan(timeUntilExpiry, 3700, "Should have ~1 hour until expiry")
    }

    func testNeedsRefreshSoon_WithExpiringToken_ReturnsTrue() async throws {
        // Given: Token expiring in 4 minutes (within 5-minute threshold)
        let expiresIn: TimeInterval = 240 // 4 minutes
        try await keychainStorage.storeTokens(
            accessToken: "token",
            refreshToken: "refresh",
            expiresIn: expiresIn
        )

        // When: Check if refresh needed soon
        let needsRefresh = await authManager.needsRefreshSoon()

        // Then: Should need refresh
        XCTAssertTrue(needsRefresh, "Should need refresh when expiring within 5 minutes")
    }

    func testNeedsRefreshSoon_WithFreshToken_ReturnsFalse() async throws {
        // Given: Token expiring in 1 hour (well beyond 5-minute threshold)
        let expiresIn: TimeInterval = 3600 // 1 hour
        try await keychainStorage.storeTokens(
            accessToken: "token",
            refreshToken: "refresh",
            expiresIn: expiresIn
        )

        // When: Check if refresh needed soon
        let needsRefresh = await authManager.needsRefreshSoon()

        // Then: Should NOT need refresh
        XCTAssertFalse(needsRefresh, "Should NOT need refresh with fresh token")
    }

    // MARK: - Disconnect Tests

    func testDisconnect_ClearsAllTokens() async throws {
        // Given: Stored tokens
        try await keychainStorage.storeTokens(
            accessToken: "token",
            refreshToken: "refresh",
            expiresIn: 3600
        )

        // Verify tokens exist
        let tokenInfoBefore = try await keychainStorage.getTokenInfo()
        XCTAssertNotNil(tokenInfoBefore, "Tokens should exist before disconnect")

        // When: Disconnect
        try await authManager.disconnect()

        // Then: All tokens should be cleared
        let tokenInfoAfter = try await keychainStorage.getTokenInfo()
        XCTAssertNil(tokenInfoAfter, "Tokens should be cleared after disconnect")

        // And: Authentication status should be false
        let isAuthenticated = await authManager.isAuthenticated()
        XCTAssertFalse(isAuthenticated, "Should NOT be authenticated after disconnect")
    }

    func testDisconnect_TriggersForensicLogs() async throws {
        // Given: Stored tokens
        try await keychainStorage.storeTokens(
            accessToken: "token",
            refreshToken: "refresh",
            expiresIn: 3600
        )

        // When: Disconnect (should trigger forensic logs)
        // Note: Forensic logs are at lines 362-368 in DexcomAuthManager.swift
        try await authManager.disconnect()

        // Then: Verify disconnect completed (logs are verified manually in console)
        let isAuthenticated = await authManager.isAuthenticated()
        XCTAssertFalse(isAuthenticated, "User should be disconnected")
    }

    // MARK: - Connection Status Check Tests

    func testConnectionStatusCheck_WithValidToken_MaintainsConnection() async throws {
        // Given: Valid token stored
        try await keychainStorage.storeTokens(
            accessToken: "valid_token",
            refreshToken: "refresh_token",
            expiresIn: 3600
        )

        // When: Check authentication status multiple times
        let isAuth1 = await authManager.isAuthenticated()
        let isAuth2 = await authManager.isAuthenticated()
        let isAuth3 = await authManager.isAuthenticated()

        // Then: Should remain authenticated
        XCTAssertTrue(isAuth1, "Should be authenticated on first check")
        XCTAssertTrue(isAuth2, "Should be authenticated on second check")
        XCTAssertTrue(isAuth3, "Should be authenticated on third check")
    }

    // MARK: - Token Buffer Tests

    func testTokenExpiration_WithBufferTime_MarkedAsExpired() async throws {
        // Given: Token expiring in 4 minutes (within 5-minute buffer)
        // Note: isTokenExpired() uses 5-minute buffer (line 74 in DexcomKeychainStorage)
        let expiresIn: TimeInterval = 240 // 4 minutes
        try await keychainStorage.storeTokens(
            accessToken: "token",
            refreshToken: "refresh",
            expiresIn: expiresIn
        )

        // When: Check if token is expired
        let isExpired = try await keychainStorage.isTokenExpired()

        // Then: Should be marked as expired due to buffer
        XCTAssertTrue(isExpired, "Token within 5-minute buffer should be considered expired")
    }

    func testTokenExpiration_OutsideBufferTime_NotMarkedAsExpired() async throws {
        // Given: Token expiring in 10 minutes (outside 5-minute buffer)
        let expiresIn: TimeInterval = 600 // 10 minutes
        try await keychainStorage.storeTokens(
            accessToken: "token",
            refreshToken: "refresh",
            expiresIn: expiresIn
        )

        // When: Check if token is expired
        let isExpired = try await keychainStorage.isTokenExpired()

        // Then: Should NOT be marked as expired
        XCTAssertFalse(isExpired, "Token outside 5-minute buffer should NOT be expired")
    }

    // MARK: - Will Expire Within Tests

    func testWillExpireWithin_ReturnsTrue_WhenWithinWindow() async throws {
        // Given: Token expiring in 10 minutes
        let expiresIn: TimeInterval = 600 // 10 minutes
        try await keychainStorage.storeTokens(
            accessToken: "token",
            refreshToken: "refresh",
            expiresIn: expiresIn
        )

        // When: Check if expires within 15 minutes
        let willExpire = await authManager.willExpireWithin(seconds: 900) // 15 minutes

        // Then: Should return true
        XCTAssertTrue(willExpire, "Token expiring in 10 min should expire within 15 min window")
    }

    func testWillExpireWithin_ReturnsFalse_WhenOutsideWindow() async throws {
        // Given: Token expiring in 1 hour
        let expiresIn: TimeInterval = 3600 // 1 hour
        try await keychainStorage.storeTokens(
            accessToken: "token",
            refreshToken: "refresh",
            expiresIn: expiresIn
        )

        // When: Check if expires within 5 minutes
        let willExpire = await authManager.willExpireWithin(seconds: 300) // 5 minutes

        // Then: Should return false
        XCTAssertFalse(willExpire, "Token expiring in 1 hour should NOT expire within 5 min window")
    }

    // MARK: - Forensic Logging Tests

    func testIsAuthenticated_TriggersForensicLogs() async throws {
        // Given: No tokens (will trigger "No token info" log)
        // (setUp already clears keychain)

        // When: Check authentication (should trigger forensic logs at lines 48-64)
        let isAuthenticated = await authManager.isAuthenticated()

        // Then: Verify result and logs are written
        XCTAssertFalse(isAuthenticated, "Should NOT be authenticated with empty keychain")
        // Forensic logs can be verified in console:
        // - "🔍 FORENSIC [DexcomAuthManager]: isAuthenticated() called"
        // - "❌ FORENSIC: No token info in keychain - user logged out"
    }

    func testGetTokenInfo_TriggersForensicLogs() async throws {
        // Given: Valid tokens
        try await keychainStorage.storeTokens(
            accessToken: "token",
            refreshToken: "refresh",
            expiresIn: 3600
        )

        // When: Get token info (should trigger forensic logs at lines 220-247)
        let tokenInfo = try await keychainStorage.getTokenInfo()

        // Then: Verify result
        XCTAssertNotNil(tokenInfo, "Token info should be retrieved")
        // Forensic logs can be verified in console:
        // - "🔍 FORENSIC [DexcomKeychainStorage]: getTokenInfo() called"
        // - "🔍 FORENSIC: Token info retrieved - isExpired: false"
    }
}
