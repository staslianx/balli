//
//  ResearchStreamProcessor.swift
//  balli
//
//  Handles SSE event processing, round completion, and token streaming
//  Split from MedicalResearchViewModel for better organization
//  Swift 6 strict concurrency compliant
//

import Foundation
import SwiftUI
import OSLog

/// Processes streaming events from research API
@MainActor
final class ResearchStreamProcessor {
    // MARK: - Properties

    private let logger = AppLoggers.Research.search
    private let streamingLogger = AppLoggers.Research.streaming

    /// Actor for SSE event deduplication
    private let eventTracker = SSEEventTracker()

    /// Cancellation tokens for filtering stale events (answerId -> UUID)
    private var cancellationTokens: [String: UUID] = [:]

    /// Reflection timeout tasks (answerId -> Task)
    private var reflectionTimeouts: [String: Task<Void, Never>] = [:]

    // MARK: - Cancellation Management

    /// Initialize cancellation token for a new search
    func initializeCancellationToken(for answerId: String) -> UUID {
        let token = UUID()
        cancellationTokens[answerId] = token
        return token
    }

    /// Remove cancellation token (stops processing events for this answer)
    func cancelSearch(for answerId: String) {
        cancellationTokens.removeValue(forKey: answerId)
        logger.info("⏹️ Stream cancelled for answer \(answerId, privacy: .public)")
    }

    /// Reset event tracker for new search
    func resetEventTracker() async {
        await eventTracker.reset()
    }

    /// Cleanup state for completed search
    func cleanupSearchState(for answerId: String) {
        cancellationTokens.removeValue(forKey: answerId)
        cancelReflectionTimeout(for: answerId)
    }

    // MARK: - Event Processing

    /// Check if event should be processed (deduplication + cancellation check)
    func shouldProcessEvent(sequence: Int, answerId: String) async -> Bool {
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

    // MARK: - Round Handling

    /// Handle round completion - CRITICAL EDGE CASE HANDLING
    func handleRoundComplete(
        round: Int,
        sources: [SourceResponse],
        status: RoundStatus,
        sequence: Int,
        answerId: String,
        currentAnswer: SearchAnswer,
        convertSource: (SourceResponse) -> ResearchSource,
        onUpdate: (SearchAnswer) -> Void,
        onError: (Error) -> Void
    ) async -> ResearchRound? {
        guard await shouldProcessEvent(sequence: sequence, answerId: answerId) else { return nil }

        logger.critical("🟢 ROUND \(round) COMPLETE - Sources in event: \(sources.count), status: \(status.rawValue)")

        // NOTE: Sources may arrive via separate api_completed events, so an empty sources array
        // in round_complete doesn't necessarily mean zero sources were found.
        // Only abort if status explicitly indicates failure.
        if round == 1 && sources.isEmpty && status == .failed {
            logger.critical("🔴 Round 1 failed with 0 sources - aborting research")
            onError(ResearchSearchError.serverError(statusCode: 404))
            return nil
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

        // 🚀 OPTIMIZATION: Display sources immediately instead of waiting for synthesis to complete
        // Convert and add sources to the answer right away
        if !sources.isEmpty {
            // Convert new sources
            let newSources = sources.map { convertSource($0) }.filter { source in
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
            onUpdate(updatedAnswer)

            logger.info("✨ Added \(uniqueNewSources.count) new sources from round \(round) (total now: \(updatedSources.count))")
        }

        logger.critical("🟢 ROUND \(round) COMPLETE - Stored \(sources.count) sources, waiting 0.3s before reflection")

        // Small delay to let fetching state breathe before reflection
        try? await Task.sleep(for: .seconds(0.3))

        return roundData
    }

    /// Handle reflection completion
    func handleReflectionComplete(
        round: Int,
        reflection: ResearchReflection,
        sequence: Int,
        answerId: String,
        rounds: [ResearchRound]
    ) async -> [ResearchRound]? {
        guard await shouldProcessEvent(sequence: sequence, answerId: answerId) else { return nil }

        logger.critical("🟢 REFLECTION \(round) COMPLETE - quality: \(reflection.evidenceQuality.rawValue), shouldContinue: \(reflection.shouldContinue)")

        // CANCEL TIMEOUT
        cancelReflectionTimeout(for: answerId)

        // Update round with reflection (create new struct since ResearchRound is immutable)
        var updatedRounds = rounds
        if let index = updatedRounds.firstIndex(where: { $0.roundNumber == round }) {
            let oldRound = updatedRounds[index]
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
            updatedRounds[index] = updatedRound
        }

        // Log reasoning
        logger.debug("Reflection reasoning: \(reflection.reasoning)")

        return updatedRounds
    }

    // MARK: - Source Content Processing

    /// Strip "Kaynaklar" (sources) section from answer content
    /// Sources are already displayed as pills in the UI
    /// PRECISION FIX: Only matches sources sections at ABSOLUTE END of content with strict formatting
    func stripSourcesSection(_ content: String) -> String {
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

    // MARK: - Private Helpers

    /// Cancel reflection timeout
    private func cancelReflectionTimeout(for answerId: String) {
        reflectionTimeouts[answerId]?.cancel()
        reflectionTimeouts.removeValue(forKey: answerId)
    }
}
