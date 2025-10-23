//
//  UserSessionManager.swift
//  balli
//
//  Manages user sessions and conversation boundaries
//  Swift 6 strict concurrency compliant
//

import Foundation
import OSLog

// MARK: - User Session Manager Actor

actor UserSessionManager {
    // MARK: - Properties

    private let logger = AppLoggers.Data.sync

    // Session tracking
    private var currentSessionId: String?
    private var messageCountInSession = 0

    // Configuration
    private let sessionBoundaryMessageThreshold = 20 // Process boundary after 20 messages
    private let conversationBoundaryMinutes = 5.0

    // MARK: - Initialization

    init() {
        logger.info("UserSessionManager initialized")
    }

    // MARK: - Session Management

    func startNewSession() -> String {
        let sessionId = "session_\(Date().timeIntervalSince1970)"
        currentSessionId = sessionId
        messageCountInSession = 0

        logger.info("Started new session: \(sessionId, privacy: .private)")
        return sessionId
    }

    func getCurrentSessionId() -> String? {
        return currentSessionId
    }

    func incrementMessageCount() {
        messageCountInSession += 1
    }

    func getMessageCount() -> Int {
        return messageCountInSession
    }

    func resetSession() {
        currentSessionId = nil
        messageCountInSession = 0
        logger.info("Session reset")
    }

    // MARK: - Boundary Detection

    func shouldTriggerMessageBoundary() -> Bool {
        return messageCountInSession >= sessionBoundaryMessageThreshold
    }

    func shouldTriggerTimeBoundary(lastActivityTime: Date) -> Bool {
        let timeSinceLastActivity = Date().timeIntervalSince(lastActivityTime)
        return timeSinceLastActivity > (conversationBoundaryMinutes * 60)
    }

    // MARK: - Session State

    func getSessionInfo() -> (sessionId: String?, messageCount: Int) {
        return (currentSessionId, messageCountInSession)
    }
}
