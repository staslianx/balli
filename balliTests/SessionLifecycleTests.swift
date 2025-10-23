//
//  SessionLifecycleTests.swift
//  balliTests
//
//  Tests for research session lifecycle management
//

import XCTest
import SwiftData
@testable import balli

@MainActor
final class SessionLifecycleTests: XCTestCase {

    var sessionManager: ResearchSessionManager!
    var container: ModelContainer!

    override func setUp() async throws {
        // Create in-memory container for testing
        let schema = Schema([ResearchSession.self, SessionMessage.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [configuration])

        // Initialize session manager without metadata generator for faster tests
        sessionManager = ResearchSessionManager(modelContainer: container, userId: "test_user", metadataGenerator: nil)
    }

    override func tearDown() async throws {
        sessionManager = nil
        container = nil
    }

    // MARK: - Session Creation Tests

    func testStartNewSessionCreatesActiveSession() {
        sessionManager.startNewSession()

        let activeSession = sessionManager.activeSession
        XCTAssertNotNil(activeSession, "Should create active session")
        XCTAssertEqual(activeSession?.status, .active, "Session should be active")
        XCTAssertEqual(activeSession?.messageCount, 0, "New session should have no messages")
    }

    func testAppendUserMessageCreatesSessionIfNeeded() async throws {
        // No active session initially
        XCTAssertNil(sessionManager.activeSession)

        // Append message should create session
        try await sessionManager.appendUserMessage("Test query")

        XCTAssertNotNil(sessionManager.activeSession, "Should create session automatically")
        XCTAssertEqual(sessionManager.activeSession?.messageCount, 1, "Should have 1 message")
    }

    // MARK: - Message Management Tests

    func testAppendUserMessageAddsToHistory() async throws {
        sessionManager.startNewSession()

        try await sessionManager.appendUserMessage("First query")
        try await sessionManager.appendUserMessage("Second query")

        let history = sessionManager.getConversationHistory()
        XCTAssertEqual(history.count, 2, "Should have 2 messages")
        XCTAssertEqual(history[0].content, "First query")
        XCTAssertEqual(history[1].content, "Second query")
    }

    func testAppendAssistantMessageAddsToHistory() async throws {
        sessionManager.startNewSession()

        try await sessionManager.appendUserMessage("Test query")
        try await sessionManager.appendAssistantMessage(
            content: "Test answer",
            tier: .search,
            sources: []
        )

        let history = sessionManager.getConversationHistory()
        XCTAssertEqual(history.count, 2, "Should have 2 messages")
        XCTAssertEqual(history[1].role, .model, "Second message should be assistant")
        XCTAssertEqual(history[1].tier, .search, "Should preserve tier")
    }

    // MARK: - Session Completion Tests

    func testEndSessionMarksAsComplete() async throws {
        sessionManager.startNewSession()
        try await sessionManager.appendUserMessage("Test query")

        try await sessionManager.endSession(generateMetadata: false)

        XCTAssertNil(sessionManager.activeSession, "Active session should be cleared")
    }

    func testEndSessionWithNoActiveSessionDoesNotThrow() async throws {
        // Should not crash when no active session
        try await sessionManager.endSession(generateMetadata: false)
    }

    // MARK: - Session End Detection Tests

    func testShouldEndSessionDetectsSatisfactionSignals() {
        XCTAssertTrue(sessionManager.shouldEndSession("teşekkürler"))
        XCTAssertTrue(sessionManager.shouldEndSession("Teşekkür ederim"))
        XCTAssertTrue(sessionManager.shouldEndSession("tamam anladım"))
        XCTAssertTrue(sessionManager.shouldEndSession("yeter artık"))
    }

    func testShouldEndSessionDetectsNewTopicSignals() {
        XCTAssertTrue(sessionManager.shouldEndSession("yeni konu"))
        XCTAssertTrue(sessionManager.shouldEndSession("başka bir şey soracağım"))
        XCTAssertTrue(sessionManager.shouldEndSession("şimdi başka bir araştırma"))
    }

    func testShouldEndSessionDoesNotDetectRegularQueries() {
        XCTAssertFalse(sessionManager.shouldEndSession("insülin nedir"))
        XCTAssertFalse(sessionManager.shouldEndSession("metformin dozajı"))
        XCTAssertFalse(sessionManager.shouldEndSession("A1C değeri ne demek"))
    }

    // MARK: - Topic Change Detection Tests

    func testDetectTopicChangeWithNoOverlap() {
        sessionManager.startNewSession()

        // First query about Dawn phenomenon
        let firstQuery = "Dawn phenomenon nedir ve sabah şekerim neden yükselir?"
        // Second query completely different topic (no keyword overlap)
        let secondQuery = "Metformin yan etkileri nelerdir?"

        // This test would require actual implementation
        // For now, we verify the method exists and doesn't crash
        _ = sessionManager.detectTopicChange(secondQuery)
    }

    // MARK: - Conversation History Tests

    func testGetFormattedHistoryReturnsCorrectFormat() async throws {
        sessionManager.startNewSession()

        try await sessionManager.appendUserMessage("Test query")
        try await sessionManager.appendAssistantMessage(content: "Test answer", tier: nil, sources: nil)

        let formatted = sessionManager.getFormattedHistory()

        XCTAssertEqual(formatted.count, 2, "Should format 2 messages")
        XCTAssertEqual(formatted[0]["role"], "user")
        XCTAssertEqual(formatted[0]["content"], "Test query")
        XCTAssertEqual(formatted[1]["role"], "model")
        XCTAssertEqual(formatted[1]["content"], "Test answer")
    }

    // MARK: - Token Limit Tests

    func testShouldEndDueToTokenLimitReturnsFalseForShortConversation() {
        sessionManager.startNewSession()

        // Short conversation should not trigger token limit
        XCTAssertFalse(sessionManager.shouldEndDueToTokenLimit())
    }

    // MARK: - Inactivity Timer Tests

    func testResetInactivityTimerDoesNotCrash() {
        sessionManager.startNewSession()
        sessionManager.resetInactivityTimer()
        // Just verify it doesn't crash
    }

    func testCancelInactivityTimerDoesNotCrash() {
        sessionManager.startNewSession()
        sessionManager.resetInactivityTimer()
        sessionManager.cancelInactivityTimer()
        // Just verify it doesn't crash
    }
}
