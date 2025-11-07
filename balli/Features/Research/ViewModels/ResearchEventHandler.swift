//
//  ResearchEventHandler.swift
//  balli
//
//  Handles all streaming event processing for medical research
//  Extracted from MedicalResearchViewModel for single responsibility
//

import Foundation
import SwiftUI
import OSLog

/// Handles all streaming events from research operations
/// This class receives state accessors and mutation callbacks from MedicalResearchViewModel
@MainActor
final class ResearchEventHandler {
    private let logger = AppLoggers.Research.search

    // Dependencies
    private let tokenBuffer: TokenBuffer
    private let tokenSmoother: TokenSmoother
    private let streamProcessor: ResearchStreamProcessor
    private let stageCoordinator: ResearchStageCoordinator
    private let searchCoordinator: ResearchSearchCoordinator
    private let persistenceManager: ResearchPersistenceManager
    private let sessionManager: ResearchSessionManager

    init(
        tokenBuffer: TokenBuffer,
        tokenSmoother: TokenSmoother,
        streamProcessor: ResearchStreamProcessor,
        stageCoordinator: ResearchStageCoordinator,
        searchCoordinator: ResearchSearchCoordinator,
        persistenceManager: ResearchPersistenceManager,
        sessionManager: ResearchSessionManager
    ) {
        self.tokenBuffer = tokenBuffer
        self.tokenSmoother = tokenSmoother
        self.streamProcessor = streamProcessor
        self.stageCoordinator = stageCoordinator
        self.searchCoordinator = searchCoordinator
        self.persistenceManager = persistenceManager
        self.sessionManager = sessionManager
    }

    // MARK: - Standard Event Handlers

    func handleToken(
        _ token: String,
        answerId: String,
        getAnswers: @escaping () -> [SearchAnswer],
        getAnswerIndex: @escaping (String) -> Int?,
        getFirstTokenProcessed: @escaping () -> Set<String>,
        updateAnswer: @escaping (Int, SearchAnswer, Bool) -> Void,
        markFirstTokenProcessed: @escaping (String) -> Void
    ) async {
        nonisolated(unsafe) let capturedGetAnswers = getAnswers
        nonisolated(unsafe) let capturedGetAnswerIndex = getAnswerIndex
        nonisolated(unsafe) let capturedGetFirstTokenProcessed = getFirstTokenProcessed
        nonisolated(unsafe) let capturedUpdateAnswer = updateAnswer
        nonisolated(unsafe) let capturedMarkFirstToken = markFirstTokenProcessed

        // Direct streaming without animation layers
        await MainActor.run {
            guard let index = capturedGetAnswerIndex(answerId) else { return }

            let currentAnswer = capturedGetAnswers()[index]
            let firstTokenProcessed = capturedGetFirstTokenProcessed()

            // Handle first token arrival
            if currentAnswer.content.isEmpty && !firstTokenProcessed.contains(answerId) {
                capturedMarkFirstToken(answerId)
                Task {
                    await self.stageCoordinator.handleFirstTokenArrival(answerId: answerId)
                }
            }

            // Update answer with new token appended directly
            let updatedAnswer = SearchAnswer(
                id: currentAnswer.id,
                query: currentAnswer.query,
                content: currentAnswer.content + token,  // Direct append, no animation
                sources: currentAnswer.sources,
                citations: currentAnswer.citations,
                timestamp: currentAnswer.timestamp,
                tokenCount: currentAnswer.tokenCount,
                tier: currentAnswer.tier,
                thinkingSummary: currentAnswer.thinkingSummary,
                processingTierRaw: currentAnswer.processingTierRaw,
                completedRounds: currentAnswer.completedRounds,
                imageAttachment: currentAnswer.imageAttachment
            )

            capturedUpdateAnswer(index, updatedAnswer, currentAnswer.content.isEmpty)
        }
    }

    func handleTierSelected(
        _ tier: String,
        answerId: String,
        getAnswers: @escaping () -> [SearchAnswer],
        updateAnswer: @escaping (Int, SearchAnswer) -> Void,
        setCurrentTier: @escaping (ResponseTier?) -> Void
    ) async {
        let answers = getAnswers()
        guard let index = answers.firstIndex(where: { $0.id == answerId }) else { return }

        let currentAnswer = answers[index]
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
            processingTierRaw: resolvedTier?.rawValue ?? currentAnswer.processingTierRaw,
            completedRounds: currentAnswer.completedRounds,
            imageAttachment: currentAnswer.imageAttachment
        )

        updateAnswer(index, updatedAnswer)
        setCurrentTier(resolvedTier)
        logger.notice("Tier updated to: \(tier, privacy: .public)")
    }

    func handleSearchComplete(
        count: Int,
        source: String,
        answerId: String,
        setSearchingSource: @escaping (String, Bool) -> Void
    ) async {
        logger.info("Search complete: \(count, privacy: .public) results from \(source, privacy: .public)")

        if source.lowercased().contains("knowledge") || source == "knowledge_base" {
            setSearchingSource(answerId, false)
            return
        }

        setSearchingSource(answerId, true)
    }

    func handleSourcesReady(
        _ sources: [SourceResponse],
        answerId: String,
        getAnswers: @escaping () -> [SearchAnswer],
        updateAnswer: @escaping (Int, SearchAnswer) -> Void,
        setSearchingSource: @escaping (String, Bool) -> Void
    ) async {
        logger.info("🎯 Sources ready: \(sources.count, privacy: .public) sources received")

        let answers = getAnswers()
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
            processingTierRaw: currentAnswer.processingTierRaw,
            completedRounds: currentAnswer.completedRounds,
            imageAttachment: currentAnswer.imageAttachment
        )

        updateAnswer(index, updatedAnswer)
        setSearchingSource(answerId, false)
    }

    func handleComplete(
        _ response: ResearchSearchResponse,
        query: String,
        answerId: String,
        getAnswers: @escaping () -> [SearchAnswer],
        updateAnswer: @escaping (Int, SearchAnswer) -> Void,
        setSearchState: @escaping (ViewState<Void>) -> Void,
        setCurrentTier: @escaping (ResponseTier?) -> Void
    ) async {
        // Capture closures for @Sendable context
        nonisolated(unsafe) let capturedGetAnswers = getAnswers
        nonisolated(unsafe) let capturedUpdateAnswer = updateAnswer

        // No animation layers to flush - content already complete from direct streaming

        let answers = getAnswers()
        guard let index = answers.firstIndex(where: { $0.id == answerId }) else { return }

        setCurrentTier(ResponseTier(tier: response.tier, processingTier: response.processingTier))

        // Filter sources
        let allSources = response.sourcesFormatted.map { searchCoordinator.convertToResearchSource($0) }
        let sources = allSources.filter { source in
            let isKnowledgeBase = source.domain.lowercased().contains("knowledge") ||
                                source.domain.isEmpty ||
                                source.url.absoluteString == "https://balli.app"
            return !isKnowledgeBase
        }

        let currentAnswer = answers[index]
        let finalContent = currentAnswer.content.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedTier = ResponseTier(tier: response.tier, processingTier: response.processingTier) ?? currentAnswer.tier

        // FIX: Preserve sources from sourcesReady event if complete response has no sources
        // This handles T2 race condition where sourcesReady arrives before complete
        if sources.isEmpty && !currentAnswer.sources.isEmpty {
            logger.info("📊 [COMPLETE] Preserving \(currentAnswer.sources.count) sources from sourcesReady (complete had none)")
        } else if !sources.isEmpty {
            logger.info("📊 [COMPLETE] Using \(sources.count) sources from complete event")
        }

        let finalAnswer = SearchAnswer(
            id: answerId,
            query: query,
            content: finalContent,
            sources: sources.isEmpty ? currentAnswer.sources : sources,  // Preserve sources from sourcesReady if complete has none
            timestamp: Date(),
            tokenCount: nil,
            tier: resolvedTier,
            thinkingSummary: response.thinkingSummary,
            processingTierRaw: response.processingTier ?? currentAnswer.processingTierRaw,
            completedRounds: stageCoordinator.getCompletedRounds(for: answerId),
            imageAttachment: currentAnswer.imageAttachment
        )

        updateAnswer(index, finalAnswer)

        // Save to persistence
        Task {
            do {
                try await persistenceManager.saveAnswer(finalAnswer)
                try await sessionManager.appendAssistantMessage(from: finalAnswer)
            } catch {
                logger.error("Failed to persist answer: \(error.localizedDescription)")
            }
        }

        setSearchState(.loaded(()))
        setCurrentTier(nil)

        streamProcessor.cleanupSearchState(for: answerId)
        stageCoordinator.cleanupSearchState(for: answerId)
    }

    func handleError(
        _ error: Error,
        query: String,
        answerId: String,
        getAnswers: @escaping () -> [SearchAnswer],
        updateAnswer: @escaping (Int, SearchAnswer) -> Void,
        setSearchState: @escaping (ViewState<Void>) -> Void,
        setCurrentTier: @escaping (ResponseTier?) -> Void
    ) async {
        // No animation layers to cancel - using direct streaming

        logger.error("Streaming error: \(error.localizedDescription, privacy: .public)")
        setSearchState(.error(error))
        setCurrentTier(nil)

        let answers = getAnswers()
        guard let index = answers.firstIndex(where: { $0.id == answerId }) else { return }

        let currentAnswer = answers[index]
        if !currentAnswer.content.isEmpty {
            let finalAnswer = SearchAnswer(
                id: answerId,
                query: query,
                content: currentAnswer.content,
                sources: [],
                timestamp: Date(),
                tokenCount: nil,
                imageAttachment: currentAnswer.imageAttachment
            )
            updateAnswer(index, finalAnswer)
            logger.warning("Stream incomplete but preserved \(currentAnswer.content.count, privacy: .public) chars")
        }
    }

    // MARK: - Multi-Round Event Handlers

    func handlePlanningStarted(message: String, sequence: Int, answerId: String) async {
        await stageCoordinator.processStageTransition(
            event: .planningStarted(message: message, sequence: sequence),
            answerId: answerId
        )
    }

    func handlePlanningComplete(plan: ResearchPlan, answerId: String) async {
        stageCoordinator.storePlan(plan, for: answerId)
    }

    func handleRoundStarted(round: Int, query: String, estimatedSources: Int, sequence: Int, answerId: String) async {
        await stageCoordinator.processStageTransition(
            event: .roundStarted(round: round, query: query, estimatedSources: estimatedSources, sequence: sequence),
            answerId: answerId
        )
    }

    func handleRoundComplete(
        round: Int,
        sources: [SourceResponse],
        status: RoundStatus,
        sequence: Int,
        answerId: String,
        getAnswer: @escaping (String) -> SearchAnswer?,
        updateAnswer: @escaping (Int, SearchAnswer) -> Void,
        setSearchState: @escaping (ViewState<Void>) -> Void,
        getAnswerIndex: @escaping (String) -> Int?
    ) async {
        guard let currentAnswer = getAnswer(answerId),
              let index = getAnswerIndex(answerId) else { return }

        if let roundData = await streamProcessor.handleRoundComplete(
            round: round,
            sources: sources,
            status: status,
            sequence: sequence,
            answerId: answerId,
            currentAnswer: currentAnswer,
            convertSource: { self.searchCoordinator.convertToResearchSource($0) },
            onUpdate: { updatedAnswer in
                updateAnswer(index, updatedAnswer)
            },
            onError: { [weak self] error in
                guard let self = self else { return }
                setSearchState(.error(error))
                self.streamProcessor.cleanupSearchState(for: answerId)
                self.stageCoordinator.cleanupSearchState(for: answerId)
            }
        ) {
            stageCoordinator.addCompletedRound(roundData, for: answerId)
        }
    }

    func handleApiStarted(api: String, message: String, answerId: String) async {
        let researchAPI = ResearchAPI(rawValue: api) ?? .exa
        await stageCoordinator.processStageTransition(
            event: .apiStarted(api: researchAPI, count: 0, message: message),
            answerId: answerId
        )
    }

    func handleReflectionStarted(round: Int, sequence: Int, answerId: String) async {
        await stageCoordinator.processStageTransition(
            event: .reflectionStarted(round: round, sequence: sequence),
            answerId: answerId
        )
    }

    func handleReflectionComplete(round: Int, reflection: ResearchReflection, sequence: Int, answerId: String) async {
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

    func handleSourceSelectionStarted(message: String, sequence: Int, answerId: String) async {
        await stageCoordinator.processStageTransition(
            event: .sourceSelectionStarted(message: message, sequence: sequence),
            answerId: answerId
        )
    }

    func handleSynthesisPreparation(message: String, sequence: Int, answerId: String) async {
        await stageCoordinator.processStageTransition(
            event: .synthesisPreparation(message: message, sequence: sequence),
            answerId: answerId
        )
    }

    func handleSynthesisStarted(totalRounds: Int, totalSources: Int, sequence: Int, answerId: String) async {
        await stageCoordinator.processStageTransition(
            event: .synthesisStarted(totalRounds: totalRounds, totalSources: totalSources, sequence: sequence),
            answerId: answerId
        )
    }
}
