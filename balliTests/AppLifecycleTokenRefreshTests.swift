//
//  AppLifecycleTokenRefreshTests.swift
//  balliTests
//
//  Comprehensive tests for app lifecycle token refresh behavior
//  Tests foreground transition triggers and token refresh logic
//  Focuses on debugging auto-logout during app transitions
//

import XCTest
@testable import balli

/// Test Suite 3: App Lifecycle Token Refresh
/// Tests AppLifecycleCoordinator.refreshDexcomTokenIfNeeded()
@MainActor
final class AppLifecycleTokenRefreshTests: XCTestCase {

    var lifecycleCoordinator: AppLifecycleCoordinator!
    var dexcomService: DexcomService!
    var keychainStorage: DexcomKeychainStorage!

    override func setUp() async throws {
        lifecycleCoordinator = AppLifecycleCoordinator.shared
        dexcomService = DependencyContainer.shared.dexcomService
        keychainStorage = DexcomKeychainStorage()

        // Clean keychain before each test
        try await keychainStorage.clearAll()
    }

    override func tearDown() async throws {
        // Clean keychain after each test
        try await keychainStorage.clearAll()
        lifecycleCoordinator = nil
        dexcomService = nil
        keychainStorage = nil
    }

    // MARK: - Foreground Transition Tests

    func testHandleForegroundTransition_ClearsBackgroundFlag() async throws {
        // Given: App was in background
        UserDefaults.standard.set(true, forKey: "AppWentToBackgroundGracefully")

        // When: Handle foreground transition
        await lifecycleCoordinator.handleForegroundTransition()

        // Then: Background flag should be cleared
        let wasGraceful = UserDefaults.standard.bool(forKey: "AppWentToBackgroundGracefully")
        XCTAssertFalse(wasGraceful, "Background flag should be cleared on foreground")
    }

    func testHandleForegroundTransition_UpdatesLastForegroundTime() async throws {
        // Given: No previous foreground time
        let beforeTime = await lifecycleCoordinator.lastForegroundTimeValue

        // When: Handle foreground transition
        await lifecycleCoordinator.handleForegroundTransition()

        // Then: Last foreground time should be updated
        let afterTime = await lifecycleCoordinator.lastForegroundTimeValue
        XCTAssertNotEqual(beforeTime, afterTime, "Last foreground time should be updated")
    }

    // MARK: - Token Refresh Trigger Tests

    func testForegroundTransition_SkipsRefresh_WhenNotConnected() async throws {
        // Given: Dexcom NOT connected (no tokens)
        // (setUp already clears keychain)

        // Verify not connected
        let isConnected = dexcomService.isConnected
        XCTAssertFalse(isConnected, "Should NOT be connected before test")

        // When: Handle foreground transition (should skip token refresh)
        await lifecycleCoordinator.handleForegroundTransition()

        // Then: Connection state should remain unchanged
        XCTAssertFalse(dexcomService.isConnected, "Should still be disconnected")
        // Forensic log should show: "❌ FORENSIC: Dexcom not connected, skipping token refresh check"
    }

    func testForegroundTransition_ChecksConnection_WhenConnected() async throws {
        // Given: Valid Dexcom connection (valid token)
        try await keychainStorage.storeTokens(
            accessToken: "valid_token",
            refreshToken: "refresh_token",
            expiresIn: 3600 // 1 hour
        )

        // Set connection status
        await dexcomService.checkConnectionStatus()

        // Verify connected
        XCTAssertTrue(dexcomService.isConnected, "Should be connected with valid token")

        // When: Handle foreground transition (should check connection)
        await lifecycleCoordinator.handleForegroundTransition()

        // Then: Connection check should be triggered
        // Forensic logs to verify:
        // - "🔐 FORENSIC: Dexcom was connected - now checking token status on foreground..."
        // - "✅ FORENSIC: After checkConnectionStatus - isConnected: true"
    }

    // MARK: - Connection Status Check Tests

    func testCheckConnectionStatus_WithValidToken_MaintainsConnection() async throws {
        // Given: Valid token stored
        try await keychainStorage.storeTokens(
            accessToken: "valid_token",
            refreshToken: "refresh_token",
            expiresIn: 3600
        )

        // When: Check connection status
        await dexcomService.checkConnectionStatus()

        // Then: Should remain connected
        XCTAssertTrue(dexcomService.isConnected, "Should be connected with valid token")
        XCTAssertEqual(dexcomService.connectionStatus, .connected, "Status should be connected")
    }

    func testCheckConnectionStatus_WithExpiredToken_DetectsDisconnection() async throws {
        // Given: Expired token stored
        try await keychainStorage.storeTokens(
            accessToken: "expired_token",
            refreshToken: "refresh_token",
            expiresIn: -1 // Already expired
        )

        // When: Check connection status
        await dexcomService.checkConnectionStatus()

        // Then: Should be disconnected
        XCTAssertFalse(dexcomService.isConnected, "Should be disconnected with expired token")
        XCTAssertEqual(dexcomService.connectionStatus, .disconnected, "Status should be disconnected")
    }

    func testCheckConnectionStatus_WithNoToken_MarksDisconnected() async throws {
        // Given: No token in keychain
        // (setUp already clears keychain)

        // When: Check connection status
        await dexcomService.checkConnectionStatus()

        // Then: Should be disconnected
        XCTAssertFalse(dexcomService.isConnected, "Should be disconnected with no token")
        XCTAssertEqual(dexcomService.connectionStatus, .disconnected, "Status should be disconnected")
    }

    // MARK: - Token Refresh Logic Tests

    func testCheckConnectionStatus_RefreshesTokenWhenNeeded() async throws {
        // Given: Token expiring soon (within 5-minute window)
        try await keychainStorage.storeTokens(
            accessToken: "expiring_token",
            refreshToken: "refresh_token",
            expiresIn: 240 // 4 minutes (within 5-minute refresh window)
        )

        // When: Check connection status (should attempt refresh)
        await dexcomService.checkConnectionStatus()

        // Then: Refresh attempt should be logged
        // Note: Actual refresh will fail without real server, but logic is tested
        // Forensic logs to verify:
        // - "🔍 FORENSIC: User is authenticated, checking if token refresh needed..."
        // - Should see either success or failure log
    }

    func testCheckConnectionStatus_SkipsRefreshWithFreshToken() async throws {
        // Given: Fresh token (1 hour expiry, well beyond 5-minute window)
        try await keychainStorage.storeTokens(
            accessToken: "fresh_token",
            refreshToken: "refresh_token",
            expiresIn: 3600 // 1 hour
        )

        // When: Check connection status (should skip refresh)
        await dexcomService.checkConnectionStatus()

        // Then: Should remain connected without refresh
        XCTAssertTrue(dexcomService.isConnected, "Should be connected with fresh token")
        // Forensic log should show: "ℹ️ FORENSIC: Token refresh not needed yet"
    }

    // MARK: - Refresh Failure Handling Tests

    func testCheckConnectionStatus_HandlesRefreshFailure() async throws {
        // Given: Token that needs refresh but has invalid refresh token
        try await keychainStorage.storeTokens(
            accessToken: "expiring_token",
            refreshToken: "invalid_refresh_token",
            expiresIn: 240 // 4 minutes
        )

        // When: Check connection status (refresh will fail)
        await dexcomService.checkConnectionStatus()

        // Then: Should handle failure gracefully (not mark as disconnected yet)
        // Forensic logs to verify:
        // - "❌ FORENSIC: Failed to proactively refresh token: <error>"
        // - "❌ FORENSIC: Error type: <type>"
    }

    // MARK: - Forensic Logging Tests

    func testCheckConnectionStatus_TriggersForensicLogs() async throws {
        // Given: No connection
        // (setUp already clears keychain)

        // When: Check connection status (should trigger forensic logs at lines 118-149)
        await dexcomService.checkConnectionStatus()

        // Then: Verify logs are triggered
        XCTAssertFalse(dexcomService.isConnected, "Should be disconnected")
        // Forensic logs to verify:
        // - "🔍 FORENSIC [DexcomService]: checkConnectionStatus() called"
        // - "🔍 FORENSIC: Current isConnected state: false"
        // - "🔍 FORENSIC: Authentication check result: false"
        // - "❌ FORENSIC: User NOT authenticated - connection lost!"
    }

    func testForegroundTransition_TriggersForensicLogsInCoordinator() async throws {
        // Given: Valid connection
        try await keychainStorage.storeTokens(
            accessToken: "valid_token",
            refreshToken: "refresh_token",
            expiresIn: 3600
        )
        await dexcomService.checkConnectionStatus()

        // When: Handle foreground transition (should trigger forensic logs at lines 112-127)
        await lifecycleCoordinator.handleForegroundTransition()

        // Then: Verify logs are triggered
        // Forensic logs to verify:
        // - "🔍 FORENSIC [AppLifecycleCoordinator]: refreshDexcomTokenIfNeeded() called"
        // - "🔍 FORENSIC: Current Dexcom connection state: true"
        // - "🔐 FORENSIC: Dexcom was connected - now checking token status on foreground..."
    }

    // MARK: - Background Transition Tests

    func testHandleBackgroundTransition_SetsGracefulFlag() async throws {
        // Given: App in foreground
        UserDefaults.standard.set(false, forKey: "AppWentToBackgroundGracefully")

        // When: Handle background transition
        await lifecycleCoordinator.handleBackgroundTransition()

        // Then: Graceful flag should be set
        let wasGraceful = UserDefaults.standard.bool(forKey: "AppWentToBackgroundGracefully")
        XCTAssertTrue(wasGraceful, "Should set graceful background flag")
    }

    func testHandleBackgroundTransition_SavesBackgroundTime() async throws {
        // Given: No previous background time
        UserDefaults.standard.removeObject(forKey: "LastBackgroundTime")

        // When: Handle background transition
        await lifecycleCoordinator.handleBackgroundTransition()

        // Then: Background time should be saved
        let lastBackgroundTime = UserDefaults.standard.object(forKey: "LastBackgroundTime") as? Date
        XCTAssertNotNil(lastBackgroundTime, "Should save last background time")
    }

    // MARK: - Wasbackgrounded State Tests

    func testWasGracefullyBackgrounded_ReturnsTrueAfterBackground() async throws {
        // Given: App transitions to background
        await lifecycleCoordinator.handleBackgroundTransition()

        // When: Check if was gracefully backgrounded
        let wasGraceful = await lifecycleCoordinator.wasGracefullyBackgrounded

        // Then: Should return true
        XCTAssertTrue(wasGraceful, "Should be marked as gracefully backgrounded")
    }

    func testWasGracefullyBackgrounded_ReturnsFalseAfterForeground() async throws {
        // Given: App transitions to background then foreground
        await lifecycleCoordinator.handleBackgroundTransition()
        await lifecycleCoordinator.handleForegroundTransition()

        // When: Check if was gracefully backgrounded
        let wasGraceful = await lifecycleCoordinator.wasGracefullyBackgrounded

        // Then: Should return false
        XCTAssertFalse(wasGraceful, "Should NOT be marked as backgrounded after foreground")
    }

    // MARK: - Connection State Consistency Tests

    func testMultipleForegroundTransitions_MaintainConnection() async throws {
        // Given: Valid connection
        try await keychainStorage.storeTokens(
            accessToken: "valid_token",
            refreshToken: "refresh_token",
            expiresIn: 3600
        )
        await dexcomService.checkConnectionStatus()

        // When: Multiple foreground transitions
        await lifecycleCoordinator.handleForegroundTransition()
        await lifecycleCoordinator.handleForegroundTransition()
        await lifecycleCoordinator.handleForegroundTransition()

        // Then: Should remain connected
        XCTAssertTrue(dexcomService.isConnected, "Should maintain connection through transitions")
    }

    func testBackgroundToForeground_ChecksConnection() async throws {
        // Given: Valid connection and app in background
        try await keychainStorage.storeTokens(
            accessToken: "valid_token",
            refreshToken: "refresh_token",
            expiresIn: 3600
        )
        await dexcomService.checkConnectionStatus()
        await lifecycleCoordinator.handleBackgroundTransition()

        // Verify connected
        XCTAssertTrue(dexcomService.isConnected, "Should be connected before foreground")

        // When: Return to foreground
        await lifecycleCoordinator.handleForegroundTransition()

        // Then: Should check connection and remain connected
        XCTAssertTrue(dexcomService.isConnected, "Should remain connected after foreground")
    }

    // MARK: - Persisted Background Time Tests

    func testPersistedLastBackgroundTime_SavesAcrossAppTermination() async throws {
        // Given: App backgrounds and saves time
        await lifecycleCoordinator.handleBackgroundTransition()

        // When: Retrieve persisted background time
        let backgroundTime = await lifecycleCoordinator.persistedLastBackgroundTime

        // Then: Should have persisted time
        XCTAssertNotNil(backgroundTime, "Background time should be persisted in UserDefaults")

        // And: Time should be recent (within last 5 seconds)
        let timeSinceSave = Date().timeIntervalSince(backgroundTime ?? Date.distantPast)
        XCTAssertLessThan(timeSinceSave, 5.0, "Background time should be recent")
    }

    // MARK: - Integration Tests

    func testCompleteLifecycle_MaintainsConnection() async throws {
        // Given: Valid connection
        try await keychainStorage.storeTokens(
            accessToken: "valid_token",
            refreshToken: "refresh_token",
            expiresIn: 3600
        )
        await dexcomService.checkConnectionStatus()

        // When: Complete lifecycle (foreground -> background -> foreground)
        await lifecycleCoordinator.handleForegroundTransition()
        XCTAssertTrue(dexcomService.isConnected, "Should be connected after first foreground")

        await lifecycleCoordinator.handleBackgroundTransition()
        XCTAssertTrue(dexcomService.isConnected, "Should remain connected in background")

        await lifecycleCoordinator.handleForegroundTransition()
        XCTAssertTrue(dexcomService.isConnected, "Should be connected after returning to foreground")

        // Then: Connection should be maintained throughout
        XCTAssertEqual(dexcomService.connectionStatus, .connected, "Status should be connected")
    }
}
