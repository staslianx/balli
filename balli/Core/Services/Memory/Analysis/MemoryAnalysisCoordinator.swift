//
//  MemoryAnalysisCoordinator.swift
//  balli
//
//  Actor responsible for analyzing conversations and extracting insights
//  Handles fact extraction, recipe detection, and conversation analysis
//  Swift 6 strict concurrency compliant
//
//  Extracted from MemoryCoordinator.swift to maintain <300 line file limit
//

import Foundation
import OSLog

// MARK: - Memory Analysis Coordinator Actor

actor MemoryAnalysisCoordinator {
    // MARK: - Properties

    private let logger = AppLoggers.Data.sync
    private let aiProcessor: AIMemoryProcessor
    private let storage: MemoryStorageActor

    // MARK: - Initialization

    init(aiProcessor: AIMemoryProcessor, storage: MemoryStorageActor) {
        self.aiProcessor = aiProcessor
        self.storage = storage
        logger.info("MemoryAnalysisCoordinator initialized")
    }

    // MARK: - Fact Extraction

    func extractFactsFromConversation(_ content: String) async -> [String] {
        return await aiProcessor.extractFactsFromConversation(content)
    }

    func analyzeConversationForMemory(_ messages: [LegacyChatMessage]) async -> [(fact: String, confidence: Double)] {
        guard let cache = await storage.getCurrentUserCache() else { return [] }

        // Convert messages to memory entries for analysis
        let memoryEntries = cache.immediateMemory

        let facts = await aiProcessor.analyzeConversationForFacts(memoryEntries)

        return facts
    }

    // MARK: - Fact Storage

    func extractAndStoreFacts(storeFact: @Sendable (String, Double) async -> Void) async {
        guard let cache = await storage.getCurrentUserCache() else { return }

        let allMessages = cache.immediateMemory + cache.recentMemory
        guard !allMessages.isEmpty else { return }

        let facts = await aiProcessor.analyzeConversationForFacts(allMessages)

        for (fact, confidence) in facts {
            await storeFact(fact, confidence)
        }
    }

    // MARK: - Recipe Processing

    func storeGeneratedRecipes(storeRecipe: @Sendable (String, String) async -> Void) async {
        guard let cache = await storage.getCurrentUserCache() else { return }

        // Check immediate memory for any recipe responses
        for entry in cache.immediateMemory {
            if entry.metadata?["role"] == "model" {
                let isRecipe = await aiProcessor.isRecipeContent(entry.content)
                if isRecipe {
                    // Extract recipe title
                    if let title = await aiProcessor.extractRecipeTitle(entry.content) {
                        await storeRecipe(entry.content, title)
                    }
                }
            }
        }
    }
}
