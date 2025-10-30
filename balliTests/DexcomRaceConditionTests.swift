//
//  DexcomRaceConditionTests.swift
//  balliTests
//
//  Comprehensive tests exposing race condition in Dexcom connection status checking
//  Tests the debounce logic bug where stale cached values are returned
//
//  BUG: checkConnectionStatus() debounce logic causes false "not connected" status
//  - Multiple rapid calls within 2 seconds trigger debounce
//  - Debounced calls return early WITHOUT updating isConnected state
//  - Callers read STALE cached value and incorrectly think connection failed
//  - Even though token IS valid and authentication would succeed
//
//  These tests DOCUMENT what SHOULD happen and EXPOSE the current bug behavior
//

import XCTest
@testable import balli

/// Test Suite: Dexcom Race Condition Detection
/// Exposes the race condition bug in checkConnectionStatus() debounce logic
@MainActor
final class DexcomRaceConditionTests: XCTestCase {

    // MARK: - Properties

    var dexcomService: DexcomService!
    var keychainStorage: DexcomKeychainStorage!
    var diagnosticsLogger: DexcomDiagnosticsLogger!
    var lifecycleCoordinator: AppLifecycleCoordinator!

    // MARK: - Setup and Teardown

    override func setUp() async throws {
        try await super.setUp()

        // Clear diagnostic logs before each test
        diagnosticsLogger = DexcomDiagnosticsLogger.shared
        await diagnosticsLogger.clearLogs()

        // Initialize keychain storage and clear all tokens
        keychainStorage = DexcomKeychainStorage()
        try await keychainStorage.clearAllTokens()

        // Create fresh DexcomService instance
        dexcomService = DexcomService()

        // Get lifecycle coordinator
        lifecycleCoordinator = AppLifecycleCoordinator.shared

        // Wait for initial connection check to complete
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
    }

    override func tearDown() async throws {
        // Clear tokens and state
        try await keychainStorage.clearAllTokens()

        // Clear diagnostic logs after test
        await diagnosticsLogger.clearLogs()

        dexcomService = nil
        keychainStorage = nil
        diagnosticsLogger = nil
        lifecycleCoordinator = nil

        try await super.tearDown()
    }

    // MARK: - Helper Methods

    /// Store valid token for testing authenticated state
    private func storeValidToken() async throws {
        try await keychainStorage.storeTokens(
            accessToken: "valid_test_token",
            refreshToken: "valid_test_refresh_token",
            expiresIn: 3600 // 1 hour
        )
    }

    /// Capture all logs from diagnostics logger
    private func captureDiagnosticLogs() async -> [DexcomDiagnosticsLogger.LogEntry] {
        await diagnosticsLogger.getAllLogs()
    }

    /// Count how many times checkConnectionStatus was within debounce window
    private func countDebouncedCalls() async -> Int {
        let logs = await captureDiagnosticLogs()
        // After fix: Look for "Within debounce window" instead of "DEBOUNCED"
        return logs.filter { $0.message.contains("Within debounce window") }.count
    }

    /// Count how many times checkConnectionStatus checked authentication
    private func countAuthChecks() async -> Int {
        let logs = await captureDiagnosticLogs()
        // After fix: Auth is ALWAYS checked, so look for "Authentication check result"
        return logs.filter { $0.message.contains("Authentication check result") }.count
    }

    /// Extract final isConnected state from logs
    private func extractFinalStateFromLogs() async -> Bool? {
        let logs = await captureDiagnosticLogs()
        let stateUpdateLogs = logs.filter { $0.message.contains("State updated") }
        guard let lastStateLog = stateUpdateLogs.last else { return nil }

        // Parse "State updated - OLD=false → NEW=true" format
        if lastStateLog.message.contains("NEW=true") {
            return true
        } else if lastStateLog.message.contains("NEW=false") {
            return false
        }
        return nil
    }

    // MARK: - Test Case 1: Single Call Success (Baseline)

    /// Test that a single call to checkConnectionStatus works correctly
    /// EXPECTED: isConnected should be true, no debounce should occur
    func testSingleCall_WithValidToken_UpdatesStateCorrectly() async throws {
        // Given: Valid token stored in keychain
        try await storeValidToken()

        // When: Call checkConnectionStatus once
        await dexcomService.checkConnectionStatus()

        // Wait for async operations to complete
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        // Then: Should be connected
        XCTAssertTrue(dexcomService.isConnected, "Should be connected with valid token")

        // Verify NO debounce (this was the first call)
        let debouncedCount = await countDebouncedCalls()
        XCTAssertEqual(debouncedCount, 0, "Should NOT be within debounce window on first call")

        // Verify auth check occurred (after fix, auth is ALWAYS checked)
        let authCheckCount = await countAuthChecks()
        XCTAssertGreaterThanOrEqual(authCheckCount, 1, "Should have performed at least 1 auth check")

        // Verify forensic logs captured the state update
        let finalState = await extractFinalStateFromLogs()
        XCTAssertEqual(finalState, true, "Logs should show state updated to true")

        // Print logs for manual verification
        let logs = await captureDiagnosticLogs()
        print("\n=== Test Case 1: Single Call Logs ===")
        for log in logs {
            print(log.fullLogLine)
        }
    }

    // MARK: - Test Case 2: Rapid Concurrent Calls (Race Condition)

    /// Test rapid concurrent calls to checkConnectionStatus
    /// BUG EXPOSURE: First call succeeds, subsequent calls are debounced
    /// CRITICAL: After all calls, isConnected should be TRUE (not stale false)
    func testRapidConcurrentCalls_WithValidToken_MaintainsCorrectState() async throws {
        // Given: Valid token in keychain
        try await storeValidToken()

        // Start with false to simulate stale state
        // (In production, this happens when app starts with old cached state)
        // Note: DexcomService initializer calls checkConnectionStatus, so we need to wait
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds for initial check

        // Record initial state
        let initialState = dexcomService.isConnected
        print("\n=== Test Case 2: Initial state = \(initialState) ===")

        // When: Call checkConnectionStatus 5 times rapidly (within 100ms)
        let callCount = 5
        let service = dexcomService!

        // Start multiple concurrent tasks
        async let call1: Void = service.checkConnectionStatus()
        async let call2: Void = service.checkConnectionStatus()
        async let call3: Void = service.checkConnectionStatus()
        async let call4: Void = service.checkConnectionStatus()
        async let call5: Void = service.checkConnectionStatus()

        // Wait for all to complete
        _ = await (call1, call2, call3, call4, call5)

        // Wait for all async operations to complete
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds

        // Then: CRITICAL ASSERTION - isConnected should be TRUE
        let finalState = dexcomService.isConnected
        print("\n=== Test Case 2: Final state = \(finalState) ===")

        // THIS IS THE BUG: If finalState is false, the debounce logic returned stale value
        XCTAssertTrue(finalState, """
            🐛 BUG DETECTED: isConnected is false after concurrent calls!
            Expected: true (token is valid)
            Actual: \(finalState)

            This means:
            1. First call succeeded and updated state to true
            2. Subsequent calls were DEBOUNCED (returned early)
            3. Some caller read the STALE cached value before first call finished
            4. Result: False "not connected" status even though token IS valid
            """)

        // Verify forensic logging
        let debouncedCount = await countDebouncedCalls()
        let authCheckCount = await countAuthChecks()

        print("\n=== Test Case 2: Statistics ===")
        print("Total calls made: \(callCount)")
        print("Debounced calls: \(debouncedCount)")
        print("Auth checks performed: \(authCheckCount)")

        // After FIX: Some calls will be within debounce window (skip token refresh)
        // But ALL calls should check auth and update state
        XCTAssertGreaterThan(debouncedCount, 0, "Some calls should be within debounce window")
        XCTAssertEqual(authCheckCount, callCount, "After FIX: ALL calls should check auth (no more stale values!)")

        // Print complete logs for forensic analysis
        let logs = await captureDiagnosticLogs()
        print("\n=== Test Case 2: Complete Forensic Logs ===")
        for log in logs {
            print(log.fullLogLine)
        }
    }

    // MARK: - Test Case 3: AppLifecycleCoordinator Foreground Simulation

    /// Test the EXACT foreground transition flow that causes the bug
    /// Simulates: App enters foreground + multiple views call checkConnectionStatus
    /// BUG EXPOSURE: AppLifecycleCoordinator reads stale isConnected=false
    func testForegroundTransition_WithConcurrentChecks_MaintainsValidConnection() async throws {
        // Given: Valid token in keychain (simulating app restart with valid token)
        try await storeValidToken()

        // Simulate stale cached state (app just started, state not yet refreshed)
        // Wait for initial check to complete first
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        print("\n=== Test Case 3: Simulating Foreground Transition ===")
        print("Initial cached state: \(dexcomService.isConnected)")

        // When: Simulate foreground transition + concurrent view checks
        // This mimics what happens in production:
        // 1. AppLifecycleCoordinator.handleForegroundTransition() calls checkConnectionStatus()
        // 2. Multiple views (7-8) ALSO call checkConnectionStatus() within milliseconds

        let coordinator = lifecycleCoordinator!
        let service = dexcomService!

        // Start all concurrent operations
        async let lifecycleTask: Void = { @MainActor in
            print("🔐 AppLifecycleCoordinator: Calling checkConnectionStatus")
            await coordinator.handleForegroundTransition()
            print("🔐 AppLifecycleCoordinator: After foreground transition")
            let state = service.isConnected
            print("🔐 AppLifecycleCoordinator: isConnected = \(state)")
        }()

        // Concurrent view checks (simulating 7 views)
        async let view1: Void = {
            try? await Task.sleep(nanoseconds: 10_000_000)
            await service.checkConnectionStatus()
        }()
        async let view2: Void = {
            try? await Task.sleep(nanoseconds: 20_000_000)
            await service.checkConnectionStatus()
        }()
        async let view3: Void = {
            try? await Task.sleep(nanoseconds: 30_000_000)
            await service.checkConnectionStatus()
        }()
        async let view4: Void = {
            try? await Task.sleep(nanoseconds: 40_000_000)
            await service.checkConnectionStatus()
        }()
        async let view5: Void = {
            try? await Task.sleep(nanoseconds: 50_000_000)
            await service.checkConnectionStatus()
        }()
        async let view6: Void = {
            try? await Task.sleep(nanoseconds: 60_000_000)
            await service.checkConnectionStatus()
        }()
        async let view7: Void = {
            try? await Task.sleep(nanoseconds: 70_000_000)
            await service.checkConnectionStatus()
        }()

        // Wait for all operations
        _ = await (lifecycleTask, view1, view2, view3, view4, view5, view6, view7)

        // Wait for all operations to complete
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds

        // Then: CRITICAL ASSERTIONS
        let finalState = dexcomService.isConnected
        print("\n=== Test Case 3: Final State After Concurrent Operations ===")
        print("isConnected: \(finalState)")

        XCTAssertTrue(finalState, """
            🐛 BUG DETECTED: AppLifecycleCoordinator sees false "not connected"!

            What happened:
            1. App entered foreground with valid token in keychain
            2. AppLifecycleCoordinator called checkConnectionStatus()
            3. Multiple views ALSO called checkConnectionStatus() concurrently
            4. Debounce logic kicked in, subsequent calls returned early
            5. AppLifecycleCoordinator READ the STALE cached isConnected=false
            6. Even though token IS valid!

            Result: False "not connected" status, potential auto-logout
            """)

        // Verify forensic logging shows the race condition
        let logs = await captureDiagnosticLogs()
        let lifecycleLogs = logs.filter { $0.category == .lifecycle }

        print("\n=== Test Case 3: Lifecycle Logs ===")
        for log in lifecycleLogs {
            print(log.fullLogLine)
        }

        // Look for the warning about stale cached value
        let staleValueWarnings = logs.filter { $0.message.contains("STALE") }
        print("\n=== Test Case 3: Stale Value Warnings ===")
        for warning in staleValueWarnings {
            print(warning.fullLogLine)
        }

        // Print complete logs
        print("\n=== Test Case 3: Complete Forensic Logs ===")
        for log in logs {
            print(log.fullLogLine)
        }
    }

    // MARK: - Test Case 4: Debounce Interval Boundary

    /// Test debounce interval boundary conditions
    /// Verifies the 2-second debounce window works as expected
    func testDebounceIntervalBoundary_RespectsTwoSecondWindow() async throws {
        // Given: Valid token
        try await storeValidToken()

        print("\n=== Test Case 4: Testing Debounce Boundary ===")

        // When: First call
        print("Call #1: Initial check")
        await dexcomService.checkConnectionStatus()
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        let stateAfterFirst = dexcomService.isConnected
        print("State after call #1: \(stateAfterFirst)")

        // Second call at 1.9 seconds (just UNDER 2-second debounce)
        print("\nWaiting 1.9 seconds...")
        try await Task.sleep(nanoseconds: 1_900_000_000) // 1.9 seconds
        print("Call #2: At 1.9 seconds (should be DEBOUNCED)")
        await dexcomService.checkConnectionStatus()
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        // Third call at 2.1 seconds (OVER 2-second debounce)
        print("\nWaiting additional 0.2 seconds (total 2.1s)...")
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        print("Call #3: At 2.1 seconds (should PROCEED)")
        await dexcomService.checkConnectionStatus()
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        let stateAfterThird = dexcomService.isConnected
        print("State after call #3: \(stateAfterThird)")

        // Then: Verify debounce behavior
        let logs = await captureDiagnosticLogs()
        let debouncedLogs = logs.filter { $0.message.contains("DEBOUNCED") }
        let proceedingLogs = logs.filter { $0.message.contains("PROCEEDING") }

        print("\n=== Test Case 4: Debounce Statistics ===")
        print("Debounced calls: \(debouncedLogs.count)")
        print("Proceeding calls: \(proceedingLogs.count)")

        // Should have exactly 1 debounced call (call #2)
        XCTAssertEqual(debouncedLogs.count, 1, "Call #2 should be debounced")

        // Should have exactly 2 proceeding calls (call #1 and #3)
        XCTAssertEqual(proceedingLogs.count, 2, "Calls #1 and #3 should proceed")

        // Final state should be true
        XCTAssertTrue(stateAfterThird, "State should remain true after call #3")

        // Print complete logs
        print("\n=== Test Case 4: Complete Forensic Logs ===")
        for log in logs {
            print(log.fullLogLine)
        }
    }

    // MARK: - Test Case 5: State Consistency Under Concurrent Load

    /// Test state consistency with heavy concurrent load
    /// Simulates 10 concurrent threads all checking connection status
    /// EXPECTED: All threads should eventually see isConnected=true
    func testConcurrentLoad_WithTenThreads_MaintainsConsistentState() async throws {
        // Given: Valid token
        try await storeValidToken()

        print("\n=== Test Case 5: Testing 10 Concurrent Threads ===")

        // When: 10 concurrent threads all call checkConnectionStatus
        let threadCount = 10
        let service = dexcomService!

        // Start all concurrent operations and collect observed states
        async let state1: Bool = { @MainActor in
            await service.checkConnectionStatus()
            return service.isConnected
        }()
        async let state2: Bool = { @MainActor in
            await service.checkConnectionStatus()
            return service.isConnected
        }()
        async let state3: Bool = { @MainActor in
            await service.checkConnectionStatus()
            return service.isConnected
        }()
        async let state4: Bool = { @MainActor in
            await service.checkConnectionStatus()
            return service.isConnected
        }()
        async let state5: Bool = { @MainActor in
            await service.checkConnectionStatus()
            return service.isConnected
        }()
        async let state6: Bool = { @MainActor in
            await service.checkConnectionStatus()
            return service.isConnected
        }()
        async let state7: Bool = { @MainActor in
            await service.checkConnectionStatus()
            return service.isConnected
        }()
        async let state8: Bool = { @MainActor in
            await service.checkConnectionStatus()
            return service.isConnected
        }()
        async let state9: Bool = { @MainActor in
            await service.checkConnectionStatus()
            return service.isConnected
        }()
        async let state10: Bool = { @MainActor in
            await service.checkConnectionStatus()
            return service.isConnected
        }()

        // Collect all observed states
        let observedStates = await [state1, state2, state3, state4, state5, state6, state7, state8, state9, state10]

        // Wait for all operations to complete
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        // Then: Verify state consistency
        let finalState = dexcomService.isConnected
        print("\n=== Test Case 5: Results ===")
        print("Final isConnected: \(finalState)")
        print("Observed states: \(observedStates)")

        // Count how many threads observed true vs false
        let trueCount = observedStates.filter { $0 == true }.count
        let falseCount = observedStates.filter { $0 == false }.count

        print("Threads that saw true: \(trueCount)")
        print("Threads that saw false: \(falseCount)")

        // CRITICAL: Final state MUST be true (token is valid)
        XCTAssertTrue(finalState, """
            🐛 BUG: Final state is false after concurrent load!
            Expected: true (token is valid)
            Actual: \(finalState)
            """)

        // BUG DETECTION: If ANY thread saw false, it read stale cached value
        if falseCount > 0 {
            print("\n⚠️ WARNING: \(falseCount) thread(s) observed STALE false value!")
            print("This indicates race condition where debounced calls returned before state update")
        }

        // Ideally, all threads should see true (but with the bug, some might see false)
        // This assertion will FAIL if the bug exists, documenting what SHOULD happen
        XCTAssertEqual(trueCount, threadCount, """
            🐛 RACE CONDITION DETECTED: Some threads saw stale false value!
            Expected: All \(threadCount) threads see true
            Actual: \(trueCount) threads saw true, \(falseCount) saw false

            This proves the bug: Debounced calls return early with stale cached state
            """)

        // Verify forensic logging
        let logs = await captureDiagnosticLogs()
        let debouncedCount = await countDebouncedCalls()
        let authCheckCount = await countAuthChecks()

        print("\n=== Test Case 5: Debounce Statistics ===")
        print("Total threads: \(threadCount)")
        print("Debounced calls: \(debouncedCount)")
        print("Auth checks performed: \(authCheckCount)")
        print("Total log entries: \(logs.count)")

        // Print complete logs
        print("\n=== Test Case 5: Complete Forensic Logs ===")
        for log in logs {
            print(log.fullLogLine)
        }
    }

    // MARK: - Additional Helper Tests

    /// Test that forensic logging actually captures the events
    func testForensicLogging_CapturesAllEvents() async throws {
        // Given: Valid token
        try await storeValidToken()

        // When: Call checkConnectionStatus
        await dexcomService.checkConnectionStatus()
        try await Task.sleep(nanoseconds: 100_000_000)

        // Then: Verify logs were captured
        let logs = await captureDiagnosticLogs()
        XCTAssertGreaterThan(logs.count, 0, "Should have captured diagnostic logs")

        // Verify we have connection logs
        let connectionLogs = logs.filter { $0.category == .connection }
        XCTAssertGreaterThan(connectionLogs.count, 0, "Should have connection logs")

        print("\n=== Forensic Logging Test: Captured Logs ===")
        for log in logs {
            print(log.fullLogLine)
        }
    }
}
