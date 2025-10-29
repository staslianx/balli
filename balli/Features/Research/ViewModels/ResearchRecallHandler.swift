//
//  ResearchRecallHandler.swift
//  balli
//
//  Handles cross-conversation recall detection and processing
//  Split from MedicalResearchViewModel for better organization
//  Swift 6 strict concurrency compliant
//

import Foundation
import SwiftUI
import OSLog

/// Handles recall requests from past research sessions
@MainActor
final class ResearchRecallHandler {
    // MARK: - Properties

    private let logger = AppLoggers.Research.search
    private let currentUserId = "demo_user"

    /// FTS5 manager for cross-conversation memory (recall)
    private let fts5Manager: FTS5Manager?
    private let recallRepository: RecallSearchRepository?

    // MARK: - Initialization

    init(fts5Manager: FTS5Manager?, recallRepository: RecallSearchRepository?) {
        self.fts5Manager = fts5Manager
        self.recallRepository = recallRepository
    }

    // MARK: - Recall Detection

    /// Determines if query should attempt recall from past sessions
    /// Uses simple heuristics for Turkish past-tense patterns
    func shouldAttemptRecall(_ query: String) async -> Bool {
        // Use Turkish locale for proper case conversion (İ→i, I→ı)
        let lowercased = query.lowercased(with: Locale(identifier: "tr_TR"))

        // Past tense patterns (Turkish)
        let pastTensePatterns = [
            "neydi", "ne konuşmuştuk", "ne araştırmıştık", "ne bulmuştuk",
            "nasıldı", "ne çıkmıştı", "ne öğrenmiştik"
        ]

        // Memory/recall phrases
        let memoryPhrases = [
            "hatırlıyor musun", "hatırla", "hatırlat",
            "daha önce", "geçen sefer", "o zaman"
        ]

        // Reference phrases
        let referencePhrases = [
            "o şey", "şu konu", "o araştırma", "o bilgi"
        ]

        let allPatterns = pastTensePatterns + memoryPhrases + referencePhrases

        return allPatterns.contains { lowercased.contains($0) }
    }

    // MARK: - Recall Processing

    /// Handles recall request by searching completed sessions and displaying results
    func handleRecallRequest(_ query: String, answerId: String) async throws -> SearchAnswer {
        logger.info("📚 Handling recall request: \(query)")

        // Check if recall repository is available
        guard let searchRepo = recallRepository else {
            throw RecallServiceError.fts5Unavailable
        }

        // Search completed sessions using FTS5-powered RecallSearchRepository
        let searchResults = try await searchRepo.searchSessions(query: query)

        logger.info("📚 Found \(searchResults.count) matching sessions")

        // Handle different scenarios
        if searchResults.isEmpty {
            // No matches - suggest new research
            return handleNoRecallMatches(answerId, query: query)
        } else if searchResults.count == 1 || isStrongMatch(searchResults) {
            // Single strong match - get full answer
            return try await handleSingleRecallMatch(answerId, query: query, result: searchResults[0])
        } else {
            // Multiple matches - ask user to clarify
            return handleMultipleRecallMatches(answerId, query: query, results: searchResults)
        }
    }

    // MARK: - Recall Result Handling

    /// Checks if first result is significantly better than others
    private func isStrongMatch(_ results: [RecallSearchResult]) -> Bool {
        guard results.count > 1 else { return true }

        let first = results[0].relevanceScore
        let second = results[1].relevanceScore

        // First result is "strong" if it's at least 15% better than second
        return (first - second) >= 0.15
    }

    /// Handles case where no past sessions match the query
    private func handleNoRecallMatches(_ answerId: String, query: String) -> SearchAnswer {
        let message = "Bu konuda daha önce bir araştırma kaydı bulamadım. Şimdi araştırayım mı?"

        let finalAnswer = SearchAnswer(
            id: answerId,
            query: query,
            content: message,
            sources: [],
            timestamp: Date(),
            tokenCount: nil,
            tier: .model  // Show "Hızlı" badge, not "Hafıza"
        )

        logger.info("📚 No recall matches - suggesting new research")
        return finalAnswer
    }

    /// Handles single strong recall match - calls backend for full LLM answer
    private func handleSingleRecallMatch(_ answerId: String, query: String, result: RecallSearchResult) async throws -> SearchAnswer {
        let formattedDate = formatRecallDate(result.createdAt)
        let title = result.title ?? "Araştırma Oturumu"

        // Get full conversation history from SwiftData
        let container = ResearchSessionModelContainer.shared.container
        let storageActor = SessionStorageActor(modelContainer: container)

        guard let conversationData = try await storageActor.loadSessionConversation(id: result.sessionId) else {
            throw RecallServiceError.noConversationHistory
        }

        // Convert to array format required by recall service
        let conversationHistory = [conversationData]

        // Call backend recall service
        let recallService = RecallService()
        let response = try await recallService.generateAnswer(
            question: query,
            userId: currentUserId,
            matchedSessions: [result],
            fullConversationHistory: conversationHistory
        )

        // Handle response
        if let answer = response.answer, let sessionRef = response.sessionReference {
            let finalMessage = """
            📚 **Geçmiş Araştırma** (\(sessionRef.date))

            \(answer)

            *Kaynak: \(sessionRef.title)*
            """

            let finalAnswer = SearchAnswer(
                id: answerId,
                query: query,
                content: finalMessage,
                sources: [],
                timestamp: Date(),
                tokenCount: nil,
                tier: .model  // Show "Hızlı" badge, not "Hafıza" (Flash model answers from memory)
            )

            logger.info("📚 Displayed LLM-generated recall answer from: \(sessionRef.title)")
            return finalAnswer
        } else {
            throw RecallServiceError.invalidResponse
        }
    }

    /// Handles multiple recall matches
    private func handleMultipleRecallMatches(_ answerId: String, query: String, results: [RecallSearchResult]) -> SearchAnswer {
        let sessionList = results.prefix(5).enumerated().map { idx, result in
            let title = result.title ?? "Araştırma Oturumu"
            let date = formatRecallDate(result.createdAt)
            let score = Int(result.relevanceScore * 100)
            return "\(idx + 1). **\(title)** - \(date) (uygunluk: %\(score))"
        }.joined(separator: "\n\n")

        let message = """
        📚 **Birkaç Araştırma Bulundu**

        Bu konuda birkaç geçmiş araştırman var:

        \(sessionList)

        Hangisinden bahsediyorsun?
        """

        let finalAnswer = SearchAnswer(
            id: answerId,
            query: query,
            content: message,
            sources: [],
            timestamp: Date(),
            tokenCount: nil,
            tier: .model  // Show "Hızlı" badge, not "Hafıza"
        )

        logger.info("📚 Displayed \(results.count) recall matches")
        return finalAnswer
    }

    // MARK: - Helper Methods

    /// Formats date for recall display
    private func formatRecallDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
