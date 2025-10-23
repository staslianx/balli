//
//  SessionBoundaryProcessor.swift
//  balli
//
//  Actor responsible for session boundary detection and processing
//  Handles session lifecycle, message tracking, and boundary triggers
//  Swift 6 strict concurrency compliant
//
//  Extracted from MemoryCoordinator.swift to maintain <300 line file limit
//

import Foundation
import OSLog

// MARK: - Session Boundary Processor Actor

actor SessionBoundaryProcessor {
    // MARK: - Properties

    private let logger = AppLoggers.Data.sync
    private let sessionManager: UserSessionManager
    private let storage: MemoryStorageActor

    // MARK: - Initialization

    init(sessionManager: UserSessionManager,
         storage: MemoryStorageActor) {
        self.sessionManager = sessionManager
        self.storage = storage
        logger.info("SessionBoundaryProcessor initialized (ChatAssistant removed - local only)")
    }

    // MARK: - Session Lifecycle

    func startNewSession() async {
        let sessionId = await sessionManager.startNewSession()

        // Update storage activity time
        await storage.updateLastActivityTime(Date())

        logger.info("Started new session: \(sessionId, privacy: .private)")
    }

    // MARK: - Message Tracking

    func trackConversationMessage() async {
        // If no active session, start one
        if await sessionManager.getCurrentSessionId() == nil {
            await startNewSession()
        }

        // Increment message count
        await sessionManager.incrementMessageCount()

        // Check if boundary should be triggered
        await checkAndTriggerBoundary()
    }

    // MARK: - Boundary Detection

    func checkConversationBoundary() async -> Bool {
        guard let lastActivityTime = await storage.getLastActivityTime() else { return false }

        return await sessionManager.shouldTriggerTimeBoundary(lastActivityTime: lastActivityTime)
    }

    private func checkAndTriggerBoundary() async {
        // Trigger boundary based on message count
        if await sessionManager.shouldTriggerMessageBoundary() {
            let messageCount = await sessionManager.getMessageCount()
            logger.info("Message threshold reached (\(messageCount)), triggering boundary")
            await processConversationSessionBoundary()
        }

        // Trigger boundary based on time gap
        if await checkConversationBoundary() {
            logger.info("Time boundary reached, triggering boundary")
            await processConversationSessionBoundary()
        }
    }

    // MARK: - Boundary Processing

    func processConversationSessionBoundary() async {
        guard let sessionId = await sessionManager.getCurrentSessionId() else {
            logger.error("Cannot process session boundary - missing session ID")
            return
        }

        logger.info("Processing conversation session boundary for session: \(sessionId) (local only - no Firebase sync)")

        // ChatAssistant removed - no Firebase sync needed
        // Just reset session tracking for local memory management
        await sessionManager.resetSession()
    }

    func processConversationBoundary() async {
        guard await checkConversationBoundary() else { return }

        logger.info("Processing conversation boundary")
    }

    // MARK: - Session State

    func getCurrentSessionId() async -> String? {
        return await sessionManager.getCurrentSessionId()
    }
}
