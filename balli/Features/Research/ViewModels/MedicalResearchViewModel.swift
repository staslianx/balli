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
import SwiftData
import OSLog
import Combine

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

    /// Current display stage for answer (republished from stageCoordinator)
    /// This MUST be @Published so SwiftUI observes changes
    @Published var currentStages: [String: String] = [:]

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

    /// Track which answers have already triggered first token arrival
    /// Prevents handleFirstTokenArrival from being called multiple times per answer
    private var firstTokenProcessed: Set<String> = []

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
    let stageCoordinator = ResearchStageCoordinator()

    private let searchService = ResearchStreamingAPIClient()
    private let tokenBuffer = TokenBuffer()
    private let sessionManager: ResearchSessionManager

    // Extracted components
    private let eventHandler: ResearchEventHandler
    private let sessionCoordinator: ResearchSessionCoordinator

    // MARK: - Loggers

    private let logger = AppLoggers.Research.search
    private let streamingLogger = AppLoggers.Research.streaming

    // Current user ID - hardcoded for 2-user personal app without authentication
    private let currentUserId = "demo_user"

    // MARK: - Combine

    private var cancellables = Set<AnyCancellable>()

    // MARK: - NotificationCenter Observers

    // Stored on MainActor for proper isolation - deinit runs on MainActor since class is @MainActor
    private var observers: [NSObjectProtocol] = []

    // MARK: - Initialization

    init() {
        // Step 1: Initialize core components without observers
        let initializer = ResearchViewModelInitializer(
            tokenBuffer: tokenBuffer,
            streamProcessor: streamProcessor,
            stageCoordinator: stageCoordinator,
            searchCoordinator: searchCoordinator,
            persistenceManager: persistenceManager,
            currentUserId: currentUserId
        )

        let coreComponents = initializer.initializeCoreComponents()

        // Assign core components before setting up observers (observers need sessionCoordinator)
        self.sessionManager = coreComponents.sessionManager
        self.eventHandler = coreComponents.eventHandler
        self.sessionCoordinator = coreComponents.sessionCoordinator

        // Step 2: Setup observers now that self is fully initialized
        self.observers = initializer.setupNotificationObservers(
            saveCurrentSession: { [weak self] in
                await self?.saveCurrentSession()
            },
            syncAnswersToPersistence: { [weak self] in
                await self?.syncAnswersToPersistence()
            }
        )

        // Step 3: Setup Combine observers
        let stageCancellable = initializer.setupStageCoordinatorObserver(
            stageCoordinator: stageCoordinator,
            updateCurrentStages: { [weak self] stages in
                self?.currentStages = stages
            }
        )
        cancellables.insert(stageCancellable)

        Task {
            await loadSessionHistory()
            await recoverActiveSession()
        }
    }

    deinit {
        MainActor.assumeIsolated {
            for observer in observers {
                NotificationCenter.default.removeObserver(observer)
            }
            observers.removeAll()
        }
    }

    // MARK: - Session Management

    private func recoverActiveSession() async {
        await sessionCoordinator.recoverActiveSession()
    }

    private func saveCurrentSession() async {
        await sessionCoordinator.saveCurrentSession()
    }

    private func endCurrentSession() async {
        await sessionCoordinator.endCurrentSession()
    }

    private func loadSessionHistory() async {
        await sessionCoordinator.loadSessionHistory(
            setSearchState: { @MainActor [weak self] state in self?.searchState = state },
            setAnswers: { @MainActor [weak self] loadedAnswers in self?.answers = loadedAnswers },
            rebuildLookup: { @MainActor [weak self] in self?.rebuildAnswerIndexLookup() }
        )
    }

    private func syncAnswersToPersistence() async {
        await sessionCoordinator.syncAnswersToPersistence(answers)
    }

    // MARK: - Public API

    /// Perform search via Cloud Function with instant question display
    func search(query: String, image: UIImage? = nil) async {
        let hasText = !query.trimmingCharacters(in: .whitespaces).isEmpty
        let hasImage = image != nil
        guard hasText || hasImage else { return }

        // Reset inactivity timer
        sessionManager.resetInactivityTimer()

        // Session management
        if sessionManager.shouldEndSession(query) {
            logger.info("Detected session end signal in query: \(query)")
            await endCurrentSession()
        }

        // Create image attachment if image provided
        var imageAttachment: ImageAttachment? = nil
        if let image = image {
            imageAttachment = ImageAttachment.create(from: image)
            logger.debug("Created image attachment: \(imageAttachment?.fileSizeDescription ?? "unknown size")")
        }

        // Append user message to session (with optional image)
        do {
            if let imageAttachment = imageAttachment {
                try await sessionManager.appendUserMessage(query, imageAttachment: imageAttachment)
            } else {
                try await sessionManager.appendUserMessage(query)
            }
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
            processingTierRaw: predictedTier?.rawValue,
            imageAttachment: imageAttachment
        )

        logger.info("Starting search - Query: \(query, privacy: .private)")

        answers.insert(placeholderAnswer, at: 0)
        rebuildAnswerIndexLookup()
        searchState = .loading
        currentSearchTier = predictedTier

        let answerId = placeholderAnswer.id

        // Ensure flag is cleared for this new answer (should already be clear, but be explicit)
        firstTokenProcessed.remove(answerId)

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
        firstTokenProcessed.removeAll() // Clear first token tracking

        do {
            try await persistenceManager.clearHistory()
        } catch {
            logger.error("Failed to clear persisted history: \(error.localizedDescription)")
        }
    }

    /// Start a new conversation - saves current answers to library and clears the view
    func startNewConversation() async {
        logger.info("💬 Starting new conversation - saving current conversation to library")
        logger.info("Current answers count: \(self.answers.count)")

        // CRITICAL: Clear UI state IMMEDIATELY (synchronously) for instant visual feedback
        // This ensures the empty state appears on first tap without delay
        answers.removeAll()
        answerIndexLookup.removeAll()
        searchingSourcesForAnswer.removeAll()
        firstTokenProcessed.removeAll()
        searchState = .idle
        currentSearchTier = nil

        // Then perform async cleanup work (persistence, session management)
        await syncAnswersToPersistence()
        await endCurrentSession()

        // Clear stage coordinator state (includes observer cleanup)
        await stageCoordinator.clearAllState()

        // Start fresh session
        sessionManager.startNewSession()

        logger.info("✅ New conversation started - previous conversation saved to library")
        logger.info("New answers count: \(self.answers.count)")
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

    /// Signal that view is ready to display stages
    func signalViewReady(for answerId: String) {
        stageCoordinator.signalViewReady(for: answerId)
    }

    // MARK: - Private Helpers

    /// Rebuild the answer index lookup dictionary for O(1) access
    private func rebuildAnswerIndexLookup() {
        answerIndexLookup.removeAll(keepingCapacity: true)
        for (index, answer) in answers.enumerated() {
            answerIndexLookup[answer.id] = index
        }
    }

    // MARK: - Streaming Search Implementation

    private func performStreamingSearch(
        query: String,
        answerId: String,
        conversationHistory: [[String: String]]?
    ) async {
        // Build callbacks using dedicated builder service
        let callbacksBuilder = ResearchStreamCallbacksBuilder(viewModel: self)
        let callbacks = callbacksBuilder.buildCallbacks(query: query, answerId: answerId)

        await searchService.searchStreaming(
            query: query,
            userId: currentUserId,
            conversationHistory: conversationHistory,
            onToken: callbacks.onToken,
            onTierSelected: callbacks.onTierSelected,
            onSearchComplete: callbacks.onSearchComplete,
            onSourcesReady: callbacks.onSourcesReady,
            onComplete: callbacks.onComplete,
            onError: callbacks.onError,
            onPlanningStarted: callbacks.onPlanningStarted,
            onPlanningComplete: callbacks.onPlanningComplete,
            onRoundStarted: callbacks.onRoundStarted,
            onRoundComplete: callbacks.onRoundComplete,
            onApiStarted: callbacks.onApiStarted,
            onReflectionStarted: callbacks.onReflectionStarted,
            onReflectionComplete: callbacks.onReflectionComplete,
            onSourceSelectionStarted: callbacks.onSourceSelectionStarted,
            onSynthesisPreparation: callbacks.onSynthesisPreparation,
            onSynthesisStarted: callbacks.onSynthesisStarted
        )
    }

    // MARK: - Event Handlers (Internal for ResearchStreamCallbacksBuilder)

    func handleToken(_ token: String, answerId: String) async {
        // STREAMING FIX: Update UI immediately with each token - no batching
        // The irregular chunking pattern was caused by race conditions between batching layers
        logger.debug("🔍 [TOKEN] Parsed token: length=\(token.count), last='\(token.last ?? Character(" "))', content='\(token)'")

        // Update answer immediately - no accumulation, no delay
        await eventHandler.handleToken(
            token,
            answerId: answerId,
            getAnswers: { @MainActor [weak self] in self?.answers ?? [] },
            getAnswerIndex: { @MainActor [weak self] id in self?.answerIndexLookup[id] },
            getFirstTokenProcessed: { @MainActor [weak self] in self?.firstTokenProcessed ?? [] },
            updateAnswer: { @MainActor [weak self] index, answer, shouldAnimate in
                guard let self = self else { return }
                // Direct update - no animation
                self.answers[index] = answer
            },
            markFirstTokenProcessed: { @MainActor [weak self] id in self?.firstTokenProcessed.insert(id) }
        )
    }

    func handleTierSelected(_ tier: String, answerId: String) async {
        await eventHandler.handleTierSelected(
            tier,
            answerId: answerId,
            getAnswers: { @MainActor [weak self] in self?.answers ?? [] },
            updateAnswer: { @MainActor [weak self] index, answer in
                self?.answers[index] = answer
            },
            setCurrentTier: { @MainActor [weak self] tier in
                self?.currentSearchTier = tier
            }
        )
    }

    func handleSearchComplete(count: Int, source: String, answerId: String) async {
        await eventHandler.handleSearchComplete(
            count: count,
            source: source,
            answerId: answerId,
            setSearchingSource: { @MainActor [weak self] id, value in
                self?.searchingSourcesForAnswer[id] = value
            }
        )
    }

    func handleSourcesReady(_ sources: [SourceResponse], answerId: String) async {
        await eventHandler.handleSourcesReady(
            sources,
            answerId: answerId,
            getAnswers: { @MainActor [weak self] in self?.answers ?? [] },
            updateAnswer: { @MainActor [weak self] index, answer in
                self?.answers[index] = answer
            },
            setSearchingSource: { @MainActor [weak self] id, value in
                self?.searchingSourcesForAnswer[id] = value
            }
        )
    }

    func handleComplete(_ response: ResearchSearchResponse, query: String, answerId: String) async {
        await eventHandler.handleComplete(
            response,
            query: query,
            answerId: answerId,
            getAnswers: { @MainActor [weak self] in self?.answers ?? [] },
            updateAnswer: { @MainActor [weak self] index, answer in
                self?.answers[index] = answer
            },
            setSearchState: { @MainActor [weak self] state in
                self?.searchState = state
            },
            setCurrentTier: { @MainActor [weak self] tier in
                self?.currentSearchTier = tier
            }
        )
    }

    func handleError(_ error: Error, query: String, answerId: String) async {
        await eventHandler.handleError(
            error,
            query: query,
            answerId: answerId,
            getAnswers: { @MainActor [weak self] in self?.answers ?? [] },
            updateAnswer: { @MainActor [weak self] index, answer in
                self?.answers[index] = answer
            },
            setSearchState: { @MainActor [weak self] state in
                self?.searchState = state
            },
            setCurrentTier: { @MainActor [weak self] tier in
                self?.currentSearchTier = tier
            }
        )
    }

    // MARK: - Multi-Round Event Handlers (Internal for ResearchStreamCallbacksBuilder)

    func handlePlanningStarted(message: String, sequence: Int, answerId: String) async {
        await eventHandler.handlePlanningStarted(message: message, sequence: sequence, answerId: answerId)
    }

    func handlePlanningComplete(plan: ResearchPlan, answerId: String) async {
        await eventHandler.handlePlanningComplete(plan: plan, answerId: answerId)
    }

    func handleRoundStarted(round: Int, query: String, estimatedSources: Int, sequence: Int, answerId: String) async {
        await eventHandler.handleRoundStarted(round: round, query: query, estimatedSources: estimatedSources, sequence: sequence, answerId: answerId)
    }

    func handleRoundComplete(round: Int, sources: [SourceResponse], status: RoundStatus, sequence: Int, answerId: String) async {
        await eventHandler.handleRoundComplete(
            round: round,
            sources: sources,
            status: status,
            sequence: sequence,
            answerId: answerId,
            getAnswer: { @MainActor [weak self] id in
                self?.answers.first(where: { $0.id == id })
            },
            updateAnswer: { @MainActor [weak self] index, answer in
                self?.answers[index] = answer
            },
            setSearchState: { @MainActor [weak self] state in
                self?.searchState = state
            },
            getAnswerIndex: { @MainActor [weak self] id in
                self?.answerIndexLookup[id]
            }
        )
    }

    func handleApiStarted(api: String, message: String, answerId: String) async {
        await eventHandler.handleApiStarted(api: api, message: message, answerId: answerId)
    }

    func handleReflectionStarted(round: Int, sequence: Int, answerId: String) async {
        await eventHandler.handleReflectionStarted(round: round, sequence: sequence, answerId: answerId)
    }

    func handleReflectionComplete(round: Int, reflection: ResearchReflection, sequence: Int, answerId: String) async {
        await eventHandler.handleReflectionComplete(round: round, reflection: reflection, sequence: sequence, answerId: answerId)
    }

    func handleSourceSelectionStarted(message: String, sequence: Int, answerId: String) async {
        await eventHandler.handleSourceSelectionStarted(message: message, sequence: sequence, answerId: answerId)
    }

    func handleSynthesisPreparation(message: String, sequence: Int, answerId: String) async {
        await eventHandler.handleSynthesisPreparation(message: message, sequence: sequence, answerId: answerId)
    }

    func handleSynthesisStarted(totalRounds: Int, totalSources: Int, sequence: Int, answerId: String) async {
        await eventHandler.handleSynthesisStarted(totalRounds: totalRounds, totalSources: totalSources, sequence: sequence, answerId: answerId)
    }
}
