//
//  MedicalResearchViewModel.swift
//  balli
//
//  Medical research view model for multi-round deep research
//  Swift 6 strict concurrency compliant
//

import Foundation
import SwiftUI
import OSLog

/// MedicalResearchViewModel manages medical research queries with T1/T2/T3 tier support
/// Handles multi-round deep research, planning, reflection, and streaming synthesis
/// @MainActor ensures all answer array mutations are serialized on the main thread
/// All streaming callbacks use @Sendable closures with proper Task { @MainActor ... } wrapping
@MainActor
class MedicalResearchViewModel: ObservableObject {
    // PERFORMANCE: ViewState pattern consolidates search operation state
    @Published var searchState: ViewState<Void> = .idle

    // Data store accumulates answers over time (not replaced wholesale)
    @Published var answers: [SearchAnswer] = []

    // PERFORMANCE: O(1) lookup dictionary for answer index (answerId -> array index)
    // Eliminates O(n) linear search called 5-15x per response
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

    @Published var currentSearchTier: ResponseTier? = nil // Track tier during search
    @Published var searchingSourcesForAnswer: [String: Bool] = [:] // Track source searching per answer

    // MARK: - Multi-Round Deep Research State

    /// Per-answer research plans (answerId -> ResearchPlan)
    @Published var currentPlans: [String: ResearchPlan] = [:]

    /// Completed research rounds (answerId -> [ResearchRound])
    @Published var completedRounds: [String: [ResearchRound]] = [:]

    /// Stage display manager for user-friendly progress (answerId -> Manager)
    private var stageManagers: [String: ResearchStageDisplayManager] = [:]

    /// Current display stage for answer (answerId -> Stage message)
    @Published var currentStages: [String: String] = [:]

    /// Flag to hold stream display until "writing report" stage completes (answerId -> Bool)
    @Published var shouldHoldStream: [String: Bool] = [:]

    // MARK: - Cancellation Management

    /// Cancellation tokens for filtering stale events (answerId -> UUID)
    private var cancellationTokens: [String: UUID] = [:]

    /// Reflection timeout tasks (answerId -> Task)
    private var reflectionTimeouts: [String: Task<Void, Never>] = [:]

    // MARK: - Event Tracking

    /// Actor for SSE event deduplication
    private let eventTracker = SSEEventTracker()

    /// Token buffer for batching streaming updates (reduces main thread hits 95%)
    private let tokenBuffer = TokenBuffer()

    // Service for Cloud Function calls
    private let searchService = ResearchStreamingAPIClient()

    // MARK: - Persistence
    private let repository = ResearchHistoryRepository()

    // MARK: - Session Management (In-Conversation Memory)
    private let sessionManager: ResearchSessionManager

    // MARK: - Cross-Conversation Memory (Recall)
    private let fts5Manager: FTS5Manager?
    private let recallRepository: RecallSearchRepository?

    // MARK: - Loggers

    private let logger = AppLoggers.Research.search
    private let streamingLogger = AppLoggers.Research.streaming

    // Current user ID - hardcoded for 2-user personal app without authentication
    private let currentUserId = "demo_user"

    // SIMPLIFICATION: Direct token accumulation without parsing or deduplication
    // No markdown processing, no streaming animations - just raw text concatenation

    // History for library
    var answerHistory: [SearchAnswer] {
        answers
    }

    // MARK: - Performance Helper

    /// Rebuild the answer index lookup dictionary for O(1) access
    /// Call this after any modification to the answers array
    private func rebuildAnswerIndexLookup() {
        answerIndexLookup.removeAll(keepingCapacity: true)
        for (index, answer) in answers.enumerated() {
            answerIndexLookup[answer.id] = index
        }
    }

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
        // Will be nil if SQLite.swift package not added or FTS5 initialization fails
        do {
            let fts5 = try FTS5Manager()
            self.fts5Manager = fts5
            self.recallRepository = RecallSearchRepository(
                modelContainer: container,
                fts5Manager: fts5
            )
            logger.info("✅ FTS5 recall search initialized")
        } catch {
            logger.warning("⚠️ FTS5 recall unavailable: \(error.localizedDescription)")
            self.fts5Manager = nil
            self.recallRepository = nil
        }

        // Setup notification observer for app backgrounding (after sessionManager init)
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("SaveActiveResearchSession"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.saveCurrentSession()
            }
        }

        // Auto-save when app backgrounds (ensures research persists if app is killed)
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

    /// Attempt to recover an active session from storage (e.g., after app crash)
    private func recoverActiveSession() async {
        do {
            let recovered = try await sessionManager.recoverActiveSession()
            if recovered {
                logger.info("Recovered active research session")
                // Optionally show a message to the user asking if they want to continue
            }
        } catch {
            logger.error("Failed to recover active session: \(error.localizedDescription)")
        }
    }

    /// Save the current research session WITHOUT clearing it (for app backgrounding)
    private func saveCurrentSession() async {
        do {
            try await sessionManager.saveActiveSession()
            logger.info("💾 Current research session saved (conversation history preserved)")
        } catch {
            logger.error("Failed to save active session: \(error.localizedDescription)")
        }
    }

    /// End the current research session and persist it with metadata
    private func endCurrentSession() async {
        do {
            try await sessionManager.endSession(generateMetadata: true)
            logger.info("✅ Current research session ended and persisted")
        } catch {
            logger.error("Failed to end session: \(error.localizedDescription)")
        }
    }

    /// Load research history based on session state:
    /// - If app was KILLED/CRASHED/CLOSED → Show empty state (fresh conversation)
    /// - If app was BACKGROUNDED → Restore last state exactly as user left it
    /// - If user switches tabs within app → Show last state exactly as user left it
    private func loadSessionHistory() async {
        let appStateManager = AppLifecycleCoordinator.shared

        // Check if app gracefully went to background (vs being terminated)
        let wasGracefullyBackgrounded = await appStateManager.wasGracefullyBackgrounded
        let persistedBackgroundTime = await appStateManager.persistedLastBackgroundTime

        // Calculate time since last background
        let timeInBackground = persistedBackgroundTime.map {
            Date().timeIntervalSince($0)
        } ?? Double.infinity  // If nil, treat as infinite time (fresh install)

        // Load history ONLY if:
        // 1. App was gracefully backgrounded (not killed/crashed)
        // 2. Time in background < 15 minutes (active conversation window)
        let shouldLoadHistory = wasGracefullyBackgrounded && (timeInBackground < 900)

        // Format time for logging (handle infinity case)
        let timeString = timeInBackground.isInfinite ? "∞" : "\(Int(timeInBackground))s"

        logger.info("🔍 [PERSISTENCE] Session check: gracefulBackground=\(wasGracefullyBackgrounded), timeInBackground=\(timeString), shouldLoad=\(shouldLoadHistory)")

        if shouldLoadHistory {
            logger.info("✅ [PERSISTENCE] Restoring previous research session (app was backgrounded)")
            await loadPersistedHistory()
        } else {
            if !wasGracefullyBackgrounded {
                logger.info("🆕 [PERSISTENCE] Starting fresh - app was killed/crashed/closed")
            } else {
                logger.info("🆕 [PERSISTENCE] Starting fresh - too much time passed (\(timeString))")
            }
            // answers remains empty ([]); user sees clean Research tab
        }
    }

    private func loadPersistedHistory() async {
        searchState = .loading

        do {
            let persistedAnswers = try await repository.loadAll()
            await MainActor.run {
                self.answers = persistedAnswers
                self.rebuildAnswerIndexLookup() // PERFORMANCE: Update O(1) lookup dictionary
                self.searchState = .loaded(())
                self.logger.info("Loaded \(persistedAnswers.count) research answers from persistence")
            }
        } catch {
            logger.error("Failed to load persisted history: \(error.localizedDescription)")
            searchState = .error(error)
        }
    }

    /// Perform search via Cloud Function with instant question display
    func search(query: String) async {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        // ⏰ SESSION MANAGEMENT: Reset inactivity timer on user interaction
        sessionManager.resetInactivityTimer()

        // 📚 RECALL DETECTION: Check if user is asking about past research
        // This takes priority over normal search routing
        if await shouldAttemptRecall(query) {
            await handleRecallRequest(query)
            return
        }

        // 🧠 SESSION MANAGEMENT: Check for session end signals before processing
        if sessionManager.shouldEndSession(query) {
            logger.info("Detected session end signal in query: \(query)")
            await endCurrentSession()
            // Still process the query as it might be a new topic
        }

        // 🧠 TOPIC CHANGE DETECTION: DISABLED - Too aggressive, was ending sessions on follow-up questions
        // The heuristic was detecting questions like "Bu herkes için aynı mı?" as topic changes
        // when they're clearly related follow-ups. Only rely on explicit user signals instead.
        //
        // if sessionManager.detectTopicChange(query) {
        //     logger.warning("❌ [SESSION-LIFECYCLE] Detected topic change - ending previous session and starting new one")
        //     await endCurrentSession()
        //     sessionManager.startNewSession()
        // }

        // 🧠 SESSION MANAGEMENT: Append user message to session
        do {
            try await sessionManager.appendUserMessage(query)
            logger.debug("Appended user message to session")
        } catch {
            logger.error("Failed to append user message to session: \(error.localizedDescription)")
        }

        // 🧠 SESSION MANAGEMENT: Check token limit
        if sessionManager.shouldEndDueToTokenLimit() {
            logger.warning("Token limit approaching - ending session gracefully")
            await endCurrentSession()
            // Start fresh session for this query
            sessionManager.startNewSession()
            do {
                try await sessionManager.appendUserMessage(query)
            } catch {
                logger.error("Failed to append user message to new session: \(error.localizedDescription)")
            }
        }

        // Predict tier based on query complexity (show "Derin Araştırma" upfront if likely Pro)
        let predictedTier = predictTier(for: query)
        #if DEBUG
        logger.debug("Predicted tier: \(predictedTier?.label ?? "Model", privacy: .public)")
        #endif

        // STEP 1: Display question immediately with predicted tier
        let placeholderAnswer = SearchAnswer(
            query: query,
            content: "", // Will be populated when response arrives
            sources: [],
            timestamp: Date(),
            tokenCount: nil,
            tier: predictedTier, // Set predicted tier immediately for badge display
            thinkingSummary: nil,
            processingTierRaw: predictedTier?.rawValue
        )

        logger.info("Starting search - Query: \(query, privacy: .private)")
        #if DEBUG
        logger.debug("Created placeholder answer ID: \(placeholderAnswer.id, privacy: .public)")
        #endif

        answers.insert(placeholderAnswer, at: 0)
        rebuildAnswerIndexLookup() // PERFORMANCE: Update O(1) lookup dictionary
        searchState = .loading
        currentSearchTier = predictedTier

        // STEP 2: Call streaming endpoint for real-time token-by-token updates
        // CONCURRENCY FIX: Capture answerId as immutable value to prevent race conditions
        let answerId = placeholderAnswer.id

        // Initialize cancellation token
        let token = UUID()
        cancellationTokens[answerId] = token

        // Reset event tracker for new search
        await eventTracker.reset()

        // 🧠 SESSION MANAGEMENT: Get conversation history for context
        let conversationHistory = sessionManager.getFormattedHistory()
        logger.info("🧠 [MEMORY-DEBUG] Passing \(conversationHistory.count) messages as context to LLM")

        // DEBUG: Log conversation history details
        if !conversationHistory.isEmpty {
            logger.info("🧠 [MEMORY-DEBUG] History preview:")
            for (index, msg) in conversationHistory.prefix(3).enumerated() {
                logger.info("🧠 [MEMORY-DEBUG]   [\(index)] \(msg)")
            }
        } else {
            logger.warning("⚠️ [MEMORY-DEBUG] No conversation history available!")
        }

        await searchService.searchStreaming(
            query: query,
            userId: currentUserId,
            conversationHistory: conversationHistory.isEmpty ? nil : conversationHistory,
            onToken: { @Sendable [weak self] token in
                // 🔄 TOKEN BATCHING: Buffer tokens and update in optimized batches
                // Reduces main thread hits from 1500+ to ~30 (95% reduction)
                guard let self = self else { return }

                Task {
                    await self.tokenBuffer.appendToken(token, for: answerId) { batchedContent in
                        Task { @MainActor [weak self] in
                            guard let self = self else { return }

                            // PERFORMANCE: O(1) dictionary lookup instead of O(n) linear search
                            if let index = self.answerIndexLookup[answerId] {
                                let currentAnswer = self.answers[index]

                                // 🔍 LOG: Track when first token arrives (indicates synthesis has started)
                                if currentAnswer.content.isEmpty {
                                    self.streamingLogger.critical("🎬 FIRST TOKEN ARRIVED - synthesis streaming started")
                                    self.streamingLogger.critical("🔒 shouldHoldStream = \(self.shouldHoldStream[answerId] ?? false)")

                                    // 🎯 CRITICAL FIX: Fade out progress card and release hold when first token arrives
                                    // This ensures smooth transition with no gap between stages and content
                                    if self.shouldHoldStream[answerId] == true {
                                        self.streamingLogger.critical("🎬 Fading out progress card NOW")

                                        // Clear stage to trigger fade out animation
                                        self.currentStages[answerId] = nil

                                        // Small delay for fade animation to complete (0.3s)
                                        Task {
                                            try? await Task.sleep(for: .seconds(0.3))

                                            await MainActor.run {
                                                self.streamingLogger.critical("🚀 Releasing hold - showing content!")
                                                self.shouldHoldStream[answerId] = false
                                            }
                                        }
                                    }
                                }

                                let updatedContent = currentAnswer.content + batchedContent

                                let updatedAnswer = SearchAnswer(
                                    id: currentAnswer.id,
                                    query: currentAnswer.query,
                                    content: updatedContent,  // Batched tokens accumulated here
                                    sources: currentAnswer.sources,
                                    citations: currentAnswer.citations,
                                    timestamp: currentAnswer.timestamp,
                                    tokenCount: currentAnswer.tokenCount,
                                    tier: currentAnswer.tier,
                                    thinkingSummary: currentAnswer.thinkingSummary,
                                    processingTierRaw: currentAnswer.processingTierRaw
                                )

                                // 🎬 Apply fade-in animation only when first token arrives (content transitions from empty → text)
                                // This ensures T3 held content and T1/T2 content both fade in smoothly
                                // Subsequent batches update without animation to prevent stutter
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
                }
            },
            onTierSelected: { @Sendable [weak self] tier in
                Task { @MainActor in
                    guard let self = self else { return }

                    // Update the answer's tier when backend determines it
                    if let index = self.answers.firstIndex(where: { $0.id == answerId }) {
                        let currentAnswer = self.answers[index]
                        let resolvedTier = ResponseTier(tier: tier, processingTier: nil)
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
                        self.answers[index] = updatedAnswer
                        self.currentSearchTier = resolvedTier
                        self.logger.notice("Tier updated to: \(tier, privacy: .public)")
                    }
                }
            },
            onSearchComplete: { @Sendable [weak self] count, source in
                Task { @MainActor in
                    guard let self = self else { return }
                    self.logger.info("Search complete: \(count, privacy: .public) results from \(source, privacy: .public)")

                    // Skip adding sources for knowledge_base (model-only responses)
                    // This ensures "Web'de Arama" and source pills don't appear for model knowledge
                    if source.lowercased().contains("knowledge") || source == "knowledge_base" {
                        #if DEBUG
                        self.logger.debug("Skipping source pill for knowledge_base source")
                        #endif
                        self.searchingSourcesForAnswer[answerId] = false
                        return
                    }

                    // Mark that sources are being found (will show indicator)
                    self.searchingSourcesForAnswer[answerId] = true
                }
            },
            onSourcesReady: { @Sendable [weak self] sources in
                Task { @MainActor in
                    guard let self = self else { return }
                    self.logger.info("🎯 Sources ready: \(sources.count, privacy: .public) sources received (showing immediately)")

                    // Update answer with sources immediately (like T3)
                    if let index = self.answers.firstIndex(where: { $0.id == answerId }) {
                        let currentAnswer = self.answers[index]

                        // Convert SourceResponse to ResearchSource
                        let researchSources = sources.map { self.convertToResearchSource($0) }

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
                        self.answers[index] = updatedAnswer
                    }

                    // Hide sources searching indicator
                    self.searchingSourcesForAnswer[answerId] = false
                }
            },
            onComplete: { @Sendable [weak self] response in
                Task { @MainActor in
                    guard let self = self else { return }

                    // 🔄 FLUSH: Ensure any remaining buffered tokens are delivered before completion
                    await self.tokenBuffer.flushRemaining(answerId) { remainingContent in
                        // Apply any final token batch on the main actor via a Task to keep this closure synchronous
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

                    // DON'T hide progress immediately - let stages complete naturally
                    // Progress will auto-hide after synthesis stage (92%) holds for 3 seconds

                    // Set tier from response
                    self.currentSearchTier = ResponseTier(tier: response.tier, processingTier: response.processingTier)
                    self.logger.notice("Final tier: \(response.tier, privacy: .public)")

                    // Convert sources, filtering out knowledge_base sources (model-only responses)
                    let allSources = response.sourcesFormatted.map { self.convertToResearchSource($0) }
                    let sources = allSources.filter { source in
                        // Filter out knowledge_base sources
                        let isKnowledgeBase = source.domain.lowercased().contains("knowledge") ||
                                            source.domain.isEmpty ||
                                            source.url.absoluteString == "https://balli.app"
                        return !isKnowledgeBase
                    }
                    #if DEBUG
                    if allSources.count - sources.count > 0 {
                        self.logger.debug("Filtered \(allSources.count - sources.count, privacy: .public) knowledge_base sources")
                    }
                    #endif

                    // 🔧 FIX #1: Eliminate race condition by using current answer's content directly
                    // DON'T capture content early - use the already-updated content from onToken callbacks
                    guard let index = self.answers.firstIndex(where: { $0.id == answerId }) else {
                        self.logger.error("Answer not found for ID: \(answerId)")
                        return
                    }

                    let currentAnswer = self.answers[index]
                    let finalContent = currentAnswer.content

                    // 🔍 DIAGNOSTIC: Log content length
                    self.logger.critical("🔍 [CONTENT-DEBUG] Content length: \(finalContent.count) chars")
                    self.logger.critical("🔍 [CONTENT-DEBUG] Last 300 chars: ...\(String(finalContent.suffix(300)))")

                    // 🔧 FIX: TEMPORARILY DISABLE stripSourcesSection to test if it's causing truncation
                    // If truncation still happens with this disabled, the problem is elsewhere
                    // let finalPlainText = self.stripSourcesSection(finalContent)
                    let finalPlainText = finalContent.trimmingCharacters(in: .whitespacesAndNewlines)

                    self.logger.critical("🔍 [CONTENT-DEBUG] Final content length: \(finalPlainText.count) chars (stripping DISABLED)")
                    self.logger.critical("🔍 [CONTENT-DEBUG] Last 300 chars: ...\(String(finalPlainText.suffix(300)))")

                    // Create final answer with complete data
                    // CRITICAL: Preserve taskSummary from current answer to prevent it disappearing
                    let resolvedTier = ResponseTier(tier: response.tier, processingTier: response.processingTier) ?? currentAnswer.tier

                    let finalAnswer = SearchAnswer(
                        id: answerId,
                        query: query,
                        content: finalPlainText,
                        sources: sources,
                        timestamp: Date(),
                        tokenCount: nil,
                        tier: resolvedTier,
                        thinkingSummary: response.thinkingSummary,
                        processingTierRaw: response.processingTier ?? currentAnswer.processingTierRaw,
                        completedRounds: self.completedRounds[answerId] ?? []
                    )

                    // Update in place (index already validated above)
                        self.logger.info("Streaming complete. Content: \(finalPlainText.count, privacy: .public) chars, Sources: \(sources.count, privacy: .public)")
                        #if DEBUG
                        self.logger.debug("Answer ID: \(answerId, privacy: .public)")
                        #endif

                        self.answers[index] = finalAnswer

                        // Auto-save answer to persistence
                        Task {
                            do {
                                try await self.repository.save(finalAnswer)
                                self.logger.info("✅ Persisted answer to CoreData: \(answerId)")
                            } catch {
                                self.logger.error("Failed to persist answer: \(error.localizedDescription)")
                            }
                        }

                        // 🧠 SESSION MANAGEMENT: Append assistant message to session
                        Task {
                            do {
                                try await self.sessionManager.appendAssistantMessage(from: finalAnswer)
                                self.logger.debug("🧠 Appended assistant message to session")
                            } catch {
                                self.logger.error("Failed to append assistant message to session: \(error.localizedDescription)")
                            }
                        }

                    self.searchState = .loaded(())
                    self.currentSearchTier = nil

                    // Clean up state for this answer
                    self.cancellationTokens.removeValue(forKey: answerId)
                    self.currentStages.removeValue(forKey: answerId)
                    self.shouldHoldStream.removeValue(forKey: answerId)
                    self.stageManagers.removeValue(forKey: answerId)
                }
            },
            onError: { @Sendable [weak self] error in
                Task { @MainActor in
                    guard let self = self else { return }

                    // 🔄 CANCEL: Stop buffering tokens on error
                    await self.tokenBuffer.cancel(answerId)

                    self.logger.error("Streaming error: \(error.localizedDescription, privacy: .public)")
                    self.searchState = .error(error)
                    self.currentSearchTier = nil

                    // Keep whatever content we've accumulated so far
                    if let index = self.answers.firstIndex(where: { $0.id == answerId }) {
                        let currentAnswer = self.answers[index]
                        let plainContent = currentAnswer.content

                        if !plainContent.isEmpty {
                            let finalAnswer = SearchAnswer(
                                id: answerId,
                                query: query,
                                content: plainContent,
                                sources: [],
                                timestamp: Date(),
                                tokenCount: nil
                            )
                            self.answers[index] = finalAnswer
                            self.logger.warning("Stream incomplete but preserved \(plainContent.count, privacy: .public) chars")
                        }
                    }
                }
            },
            // T3 Deep Research event handlers for storing round data
            onPlanningStarted: { @Sendable [weak self] message, sequence in
                Task { @MainActor in
                    guard let self = self else { return }
                    await self.processStageTransition(event: .planningStarted(message: message, sequence: sequence), answerId: answerId)
                }
            },
            onPlanningComplete: { @Sendable [weak self] plan, sequence in
                Task { @MainActor in
                    guard let self = self else { return }
                    self.currentPlans[answerId] = plan
                    self.logger.info("Stored research plan: \(plan.estimatedRounds) rounds")
                }
            },
            onRoundStarted: { @Sendable [weak self] round, query, estimatedSources, sequence in
                Task { @MainActor in
                    guard let self = self else { return }
                    await self.processStageTransition(event: .roundStarted(round: round, query: query, estimatedSources: estimatedSources, sequence: sequence), answerId: answerId)
                }
            },
            onRoundComplete: { @Sendable [weak self] round, sources, status, sequence in
                Task { @MainActor in
                    guard let self = self else { return }
                    await self.handleRoundComplete(round: round, sources: sources, status: status, sequence: sequence, answerId: answerId)
                }
            },
            onApiStarted: { @Sendable [weak self] api, count, message in
                Task { @MainActor in
                    guard let self = self else { return }
                    await self.processStageTransition(event: .apiStarted(api: api, count: count, message: message), answerId: answerId)
                }
            },
            onReflectionStarted: { @Sendable [weak self] round, sequence in
                Task { @MainActor in
                    guard let self = self else { return }
                    await self.processStageTransition(event: .reflectionStarted(round: round, sequence: sequence), answerId: answerId)
                }
            },
            onReflectionComplete: { @Sendable [weak self] round, reflection, sequence in
                Task { @MainActor in
                    guard let self = self else { return }
                    await self.handleReflectionComplete(round: round, reflection: reflection, sequence: sequence, answerId: answerId)
                }
            },
            onSourceSelectionStarted: { @Sendable [weak self] message, sequence in
                Task { @MainActor in
                    guard let self = self else { return }
                    await self.processStageTransition(event: .sourceSelectionStarted(message: message, sequence: sequence), answerId: answerId)
                }
            },
            onSynthesisPreparation: { @Sendable [weak self] message, sequence in
                Task { @MainActor in
                    guard let self = self else { return }
                    await self.processStageTransition(event: .synthesisPreparation(message: message, sequence: sequence), answerId: answerId)
                }
            },
            onSynthesisStarted: { @Sendable [weak self] totalRounds, totalSources, sequence in
                Task { @MainActor in
                    guard let self = self else { return }
                    await self.processStageTransition(event: .synthesisStarted(totalRounds: totalRounds, totalSources: totalSources, sequence: sequence), answerId: answerId)
                }
            }
        )
    }

    // MARK: - Multi-Round Event Handlers

    /// Handle round completion - CRITICAL EDGE CASE HANDLING
    private func handleRoundComplete(round: Int, sources: [SourceResponse], status: RoundStatus, sequence: Int, answerId: String) async {
        guard await shouldProcessEvent(sequence: sequence, answerId: answerId) else { return }

        logger.critical("🟢 ROUND \(round) COMPLETE - Sources in event: \(sources.count), status: \(status.rawValue)")

        // NOTE: Sources may arrive via separate api_completed events, so an empty sources array
        // in round_complete doesn't necessarily mean zero sources were found.
        // Only abort if status explicitly indicates failure.
        if round == 1 && sources.isEmpty && status == .failed {
            logger.critical("🔴 Round 1 failed with 0 sources - aborting research")
            // Clean up state
            cancellationTokens.removeValue(forKey: answerId)
            currentPlans.removeValue(forKey: answerId)
            completedRounds.removeValue(forKey: answerId)

            // Show error to user
            searchState = .error(ResearchSearchError.serverError(statusCode: 404)) // Will show "No sources found"
            return
        }

        // Create round data with placeholder results structure
        let roundResults = ResearchRound.RoundResults(
            exa: sources.filter { $0.type == "medical_source" }.map { SourceWithMetadata(source: $0, foundInRound: round, originalIndex: 0, deduplicatedIndex: nil) },
            pubmed: sources.filter { $0.type == "pubmed" }.map { SourceWithMetadata(source: $0, foundInRound: round, originalIndex: 0, deduplicatedIndex: nil) },
            arxiv: sources.filter { $0.type == "arxiv" }.map { SourceWithMetadata(source: $0, foundInRound: round, originalIndex: 0, deduplicatedIndex: nil) },
            clinicalTrials: sources.filter { $0.type == "clinical_trial" }.map { SourceWithMetadata(source: $0, foundInRound: round, originalIndex: 0, deduplicatedIndex: nil) }
        )

        let roundData = ResearchRound(
            roundNumber: round,
            query: "", // Will be populated by backend
            keywords: "",
            sourceMix: ResearchRound.SourceMix(
                pubmedCount: sources.filter { $0.type == "pubmed" }.count,
                arxivCount: sources.filter { $0.type == "arxiv" }.count,
                clinicalTrialsCount: sources.filter { $0.type == "clinical_trial" }.count,
                exaCount: sources.filter { $0.type == "medical_source" }.count
            ),
            results: roundResults,
            sourcesFound: sources.count,
            timings: ResearchRound.RoundTimings(
                keywordExtraction: 0,
                fetch: 0,
                total: 0
            ),
            reflection: nil,
            status: status,
            sequence: sequence
        )

        // Store round
        var rounds = completedRounds[answerId] ?? []
        rounds.append(roundData)
        completedRounds[answerId] = rounds

        // 🚀 OPTIMIZATION: Display sources immediately instead of waiting for synthesis to complete
        // Convert and add sources to the answer right away
        if !sources.isEmpty {
            if let index = self.answers.firstIndex(where: { $0.id == answerId }) {
                let currentAnswer = self.answers[index]

                // Convert new sources
                let newSources = sources.map { convertToResearchSource($0) }.filter { source in
                    // Filter out knowledge_base sources
                    let isKnowledgeBase = source.domain.lowercased().contains("knowledge") ||
                                        source.domain.isEmpty ||
                                        source.url.absoluteString == "https://balli.app"
                    return !isKnowledgeBase
                }

                // Merge with existing sources (avoid duplicates by URL)
                let existingURLs = Set(currentAnswer.sources.map { $0.url.absoluteString })
                let uniqueNewSources = newSources.filter { !existingURLs.contains($0.url.absoluteString) }
                let updatedSources = currentAnswer.sources + uniqueNewSources

                // Update answer with new sources
                let updatedAnswer = SearchAnswer(
                    id: currentAnswer.id,
                    query: currentAnswer.query,
                    content: currentAnswer.content,
                    sources: updatedSources,
                    citations: currentAnswer.citations,
                    timestamp: currentAnswer.timestamp,
                    tokenCount: currentAnswer.tokenCount,
                    tier: currentAnswer.tier,
                    thinkingSummary: currentAnswer.thinkingSummary,
                    processingTierRaw: currentAnswer.processingTierRaw
                )
                self.answers[index] = updatedAnswer

                logger.info("✨ Added \(uniqueNewSources.count) new sources from round \(round) (total now: \(updatedSources.count))")
            }
        }

        logger.critical("🟢 ROUND \(round) COMPLETE - Stored \(sources.count) sources, waiting 0.3s before reflection")

        // Small delay to let fetching state breathe before reflection
        try? await Task.sleep(for: .seconds(0.3))
    }

    /// Handle reflection completion
    private func handleReflectionComplete(round: Int, reflection: ResearchReflection, sequence: Int, answerId: String) async {
        guard await shouldProcessEvent(sequence: sequence, answerId: answerId) else { return }

        logger.critical("🟢 REFLECTION \(round) COMPLETE - quality: \(reflection.evidenceQuality.rawValue), shouldContinue: \(reflection.shouldContinue)")

        // CANCEL TIMEOUT
        cancelReflectionTimeout(for: answerId)

        // Update round with reflection (create new struct since ResearchRound is immutable)
        var rounds = completedRounds[answerId] ?? []
        if let index = rounds.firstIndex(where: { $0.roundNumber == round }) {
            let oldRound = rounds[index]
            let updatedRound = ResearchRound(
                roundNumber: oldRound.roundNumber,
                query: oldRound.query,
                keywords: oldRound.keywords,
                sourceMix: oldRound.sourceMix,
                results: oldRound.results,
                sourcesFound: oldRound.sourcesFound,
                timings: oldRound.timings,
                reflection: reflection,
                status: .complete,
                sequence: oldRound.sequence
            )
            rounds[index] = updatedRound
            completedRounds[answerId] = rounds
        }

        // Log reasoning
        logger.debug("Reflection reasoning: \(reflection.reasoning)")
    }

    // MARK: - Helper Methods

    /// Process stage transition from SSE event
    private func processStageTransition(event: ResearchSSEEvent, answerId: String) async {
        // Get or create stage manager for this answer
        let manager = stageManagers[answerId] ?? ResearchStageDisplayManager()
        stageManagers[answerId] = manager

        // Map event to stage
        guard let newStage = manager.mapEventToStage(event) else {
            return // Event doesn't map to a stage change
        }

        // 🎯 SYNTHESIS STAGE TIMING FIX: Split time between gathering and writing stages
        // User wants to see BOTH stages before stream appears
        // Solution: When gatheringInfo arrives, show it for HALF the normal time,
        // then auto-switch to writingReport for the other half

        if newStage == .gatheringInfo {
            // Hold stream during BOTH synthesis stages
            shouldHoldStream[answerId] = true
            logger.info("🚫 Stream display HELD - starting synthesis sequence")

            // Show "Bilgileri bir araya getiriyorum" for 1.0 seconds
            currentStages[answerId] = "Bilgileri bir araya getiriyorum"
            logger.info("📊 Stage 1/2: Bilgileri bir araya getiriyorum (1.0s)")
            try? await Task.sleep(for: .seconds(1.0))

            // Auto-switch to "Kapsamlı bir rapor yazıyorum" and keep it visible
            // The stage will stay visible until the first token arrives and triggers fade
            currentStages[answerId] = "Kapsamlı bir rapor yazıyorum"
            logger.info("📊 Stage 2/2: Kapsamlı bir rapor yazıyorum (staying until first token arrives)")

            // DON'T fade out here - the onToken callback will fade it out when the first token arrives!
            // This ensures the progress card stays visible until content is actually ready
            logger.info("⏳ Waiting for first token to trigger fade & release...")

            // Don't process stage transition normally - we handled it above
            return
        }

        // For writingReport event (if it arrives), just ignore it since we already handled it
        if newStage == .writingReport {
            logger.info("⏩ Skipping writingReport event - already handled in gatheringInfo")
            return
        }

        // Normal stage transition for all other stages
        await manager.transitionToStage(newStage)
        currentStages[answerId] = manager.stageMessage
    }

    /// Check if event should be processed (deduplication + cancellation check)
    private func shouldProcessEvent(sequence: Int, answerId: String) async -> Bool {
        // Check cancellation token
        guard cancellationTokens[answerId] != nil else {
            logger.debug("No cancellation token for answer \(answerId) - stale event")
            return false
        }

        // Check event deduplication
        let eventId = SSEEventTracker.generateEventId(type: "event", sequence: sequence)
        if await eventTracker.hasProcessed(eventId: eventId) {
            logger.debug("Duplicate event \(sequence) - skipping")
            return false
        }

        await eventTracker.markProcessed(eventId: eventId)
        return true
    }

    /// Cancel reflection timeout
    private func cancelReflectionTimeout(for answerId: String) {
        reflectionTimeouts[answerId]?.cancel()
        reflectionTimeouts.removeValue(forKey: answerId)
    }

    /// Convert Cloud Function source to app Source model
    private func convertToResearchSource(_ response: SourceResponse) -> ResearchSource {
        // Map credibility badge
        let badge: ResearchSource.CredibilityType = switch response.credibilityBadge {
        case .medicalSource:
            .medicalSource
        case .peerReviewed:
            .peerReviewed
        case .clinicalTrial:
            .peerReviewed // Map clinical trial to peer reviewed
        case .expert:
            .medicalSource // Map expert to medical source
        }

        // Handle sources without URLs (like knowledge_base type)
        // Provide fallback URL if URL parsing fails (shouldn't happen in practice)
        let sourceURL: URL
        if let parsedURL = URL(string: response.url) {
            sourceURL = parsedURL
        } else if let fallbackURL = URL(string: "https://balli.app") {
            sourceURL = fallbackURL
            logger.warning("Failed to create URL from: \(response.url, privacy: .public), using fallback")
        } else {
            // Last resort: create a safe placeholder URL
            // This should never happen as "https://balli.app" is a valid URL
            logger.error("Critical: Failed to create any valid URL for source: \(response.url, privacy: .public)")
            return ResearchSource(
                id: response.id,
                url: URL(fileURLWithPath: "/"), // Safe system URL
                domain: response.domain,
                title: response.title,
                snippet: response.snippet,
                publishDate: parseDate(response.publishDate),
                author: response.author,
                credibilityBadge: badge,
                faviconURL: nil
            )
        }

        return ResearchSource(
            id: response.id,
            url: sourceURL,
            domain: response.domain,
            title: response.title,
            snippet: response.snippet,
            publishDate: parseDate(response.publishDate),
            author: response.author,
            credibilityBadge: badge,
            faviconURL: ResearchSource.generateFaviconURL(from: sourceURL)
        )
    }

    /// Parse date string from Cloud Function
    private func parseDate(_ dateString: String?) -> Date? {
        guard let dateString = dateString else { return nil }

        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString) {
            return date
        }

        // Try simple date format (YYYY-MM-DD)
        let simpleDateFormatter = DateFormatter()
        simpleDateFormatter.dateFormat = "yyyy-MM-dd"
        return simpleDateFormatter.date(from: dateString)
    }

    /// Strip "Kaynaklar" (sources) section from answer content
    /// Sources are already displayed as pills in the UI
    /// PRECISION FIX: Only matches sources sections at ABSOLUTE END of content with strict formatting
    private func stripSourcesSection(_ content: String) -> String {
        let originalLength = content.count

        // HYPER-PRECISE patterns that ONLY match sources sections at the VERY END:
        // Requirements:
        // 1. Must be in last 20% of content (not 30% - be even stricter)
        // 2. Must have specific "Kaynaklar" header formatting
        // 3. Must be followed by MULTIPLE list items with URLs/links
        // 4. Must match ALL THE WAY to end of string ($)

        let patterns = [
            // Markdown heading + multiple numbered items with URLs: ## Kaynaklar\n1. http...\n2. http...
            // Requires at least 2 list items to qualify as a sources section
            "\n\n##+ *(?:Kaynaklar|Sources):?\\s*\n(?:\\d+\\.\\s*(?:https?://|\\[).{10,}?\\n){2,}.*$",

            // Bold heading + multiple items: **Kaynaklar**\n1. [...]\n2. [...]
            "\n\n\\*\\*(?:Kaynaklar|Sources)\\*\\*:?\\s*\n(?:\\d+\\.\\s*(?:https?://|\\[).{10,}?\\n){2,}.*$",

            // Horizontal rule + heading + items: ---\n## Kaynaklar\n1. ...\n2. ...
            "\n\n---+\\s*\n##+ *(?:Kaynaklar|Sources):?\\s*\n(?:\\d+\\.\\s*(?:https?://|\\[).{10,}?\\n){2,}.*$"
        ]

        var result = content

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) {
                let nsRange = NSRange(result.startIndex..., in: result)
                let matches = regex.matches(in: result, range: nsRange)

                // Only strip if match is in last 20% of content (stricter than before)
                if let match = matches.last {
                    let matchStart = match.range.location
                    let contentLength = result.count
                    let matchPosition = Double(matchStart) / Double(contentLength)

                    // STRICTER THRESHOLD: Only strip if match is in last 20% of content
                    if matchPosition > 0.80 {
                        let strippedResult = regex.stringByReplacingMatches(in: result, range: nsRange, withTemplate: "")

                        // STRICTER SAFETY CHECK: If stripping would remove more than 25% of content, DON'T DO IT
                        let strippedLength = strippedResult.count
                        let contentLoss = Double(originalLength - strippedLength) / Double(originalLength)

                        if contentLoss > 0.25 {
                            logger.warning("🚨 SAFETY ABORT: Stripping would remove \(Int(contentLoss * 100))% of content - keeping original")
                            logger.debug("Original: \(originalLength) chars, After strip: \(strippedLength) chars")
                            return content.trimmingCharacters(in: .whitespacesAndNewlines)
                        }

                        result = strippedResult
                        logger.debug("Stripped sources section at position \(Int(matchPosition * 100))% (removed \(Int(contentLoss * 100))% of content)")
                        break // Only strip once
                    } else {
                        logger.debug("Skipped stripping - 'Kaynaklar' found at \(Int(matchPosition * 100))% (too early, likely part of answer)")
                    }
                }
            }
        }

        // If no pattern matched, check for simple trailing sources section
        // Final safety: look for "\n\n## Kaynaklar" or "\n\n**Kaynaklar**" in last 100 chars
        if result == content && result.count > 100 {
            let trailer = String(result.suffix(100))
            if trailer.contains("## Kaynaklar") || trailer.contains("**Kaynaklar**") || trailer.contains("## Sources") {
                // Find the last occurrence
                if let range = result.range(of: "\n\n## Kaynaklar", options: .backwards) ??
                              result.range(of: "\n\n**Kaynaklar**", options: .backwards) ??
                              result.range(of: "\n\n## Sources", options: .backwards) {
                    let beforeSection = String(result[..<range.lowerBound])
                    let sectionSize = result.count - beforeSection.count
                    let contentLoss = Double(sectionSize) / Double(originalLength)

                    // Only strip if section is small (< 15% of content)
                    if contentLoss < 0.15 {
                        result = beforeSection
                        logger.debug("Stripped trailing Kaynaklar section (\(Int(contentLoss * 100))% of content)")
                    }
                }
            }
        }

        // Trim trailing whitespace
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Predict tier based on query complexity and keywords
    /// Shows "Derin Araştırma" upfront for queries likely to be Pro tier
    private func predictTier(for query: String) -> ResponseTier? {
        let lowercaseQuery = query.lowercased()

        // Pro tier indicators (medical decisions, treatments, complex questions)
        let proKeywords = [
            "tedavi", "treatment", "ilaç", "medication", "insülin değiştir",
            "geçmeli miyim", "should i switch", "yan etki", "side effect",
            "komplikasyon", "complication", "araştırma", "research",
            "çalışma", "study", "kanıt", "evidence", "karşılaştır", "compare",
            "fark", "difference", "hangisi daha iyi", "which is better",
            "risk", "tehlike", "danger", "güvenli mi", "is it safe",
            "ameliyat", "surgery", "transplant", "transplantasyon",
            "klinik", "clinical", "deneme", "trial"
        ]

        // Check for Pro tier keywords
        let hasProKeyword = proKeywords.contains { lowercaseQuery.contains($0) }

        // Check query length (longer queries often need comprehensive research)
        let isLongQuery = query.count > 60

        // Check for question words that indicate decision-making
        let hasDecisionQuestion = lowercaseQuery.contains("meli") || // "geçmeli", "kullanmalı"
                                  lowercaseQuery.contains("should") ||
                                  lowercaseQuery.contains("hangisi") ||
                                  lowercaseQuery.contains("which")

        // TEMPORARILY DISABLED: Deep Research (T3) tier
        // TODO: Re-enable after fixing deep research issues
        // Predict Research tier (T3) if:
        // - Has Pro keyword + decision question, OR
        // - Has Pro keyword + long query
        // if (hasProKeyword && hasDecisionQuestion) || (hasProKeyword && isLongQuery) {
        //     return .research
        // }

        // Default to Model tier (T1/T2 only - T3 disabled)
        return nil
    }

    // MARK: - History Management

    /// Clear all answers and start fresh
    func clearHistory() async {
        answers.removeAll()
        answerIndexLookup.removeAll() // PERFORMANCE: Clear O(1) lookup dictionary

        do {
            try await repository.deleteAll()
            logger.info("✅ Cleared all history from memory and persistence")
        } catch {
            logger.error("Failed to clear persisted history: \(error.localizedDescription)")
        }
    }

    /// Sync all in-memory answers to CoreData persistence
    /// Called when app backgrounds to ensure research is saved if app is killed
    private func syncAnswersToPersistence() async {
        guard !self.answers.isEmpty else {
            logger.debug("No answers to sync to persistence")
            return
        }

        logger.info("🔄 Syncing \(self.answers.count) answers to persistence")

        for answer in self.answers {
            // Skip placeholder answers (no content yet)
            guard !answer.content.isEmpty else {
                logger.debug("Skipping placeholder answer: \(answer.id)")
                continue
            }

            do {
                try await repository.save(answer)
                logger.debug("✅ Synced answer to persistence: \(answer.id)")
            } catch {
                logger.error("❌ Failed to sync answer \(answer.id): \(error.localizedDescription)")
            }
        }

        logger.info("✅ Sync to persistence complete")
    }

    /// Start a new conversation - saves current answers to library and clears the view
    func startNewConversation() async {
        logger.info("💬 Starting new conversation - saving current conversation to library")

        // Save current conversation before clearing
        await syncAnswersToPersistence()

        // End current session (persists to SwiftData with metadata)
        await endCurrentSession()

        // Clear in-memory state for fresh conversation
        answers.removeAll()
        answerIndexLookup.removeAll()

        // Start fresh session
        sessionManager.startNewSession()

        logger.info("✅ New conversation started - previous conversation saved to library")
    }

    /// Cancel streaming response for the currently active search
    /// Tokens generated before cancellation are preserved
    func cancelCurrentSearch() {
        guard let currentAnswer = answers.first, currentAnswer.content.isEmpty || isSearching else {
            logger.debug("No active search to cancel")
            return
        }

        let answerId = currentAnswer.id

        // Remove cancellation token to stop processing new events
        cancellationTokens.removeValue(forKey: answerId)

        logger.info("⏹️ Stream cancelled for answer \(answerId, privacy: .public)")
        logger.info("📝 Preserved content: \(currentAnswer.content.count, privacy: .public) chars")

        // Mark search as complete (stops the search indicator)
        searchState = .idle
        currentSearchTier = nil

        // Clean up associated state
        currentStages.removeValue(forKey: answerId)
        shouldHoldStream.removeValue(forKey: answerId)
        stageManagers.removeValue(forKey: answerId)

        // Preserve the accumulated content and save it
        Task {
            if let index = answers.firstIndex(where: { $0.id == answerId }) {
                let answer = answers[index]
                if !answer.content.isEmpty {
                    // Save the partial answer to persistence
                    do {
                        try await repository.save(answer)
                        logger.info("✅ Persisted cancelled answer: \(answerId, privacy: .public)")
                    } catch {
                        logger.error("Failed to persist cancelled answer: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    /// Submit feedback for an answer
    func submitFeedback(rating: String, answer: SearchAnswer) async {
        logger.info("Submitting \(rating, privacy: .public) feedback for message: \(answer.id, privacy: .public)")

        do {
            // Convert answer sources to SourceResponse format
            let sources = answer.sources.compactMap { source -> SourceResponse? in
                guard let credibilityType = source.credibilityBadge,
                      let credibilityBadge = mapCredibilityType(credibilityType) else {
                    return nil
                }

                // Map credibility badge to type string
                let type: String = switch credibilityBadge {
                case .peerReviewed: "pubmed"
                case .medicalSource: "medical_source"
                case .clinicalTrial: "clinical_trial"
                case .expert: "knowledge_base"
                }

                return SourceResponse(
                    id: source.id,
                    url: source.url.absoluteString,
                    domain: source.domain,
                    title: source.title,
                    snippet: source.snippet ?? "",
                    publishDate: source.publishDate?.formatted(),
                    author: source.author,
                    credibilityBadge: credibilityBadge,
                    type: type
                )
            }

            try await searchService.submitFeedback(
                messageId: answer.id,
                prompt: answer.query,
                response: answer.content,
                sources: sources,
                tier: answer.tier?.rawValue,
                rating: rating
            )

            logger.info("Feedback submitted successfully")
        } catch {
            logger.error("Failed to submit feedback: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Recall from Past Research

    /// Determines if query should attempt recall from past sessions
    /// Uses simple heuristics for Turkish past-tense patterns
    private func shouldAttemptRecall(_ query: String) async -> Bool {
        let lowercased = query.lowercased()

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

    /// Handles recall request by searching completed sessions and displaying results
    private func handleRecallRequest(_ query: String) async {
        logger.info("📚 Handling recall request: \(query)")

        // Create placeholder answer with recall tier
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
                await handleNoRecallMatches(answerId, query: query)
            } else if searchResults.count == 1 || isStrongMatch(searchResults) {
                // Single strong match - get full answer
                await handleSingleRecallMatch(answerId, query: query, result: searchResults[0])
            } else {
                // Multiple matches - ask user to clarify
                await handleMultipleRecallMatches(answerId, query: query, results: searchResults)
            }

        } catch {
            logger.error("📚 Recall search failed: \(error.localizedDescription)")
            searchState = .error(error)
        }
    }

    /// Checks if first result is significantly better than others
    private func isStrongMatch(_ results: [RecallSearchResult]) -> Bool {
        guard results.count > 1 else { return true }

        let first = results[0].relevanceScore
        let second = results[1].relevanceScore

        // First result is "strong" if it's at least 15% better than second
        return (first - second) >= 0.15
    }

    /// Handles case where no past sessions match the query
    private func handleNoRecallMatches(_ answerId: String, query: String) async {
        guard let index = answerIndexLookup[answerId] else { return }

        let message = "Bu konuda daha önce bir araştırma kaydı bulamadım. Şimdi araştırayım mı?"

        let finalAnswer = SearchAnswer(
            id: answerId,
            query: query,
            content: message,
            sources: [],
            timestamp: Date(),
            tokenCount: nil,
            tier: .recall
        )

        answers[index] = finalAnswer
        searchState = .loaded(())

        logger.info("📚 No recall matches - suggesting new research")
    }

    /// Handles single strong recall match - calls backend for full LLM answer
    private func handleSingleRecallMatch(_ answerId: String, query: String, result: RecallSearchResult) async {
        guard let index = answerIndexLookup[answerId] else { return }

        let formattedDate = formatRecallDate(result.createdAt)
        let title = result.title ?? "Araştırma Oturumu"

        // Show loading state with session info
        let loadingMessage = """
        📚 **Geçmiş Araştırma Bulundu**

        **\(title)**
        📅 Tarih: \(formattedDate)

        Cevap oluşturuluyor...
        """

        let loadingAnswer = SearchAnswer(
            id: answerId,
            query: query,
            content: loadingMessage,
            sources: [],
            timestamp: Date(),
            tokenCount: nil,
            tier: .recall
        )

        answers[index] = loadingAnswer

        // Get full conversation history from SwiftData
        do {
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
                    tier: .recall
                )

                answers[index] = finalAnswer
                searchState = .loaded(())

                logger.info("📚 Displayed LLM-generated recall answer from: \(sessionRef.title)")
            } else {
                throw RecallServiceError.invalidResponse
            }

        } catch {
            logger.error("📚 Failed to generate recall answer: \(error.localizedDescription)")

            // Fallback to basic session info
            let errorMessage = """
            📚 **Geçmiş Araştırma Bulundu**

            **\(title)**
            📅 Tarih: \(formattedDate)

            Bu konuyu daha önce araştırmıştın (uygunluk: %\(Int(result.relevanceScore * 100))).

            *Cevap oluşturulamadı: \(error.localizedDescription)*
            """

            let fallbackAnswer = SearchAnswer(
                id: answerId,
                query: query,
                content: errorMessage,
                sources: [],
                timestamp: Date(),
                tokenCount: nil,
                tier: .recall
            )

            answers[index] = fallbackAnswer
            searchState = .loaded(())
        }
    }

    /// Handles multiple recall matches
    private func handleMultipleRecallMatches(_ answerId: String, query: String, results: [RecallSearchResult]) async {
        guard let index = answerIndexLookup[answerId] else { return }

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
            tier: .recall
        )

        answers[index] = finalAnswer
        searchState = .loaded(())

        logger.info("📚 Displayed \(results.count) recall matches")
    }

    /// Formats date for recall display
    private func formatRecallDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    /// Map Source.CredibilityType to CredibilityBadge
    private func mapCredibilityType(_ type: ResearchSource.CredibilityType) -> CredibilityBadge? {
        switch type {
        case .peerReviewed:
            return .peerReviewed
        case .medicalSource:
            return .medicalSource
        case .majorNews:
            return .medicalSource // Map major news to medical source
        case .government:
            return .medicalSource // Map government to medical source
        case .academic:
            return .peerReviewed // Map academic to peer reviewed
        }
    }
}

