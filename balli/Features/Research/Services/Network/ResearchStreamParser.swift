//
//  ResearchStreamParser.swift
//  balli
//
//  SSE stream parsing and buffer management for research streaming
//  Swift 6 strict concurrency compliant
//

import Foundation
import OSLog

/// Manages SSE stream parsing, buffer management, and event processing
/// Actor-isolated for thread-safe stream processing
actor ResearchStreamParser {

    // MARK: - Logger

    private let logger = AppLoggers.Research.streaming

    // MARK: - Stream State

    private var textBuffer = ""
    private var dataBuffer = Data()
    private var accumulatedAnswer = ""
    private var accumulatedSources: [SourceResponse] = []
    private var detectedTier: Int = 1
    private var tokenCount = 0
    private var streamComplete = false
    private var lastEventTime = Date()
    private var completeEventFired = false
    private var pendingCompleteData: CompleteEventData?

    // MARK: - Stream Statistics

    struct StreamStats: Sendable {
        let totalBytesRead: Int
        let tokenCount: Int
        let accumulatedAnswerLength: Int
        let sourcesCount: Int
        let streamComplete: Bool
    }

    // MARK: - Complete Event Data

    struct CompleteEventData: Sendable {
        let sources: [SourceResponse]
        let metadata: MetadataInfo
        let researchSummary: ResearchSummary?
        let processingTier: String?
        let thinkingSummary: String?
    }

    // MARK: - Initialization

    init() {
        dataBuffer.reserveCapacity(4096) // Pre-allocate for performance
    }

    // MARK: - Stream State Management

    func reset() {
        textBuffer = ""
        dataBuffer.removeAll(keepingCapacity: true)
        accumulatedAnswer = ""
        accumulatedSources = []
        detectedTier = 1
        tokenCount = 0
        streamComplete = false
        lastEventTime = Date()
        completeEventFired = false
        pendingCompleteData = nil
    }

    func getStreamStats(totalBytesRead: Int) -> StreamStats {
        StreamStats(
            totalBytesRead: totalBytesRead,
            tokenCount: tokenCount,
            accumulatedAnswerLength: accumulatedAnswer.count,
            sourcesCount: accumulatedSources.count,
            streamComplete: streamComplete
        )
    }

    func hasCompleteEvent() -> Bool {
        pendingCompleteData != nil
    }

    func shouldFireCompleteEvent() -> Bool {
        pendingCompleteData != nil && !completeEventFired
    }

    // MARK: - Buffer Management

    func appendToDataBuffer(_ chunk: Data) {
        dataBuffer.append(chunk)
    }

    func clearDataBuffer() {
        dataBuffer.removeAll(keepingCapacity: true)
    }

    func getDataBufferSize() -> Int {
        dataBuffer.count
    }

    func getTextBufferSize() -> Int {
        textBuffer.count
    }

    func hasTextBuffer() -> Bool {
        !textBuffer.isEmpty
    }

    // MARK: - Event Processing

    func processDataBuffer() -> Bool {
        guard !dataBuffer.isEmpty else { return false }

        // Try to decode the accumulated data
        if let decodedString = String(data: dataBuffer, encoding: .utf8) {
            textBuffer += decodedString
            dataBuffer.removeAll(keepingCapacity: true)
            lastEventTime = Date() // Reset idle timer on successful decode
            return true
        } else if dataBuffer.count > 8192 {
            // If we can't decode and buffer is getting too large, try to recover
            logger.warning("⚠️ Unable to decode \(self.dataBuffer.count) bytes, attempting recovery")

            // Try to find a valid UTF-8 boundary
            for i in stride(from: dataBuffer.count - 1, to: 0, by: -1) {
                let partialData = dataBuffer.prefix(i)
                if let recovered = String(data: partialData, encoding: .utf8) {
                    textBuffer += recovered
                    dataBuffer.removeFirst(i)
                    logger.info("✅ Recovered \(i) bytes")
                    return true
                }
            }

            // If still can't decode, skip the bad data
            if dataBuffer.count > 8192 {
                logger.error("❌ Skipping \(self.dataBuffer.count) bytes of bad data")
                dataBuffer.removeAll(keepingCapacity: true)
            }
        }

        return false
    }

    func processCompleteEvents() -> [String] {
        var processedEvents: [String] = []

        // Process complete SSE events (ending with \n\n)
        while let eventEndRange = textBuffer.range(of: "\n\n") {
            // Extract the complete event
            let eventData = String(textBuffer[..<eventEndRange.lowerBound])

            // 🔍 FORENSIC: Log complete SSE event before parsing
            if !eventData.isEmpty {
                let eventPreview = eventData.prefix(200)
                let eventBytes = eventData.utf8.count
                logger.debug("🔍 [SSE-EVENT] bytes=\(eventBytes), preview='\(eventPreview)'")
                processedEvents.append(eventData)
            }

            // Remove processed event from buffer (including the \n\n)
            textBuffer.removeSubrange(..<eventEndRange.upperBound)
        }

        return processedEvents
    }

    func processRemainingBuffer() -> String? {
        guard !textBuffer.isEmpty else { return nil }

        let remaining = textBuffer
        textBuffer = ""
        return remaining
    }

    // MARK: - Event Handling

    func handleEvent(
        _ event: ResearchSSEEvent,
        onToken: @escaping @Sendable (String) -> Void,
        onTierSelected: @escaping @Sendable (Int) -> Void,
        onSearchComplete: @escaping @Sendable (Int, String) -> Void,
        onSourcesReady: (@Sendable ([SourceResponse]) -> Void)?,
        onError: @escaping @Sendable (Error) -> Void,
        onPlanningStarted: (@Sendable (String, Int) -> Void)?,
        onPlanningComplete: (@Sendable (ResearchPlan, Int) -> Void)?,
        onRoundStarted: (@Sendable (Int, String, Int, Int) -> Void)?,
        onRoundComplete: (@Sendable (Int, [SourceResponse], RoundStatus, Int) -> Void)?,
        onApiStarted: (@Sendable (ResearchAPI, Int, String) -> Void)?,
        onReflectionStarted: (@Sendable (Int, Int) -> Void)?,
        onReflectionComplete: (@Sendable (Int, ResearchReflection, Int) -> Void)?,
        onSourceSelectionStarted: (@Sendable (String, Int) -> Void)?,
        onSynthesisPreparation: (@Sendable (String, Int) -> Void)?,
        onSynthesisStarted: (@Sendable (Int, Int, Int) -> Void)?
    ) {
        lastEventTime = Date() // Reset idle timer on any event

        #if DEBUG
        logger.debug("Received SSE event: \(String(describing: event), privacy: .public)")
        #endif

        switch event {
        case .token(let content):
            // STREAMING FIX: Removed word order detection spam (72 false positives per query)
            // Turkish words like " bir", " için", " ve", " bu" naturally appear at token boundaries
            // and do NOT indicate reordering issues. The detection was overzealous for Turkish grammar.
            // If word reordering actually occurs, it will be visible in user-reported bugs with
            // actual garbled text examples, not log spam about normal Turkish grammar.

            accumulatedAnswer += content
            tokenCount += 1

            // 🔍 FORENSIC: Detailed token emission tracking
            let charCount = content.count
            let bytes = content.utf8.map { String(format: "%02X", $0) }.joined(separator: " ")
            let escapedContent = content.replacingOccurrences(of: "\n", with: "\\n")
                .replacingOccurrences(of: "\t", with: "\\t")
                .replacingOccurrences(of: "\r", with: "\\r")

            logger.debug("🟡 [TOKEN-EMIT] #\(self.tokenCount) chars=\(charCount), bytes=[\(bytes)], accumulated=\(self.accumulatedAnswer.count), raw='\(escapedContent)'")
            onToken(content)

        case .tierSelected(let tier, let reasoning, let confidence):
            detectedTier = tier
            let tierName = tier == 1 ? "MODEL (Hızlı)" : tier == 2 ? "HYBRID_RESEARCH (Araştırma)" : "DEEP_RESEARCH (Derin)"
            logger.warning("🎯 [ROUTING] Backend selected Tier \(tier) (\(tierName))")
            logger.warning("🎯 [ROUTING] Reasoning: \(reasoning)")
            logger.warning("🎯 [ROUTING] Confidence: \(String(format: "%.0f%%", confidence * 100))")
            onTierSelected(tier)

        case .complete(let sources, let metadata, let researchSummary, let processingTier, let thinkingSummary):
            accumulatedSources = sources
            logger.info("✅ Stream complete event received. SSE chunks: \(self.tokenCount), Answer: \(self.accumulatedAnswer.count) chars, Sources: \(sources.count)")

            // Log actual Gemini token usage if available
            if let tokenUsage = metadata.tokenUsage {
                logger.critical("📊 [GEMINI-TOKENS] Input: \(tokenUsage.input), Output: \(tokenUsage.output), Total: \(tokenUsage.total)")
            }

            streamComplete = true

            // Store complete event data and continue reading the stream
            logger.warning("⏸️ Received 'complete' - storing data but continuing stream")
            pendingCompleteData = CompleteEventData(
                sources: sources,
                metadata: metadata,
                researchSummary: researchSummary,
                processingTier: processingTier,
                thinkingSummary: thinkingSummary
            )

        case .searchComplete(let count, let source):
            logger.info("Search complete: \(count, privacy: .public) results from \(source, privacy: .public)")
            onSearchComplete(count, source)

        case .sourcesReady(let sources):
            logger.info("Sources ready: \(sources.count, privacy: .public) sources available")
            onSourcesReady?(sources)

        case .error(let message):
            logger.error("Streaming error: \(message, privacy: .public)")
            onError(ResearchSearchError.serverError(statusCode: 500))

        // Multi-Round Deep Research V2 Events
        case .planningStarted(let message, let sequence):
            logger.info("Planning started: \(message, privacy: .public)")
            onPlanningStarted?(message, sequence)

        case .planningComplete(let plan, let sequence):
            logger.info("Planning complete: \(plan.estimatedRounds) rounds, complexity: \(plan.complexity.rawValue)")
            onPlanningComplete?(plan, sequence)

        case .roundStarted(let round, let query, let estimatedSources, let sequence):
            logger.info("Round \(round) started: \(query, privacy: .private)")
            onRoundStarted?(round, query, estimatedSources, sequence)

        case .roundComplete(let round, let sources, let status, let sequence):
            logger.info("Round \(round) complete: \(sources.count) sources, status: \(status.rawValue)")
            onRoundComplete?(round, sources, status, sequence)

        case .apiStarted(let api, let count, let message):
            logger.info("API started: \(api.rawValue), count: \(count)")
            onApiStarted?(api, count, message)

        case .reflectionStarted(let round, let sequence):
            logger.info("Reflection \(round) started")
            onReflectionStarted?(round, sequence)

        case .reflectionComplete(let round, let reflection, let sequence):
            logger.info("Reflection \(round) complete: quality=\(reflection.evidenceQuality.rawValue), continue=\(reflection.shouldContinue)")
            onReflectionComplete?(round, reflection, sequence)

        case .sourceSelectionStarted(let message, let sequence):
            logger.info("Source selection started: \(message, privacy: .public)")
            onSourceSelectionStarted?(message, sequence)

        case .synthesisPreparation(let message, let sequence):
            logger.info("Synthesis preparation: \(message, privacy: .public)")
            onSynthesisPreparation?(message, sequence)

        case .synthesisStarted(let totalRounds, let totalSources, let sequence):
            logger.info("Synthesis started: \(totalRounds) rounds, \(totalSources) sources")
            onSynthesisStarted?(totalRounds, totalSources, sequence)

        default:
            // Ignore other events (routing, searching, etc.)
            break
        }
    }

    // MARK: - Complete Event Finalization

    func finalizeCompleteEvent(onComplete: @escaping @Sendable (ResearchSearchResponse) -> Void) {
        guard let completeData = pendingCompleteData, !completeEventFired else { return }

        logger.warning("✅ Firing delayed complete event - SSE chunks: \(self.tokenCount), Answer: \(self.accumulatedAnswer.count) chars")

        // Log Gemini token usage
        if let tokenUsage = completeData.metadata.tokenUsage {
            logger.critical("📊 [GEMINI-TOKENS] Input: \(tokenUsage.input), Output: \(tokenUsage.output), Total: \(tokenUsage.total)")
        }

        let response = ResearchSearchResponse(
            answer: accumulatedAnswer,
            tier: detectedTier,
            processingTier: completeData.processingTier,
            thinkingSummary: completeData.thinkingSummary,
            routing: RoutingInfo(
                selectedTier: detectedTier,
                reasoning: "",
                confidence: 1.0
            ),
            sources: completeData.sources.map { convertToResearchSource($0) },
            metadata: completeData.metadata,
            researchSummary: completeData.researchSummary,
            rateLimitInfo: nil
        )

        completeEventFired = true
        onComplete(response)
    }

    func synthesizeCompleteEvent(onComplete: @escaping @Sendable (ResearchSearchResponse) -> Void) {
        guard !streamComplete && !completeEventFired && pendingCompleteData == nil && accumulatedAnswer.count > 100 else {
            return
        }

        logger.warning("⚠️ Synthesizing complete event - have \(self.accumulatedAnswer.count) chars but no complete signal")

        let response = ResearchSearchResponse(
            answer: accumulatedAnswer,
            tier: detectedTier,
            processingTier: nil,
            thinkingSummary: nil,
            routing: RoutingInfo(
                selectedTier: detectedTier,
                reasoning: "",
                confidence: 1.0
            ),
            sources: accumulatedSources.map { convertToResearchSource($0) },
            metadata: MetadataInfo(
                processingTime: "unknown",
                modelUsed: "unknown",
                costTier: "unknown",
                tokenUsage: nil
            ),
            researchSummary: nil,
            rateLimitInfo: nil
        )

        completeEventFired = true
        onComplete(response)
    }

    func handleTimeout(onComplete: @escaping @Sendable (ResearchSearchResponse) -> Void, onError: @escaping @Sendable (Error) -> Void) {
        logger.critical("🚨 TIMEOUT after 360s - Answer: \(self.accumulatedAnswer.count) chars, Sources: \(self.accumulatedSources.count)")

        // Preserve partial response on timeout
        if !accumulatedAnswer.isEmpty {
            logger.warning("⚠️ Preserving partial response from timeout")

            let response = ResearchSearchResponse(
                answer: accumulatedAnswer,
                tier: detectedTier,
                processingTier: nil,
                thinkingSummary: nil,
                routing: RoutingInfo(
                    selectedTier: detectedTier,
                    reasoning: "",
                    confidence: 1.0
                ),
                sources: accumulatedSources.map { convertToResearchSource($0) },
                metadata: MetadataInfo(
                    processingTime: "timeout",
                    modelUsed: "unknown",
                    costTier: "unknown",
                    tokenUsage: nil
                ),
                researchSummary: nil,
                rateLimitInfo: nil
            )

            onComplete(response)
        } else {
            onError(ResearchSearchError.networkTimeout)
        }
    }

    func checkStreamCompletion(onError: @escaping @Sendable (Error) -> Void) {
        if !streamComplete {
            if accumulatedAnswer.isEmpty {
                logger.error("❌ Stream ended with no content")
                onError(ResearchSearchError.networkError)
            } else if accumulatedAnswer.count <= 100 {
                logger.error("❌ Stream ended with insufficient content: \(self.accumulatedAnswer.count) chars")
                onError(ResearchSearchError.streamingConnectionLost)
            } else {
                logger.info("✅ Response preserved via synthetic complete event")
            }
        }
    }

    // MARK: - Idle Timeout Check

    func checkIdleTimeout() -> Bool {
        let idleDuration = Date().timeIntervalSince(lastEventTime)
        if idleDuration > 120 { // 2 minutes timeout
            logger.error("❌ Stream idle for \(Int(idleDuration))s - timing out")
            return true
        }
        return false
    }

    // MARK: - Helper Methods

    private func convertToResearchSource(_ source: SourceResponse) -> DiabetesSource {
        return DiabetesSource(
            title: source.title,
            url: source.url.isEmpty ? nil : source.url,
            type: mapBadgeToType(source.credibilityBadge),
            authors: source.author,
            journal: nil,
            year: nil,
            pmid: nil
        )
    }

    private func mapBadgeToType(_ badge: CredibilityBadge) -> String {
        switch badge {
        case .peerReviewed: return "pubmed"
        case .clinicalTrial: return "clinical_trial"
        case .expert: return "knowledge_base"
        case .medicalSource: return "medical_source"
        }
    }
}
