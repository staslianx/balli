//
//  ResearchStreamingAPIClient.swift
//  balli
//
//  Firebase Cloud Function HTTP/SSE streaming client for research
//  Swift 6 strict concurrency compliant
//

import Foundation
import OSLog

/// HTTP/SSE streaming client for Firebase Cloud Functions research endpoint
/// Main coordinator delegating to specialized services
@MainActor
class ResearchStreamingAPIClient {

    // MARK: - Logger

    internal let logger = AppLoggers.Research.network
    private let streamingLogger = AppLoggers.Research.streaming

    // MARK: - Services

    private let networkService = ResearchNetworkService()
    private let streamParser = ResearchStreamParser()

    // MARK: - Non-Streaming Search

    /// Perform research search via Cloud Function
    func search(query: String, userId: String, conversationHistory: [[String: String]]? = nil) async throws -> ResearchSearchResponse {

        // Build request
        let jsonData = try await networkService.buildNonStreamingSearchRequestBody(query: query, userId: userId)
        let request = try await networkService.createNonStreamingRequest(jsonData: jsonData)

        // Execute request
        let data = try await networkService.executeNonStreamingSearch(request: request)

        // Decode response
        return try await networkService.decodeSearchResponse(from: data)
    }

    // MARK: - Streaming Search

    /// Perform research search via Cloud Function with token-by-token streaming
    /// - Parameters:
    ///   - query: The search query
    ///   - userId: User identifier
    ///   - onToken: Callback for each token received
    ///   - onTierSelected: Callback when tier is determined by backend
    ///   - onComplete: Callback when complete with final sources and metadata
    ///   - onPlanningStarted: Multi-round V2 - Planning phase started (T3 only)
    ///   - onPlanningComplete: Multi-round V2 - Planning completed with plan (T3 only)
    ///   - onRoundStarted: Multi-round V2 - Research round started (T3 only)
    ///   - onRoundComplete: Multi-round V2 - Research round completed (T3 only)
    ///   - onReflectionStarted: Multi-round V2 - Reflection started (T3 only)
    ///   - onReflectionComplete: Multi-round V2 - Reflection completed (T3 only)
    ///   - onSynthesisStarted: Multi-round V2 - Final synthesis started (T3 only)
    /// CONCURRENCY FIX: All callbacks marked @Sendable for thread-safety verification
    /// NOTE: T1 (model) and T2 (exa search) don't need progress tracking - only T3 uses V2 events
    func searchStreaming(
        query: String,
        userId: String,
        conversationHistory: [[String: String]]? = nil,
        onToken: @escaping @Sendable (String) -> Void,
        onTierSelected: @escaping @Sendable (Int) -> Void,
        onSearchComplete: @escaping @Sendable (Int, String) -> Void,
        onSourcesReady: (@Sendable ([SourceResponse]) -> Void)? = nil,
        onComplete: @escaping @Sendable (ResearchSearchResponse) -> Void,
        onError: @escaping @Sendable (Error) -> Void,
        onPlanningStarted: (@Sendable (String, Int) -> Void)? = nil,
        onPlanningComplete: (@Sendable (ResearchPlan, Int) -> Void)? = nil,
        onRoundStarted: (@Sendable (Int, String, Int, Int) -> Void)? = nil,
        onRoundComplete: (@Sendable (Int, [SourceResponse], RoundStatus, Int) -> Void)? = nil,
        onApiStarted: (@Sendable (ResearchAPI, Int, String) -> Void)? = nil,
        onReflectionStarted: (@Sendable (Int, Int) -> Void)? = nil,
        onReflectionComplete: (@Sendable (Int, ResearchReflection, Int) -> Void)? = nil,
        onSourceSelectionStarted: (@Sendable (String, Int) -> Void)? = nil,
        onSynthesisPreparation: (@Sendable (String, Int) -> Void)? = nil,
        onSynthesisStarted: (@Sendable (Int, Int, Int) -> Void)? = nil
    ) async {
        // Build request
        guard let jsonData = try? await networkService.buildSearchRequestBody(
            query: query,
            userId: userId,
            conversationHistory: conversationHistory
        ) else {
            onError(ResearchSearchError.invalidRequest)
            return
        }

        if let history = conversationHistory {
            streamingLogger.info("🧠 Including \(history.count) messages in conversation context")
        }

        // Create streaming request
        guard let request = try? await networkService.createStreamingRequest(jsonData: jsonData) else {
            onError(ResearchSearchError.invalidRequest)
            return
        }

        streamingLogger.notice("🟢 Stream starting - Query: \(String(query.prefix(50)))..., Timeout: 360s")

        // Reset parser state
        await streamParser.reset()

        do {
            // Create streaming session
            let session = await networkService.createStreamingURLSession()
            let (asyncBytes, response) = try await session.bytes(for: request)

            // Validate response
            try await networkService.validateStreamingResponse(response)

            guard let httpResponse = response as? HTTPURLResponse else {
                streamingLogger.error("❌ Invalid HTTP response")
                onError(ResearchSearchError.networkError)
                return
            }

            streamingLogger.info("✅ Stream connection established - HTTP \(httpResponse.statusCode)")

            // Stream processing
            var totalBytesRead = 0
            var currentChunk = Data()
            currentChunk.reserveCapacity(4096)

            for try await byte in asyncBytes {
                currentChunk.append(byte)
                totalBytesRead += 1

                // Process when we have a full chunk OR detect event boundary
                if currentChunk.count >= 4096 ||
                   (currentChunk.count > 1 && currentChunk.suffix(2) == Data([0x0A, 0x0A])) { // \n\n in bytes

                    // Append chunk to parser
                    await streamParser.appendToDataBuffer(currentChunk)
                    currentChunk.removeAll(keepingCapacity: true)

                    // Log progress every 4KB
                    if totalBytesRead % 4096 == 0 {
                        let stats = await streamParser.getStreamStats(totalBytesRead: totalBytesRead)
                        streamingLogger.debug("📊 Read \(totalBytesRead) bytes, answer: \(stats.accumulatedAnswerLength) chars")
                    }

                    // Process data buffer
                    if await streamParser.processDataBuffer() {
                        // Process complete events
                        let events = await streamParser.processCompleteEvents()

                        for eventData in events {
                            if let event = ResearchSSEParser.parseEvent(from: eventData) {
                                await streamParser.handleEvent(
                                    event,
                                    onToken: onToken,
                                    onTierSelected: onTierSelected,
                                    onSearchComplete: onSearchComplete,
                                    onSourcesReady: onSourcesReady,
                                    onError: onError,
                                    onPlanningStarted: onPlanningStarted,
                                    onPlanningComplete: onPlanningComplete,
                                    onRoundStarted: onRoundStarted,
                                    onRoundComplete: onRoundComplete,
                                    onApiStarted: onApiStarted,
                                    onReflectionStarted: onReflectionStarted,
                                    onReflectionComplete: onReflectionComplete,
                                    onSourceSelectionStarted: onSourceSelectionStarted,
                                    onSynthesisPreparation: onSynthesisPreparation,
                                    onSynthesisStarted: onSynthesisStarted
                                )
                            }
                        }
                    }
                }

                // Check for idle timeout
                if await streamParser.checkIdleTimeout() {
                    break
                }
            }

            // Process any remaining data
            if !currentChunk.isEmpty {
                await streamParser.appendToDataBuffer(currentChunk)
                streamingLogger.debug("📊 Appended final chunk: \(currentChunk.count) bytes")
            }

            // Final buffer processing
            let remainingBufferSize = await streamParser.getDataBufferSize()
            if remainingBufferSize > 0 {
                streamingLogger.warning("⚠️ Stream ended with \(remainingBufferSize) bytes in buffer")
                await streamParser.processDataBuffer()

                // Process any remaining events
                let remainingEvents = await streamParser.processCompleteEvents()
                for eventData in remainingEvents {
                    if let event = ResearchSSEParser.parseEvent(from: eventData) {
                        await streamParser.handleEvent(
                            event,
                            onToken: onToken,
                            onTierSelected: onTierSelected,
                            onSearchComplete: onSearchComplete,
                            onSourcesReady: onSourcesReady,
                            onError: onError,
                            onPlanningStarted: onPlanningStarted,
                            onPlanningComplete: onPlanningComplete,
                            onRoundStarted: onRoundStarted,
                            onRoundComplete: onRoundComplete,
                            onApiStarted: onApiStarted,
                            onReflectionStarted: onReflectionStarted,
                            onReflectionComplete: onReflectionComplete,
                            onSourceSelectionStarted: onSourceSelectionStarted,
                            onSynthesisPreparation: onSynthesisPreparation,
                            onSynthesisStarted: onSynthesisStarted
                        )
                    }
                }
            }

            // Log final stream state
            let finalStats = await streamParser.getStreamStats(totalBytesRead: totalBytesRead)
            streamingLogger.critical("🔴 Stream loop ended - Total bytes: \(totalBytesRead), Tokens: \(finalStats.tokenCount), Answer: \(finalStats.accumulatedAnswerLength) chars, Sources: \(finalStats.sourcesCount), Complete: \(finalStats.streamComplete)")

            // Fire complete event if pending
            if await streamParser.shouldFireCompleteEvent() {
                await streamParser.finalizeCompleteEvent(onComplete: onComplete)
            }

            // Process remaining text buffer
            if await streamParser.hasTextBuffer() {
                streamingLogger.info("🔧 Processing remaining buffer after stream end")
                if let remaining = await streamParser.processRemainingBuffer() {
                    if remaining.contains("\"type\":\"complete\"") {
                        streamingLogger.warning("⚠️ Found complete event in remaining buffer - processing")
                        if let event = ResearchSSEParser.parseEvent(from: remaining) {
                            await streamParser.handleEvent(
                                event,
                                onToken: onToken,
                                onTierSelected: onTierSelected,
                                onSearchComplete: onSearchComplete,
                                onSourcesReady: onSourcesReady,
                                onError: onError,
                                onPlanningStarted: onPlanningStarted,
                                onPlanningComplete: onPlanningComplete,
                                onRoundStarted: onRoundStarted,
                                onRoundComplete: onRoundComplete,
                                onApiStarted: onApiStarted,
                                onReflectionStarted: onReflectionStarted,
                                onReflectionComplete: onReflectionComplete,
                                onSourceSelectionStarted: onSourceSelectionStarted,
                                onSynthesisPreparation: onSynthesisPreparation,
                                onSynthesisStarted: onSynthesisStarted
                            )
                        }
                    }
                }
            }

            // Synthesize complete event if needed
            await streamParser.synthesizeCompleteEvent(onComplete: onComplete)

            // Check final stream completion
            await streamParser.checkStreamCompletion(onError: onError)

        } catch let error as URLError where error.code == .timedOut {
            await streamParser.handleTimeout(onComplete: onComplete, onError: onError)
        } catch {
            streamingLogger.error("❌ Unexpected error: \(error.localizedDescription, privacy: .public)")
            onError(ResearchSearchError.networkError)
        }
    }

    // MARK: - Feedback Submission

    /// Submit feedback for a research answer
    /// - Parameters:
    ///   - messageId: The unique ID of the message
    ///   - prompt: The user's query
    ///   - response: The AI's response
    ///   - sources: Array of sources used
    ///   - tier: The response tier used
    ///   - rating: User's rating ("up" or "down")
    func submitFeedback(
        messageId: String,
        prompt: String,
        response: String,
        sources: [SourceResponse],
        tier: String?,
        rating: String
    ) async throws {
        // Build request
        let jsonData = try await networkService.buildFeedbackRequestBody(
            messageId: messageId,
            prompt: prompt,
            response: response,
            sources: sources,
            tier: tier,
            rating: rating
        )

        let request = try await networkService.createFeedbackRequest(jsonData: jsonData)

        // Submit feedback
        try await networkService.submitFeedback(request: request)

        logger.info("Feedback submitted for message: \(messageId, privacy: .public)")
    }
}
