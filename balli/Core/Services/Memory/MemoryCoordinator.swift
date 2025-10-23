//
//  MemoryCoordinator.swift
//  balli
//
//  Main public API for memory management
//  Coordinates between storage, retrieval, and integration actors
//  Swift 6 strict concurrency compliant
//
//  Replaces the monolithic MemoryService.swift (1,119 lines)
//  with a clean coordinator pattern
//

import Foundation
import OSLog

// MARK: - Memory Coordinator Actor

actor MemoryCoordinator {
    // MARK: - Properties

    private let logger = AppLoggers.Data.sync
    private let healthKitService: HealthKitServiceProtocol

    // Specialized actors for different responsibilities
    private let storage: MemoryStorageActor
    private let retrieval: MemoryRetrievalActor
    private let sessionManager: UserSessionManager
    private let aiProcessor: AIMemoryProcessor

    // High-level coordinators (extracted for <300 line compliance)
    private let sessionProcessor: SessionBoundaryProcessor
    private let contextBuilder: MemoryContextBuilder
    private let analysisCoordinator: MemoryAnalysisCoordinator

    // MARK: - Initialization

    init(healthKitService: HealthKitServiceProtocol) {
        self.healthKitService = healthKitService

        // Initialize specialized actors
        self.storage = MemoryStorageActor()
        self.retrieval = MemoryRetrievalActor()
        self.sessionManager = UserSessionManager()
        self.aiProcessor = AIMemoryProcessor()

        // Initialize high-level coordinators
        self.sessionProcessor = SessionBoundaryProcessor(
            sessionManager: sessionManager,
            storage: storage
        )
        self.contextBuilder = MemoryContextBuilder(retrieval: retrieval)
        self.analysisCoordinator = MemoryAnalysisCoordinator(
            aiProcessor: aiProcessor,
            storage: storage
        )

        logger.info("MemoryCoordinator initialized (ChatAssistant removed - basic memory only)")
    }

    // MARK: - User Session Management

    func switchUser(_ userId: String) async {
        // Switch user in storage
        await storage.switchUser(userId)

        logger.info("User switched to \(userId)")
    }

    func clearUserMemory(_ userId: String) async {
        await storage.clearUserMemory(userId)
    }

    // MARK: - Memory Storage

    func rememberFact(_ fact: String, confidence: Double = 1.0) async {
        await storage.storeFact(fact, confidence: confidence)
    }

    func rememberPreference(key: String, value: PreferenceValue) async {
        await storage.storePreference(key: key, value: value)
    }

    func rememberConversation(_ message: LegacyChatMessage) async {
        // Skip processing empty messages
        let trimmedContent = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedContent.isEmpty {
            logger.info("Skipping empty message - no content to process")
            return
        }

        // Update activity time
        await storage.updateLastActivityTime(Date())

        // ChatAssistant removed - basic local memory only (no embeddings, no Firestore sync)
        let entry = MemoryEntry(
            type: .conversation,
            content: trimmedContent,
            metadata: [
                "role": message.isUser ? "user" : "assistant",
                "messageId": message.id.uuidString
            ],
            source: "conversation",
            tier: .immediate,
            embedding: nil
        )

        // Store conversation entry
        await storage.storeConversation(entry)

        // Cascade memory tiers when limits exceeded
        guard let userId = await storage.getCurrentUserId() else { return }
        await cascadeMemoryTiers(for: userId)
    }

    func rememberRecipe(_ recipe: String, title: String) async {
        let entry = MemoryEntry(
            type: .recipe,
            content: recipe,
            metadata: ["title": title],
            source: "ai_generated"
        )

        await storage.storeRecipe(title: title, entry: entry)
    }

    func rememberGlucosePattern(meal: String, glucoseRise: Double, timeToBaseline: Int) async {
        await storage.storeGlucosePattern(meal: meal, glucoseRise: glucoseRise, timeToBaseline: timeToBaseline)
    }

    // MARK: - Memory Retrieval

    func getRelevantContext(for prompt: String) async -> String {
        guard let userId = await storage.getCurrentUserId(),
              let cache = await storage.getCurrentUserCache() else {
            logger.error("No active user for context retrieval")
            return ""
        }

        return await contextBuilder.getRelevantContext(for: prompt, cache: cache, userId: userId)
    }

    func buildEnrichedPrompt(_ userPrompt: String) async -> String {
        guard let userId = await storage.getCurrentUserId(),
              let cache = await storage.getCurrentUserCache() else {
            return userPrompt
        }

        return await contextBuilder.buildEnrichedPrompt(userPrompt, cache: cache, userId: userId)
    }

    // MARK: - Fact Extraction

    func extractFactsFromConversation(_ content: String) async -> [String] {
        return await analysisCoordinator.extractFactsFromConversation(content)
    }

    func analyzeConversationForMemory(_ messages: [LegacyChatMessage]) async {
        let facts = await analysisCoordinator.analyzeConversationForMemory(messages)

        for (fact, confidence) in facts {
            await rememberFact(fact, confidence: confidence)
        }
    }

    // MARK: - Memory Tier Management

    private func cascadeMemoryTiers(for userId: String) async {
        await storage.cascadeMemoryTiers(
            summarize: { entry in
                await self.aiProcessor.summarizeMessage(entry)
            },
            extractFacts: { entry in
                await self.aiProcessor.extractKeyFacts(entry)
            }
        )
    }

    // MARK: - Session Management

    func startNewSession() async {
        await sessionProcessor.startNewSession()
    }

    func rememberConversationMessage(_ message: LegacyChatMessage) async {
        // Process as before
        await rememberConversation(message)

        // Track message and check boundaries
        await sessionProcessor.trackConversationMessage()
    }

    func checkConversationBoundary() async -> Bool {
        return await sessionProcessor.checkConversationBoundary()
    }

    func processConversationSessionBoundary() async {
        await sessionProcessor.processConversationSessionBoundary()
    }

    func processConversationBoundary() async {
        guard await sessionProcessor.checkConversationBoundary() else { return }

        logger.info("Processing conversation boundary")

        // Extract and store important facts
        await extractAndStoreFacts()

        // Store full recipes if any were generated
        await storeGeneratedRecipes()

        // Clean up expired memory
        await cleanupExpiredMemory()
    }

    // MARK: - Memory Cleanup

    func cleanupExpiredMemory() async {
        await storage.cleanupExpiredMemory()
    }

    // MARK: - Helper Methods

    private func extractAndStoreFacts() async {
        await analysisCoordinator.extractAndStoreFacts { fact, confidence in
            await self.rememberFact(fact, confidence: confidence)
        }
    }

    private func storeGeneratedRecipes() async {
        await analysisCoordinator.storeGeneratedRecipes { content, title in
            await self.rememberRecipe(content, title: title)
        }
    }

    // MARK: - Enhanced Memory System Integration

    func getEnhancedMemoryContext(for query: String) async -> String {
        guard let userId = await storage.getCurrentUserId(),
              let cache = await storage.getCurrentUserCache() else {
            logger.error("No active user for enhanced memory context")
            return ""
        }

        return await contextBuilder.getEnhancedMemoryContext(for: query, cache: cache, userId: userId)
    }

    func processMessageWithEmbedding(_ message: LegacyChatMessage) async {
        await rememberConversationMessage(message)
    }
}

// MARK: - Backward Compatibility

typealias MemoryService = MemoryCoordinator
