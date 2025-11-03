import Foundation
import SwiftData
import OSLog

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.balli",
    category: "SessionManager"
)

/// In-memory representation of an active research session
struct ActiveSessionState {
    var sessionId: UUID
    var conversationHistory: [SessionMessageData]
    var status: SessionStatus
    var createdAt: Date
    var lastUpdated: Date

    var messageCount: Int {
        conversationHistory.count
    }

    init() {
        self.sessionId = UUID()
        self.conversationHistory = []
        self.status = .active
        self.createdAt = Date()
        self.lastUpdated = Date()
    }
}

/// Lightweight in-memory message data structure
struct SessionMessageData: Sendable {
    let id: UUID
    let role: MessageRole
    let content: String
    let timestamp: Date
    let tier: ResponseTier?
    let sources: [ResearchSource]?
    let imageAttachment: ImageAttachment?

    init(
        role: MessageRole,
        content: String,
        tier: ResponseTier? = nil,
        sources: [ResearchSource]? = nil,
        imageAttachment: ImageAttachment? = nil
    ) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.timestamp = Date()
        self.tier = tier
        self.sources = sources
        self.imageAttachment = imageAttachment
    }
}

/// Manages research conversation sessions with in-memory active session and SwiftData persistence
@MainActor
final class ResearchSessionManager: ObservableObject {
    // MARK: - Published State

    /// Current active session (in-memory, fast access)
    @Published private(set) var activeSession: ActiveSessionState?

    // MARK: - Dependencies

    private let storageActor: SessionStorageActor
    private let metadataGenerator: SessionMetadataGenerator?
    private let userId: String

    // MARK: - Configuration

    /// Auto-save threshold (messages)
    private let autoSaveThreshold = 4

    /// Token limit threshold for graceful session end
    private let tokenLimitThreshold = 150_000

    /// Inactivity timeout (30 minutes in seconds)
    private let inactivityTimeout: TimeInterval = 1800

    // MARK: - Inactivity Timer

    /// Task that handles inactivity timeout
    private var inactivityTimer: Task<Void, Never>?

    // MARK: - Initialization

    init(modelContainer: ModelContainer, userId: String, metadataGenerator: SessionMetadataGenerator? = nil) {
        self.storageActor = SessionStorageActor(modelContainer: modelContainer)
        self.metadataGenerator = metadataGenerator
        self.userId = userId
        logger.info("ResearchSessionManager initialized for user: \(userId)")
    }

    // MARK: - Session Lifecycle

    /// Starts a new research session
    func startNewSession() {
        let newSession = ActiveSessionState()
        activeSession = newSession
        logger.warning("🆕 [SESSION-LIFECYCLE] Started NEW session: \(newSession.sessionId)")

        // Start inactivity timer for new session
        resetInactivityTimer()
    }

    /// Saves the current session to SwiftData WITHOUT clearing it (used for app backgrounding)
    /// This allows conversation history to persist across app backgrounding
    func saveActiveSession() async throws {
        guard let session = activeSession else {
            logger.debug("No active session to save")
            return
        }

        // Convert conversation history to raw data for storage
        let conversationData = session.conversationHistory.map { message in
            (
                id: message.id,
                role: message.role.rawValue,
                content: message.content,
                timestamp: message.timestamp,
                tier: message.tier?.rawValue,
                sourcesData: message.sources.flatMap { try? JSONEncoder().encode($0) },
                imageAttachmentData: message.imageAttachment.flatMap { try? JSONEncoder().encode($0) }
            )
        }

        // Save to SwiftData without metadata (backup only)
        try await storageActor.saveSession(
            sessionId: session.sessionId,
            conversationHistory: conversationData,
            status: session.status.rawValue,
            createdAt: session.createdAt,
            lastUpdated: session.lastUpdated,
            title: nil,
            summary: nil,
            keyTopics: []
        )

        logger.info("💾 Active session saved to storage (without clearing): \(session.sessionId)")
    }

    /// Ends the current session and persists it to SwiftData
    /// - Parameter generateMetadata: Whether to generate title, summary, and key topics
    func endSession(generateMetadata: Bool = true) async throws {
        guard var session = activeSession else {
            logger.warning("Attempted to end session but no active session exists")
            return
        }

        session.status = .complete
        session.lastUpdated = Date()

        var title: String?
        var summary: String?
        var keyTopics: [String] = []

        // Generate metadata if requested
        if generateMetadata, let generator = metadataGenerator, !session.conversationHistory.isEmpty {
            logger.info("Generating metadata for session: \(session.sessionId)")

            // Capture conversation history as local value to avoid data races
            let conversationHistory = session.conversationHistory

            // Use unified backend call for efficiency (single LLM request)
            (title, summary, keyTopics) = try await generator.generateAllMetadata(conversationHistory, userId: self.userId)
        }

        // Convert conversation history to raw data for storage
        let conversationData = session.conversationHistory.map { message in
            (
                id: message.id,
                role: message.role.rawValue,
                content: message.content,
                timestamp: message.timestamp,
                tier: message.tier?.rawValue,
                sourcesData: message.sources.flatMap { try? JSONEncoder().encode($0) },
                imageAttachmentData: message.imageAttachment.flatMap { try? JSONEncoder().encode($0) }
            )
        }

        // Save to SwiftData with raw data
        try await storageActor.saveSession(
            sessionId: session.sessionId,
            conversationHistory: conversationData,
            status: session.status.rawValue,
            createdAt: session.createdAt,
            lastUpdated: session.lastUpdated,
            title: title,
            summary: summary,
            keyTopics: keyTopics
        )

        // Cancel inactivity timer since session is ending
        cancelInactivityTimer()

        // Clear active session
        activeSession = nil

        logger.warning("❌ [SESSION-LIFECYCLE] Session ENDED and CLEARED: \(session.sessionId)")
    }

    /// Checks if the current session should end based on token limit
    /// - Returns: True if session should end due to token limit
    func shouldEndDueToTokenLimit() -> Bool {
        guard let session = activeSession else { return false }

        let estimatedTokens = TokenEstimator.estimateTokens(session.conversationHistory)
        return estimatedTokens > tokenLimitThreshold
    }

    // MARK: - Message Management

    /// Appends a user message to the active session
    func appendUserMessage(_ content: String, imageAttachment: ImageAttachment? = nil) async throws {
        // Create session if none exists
        if activeSession == nil {
            logger.warning("⚠️ [SESSION-LIFECYCLE] No active session found, creating new one!")
            startNewSession()
        } else if let session = activeSession {
            logger.info("✅ [SESSION-LIFECYCLE] Active session exists: \(session.sessionId)")
        }

        guard var session = activeSession else {
            throw SessionError.noActiveSession
        }

        // Create message
        let message = SessionMessageData(
            role: .user,
            content: content,
            imageAttachment: imageAttachment
        )

        // Append to history
        session.conversationHistory.append(message)
        session.lastUpdated = Date()

        // Update state
        activeSession = session

        logger.info("📝 [SESSION-LIFECYCLE] Appended user message (total messages: \(session.messageCount)) to session: \(session.sessionId)")
        if imageAttachment != nil {
            logger.info("🖼️ [SESSION-LIFECYCLE] Message includes image attachment")
        }

        // Reset inactivity timer (user is active)
        resetInactivityTimer()

        // Auto-save if threshold met
        try await autoSaveIfNeeded()
    }

    /// Appends an assistant/model message to the active session
    func appendAssistantMessage(content: String, tier: ResponseTier?, sources: [ResearchSource]?) async throws {
        guard var session = activeSession else {
            logger.error("❌ [SESSION-LIFECYCLE] Cannot append assistant message - no active session!")
            throw SessionError.noActiveSession
        }

        // Create message (using .model role for assistant responses)
        let message = SessionMessageData(role: .model, content: content, tier: tier, sources: sources)

        // Append to history
        session.conversationHistory.append(message)
        session.lastUpdated = Date()

        // Update state
        activeSession = session

        logger.info("🤖 [SESSION-LIFECYCLE] Appended assistant message (total messages: \(session.messageCount)) to session: \(session.sessionId)")

        // Auto-save if threshold met
        try await autoSaveIfNeeded()
    }

    /// Appends an assistant message from a SearchAnswer
    func appendAssistantMessage(from answer: SearchAnswer) async throws {
        try await appendAssistantMessage(
            content: answer.content,
            tier: answer.tier,
            sources: answer.sources
        )
    }

    // MARK: - Conversation Context

    /// Returns the full conversation history for LLM context
    func getConversationHistory() -> [SessionMessageData] {
        return activeSession?.conversationHistory ?? []
    }

    /// Returns conversation history formatted for API requests
    func getFormattedHistory() -> [[String: String]] {
        let history = getConversationHistory()
        logger.info("🔍 [SESSION-DEBUG] getFormattedHistory called - found \(history.count) messages in session")

        if let session = activeSession {
            logger.info("🔍 [SESSION-DEBUG] Active session: \(session.sessionId)")
            logger.info("🔍 [SESSION-DEBUG] Session has \(session.conversationHistory.count) messages")
        } else {
            logger.warning("⚠️ [SESSION-DEBUG] No active session!")
        }

        let formatted = history.map { message in
            var dict: [String: String] = [
                "role": message.role.rawValue,
                "content": message.content
            ]

            // Add image if present
            if let imageAttachment = message.imageAttachment {
                dict["imageBase64"] = imageAttachment.base64String
                logger.info("🖼️ [SESSION-DEBUG] Including image attachment (\(imageAttachment.fileSizeDescription)) in message")
            }

            return dict
        }

        if !formatted.isEmpty {
            logger.info("🔍 [SESSION-DEBUG] Returning \(formatted.count) formatted messages")
            for (index, msg) in formatted.prefix(2).enumerated() {
                logger.info("🔍 [SESSION-DEBUG]   [\(index)] \(msg)")
            }
        } else {
            logger.warning("⚠️ [SESSION-DEBUG] No messages in active session to format!")
        }

        return formatted
    }

    // MARK: - Session Detection

    /// Detects if user message signals session should end
    func shouldEndSession(_ userMessage: String) -> Bool {
        let lowercased = userMessage.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Satisfaction signals
        let satisfactionSignals = [
            "teşekkürler",
            "teşekkür ederim",
            "sağ ol",
            "tamam anladım",
            "tamam yeter",
            "yeter",
            "anladım"
        ]

        // New topic signals
        let newTopicSignals = [
            "yeni konu",
            "başka bir şey",
            "şimdi başka",
            "yeni bir araştırma"
        ]

        let allSignals = satisfactionSignals + newTopicSignals

        return allSignals.contains { lowercased.contains($0) }
    }

    /// Detects if current query is about a different topic (topic change detection)
    /// Compares with last user message to detect context shifts
    func detectTopicChange(_ currentQuery: String) -> Bool {
        guard let session = activeSession else { return false }

        // Need at least 2 user messages to detect a topic change
        let userMessages = session.conversationHistory.filter { $0.role == .user }
        guard userMessages.count >= 1 else { return false }

        // Get last user message
        guard let lastMessage = userMessages.last else { return false }

        // Simple heuristic: If the new query has no overlapping keywords with previous conversation,
        // it's likely a topic change
        let currentWords = Set(extractKeywords(from: currentQuery))
        let previousWords = Set(extractKeywords(from: lastMessage.content))

        // If less than 20% overlap, consider it a topic change
        let intersection = currentWords.intersection(previousWords)
        let overlap = Double(intersection.count) / Double(max(currentWords.count, 1))

        logger.info("🔍 [TOPIC-DETECTION] Query: '\(currentQuery)'")
        logger.info("🔍 [TOPIC-DETECTION] Current keywords: \(currentWords)")
        logger.info("🔍 [TOPIC-DETECTION] Previous keywords: \(previousWords)")
        logger.info("🔍 [TOPIC-DETECTION] Overlap: \(String(format: "%.0f%%", overlap * 100)) (threshold: 20%)")
        logger.info("🔍 [TOPIC-DETECTION] Topic change: \(overlap < 0.2 ? "YES" : "NO")")

        return overlap < 0.2
    }

    /// Extracts meaningful keywords from a query (words longer than 4 chars, excluding common words)
    private func extractKeywords(from text: String) -> [String] {
        let stopWords = Set(["nedir", "nasıl", "neden", "gibi", "için", "daha", "çok", "olan", "olur", "yapar"])

        let words = text.lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { $0.count > 4 && !stopWords.contains($0) }

        return words
    }

    // MARK: - Inactivity Timer Management

    /// Resets the inactivity timer (call this after every user interaction)
    func resetInactivityTimer() {
        // Cancel existing timer
        inactivityTimer?.cancel()

        // Start new timer
        inactivityTimer = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(self?.inactivityTimeout ?? 1800))

                // Timer expired - end session due to inactivity
                if let self = self {
                    Task { @MainActor in
                        try? await self.endSession(generateMetadata: true)
                        logger.info("⏰ Session ended due to inactivity timeout")
                    }
                }
            } catch {
                // Task was cancelled (normal flow when user interacts)
                logger.debug("Inactivity timer cancelled")
            }
        }
    }

    /// Cancels the inactivity timer without ending the session
    func cancelInactivityTimer() {
        inactivityTimer?.cancel()
        inactivityTimer = nil
    }

    // MARK: - Recovery

    /// Attempts to recover an active session from storage (e.g., after app crash)
    func recoverActiveSession() async throws -> Bool {
        guard let sessionData = try storageActor.loadActiveSession() else {
            logger.info("No active session found to recover")
            return false
        }

        // Convert raw data back to in-memory state
        var recoveredSession = ActiveSessionState()
        recoveredSession.sessionId = sessionData.sessionId
        recoveredSession.status = SessionStatus(rawValue: sessionData.status) ?? .active
        recoveredSession.createdAt = sessionData.createdAt
        recoveredSession.lastUpdated = sessionData.lastUpdated

        // Convert messages
        recoveredSession.conversationHistory = sessionData.conversationHistory.map { messageData in
            SessionMessageData(
                role: MessageRole(rawValue: messageData.role) ?? .user,
                content: messageData.content,
                tier: messageData.tier.flatMap { ResponseTier(rawValue: $0) },
                sources: messageData.sources
            )
        }

        activeSession = recoveredSession

        logger.info("Recovered active session: \(recoveredSession.sessionId)")
        return true
    }

    // MARK: - Private Helpers

    /// Auto-saves the session if message count threshold is met
    private func autoSaveIfNeeded() async throws {
        guard let session = activeSession else { return }

        // Auto-save every N messages as backup
        if session.messageCount % autoSaveThreshold == 0 && session.messageCount > 0 {
            // Convert conversation history to raw data
            let conversationData = session.conversationHistory.map { message in
                (
                    id: message.id,
                    role: message.role.rawValue,
                    content: message.content,
                    timestamp: message.timestamp,
                    tier: message.tier?.rawValue,
                    sourcesData: message.sources.flatMap { try? JSONEncoder().encode($0) },
                    imageAttachmentData: message.imageAttachment.flatMap { try? JSONEncoder().encode($0) }
                )
            }

            // Save backup without metadata
            try await storageActor.saveSession(
                sessionId: session.sessionId,
                conversationHistory: conversationData,
                status: session.status.rawValue,
                createdAt: session.createdAt,
                lastUpdated: session.lastUpdated,
                title: nil,
                summary: nil,
                keyTopics: []
            )
            logger.info("Auto-saved session backup: \(session.sessionId)")
        }
    }

    // MARK: - Highlight Persistence

    /// Save a highlight for a specific message
    func saveHighlight(_ highlight: TextHighlight, for messageId: String) async throws {
        guard let uuid = UUID(uuidString: messageId) else {
            throw SessionError.persistenceFailed(underlying: NSError(
                domain: "com.balli.highlights",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Invalid message ID format"]
            ))
        }

        // Load existing highlights
        var highlights = try storageActor.loadMessageHighlights(messageId: uuid)

        // Append new highlight
        highlights.append(highlight)

        // Save updated highlights
        try storageActor.updateMessageHighlights(messageId: uuid, highlights: highlights)
        logger.info("Saved highlight for message: \(messageId)")
    }

    /// Update a highlight for a specific message
    func updateHighlight(_ highlight: TextHighlight, for messageId: String) async throws {
        guard let uuid = UUID(uuidString: messageId) else {
            throw SessionError.persistenceFailed(underlying: NSError(
                domain: "com.balli.highlights",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Invalid message ID format"]
            ))
        }

        // Load existing highlights
        var highlights = try storageActor.loadMessageHighlights(messageId: uuid)

        // Update specific highlight
        if let index = highlights.firstIndex(where: { $0.id == highlight.id }) {
            highlights[index] = highlight

            // Save updated highlights
            try storageActor.updateMessageHighlights(messageId: uuid, highlights: highlights)
            logger.info("Updated highlight \(highlight.id) for message: \(messageId)")
        } else {
            logger.warning("Highlight not found: \(highlight.id)")
        }
    }

    /// Delete a highlight from a specific message
    func deleteHighlight(id highlightId: UUID, from messageId: String) async throws {
        guard let uuid = UUID(uuidString: messageId) else {
            throw SessionError.persistenceFailed(underlying: NSError(
                domain: "com.balli.highlights",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Invalid message ID format"]
            ))
        }

        // Load existing highlights
        var highlights = try storageActor.loadMessageHighlights(messageId: uuid)

        // Remove highlight
        highlights.removeAll { $0.id == highlightId }

        // Save updated highlights
        try storageActor.updateMessageHighlights(messageId: uuid, highlights: highlights)
        logger.info("Deleted highlight \(highlightId) from message: \(messageId)")
    }

    /// Load highlights for a specific message
    func loadHighlights(for messageId: String) async -> [TextHighlight]? {
        do {
            guard let uuid = UUID(uuidString: messageId) else {
                logger.error("Invalid message ID format: \(messageId)")
                return nil
            }

            let highlights = try storageActor.loadMessageHighlights(messageId: uuid)
            logger.info("Loaded \(highlights.count) highlights for message: \(messageId)")
            return highlights
        } catch {
            logger.error("Failed to load highlights: \(error.localizedDescription)")
            return nil
        }
    }
}

// MARK: - Errors

enum SessionError: LocalizedError {
    case noActiveSession
    case persistenceFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .noActiveSession:
            return "Aktif bir araştırma oturumu yok."
        case .persistenceFailed(let error):
            return "Oturum kaydedilemedi: \(error.localizedDescription)"
        }
    }
}
