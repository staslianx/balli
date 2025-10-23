//
//  MemoryContextBuilder.swift
//  balli
//
//  Actor responsible for building context and enriched prompts
//  Handles context retrieval and prompt enrichment for AI interactions
//  Swift 6 strict concurrency compliant
//
//  Extracted from MemoryCoordinator.swift to maintain <300 line file limit
//

import Foundation
import OSLog

// MARK: - Memory Context Builder Actor

actor MemoryContextBuilder {
    // MARK: - Properties

    private let logger = AppLoggers.Data.sync
    private let retrieval: MemoryRetrievalActor

    // MARK: - Initialization

    init(retrieval: MemoryRetrievalActor) {
        self.retrieval = retrieval
        logger.info("MemoryContextBuilder initialized")
    }

    // MARK: - Context Building

    /// Get relevant context for a given prompt
    func getRelevantContext(for prompt: String, cache: UserMemoryCache?, userId: String) async -> String {
        guard let userId = userId as String?,
              let cache = cache else {
            logger.error("No active user for context retrieval")
            return ""
        }

        return await retrieval.getRelevantContext(for: prompt, cache: cache, userId: userId)
    }

    /// Build an enriched prompt with memory context
    func buildEnrichedPrompt(_ userPrompt: String, cache: UserMemoryCache?, userId: String) async -> String {
        let context = await getRelevantContext(for: userPrompt, cache: cache, userId: userId)

        if context.isEmpty {
            return userPrompt
        }

        return """
        <context>
        \(context)
        </context>

        <user_message>
        \(userPrompt)
        </user_message>
        """
    }

    /// Get enhanced memory context using Firebase search
    func getEnhancedMemoryContext(for query: String, cache: UserMemoryCache?, userId: String) async -> String {
        guard let userId = userId as String?,
              let cache = cache else {
            logger.error("No active user for enhanced memory context")
            return ""
        }

        return await retrieval.getRelevantContext(for: query, cache: cache, userId: userId)
    }
}
