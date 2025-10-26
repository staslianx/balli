//
//  MedicalResearchViewModel.swift
//  balli
//
//  Medical research view model - Main coordinator
//  Orchestrates search, persistence, recall, and streaming
//  Swift 6 strict concurrency compliant
//

import Foundation
import SwiftUI
import OSLog

/// MedicalResearchViewModel manages medical research queries with T1/T2/T3 tier support
/// Handles multi-round deep research, planning, reflection, and streaming synthesis
/// @MainActor ensures all answer array mutations are serialized on the main thread
@MainActor
class MedicalResearchViewModel: ObservableObject {
    // MARK: - Published State

    /// ViewState pattern consolidates search operation state
    @Published var searchState: ViewState<Void> = .idle

    /// Data store accumulates answers over time (not replaced wholesale)
    @Published var answers: [SearchAnswer] = []

    /// Track tier during search
    @Published var currentSearchTier: ResponseTier? = nil

    /// Track source searching per answer
    @Published var searchingSourcesForAnswer: [String: Bool] = [:]

    // MARK: - Multi-Round Research State (delegated to stageCoordinator)

    /// Current display stage for answer (exposed from stageCoordinator)
    var currentStages: [String: String] {
        stageCoordinator.currentStages
    }

    /// Flag to hold stream display (exposed from stageCoordinator)
    var shouldHoldStream: [String: Bool] {
        stageCoordinator.shouldHoldStream
    }

    /// Per-answer research plans (exposed from stageCoordinator)
    var currentPlans: [String: ResearchPlan] {
        stageCoordinator.currentPlans
    }

    /// Completed research rounds (exposed from stageCoordinator)
    var completedRounds: [String: [ResearchRound]] {
        stageCoordinator.completedRounds
    }

    // MARK: - Performance Optimization

    /// O(1) lookup dictionary for answer index (answerId -> array index)
    /// Eliminates O(n) linear search called 5-15x per response
    private var answerIndexLookup: [String: Int] = [:]

    // MARK: - Convenience Properties

    /// Check if search is in progress
    var isSearching: Bool {
        searchState.isLoading
    }

    /// Access search error if present
    var searchError: Error? {
        searchState.error
    }

    /// History for library
    var answerHistory: [SearchAnswer] {
        answers
    }

    // MARK: - Coordinators & Services

    private let searchCoordinator = ResearchSearchCoordinator()
    private let persistenceManager = ResearchPersistenceManager()
    private let streamProcessor = ResearchStreamProcessor()
    private let recallHandler: ResearchRecallHandler
    let stageCoordinator = ResearchStageCoordinator()

    private let searchService = ResearchStreamingAPIClient()
    private let tokenBuffer = TokenBuffer()
    private let sessionManager: ResearchSessionManager

    // MARK: - Loggers

    private let logger = AppLoggers.Research.search
    private let streamingLogger = AppLoggers.Research.streaming

    // Current user ID - hardcoded for 2-user personal app without authentication
    private let currentUserId = "demo_user"

    // MARK: - Initialization

    init() {
        // Initialize session manager with ModelContainer, userId, and metadata generator
        let container = ResearchSessionModelContainer.shared.container
        let metadataGenerator = SessionMetadataGenerator()
        self.sessionManager = ResearchSessionManager(
            modelContainer: container,
            userId: currentUserId,
            metadataGenerator: metadataGenerator
        )

        // Initialize FTS5 manager for cross-conversation memory (recall)
        let fts5Manager: FTS5Manager?
        let recallRepository: RecallSearchRepository?

        do {
            let fts5 = try FTS5Manager()
            fts5Manager = fts5
            recallRepository = RecallSearchRepository(
                modelContainer: container,
                fts5Manager: fts5
            )
            logger.info("✅ FTS5 recall search initialized")
        } catch {
            logger.warning("⚠️ FTS5 recall unavailable: \(error.localizedDescription)")
            fts5Manager = nil
            recallRepository = nil
        }

        self.recallHandler = ResearchRecallHandler(
            fts5Manager: fts5Manager,
            recallRepository: recallRepository
        )

        // Setup notification observers
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("SaveActiveResearchSession"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.saveCurrentSession()
            }
        }

        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.syncAnswersToPersistence()
            }
        }

        Task {
            await loadSessionHistory()
            await recoverActiveSession()
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Session Management

    private func recoverActiveSession() async {
        await persistenceManager.recoverActiveSession(using: sessionManager)
    }

    private func saveCurrentSession() async {
        await persistenceManager.saveCurrentSession(using: sessionManager)
    }

    private func endCurrentSession() async {
        await persistenceManager.endCurrentSession(using: sessionManager)
    }

    private func loadSessionHistory() async {
        let loadedAnswers = await persistenceManager.loadSessionHistory()
        if !loadedAnswers.isEmpty {
            searchState = .loading
            answers = loadedAnswers
            rebuildAnswerIndexLookup()
            searchState = .loaded(())
        }
    }

    private func syncAnswersToPersistence() async {
        await persistenceManager.syncAnswersToPersistence(answers)
    }

    // MARK: - Public API

    /// Perform search via Cloud Function with instant question display
    func search(query: String) async {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        // Reset inactivity timer
        sessionManager.resetInactivityTimer()

        // Check for recall request
        if await recallHandler.shouldAttemptRecall(query) {
            await handleRecallRequest(query)
            return
        }

        // Session management
        if sessionManager.shouldEndSession(query) {
            logger.info("Detected session end signal in query: \(query)")
            await endCurrentSession()
        }

        // Append user message to session
        do {
            try await sessionManager.appendUserMessage(query)
            logger.debug("Appended user message to session")
        } catch {
            logger.error("Failed to append user message to session: \(error.localizedDescription)")
        }

        // Check token limit
        if sessionManager.shouldEndDueToTokenLimit() {
            logger.warning("Token limit approaching - ending session gracefully")
            await endCurrentSession()
            sessionManager.startNewSession()
            do {
                try await sessionManager.appendUserMessage(query)
            } catch {
                logger.error("Failed to append user message to new session: \(error.localizedDescription)")
            }
        }

        // Predict tier and create placeholder answer
        let predictedTier = searchCoordinator.predictTier(for: query)
        let placeholderAnswer = SearchAnswer(
            query: query,
            content: "",
            sources: [],
            timestamp: Date(),
            tokenCount: nil,
            tier: predictedTier,
            thinkingSummary: nil,
            processingTierRaw: predictedTier?.rawValue
        )

        logger.info("Starting search - Query: \(query, privacy: .private)")

        answers.insert(placeholderAnswer, at: 0)
        rebuildAnswerIndexLookup()
        searchState = .loading
        currentSearchTier = predictedTier

        let answerId = placeholderAnswer.id

        // Initialize stream processor
        _ = streamProcessor.initializeCancellationToken(for: answerId)
        await streamProcessor.resetEventTracker()

        // Get conversation history (already in correct format from sessionManager)
        let conversationHistory = sessionManager.getFormattedHistory()
        logger.info("🧠 [MEMORY-DEBUG] Passing \(conversationHistory.count) messages as context to LLM")

        // Start streaming search
        await performStreamingSearch(
            query: query,
            answerId: answerId,
            conversationHistory: conversationHistory
        )
    }

    /// Clear all answers and start fresh
    func clearHistory() async {
        answers.removeAll()
        answerIndexLookup.removeAll()

        do {
            try await persistenceManager.clearHistory()
        } catch {
            logger.error("Failed to clear persisted history: \(error.localizedDescription)")
        }
    }

    /// Start a new conversation - saves current answers to library and clears the view
    func startNewConversation() async {
        logger.info("💬 Starting new conversation - saving current conversation to library")

        await syncAnswersToPersistence()
        await endCurrentSession()

        answers.removeAll()
        answerIndexLookup.removeAll()

        sessionManager.startNewSession()

        logger.info("✅ New conversation started - previous conversation saved to library")
    }

    /// Cancel streaming response for the currently active search
    func cancelCurrentSearch() {
        guard let currentAnswer = answers.first, currentAnswer.content.isEmpty || isSearching else {
            logger.debug("No active search to cancel")
            return
        }

        let answerId = currentAnswer.id

        streamProcessor.cancelSearch(for: answerId)
        stageCoordinator.cleanupSearchState(for: answerId)

        logger.info("📝 Preserved content: \(currentAnswer.content.count, privacy: .public) chars")

        searchState = .idle
        currentSearchTier = nil

        // Save partial answer
        Task {
            if !currentAnswer.content.isEmpty {
                do {
                    try await persistenceManager.saveAnswer(currentAnswer)
                    logger.info("✅ Persisted cancelled answer: \(answerId, privacy: .public)")
                } catch {
                    logger.error("Failed to persist cancelled answer: \(error.localizedDescription)")
                }
            }
        }
    }

    /// Submit feedback for an answer
    func submitFeedback(rating: String, answer: SearchAnswer) async {
        await searchCoordinator.submitFeedback(rating: rating, answer: answer)
    }

    // MARK: - Private Helpers

    /// Rebuild the answer index lookup dictionary for O(1) access
    private func rebuildAnswerIndexLookup() {
        answerIndexLookup.removeAll(keepingCapacity: true)
        for (index, answer) in answers.enumerated() {
            answerIndexLookup[answer.id] = index
        }
    }

    /// Handle recall request
    private func handleRecallRequest(_ query: String) async {
        logger.info("📚 Handling recall request: \(query)")

        let placeholderAnswer = SearchAnswer(
            query: query,
            content: "",
            sources: [],
            timestamp: Date(),
            tokenCount: nil,
            tier: .recall
        )

        answers.insert(placeholderAnswer, at: 0)
        rebuildAnswerIndexLookup()
        searchState = .loading

        let answerId = placeholderAnswer.id

        do {
            let finalAnswer = try await recallHandler.handleRecallRequest(query, answerId: answerId)
            if let index = answerIndexLookup[answerId] {
                answers[index] = finalAnswer
            }
            searchState = .loaded(())
        } catch {
            logger.error("📚 Recall search failed: \(error.localizedDescription)")
            searchState = .error(error)
        }
    }

    // MARK: - Streaming Search Implementation

    private func performStreamingSearch(
        query: String,
        answerId: String,
        conversationHistory: [[String: String]]?
    ) async {
        await searchService.searchStreaming(
            query: query,
            userId: currentUserId,
            conversationHistory: conversationHistory,
            onToken: { @Sendable [weak self] token in
                guard let self = self else { return }
                Task {
                    await self.handleToken(token, answerId: answerId)
                }
            },
            onTierSelected: { @Sendable [weak self] tier in
                Task { @MainActor in
                    await self?.handleTierSelected(String(tier), answerId: answerId)
                }
            },
            onSearchComplete: { @Sendable [weak self] count, source in
                Task { @MainActor in
                    await self?.handleSearchComplete(count: count, source: source, answerId: answerId)
                }
            },
            onSourcesReady: { @Sendable [weak self] sources in
                Task { @MainActor in
                    await self?.handleSourcesReady(sources, answerId: answerId)
                }
            },
            onComplete: { @Sendable [weak self] response in
                Task { @MainActor in
                    await self?.handleComplete(response, query: query, answerId: answerId)
                }
            },
            onError: { @Sendable [weak self] error in
                Task { @MainActor in
                    await self?.handleError(error, query: query, answerId: answerId)
                }
            },
            onPlanningStarted: { @Sendable [weak self] message, sequence in
                Task { @MainActor in
                    await self?.handlePlanningStarted(message: message, sequence: sequence, answerId: answerId)
                }
            },
            onPlanningComplete: { @Sendable [weak self] plan, sequence in
                Task { @MainActor in
                    await self?.handlePlanningComplete(plan: plan, answerId: answerId)
                }
            },
            onRoundStarted: { @Sendable [weak self] round, query, estimatedSources, sequence in
                Task { @MainActor in
                    await self?.handleRoundStarted(round: round, query: query, estimatedSources: estimatedSources, sequence: sequence, answerId: answerId)
                }
            },
            onRoundComplete: { @Sendable [weak self] round, sources, status, sequence in
                Task { @MainActor in
                    await self?.handleRoundComplete(round: round, sources: sources, status: status, sequence: sequence, answerId: answerId)
                }
            },
            onApiStarted: { @Sendable [weak self] api, count, message in
                Task { @MainActor in
                    await self?.handleApiStarted(api: api.rawValue, message: message, answerId: answerId)
                }
            },
            onReflectionStarted: { @Sendable [weak self] round, sequence in
                Task { @MainActor in
                    await self?.handleReflectionStarted(round: round, sequence: sequence, answerId: answerId)
                }
            },
            onReflectionComplete: { @Sendable [weak self] round, reflection, sequence in
                Task { @MainActor in
                    await self?.handleReflectionComplete(round: round, reflection: reflection, sequence: sequence, answerId: answerId)
                }
            },
            onSourceSelectionStarted: { @Sendable [weak self] message, sequence in
                Task { @MainActor in
                    await self?.handleSourceSelectionStarted(message: message, sequence: sequence, answerId: answerId)
                }
            },
            onSynthesisPreparation: { @Sendable [weak self] message, sequence in
                Task { @MainActor in
                    await self?.handleSynthesisPreparation(message: message, sequence: sequence, answerId: answerId)
                }
            },
            onSynthesisStarted: { @Sendable [weak self] totalRounds, totalSources, sequence in
                Task { @MainActor in
                    await self?.handleSynthesisStarted(totalRounds: totalRounds, totalSources: totalSources, sequence: sequence, answerId: answerId)
                }
            }
        )
    }

    // MARK: - Event Handlers

    private func handleToken(_ token: String, answerId: String) async {
        await tokenBuffer.appendToken(token, for: answerId) { batchedContent in
            Task { @MainActor [weak self] in
                guard let self = self,
                      let index = self.answerIndexLookup[answerId] else { return }

                let currentAnswer = self.answers[index]

                // Handle first token arrival
                if currentAnswer.content.isEmpty {
                    await self.stageCoordinator.handleFirstTokenArrival(answerId: answerId)
                }

                let updatedContent = currentAnswer.content + batchedContent
                let updatedAnswer = SearchAnswer(
                    id: currentAnswer.id,
                    query: currentAnswer.query,
                    content: updatedContent,
                    sources: currentAnswer.sources,
                    citations: currentAnswer.citations,
                    timestamp: currentAnswer.timestamp,
                    tokenCount: currentAnswer.tokenCount,
                    tier: currentAnswer.tier,
                    thinkingSummary: currentAnswer.thinkingSummary,
                    processingTierRaw: currentAnswer.processingTierRaw
                )

                if currentAnswer.content.isEmpty {
                    withAnimation(.easeIn(duration: 0.4)) {
                        self.answers[index] = updatedAnswer
                    }
                } else {
                    self.answers[index] = updatedAnswer
                }
            }
        }
    }

    private func handleTierSelected(_ tier: String, answerId: String) async {
        guard let index = answers.firstIndex(where: { $0.id == answerId }) else { return }

        let currentAnswer = answers[index]
        // Convert String to Int for ResponseTier
        let tierInt = Int(tier) ?? 1
        let resolvedTier = ResponseTier(tier: tierInt, processingTier: nil)
        let updatedAnswer = SearchAnswer(
            id: currentAnswer.id,
            query: currentAnswer.query,
            content: currentAnswer.content,
            sources: currentAnswer.sources,
            citations: currentAnswer.citations,
            timestamp: currentAnswer.timestamp,
            tokenCount: currentAnswer.tokenCount,
            tier: resolvedTier,
            thinkingSummary: currentAnswer.thinkingSummary,
            processingTierRaw: resolvedTier?.rawValue ?? currentAnswer.processingTierRaw
        )
        answers[index] = updatedAnswer
        currentSearchTier = resolvedTier
        logger.notice("Tier updated to: \(tier, privacy: .public)")
    }

    private func handleSearchComplete(count: Int, source: String, answerId: String) async {
        logger.info("Search complete: \(count, privacy: .public) results from \(source, privacy: .public)")

        if source.lowercased().contains("knowledge") || source == "knowledge_base" {
            searchingSourcesForAnswer[answerId] = false
            return
        }

        searchingSourcesForAnswer[answerId] = true
    }

    private func handleSourcesReady(_ sources: [SourceResponse], answerId: String) async {
        logger.info("🎯 Sources ready: \(sources.count, privacy: .public) sources received")

        guard let index = answers.firstIndex(where: { $0.id == answerId }) else { return }

        let currentAnswer = answers[index]
        let researchSources = sources.map { searchCoordinator.convertToResearchSource($0) }

        let updatedAnswer = SearchAnswer(
            id: currentAnswer.id,
            query: currentAnswer.query,
            content: currentAnswer.content,
            sources: researchSources,
            citations: currentAnswer.citations,
            timestamp: currentAnswer.timestamp,
            tokenCount: currentAnswer.tokenCount,
            tier: currentAnswer.tier,
            thinkingSummary: currentAnswer.thinkingSummary,
            processingTierRaw: currentAnswer.processingTierRaw
        )
        answers[index] = updatedAnswer
        searchingSourcesForAnswer[answerId] = false
    }

    private func handleComplete(_ response: ResearchSearchResponse, query: String, answerId: String) async {
        // Flush remaining tokens
        await tokenBuffer.flushRemaining(answerId) { remainingContent in
            if !remainingContent.isEmpty {
                Task { @MainActor in
                    if let index = self.answers.firstIndex(where: { $0.id == answerId }) {
                        let currentAnswer = self.answers[index]
                        let finalContent = currentAnswer.content + remainingContent
                        let updatedAnswer = SearchAnswer(
                            id: currentAnswer.id,
                            query: currentAnswer.query,
                            content: finalContent,
                            sources: currentAnswer.sources,
                            citations: currentAnswer.citations,
                            timestamp: currentAnswer.timestamp,
                            tokenCount: currentAnswer.tokenCount,
                            tier: currentAnswer.tier,
                            thinkingSummary: currentAnswer.thinkingSummary,
                            processingTierRaw: currentAnswer.processingTierRaw,
                            completedRounds: currentAnswer.completedRounds
                        )
                        self.answers[index] = updatedAnswer
                    }
                }
            }
        }

        currentSearchTier = ResponseTier(tier: response.tier, processingTier: response.processingTier)

        // Filter sources
        let allSources = response.sourcesFormatted.map { searchCoordinator.convertToResearchSource($0) }
        let sources = allSources.filter { source in
            let isKnowledgeBase = source.domain.lowercased().contains("knowledge") ||
                                source.domain.isEmpty ||
                                source.url.absoluteString == "https://balli.app"
            return !isKnowledgeBase
        }

        guard let index = answers.firstIndex(where: { $0.id == answerId }) else { return }

        let currentAnswer = answers[index]
        let finalContent = currentAnswer.content.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedTier = ResponseTier(tier: response.tier, processingTier: response.processingTier) ?? currentAnswer.tier

        let finalAnswer = SearchAnswer(
            id: answerId,
            query: query,
            content: finalContent,
            sources: sources,
            timestamp: Date(),
            tokenCount: nil,
            tier: resolvedTier,
            thinkingSummary: response.thinkingSummary,
            processingTierRaw: response.processingTier ?? currentAnswer.processingTierRaw,
            completedRounds: stageCoordinator.getCompletedRounds(for: answerId)
        )

        answers[index] = finalAnswer

        // Save to persistence
        Task {
            do {
                try await persistenceManager.saveAnswer(finalAnswer)
                try await sessionManager.appendAssistantMessage(from: finalAnswer)
            } catch {
                logger.error("Failed to persist answer: \(error.localizedDescription)")
            }
        }

        searchState = .loaded(())
        currentSearchTier = nil

        streamProcessor.cleanupSearchState(for: answerId)
        stageCoordinator.cleanupSearchState(for: answerId)
    }

    private func handleError(_ error: Error, query: String, answerId: String) async {
        await tokenBuffer.cancel(answerId)

        logger.error("Streaming error: \(error.localizedDescription, privacy: .public)")
        searchState = .error(error)
        currentSearchTier = nil

        if let index = answers.firstIndex(where: { $0.id == answerId }) {
            let currentAnswer = answers[index]
            if !currentAnswer.content.isEmpty {
                let finalAnswer = SearchAnswer(
                    id: answerId,
                    query: query,
                    content: currentAnswer.content,
                    sources: [],
                    timestamp: Date(),
                    tokenCount: nil
                )
                answers[index] = finalAnswer
                logger.warning("Stream incomplete but preserved \(currentAnswer.content.count, privacy: .public) chars")
            }
        }
    }

    // MARK: - Multi-Round Event Handlers

    private func handlePlanningStarted(message: String, sequence: Int, answerId: String) async {
        await stageCoordinator.processStageTransition(
            event: .planningStarted(message: message, sequence: sequence),
            answerId: answerId
        )
    }

    private func handlePlanningComplete(plan: ResearchPlan, answerId: String) async {
        stageCoordinator.storePlan(plan, for: answerId)
    }

    private func handleRoundStarted(round: Int, query: String, estimatedSources: Int, sequence: Int, answerId: String) async {
        await stageCoordinator.processStageTransition(
            event: .roundStarted(round: round, query: query, estimatedSources: estimatedSources, sequence: sequence),
            answerId: answerId
        )
    }

    private func handleRoundComplete(round: Int, sources: [SourceResponse], status: RoundStatus, sequence: Int, answerId: String) async {
        guard let index = answerIndexLookup[answerId] else { return }
        let currentAnswer = answers[index]

        if let roundData = await streamProcessor.handleRoundComplete(
            round: round,
            sources: sources,
            status: status,
            sequence: sequence,
            answerId: answerId,
            currentAnswer: currentAnswer,
            convertSource: { self.searchCoordinator.convertToResearchSource($0) },
            onUpdate: { updatedAnswer in
                self.answers[index] = updatedAnswer
            },
            onError: { error in
                self.searchState = .error(error)
                self.streamProcessor.cleanupSearchState(for: answerId)
                self.stageCoordinator.cleanupSearchState(for: answerId)
            }
        ) {
            stageCoordinator.addCompletedRound(roundData, for: answerId)
        }
    }

    private func handleApiStarted(api: String, message: String, answerId: String) async {
        // Convert String back to ResearchAPI enum
        let researchAPI = ResearchAPI(rawValue: api) ?? .exa
        await stageCoordinator.processStageTransition(
            event: .apiStarted(api: researchAPI, count: 0, message: message),
            answerId: answerId
        )
    }

    private func handleReflectionStarted(round: Int, sequence: Int, answerId: String) async {
        await stageCoordinator.processStageTransition(
            event: .reflectionStarted(round: round, sequence: sequence),
            answerId: answerId
        )
    }

    private func handleReflectionComplete(round: Int, reflection: ResearchReflection, sequence: Int, answerId: String) async {
        let currentRounds = stageCoordinator.getCompletedRounds(for: answerId)

        if let updatedRounds = await streamProcessor.handleReflectionComplete(
            round: round,
            reflection: reflection,
            sequence: sequence,
            answerId: answerId,
            rounds: currentRounds
        ) {
            stageCoordinator.updateRoundWithReflection(updatedRounds, for: answerId)
        }
    }

    private func handleSourceSelectionStarted(message: String, sequence: Int, answerId: String) async {
        await stageCoordinator.processStageTransition(
            event: .sourceSelectionStarted(message: message, sequence: sequence),
            answerId: answerId
        )
    }

    private func handleSynthesisPreparation(message: String, sequence: Int, answerId: String) async {
        await stageCoordinator.processStageTransition(
            event: .synthesisPreparation(message: message, sequence: sequence),
            answerId: answerId
        )
    }

    private func handleSynthesisStarted(totalRounds: Int, totalSources: Int, sequence: Int, answerId: String) async {
        await stageCoordinator.processStageTransition(
            event: .synthesisStarted(totalRounds: totalRounds, totalSources: totalSources, sequence: sequence),
            answerId: answerId
        )
    }
}
