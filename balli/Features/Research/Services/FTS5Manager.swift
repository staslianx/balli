import Foundation
import SQLite
import OSLog

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.balli",
    category: "FTS5Search"
)

/// Thread-safe actor managing SQLite FTS5 full-text search for research sessions
/// Provides fast, Turkish-aware semantic search across completed sessions
actor FTS5Manager {
    // MARK: - Database Schema

    /// FTS5 virtual table for session search
    /// Uses Porter stemming for Turkish language support
    private let sessionsTable = VirtualTable("sessions_fts")

    // Column expressions
    private let sessionId = Expression<String>("session_id")
    private let title = Expression<String>("title")
    private let summary = Expression<String>("summary")
    private let keyTopics = Expression<String>("key_topics") // JSON array as string
    private let conversationText = Expression<String>("conversation_text") // Full conversation
    private let lastUpdated = Expression<Date>("last_updated")

    // MARK: - Database Connection

    nonisolated(unsafe) private let db: Connection
    private let dbPath: String

    // MARK: - Initialization

    init(dbPath: String? = nil) throws {
        // Use default path in app's documents directory
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw FTS5Error.databaseError("Documents directory unavailable")
        }
        self.dbPath = dbPath ?? documentsPath.appendingPathComponent("research_sessions_fts.db").path

        logger.info("Initializing FTS5Manager at path: \(self.dbPath)")

        // Create database connection
        self.db = try Connection(self.dbPath)

        // Enable write-ahead logging for better concurrency
        try db.execute("PRAGMA journal_mode=WAL")

        // Create FTS5 table if it doesn't exist
        try createFTS5TableIfNeeded()

        logger.info("✅ FTS5Manager initialized successfully")
    }

    // MARK: - Table Creation

    /// Creates the FTS5 virtual table with Turkish language support
    private nonisolated func createFTS5TableIfNeeded() throws {
        // Check if table exists
        let tableExists = try db.scalar(
            "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='sessions_fts'"
        ) as! Int64 > 0

        if tableExists {
            logger.debug("FTS5 table already exists")
            return
        }

        logger.info("Creating FTS5 table with Turkish tokenizer...")

        // Create FTS5 table with porter tokenizer for stemming
        // Porter tokenizer works reasonably well for Turkish
        let createTableSQL = """
        CREATE VIRTUAL TABLE sessions_fts USING fts5(
            session_id UNINDEXED,
            title,
            summary,
            key_topics,
            conversation_text,
            last_updated UNINDEXED,
            tokenize = 'porter unicode61 remove_diacritics 2'
        )
        """

        try db.execute(createTableSQL)
        logger.info("✅ FTS5 table created successfully")
    }

    // MARK: - Indexing (Upsert)

    /// Indexes or updates a completed session in FTS5
    /// - Parameters:
    ///   - sessionId: Unique session identifier
    ///   - title: Session title (5-7 words)
    ///   - summary: Session summary (2-3 sentences)
    ///   - keyTopics: Array of key topics
    ///   - conversationHistory: Full conversation messages
    func indexSession(
        sessionId: UUID,
        title: String,
        summary: String,
        keyTopics: [String],
        conversationHistory: [(role: String, content: String)]
    ) throws {
        logger.info("📝 Indexing session: \(sessionId)")

        // Build full conversation text for search
        let conversationText = conversationHistory
            .map { "\($0.role): \($0.content)" }
            .joined(separator: "\n\n")

        // Convert key topics to searchable string
        let keyTopicsText = keyTopics.joined(separator: ", ")

        // Delete existing entry if present (upsert logic)
        try deleteSession(sessionId: sessionId)

        // Insert new entry
        let insert = sessionsTable.insert(
            self.sessionId <- sessionId.uuidString,
            self.title <- title,
            self.summary <- summary,
            self.keyTopics <- keyTopicsText,
            self.conversationText <- conversationText,
            self.lastUpdated <- Date()
        )

        try db.run(insert)
        logger.info("✅ Session indexed: \(sessionId)")
    }

    // MARK: - Search

    /// Searches sessions using FTS5 full-text search
    /// - Parameters:
    ///   - query: User's search query (Turkish)
    ///   - limit: Maximum number of results to return
    /// - Returns: Array of session IDs ranked by relevance
    func search(query: String, limit: Int = 10) throws -> [UUID] {
        logger.info("🔍 Searching for: '\(query)' (limit: \(limit))")

        // Sanitize query for FTS5 (remove special characters that could break syntax)
        let sanitizedQuery = sanitizeFTS5Query(query)

        guard !sanitizedQuery.isEmpty else {
            logger.warning("⚠️ Empty query after sanitization")
            return []
        }

        // Build FTS5 MATCH query with ranking
        // bm25() provides relevance scoring (lower is better)
        let searchSQL = """
        SELECT session_id, rank
        FROM sessions_fts
        WHERE sessions_fts MATCH ?
        ORDER BY rank
        LIMIT ?
        """

        let statement = try db.prepare(searchSQL)
        let results = try statement.bind(sanitizedQuery, limit).map { row -> (String, Double) in
            guard let sessionIdString = row[0] as? String,
                  let rank = row[1] as? Double else {
                throw FTS5Error.databaseError("Invalid query result format: expected (String, Double)")
            }
            return (sessionIdString, rank)
        }

        logger.info("✅ Found \(results.count) results")

        // Convert to UUIDs
        let sessionIds = results.compactMap { UUID(uuidString: $0.0) }

        // Log top results for debugging
        for (index, result) in results.prefix(3).enumerated() {
            logger.debug("  [\(index + 1)] Session: \(result.0), Rank: \(String(format: "%.2f", result.1))")
        }

        return sessionIds
    }

    // MARK: - Deletion

    /// Deletes a session from FTS5 index
    /// - Parameter sessionId: Session to delete
    func deleteSession(sessionId: UUID) throws {
        let deleteSQL = "DELETE FROM sessions_fts WHERE session_id = ?"
        try db.run(deleteSQL, sessionId.uuidString)
        logger.debug("🗑️ Deleted session from FTS5: \(sessionId)")
    }

    /// Clears all indexed sessions (for testing or reset)
    func clearAll() throws {
        try db.run("DELETE FROM sessions_fts")
        logger.warning("🗑️ Cleared all FTS5 index entries")
    }

    // MARK: - Statistics

    /// Returns the number of indexed sessions
    func getIndexedSessionCount() throws -> Int {
        let count = try db.scalar("SELECT COUNT(*) FROM sessions_fts") as! Int64
        return Int(count)
    }

    // MARK: - Private Helpers

    /// Sanitizes user query for FTS5 MATCH syntax
    /// Removes or escapes characters that have special meaning in FTS5
    private func sanitizeFTS5Query(_ query: String) -> String {
        // Remove special FTS5 operators: " * ( ) AND OR NOT
        var sanitized = query
            .replacingOccurrences(of: "\"", with: "")
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")

        // Remove standalone boolean operators (they need proper syntax)
        let words = sanitized.components(separatedBy: .whitespacesAndNewlines)
        let filtered = words.filter { word in
            let lower = word.lowercased()
            return !["and", "or", "not", "ve", "veya", "değil"].contains(lower)
        }

        sanitized = filtered.joined(separator: " ")

        // Trim whitespace
        sanitized = sanitized.trimmingCharacters(in: .whitespacesAndNewlines)

        return sanitized
    }
}

// MARK: - Migration Support

extension FTS5Manager {
    /// Migrates all completed sessions from SwiftData to FTS5
    /// Call this once on first app launch after adding FTS5
    func migrateExistingSessions(sessions: [(
        sessionId: UUID,
        title: String?,
        summary: String?,
        keyTopics: [String],
        conversationHistory: [(role: String, content: String)]
    )]) throws {
        logger.info("🔄 Starting FTS5 migration for \(sessions.count) sessions...")

        var migratedCount = 0
        var skippedCount = 0

        for session in sessions {
            // Only migrate sessions with metadata (complete sessions)
            guard let title = session.title, let summary = session.summary else {
                logger.debug("⏭️ Skipping session without metadata: \(session.sessionId)")
                skippedCount += 1
                continue
            }

            do {
                try indexSession(
                    sessionId: session.sessionId,
                    title: title,
                    summary: summary,
                    keyTopics: session.keyTopics,
                    conversationHistory: session.conversationHistory
                )
                migratedCount += 1
            } catch {
                logger.error("❌ Failed to migrate session \(session.sessionId): \(error.localizedDescription)")
            }
        }

        logger.info("✅ Migration complete: \(migratedCount) migrated, \(skippedCount) skipped")
    }
}

// MARK: - Errors

enum FTS5Error: LocalizedError {
    case databaseError(String)
    case invalidQuery(String)

    var errorDescription: String? {
        switch self {
        case .databaseError(let message):
            return "Veritabanı hatası: \(message)"
        case .invalidQuery(let query):
            return "Geçersiz arama sorgusu: \(query)"
        }
    }
}
