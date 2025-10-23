import Foundation
import SwiftData
import OSLog

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.balli",
    category: "SessionStorage"
)

/// Thread-safe actor for managing persistence of research sessions using SwiftData
/// IMPORTANT: ModelContext operations must run on @MainActor when used with observed models
actor SessionStorageActor {
    private let modelContainer: ModelContainer
    private let fts5Manager: FTS5Manager?

    /// Initializes the storage actor with a SwiftData model container and optional FTS5 manager
    init(modelContainer: ModelContainer, fts5Manager: FTS5Manager? = nil) {
        self.modelContainer = modelContainer
        self.fts5Manager = fts5Manager
        logger.info("SessionStorageActor initialized with FTS5: \(fts5Manager != nil)")
    }

    /// Creates a background ModelContext for this actor
    /// Each operation gets its own context to avoid thread-safety issues
    @MainActor
    private func createContext() -> ModelContext {
        return ModelContext(modelContainer)
    }

    // MARK: - Save Operations

    /// Saves or updates a research session from raw data
    @MainActor
    func saveSession(
        sessionId: UUID,
        conversationHistory: [(id: UUID, role: String, content: String, timestamp: Date, tier: String?, sourcesData: Data?)],
        status: String,
        createdAt: Date,
        lastUpdated: Date,
        title: String?,
        summary: String?,
        keyTopics: [String]
    ) async throws {
        let modelContext = createContext()

        // Check if session already exists
        let fetchDescriptor = FetchDescriptor<ResearchSession>(
            predicate: #Predicate { $0.sessionId == sessionId }
        )

        let existingSessions = try modelContext.fetch(fetchDescriptor)
        let session: ResearchSession

        if let existing = existingSessions.first {
            // Update existing session
            session = existing
            session.conversationHistory.removeAll()
            logger.debug("Updating existing session: \(sessionId)")
        } else {
            // Create new session
            session = ResearchSession()
            session.sessionId = sessionId
            modelContext.insert(session)
            logger.info("Inserted new session: \(sessionId)")
        }

        // Update properties
        session.statusRaw = status
        session.createdAt = createdAt
        session.lastUpdated = lastUpdated
        session.title = title
        session.summary = summary
        session.keyTopics = keyTopics

        // Add messages
        for messageData in conversationHistory {
            let message = SessionMessage(
                role: MessageRole(rawValue: messageData.role) ?? .user,
                content: messageData.content,
                timestamp: messageData.timestamp,
                tier: messageData.tier.flatMap { ResponseTier(rawValue: $0) },
                sources: messageData.sourcesData.flatMap { try? JSONDecoder().decode([ResearchSource].self, from: $0) }
            )
            message.id = messageData.id
            session.conversationHistory.append(message)
        }

        // Save changes to SwiftData
        try modelContext.save()
        logger.info("Session saved successfully: \(sessionId)")

        // Sync to FTS5 if this is a complete session with metadata
        if status == "complete", let title = title, let summary = summary, let fts5 = fts5Manager {
            logger.info("📚 Syncing complete session to FTS5: \(sessionId)")

            // Convert conversation history to format FTS5Manager expects
            let conversationForFTS = conversationHistory.map { (role: $0.role, content: $0.content) }

            do {
                try await fts5.indexSession(
                    sessionId: sessionId,
                    title: title,
                    summary: summary,
                    keyTopics: keyTopics,
                    conversationHistory: conversationForFTS
                )
                logger.info("✅ Session indexed in FTS5: \(sessionId)")
            } catch {
                logger.error("❌ Failed to index session in FTS5: \(error.localizedDescription)")
                // Don't throw - FTS5 sync failure shouldn't fail the entire save
            }
        }
    }

    // MARK: - Load Operations

    /// Loads a specific session by ID
    @MainActor
    func loadSession(id: UUID) throws -> ResearchSession? {
        let modelContext = createContext()
        let fetchDescriptor = FetchDescriptor<ResearchSession>(
            predicate: #Predicate { $0.sessionId == id }
        )

        let sessions = try modelContext.fetch(fetchDescriptor)
        let session = sessions.first

        if let session {
            logger.info("Loaded session: \(id)")
        } else {
            logger.warning("Session not found: \(id)")
        }

        return session
    }

    /// Loads session conversation history as Sendable data
    @MainActor
    func loadSessionConversation(id: UUID) throws -> (sessionId: UUID, messages: [SessionMessageData])? {
        let modelContext = createContext()
        let fetchDescriptor = FetchDescriptor<ResearchSession>(
            predicate: #Predicate { $0.sessionId == id }
        )

        let sessions = try modelContext.fetch(fetchDescriptor)
        guard let session = sessions.first else {
            logger.warning("Session not found: \(id)")
            return nil
        }

        let messages = session.conversationHistory.map { msg in
            SessionMessageData(
                role: msg.role,
                content: msg.content,
                tier: msg.tier,
                sources: msg.sources
            )
        }

        logger.info("Loaded \(messages.count) messages from session: \(id)")

        return (sessionId: session.sessionId, messages: messages)
    }

    /// Loads the currently active session (if any) as raw data
    @MainActor
    func loadActiveSession() throws -> (
        sessionId: UUID,
        conversationHistory: [(id: UUID, role: String, content: String, timestamp: Date, tier: String?, sources: [ResearchSource]?)],
        status: String,
        createdAt: Date,
        lastUpdated: Date
    )? {
        let modelContext = createContext()
        let fetchDescriptor = FetchDescriptor<ResearchSession>(
            predicate: #Predicate { $0.statusRaw == "active" },
            sortBy: [SortDescriptor(\.lastUpdated, order: .reverse)]
        )

        let activeSessions = try modelContext.fetch(fetchDescriptor)
        guard let session = activeSessions.first else {
            logger.info("No active session found")
            return nil
        }

        logger.info("Found active session: \(session.sessionId)")

        // Convert to raw data
        let conversationData = session.conversationHistory.map { message in
            (
                id: message.id,
                role: message.roleRaw,
                content: message.content,
                timestamp: message.timestamp,
                tier: message.tierRaw,
                sources: message.sources
            )
        }

        return (
            sessionId: session.sessionId,
            conversationHistory: conversationData,
            status: session.statusRaw,
            createdAt: session.createdAt,
            lastUpdated: session.lastUpdated
        )
    }

    /// Loads all completed sessions
    @MainActor
    func loadCompletedSessions() throws -> [ResearchSession] {
        let modelContext = createContext()
        let fetchDescriptor = FetchDescriptor<ResearchSession>(
            predicate: #Predicate { $0.statusRaw == "complete" },
            sortBy: [SortDescriptor(\.lastUpdated, order: .reverse)]
        )

        let sessions = try modelContext.fetch(fetchDescriptor)
        logger.info("Loaded \(sessions.count) completed sessions")

        return sessions
    }

    /// Extracts Sendable session data for FTS5 migration
    /// This method avoids Sendable conformance issues by extracting only primitive types
    @MainActor
    func extractSessionDataForMigration() throws -> [(
        sessionId: UUID,
        title: String?,
        summary: String?,
        keyTopics: [String],
        conversationHistory: [(role: String, content: String)]
    )] {
        let modelContext = createContext()
        let fetchDescriptor = FetchDescriptor<ResearchSession>(
            predicate: #Predicate { $0.statusRaw == "complete" && $0.title != nil },
            sortBy: [SortDescriptor(\.lastUpdated, order: .reverse)]
        )

        let sessions = try modelContext.fetch(fetchDescriptor)

        return sessions.map { session in
            let conversation = session.conversationHistory.map { message in
                (role: message.roleRaw, content: message.content)
            }
            return (
                sessionId: session.sessionId,
                title: session.title,
                summary: session.summary,
                keyTopics: session.keyTopics,
                conversationHistory: conversation
            )
        }
    }

    /// Loads all sessions (active and completed)
    @MainActor
    func loadAllSessions() throws -> [ResearchSession] {
        let modelContext = createContext()
        let fetchDescriptor = FetchDescriptor<ResearchSession>(
            sortBy: [SortDescriptor(\.lastUpdated, order: .reverse)]
        )

        let sessions = try modelContext.fetch(fetchDescriptor)
        logger.info("Loaded \(sessions.count) total sessions")

        return sessions
    }

    // MARK: - Delete Operations

    /// Deletes a specific session
    @MainActor
    func deleteSession(_ session: ResearchSession) async throws {
        let sessionId = session.sessionId
        let modelContext = createContext()
        modelContext.delete(session)
        try modelContext.save()
        logger.info("Deleted session from SwiftData: \(sessionId)")

        // Also delete from FTS5 index if available
        if let fts5 = fts5Manager {
            do {
                try await fts5.deleteSession(sessionId: sessionId)
                logger.info("✅ Deleted session from FTS5: \(sessionId)")
            } catch {
                logger.error("❌ Failed to delete from FTS5: \(error.localizedDescription)")
                // Don't throw - FTS5 deletion failure shouldn't fail the entire operation
            }
        }
    }

    /// Deletes all completed sessions (cleanup)
    @MainActor
    func deleteCompletedSessions() async throws {
        let sessions = try loadCompletedSessions()
        let modelContext = createContext()
        let sessionIds = sessions.map { $0.sessionId }

        for session in sessions {
            modelContext.delete(session)
        }

        try modelContext.save()
        logger.info("Deleted \(sessions.count) completed sessions from SwiftData")

        // Also clear from FTS5 if available
        if let fts5 = fts5Manager {
            for sessionId in sessionIds {
                do {
                    try await fts5.deleteSession(sessionId: sessionId)
                } catch {
                    logger.error("❌ Failed to delete session \(sessionId) from FTS5: \(error.localizedDescription)")
                }
            }
            logger.info("✅ Deleted \(sessionIds.count) sessions from FTS5")
        }
    }
}
