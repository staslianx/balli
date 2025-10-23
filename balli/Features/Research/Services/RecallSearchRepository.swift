//
//  RecallSearchRepository.swift
//  balli
//
//  Thread-safe actor for searching completed research sessions using FTS5 full-text search
//  Swift 6 strict concurrency compliant
//

import Foundation
import SwiftData
import OSLog

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.balli",
    category: "RecallSearch"
)

/// Result from a recall search containing session data and relevance score
/// Uses value types to maintain Sendable conformance
struct RecallSearchResult: Sendable {
    let sessionId: UUID
    let title: String?
    let summary: String?
    let keyTopics: [String]
    let createdAt: Date
    let lastUpdated: Date
    let messageCount: Int
    let relevanceScore: Double

    init(from session: ResearchSession, relevanceScore: Double) {
        self.sessionId = session.sessionId
        self.title = session.title
        self.summary = session.summary
        self.keyTopics = session.keyTopics
        self.createdAt = session.createdAt
        self.lastUpdated = session.lastUpdated
        self.messageCount = session.messageCount
        self.relevanceScore = relevanceScore
    }
}

/// Thread-safe actor for searching completed research sessions using FTS5
/// Uses SQLite FTS5 for fast, Turkish-aware full-text search with ranking
actor RecallSearchRepository {
    private let modelContainer: ModelContainer
    private let modelContext: ModelContext
    private let fts5Manager: FTS5Manager

    /// Maximum number of search results to return
    private let maxResults = 5

    init(modelContainer: ModelContainer, fts5Manager: FTS5Manager) {
        self.modelContainer = modelContainer
        self.modelContext = ModelContext(modelContainer)
        self.fts5Manager = fts5Manager
        logger.info("RecallSearchRepository initialized with FTS5")
    }

    // MARK: - Search Operations

    /// Searches completed sessions using FTS5 full-text search
    /// Returns sessions ranked by relevance using BM25 algorithm
    func searchSessions(query: String) async throws -> [RecallSearchResult] {
        logger.info("🔍 Searching sessions via FTS5 for: \(query, privacy: .private)")

        // Search using FTS5 (returns session IDs ranked by relevance)
        let sessionIds = try await fts5Manager.search(query: query, limit: maxResults)

        guard !sessionIds.isEmpty else {
            logger.info("No FTS5 results found for query")
            return []
        }

        logger.debug("FTS5 returned \(sessionIds.count) session IDs")

        // Fetch full session data from SwiftData for each result
        var results: [RecallSearchResult] = []

        for (index, sessionId) in sessionIds.enumerated() {
            // Fetch session from SwiftData
            let fetchDescriptor = FetchDescriptor<ResearchSession>(
                predicate: #Predicate { $0.sessionId == sessionId }
            )

            guard let session = try modelContext.fetch(fetchDescriptor).first else {
                logger.warning("Session \(sessionId) found in FTS5 but missing in SwiftData")
                continue
            }

            // Calculate normalized relevance score (1.0 for best match, decreasing)
            // FTS5 BM25 rank is negative (lower is better), so we normalize to 0-1
            let normalizedScore = 1.0 - (Double(index) / Double(sessionIds.count))

            let result = RecallSearchResult(from: session, relevanceScore: normalizedScore)
            results.append(result)
        }

        logger.info("✅ Found \(results.count) sessions from FTS5 search")

        return results
    }

}
