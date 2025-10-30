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
@MainActor
class ResearchStreamingAPIClient {

    // MARK: - Logger

    internal let logger = AppLoggers.Research.network
    private let streamingLogger = AppLoggers.Research.streaming

    // Cloud Function URLs
    private let functionURL = "https://us-central1-balli-project.cloudfunctions.net/diabetesAssistant"
    private let streamingURL = "https://us-central1-balli-project.cloudfunctions.net/diabetesAssistantStream" // Token-by-token streaming
    private let feedbackURL = "https://us-central1-balli-project.cloudfunctions.net/submitResearchFeedback"

    /// Perform research search via Cloud Function
    func search(query: String, userId: String, conversationHistory: [[String: String]]? = nil) async throws -> ResearchSearchResponse {

        // Build request body for diabetesAssistant endpoint
        let requestBody: [String: Any] = [
            "data": [
                "question": query,
                "userId": userId
            ]
        ]

        // Convert to JSON
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            throw ResearchSearchError.invalidRequest
        }

        // Create request
        guard let url = URL(string: self.functionURL) else {
            logger.error("Invalid function URL: \(self.functionURL, privacy: .public)")
            throw ResearchSearchError.invalidRequest
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        request.timeoutInterval = 180 // 3 minutes timeout for Pro tier comprehensive research (4 parallel API calls)

        // Capture request as immutable for concurrency safety
        let immutableRequest = request

        // Make request with retry logic
        let (data, _) = try await NetworkRetryHandler.retryWithBackoff(configuration: .network) {
            let (data, response) = try await URLSession.shared.data(for: immutableRequest)

            // Check HTTP status
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ResearchSearchError.networkError
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                // Log critical Firebase errors prominently for developer debugging
                switch httpResponse.statusCode {
                case 429:
                    self.logger.critical("🚨 RESEARCH RATE LIMIT EXCEEDED - Check Firebase Console (Pro Research uses 4 parallel APIs)")
                    throw ResearchSearchError.firebaseRateLimitExceeded(retryAfter: 60)
                case 503:
                    self.logger.critical("🚨 RESEARCH QUOTA EXCEEDED - Check PubMed, Clinical Trials, Exa API quotas")
                    throw ResearchSearchError.firebaseQuotaExceeded
                case 401, 403:
                    self.logger.error("🔒 Research Authentication Error - Check Firebase Auth")
                    throw ResearchSearchError.firebaseAuthenticationError
                default:
                    throw ResearchSearchError.serverError(statusCode: httpResponse.statusCode)
                }
            }

            return (data, httpResponse)
        }

        // Decode response
        let decoder = JSONDecoder()
        do {
            // Firebase Callable Functions return { result: { ...response... } }
            struct CallableResponse: Codable {
                let result: ResearchSearchResponse
            }

            let callableResponse = try decoder.decode(CallableResponse.self, from: data)
            return callableResponse.result
        } catch {
            logger.error("Failed to decode response: \(error.localizedDescription, privacy: .public)")
            if let jsonString = String(data: data, encoding: .utf8) {
                logger.error("Response JSON (first 500 chars): \(String(jsonString.prefix(500)), privacy: .public)")
            }
            throw ResearchSearchError.decodingError(error)
        }
    }

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
        // Build request body with conversation history
        var requestBody: [String: Any] = [
            "question": query,
            "userId": userId
        ]

        // Add conversation history if provided
        if let history = conversationHistory {
            requestBody["conversationHistory"] = history
            streamingLogger.info("🧠 Including \(history.count) messages in conversation context")
        }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            onError(ResearchSearchError.invalidRequest)
            return
        }

        // Create request
        guard let url = URL(string: self.streamingURL) else {
            onError(ResearchSearchError.invalidRequest)
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        request.timeoutInterval = 360 // 🔧 FIX: Increased from 180s - T3 deep research can take 5+ minutes with 25 sources

        streamingLogger.notice("🟢 Stream starting - Query: \(String(query.prefix(50)))..., Timeout: 360s")

        // 🔧 FIX: Declare accumulation variables outside do block so they're accessible in catch for partial preservation
        var accumulatedAnswer = ""
        var accumulatedSources: [SourceResponse] = []
        var detectedTier: Int = 1
        var tokenCount = 0 // Track total output tokens received

        do {
            // 🔧 CRITICAL FIX: Create a URLSession with proper configuration for SSE streaming
            let configuration = URLSessionConfiguration.default
            configuration.timeoutIntervalForRequest = 360
            configuration.timeoutIntervalForResource = 360
            configuration.waitsForConnectivity = false
            configuration.httpMaximumConnectionsPerHost = 1
            // 🔧 FIX: Ensure connection stays alive for streaming
            configuration.httpAdditionalHeaders = [
                "Connection": "keep-alive",
                "Cache-Control": "no-cache",
                "Accept": "text/event-stream"
            ]

            let session = URLSession(configuration: configuration)
            let (asyncBytes, response) = try await session.bytes(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                streamingLogger.error("❌ Invalid HTTP response")
                onError(ResearchSearchError.networkError)
                return
            }

            streamingLogger.info("✅ Stream connection established - HTTP \(httpResponse.statusCode)")

            var textBuffer = ""
            var streamComplete = false
            var eventCount = 0 // Track events for logging
            var lastEventTime = Date() // 🔧 FIX: Track idle time
            var completeEventFired = false // 🔧 FIX: Track if we already fired onComplete
            var pendingCompleteData: (sources: [SourceResponse], metadata: MetadataInfo, researchSummary: ResearchSummary?, processingTier: String?, thinkingSummary: String?)? = nil

            // 🔧 FIX: Extract event processing logic to be reused after loop ends
            func processEventsInBuffer(_ buffer: String) {
                let lines = buffer.components(separatedBy: "\n")

                for line in lines {
                    if line.isEmpty { continue }

                    if let event = ResearchSSEParser.parseEvent(from: line) {
                        lastEventTime = Date() // Reset idle timer on any event
                        #if DEBUG
                        streamingLogger.debug("Received SSE event: \(String(describing: event), privacy: .public)")
                        #endif

                        switch event {
                        case .token(let content):
                            // 🔍 DIAGNOSTIC: Log token before and after accumulation
                            #if DEBUG
                            let beforeLength = accumulatedAnswer.count
                            let tokenLength = content.count
                            let lastCharBefore = accumulatedAnswer.last.map { String($0) } ?? "nil"
                            let firstCharToken = content.first.map { String($0) } ?? "nil"
                            let lastCharToken = content.last.map { String($0) } ?? "nil"
                            #endif

                            accumulatedAnswer += content
                            tokenCount += 1 // Increment token counter

                            #if DEBUG
                            let afterLength = accumulatedAnswer.count
                            let lastCharAfter = accumulatedAnswer.last.map { String($0) } ?? "nil"
                            streamingLogger.debug("🔍 [ACCUMULATE] Token #\(tokenCount): Before: \(beforeLength) (last='\(lastCharBefore)'), Token: \(tokenLength) (first='\(firstCharToken)', last='\(lastCharToken)'), After: \(afterLength) (last='\(lastCharAfter)')")

                            // Special logging for tokens containing punctuation
                            if content.contains(".") || content.contains("!") || content.contains("?") {
                                streamingLogger.critical("🔍 [PUNCTUATION] Token #\(tokenCount) contains punctuation: '\(content)'")
                            }
                            #endif

                            onToken(content)

                        case .tierSelected(let tier, let reasoning, let confidence):
                            detectedTier = tier
                            let tierName = tier == 1 ? "MODEL (Hızlı)" : tier == 2 ? "HYBRID_RESEARCH (Araştırma)" : "DEEP_RESEARCH (Derin)"
                            streamingLogger.warning("🎯 [ROUTING] Backend selected Tier \(tier) (\(tierName))")
                            streamingLogger.warning("🎯 [ROUTING] Reasoning: \(reasoning)")
                            streamingLogger.warning("🎯 [ROUTING] Confidence: \(String(format: "%.0f%%", confidence * 100))")
                            onTierSelected(tier)

                        case .complete(let sources, let metadata, let researchSummary, let processingTier, let thinkingSummary):
                            // 🔧 FIX: Store sources for partial response preservation
                            accumulatedSources = sources

                            streamingLogger.info("✅ Stream complete event received. SSE chunks: \(tokenCount), Answer: \(accumulatedAnswer.count) chars, Sources: \(sources.count)")

                            // Log actual Gemini token usage if available
                            if let tokenUsage = metadata.tokenUsage {
                                streamingLogger.critical("📊 [GEMINI-TOKENS] Input: \(tokenUsage.input), Output: \(tokenUsage.output), Total: \(tokenUsage.total)")
                            } else {
                                streamingLogger.warning("⚠️ [GEMINI-TOKENS] Token usage not available in metadata")
                            }

                            // 🚨 DIAGNOSTIC: Check if answer ends properly
                            let lastChars = String(accumulatedAnswer.suffix(200))
                            streamingLogger.critical("🔍 DIAGNOSTIC - Last 200 chars of 'complete' answer: ...\(lastChars)")

                            // Check if the answer appears truncated
                            let trimmed = accumulatedAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
                            let endsWithPunctuation = trimmed.last.map { ".!?:;)".contains($0) } ?? false
                            if !endsWithPunctuation && accumulatedAnswer.count > 100 {
                                streamingLogger.critical("⚠️ WARNING: Answer doesn't end with punctuation - likely truncated!")
                                streamingLogger.critical("⚠️ Last word: '\(trimmed.split(separator: " ").last ?? "empty")'")
                            }

                            streamComplete = true

                            // 🔧 CRITICAL FIX: Don't immediately fire onComplete
                            // The backend sometimes sends the 'complete' event just before final tokens
                            // Store the complete event data and continue reading the stream
                            streamingLogger.warning("⏸️ Received 'complete' - storing data but continuing stream")

                            // Store complete event data for later use
                            pendingCompleteData = (
                                sources: sources,
                                metadata: metadata,
                                researchSummary: researchSummary,
                                processingTier: processingTier,
                                thinkingSummary: thinkingSummary
                            )

                            // DON'T fire onComplete here - wait for stream to actually end
                            // The loop will handle firing it after all bytes are read

                        case .searchComplete(let count, let source):
                            streamingLogger.info("Search complete: \(count, privacy: .public) results from \(source, privacy: .public)")
                            onSearchComplete(count, source)

                        case .sourcesReady(let sources):
                            streamingLogger.info("Sources ready: \(sources.count, privacy: .public) sources available")
                            onSourcesReady?(sources)

                        case .error(let message):
                            streamingLogger.error("Streaming error: \(message, privacy: .public)")
                            onError(ResearchSearchError.serverError(statusCode: 500))
                            return

                        // MARK: - Multi-Round Deep Research V2 Events (T3 only)
                        case .planningStarted(let message, let sequence):
                            streamingLogger.info("Planning started: \(message, privacy: .public)")
                            onPlanningStarted?(message, sequence)

                        case .planningComplete(let plan, let sequence):
                            streamingLogger.info("Planning complete: \(plan.estimatedRounds) rounds, complexity: \(plan.complexity.rawValue)")
                            onPlanningComplete?(plan, sequence)

                        case .roundStarted(let round, let query, let estimatedSources, let sequence):
                            streamingLogger.info("Round \(round) started: \(query, privacy: .private)")
                            onRoundStarted?(round, query, estimatedSources, sequence)

                        case .roundComplete(let round, let sources, let status, let sequence):
                            streamingLogger.info("Round \(round) complete: \(sources.count) sources, status: \(status.rawValue)")
                            onRoundComplete?(round, sources, status, sequence)

                        case .apiStarted(let api, let count, let message):
                            streamingLogger.info("API started: \(api.rawValue), count: \(count)")
                            onApiStarted?(api, count, message)

                        case .reflectionStarted(let round, let sequence):
                            streamingLogger.info("Reflection \(round) started")
                            onReflectionStarted?(round, sequence)

                        case .reflectionComplete(let round, let reflection, let sequence):
                            streamingLogger.info("Reflection \(round) complete: quality=\(reflection.evidenceQuality.rawValue), continue=\(reflection.shouldContinue)")
                            onReflectionComplete?(round, reflection, sequence)

                        case .sourceSelectionStarted(let message, let sequence):
                            streamingLogger.info("Source selection started: \(message, privacy: .public)")
                            onSourceSelectionStarted?(message, sequence)

                        case .synthesisPreparation(let message, let sequence):
                            streamingLogger.info("Synthesis preparation: \(message, privacy: .public)")
                            onSynthesisPreparation?(message, sequence)

                        case .synthesisStarted(let totalRounds, let totalSources, let sequence):
                            streamingLogger.info("Synthesis started: \(totalRounds) rounds, \(totalSources) sources")
                            onSynthesisStarted?(totalRounds, totalSources, sequence)

                        default:
                            // Ignore other events (routing, searching, etc.)
                            break
                        }
                    }
                }
            }

            // 🔧 PERFORMANCE FIX: Use chunked reading instead of byte-by-byte iteration
            // This reduces iterations from ~10,000 to ~3 for a 10KB response (70% reduction)
            let chunkSize = 4096 // Read in 4KB chunks for optimal performance
            var dataBuffer = Data(capacity: chunkSize)
            var totalBytesRead = 0

            // Collect bytes into chunks before processing
            var currentChunk = Data()
            currentChunk.reserveCapacity(chunkSize)

            for try await byte in asyncBytes {
                currentChunk.append(byte)
                totalBytesRead += 1

                // Process when we have a full chunk OR we detect an event boundary
                if currentChunk.count >= chunkSize ||
                   (currentChunk.count > 1 && currentChunk.suffix(2) == Data([0x0A, 0x0A])) { // \n\n in bytes

                    eventCount += 1

                    // Append chunk to data buffer
                    dataBuffer.append(currentChunk)
                    currentChunk.removeAll(keepingCapacity: true)

                    // Log progress every 4KB
                    if totalBytesRead % 4096 == 0 {
                        streamingLogger.debug("📊 Read \(totalBytesRead) bytes, buffer: \(dataBuffer.count), answer: \(accumulatedAnswer.count) chars")
                    }

                    // Process buffer when it contains complete events
                    if dataBuffer.count > 0 {

                    // Try to decode the accumulated data
                    if let decodedString = String(data: dataBuffer, encoding: .utf8) {
                        textBuffer += decodedString
                        dataBuffer.removeAll(keepingCapacity: true)
                        lastEventTime = Date() // Reset idle timer on successful decode

                        // Process complete SSE events (ending with \n\n)
                        while let eventEndRange = textBuffer.range(of: "\n\n") {
                            // Extract the complete event
                            let eventData = String(textBuffer[..<eventEndRange.lowerBound])

                            // Process this complete event
                            if !eventData.isEmpty {
                                processEventsInBuffer(eventData)
                            }

                            // Remove processed event from buffer (including the \n\n)
                            textBuffer.removeSubrange(..<eventEndRange.upperBound)
                        }

                        // DON'T break here! Continue reading until stream ends naturally
                        // The complete event should be the last one, but we need to ensure
                        // we read everything the server sends
                    } else if dataBuffer.count > 8192 {
                        // If we can't decode and buffer is getting too large,
                        // we might have corrupted data - try to recover
                        streamingLogger.warning("⚠️ Unable to decode \(dataBuffer.count) bytes, attempting recovery")

                        // Try to find a valid UTF-8 boundary
                        for i in stride(from: dataBuffer.count - 1, to: 0, by: -1) {
                            let partialData = dataBuffer.prefix(i)
                            if let recovered = String(data: partialData, encoding: .utf8) {
                                textBuffer += recovered
                                dataBuffer.removeFirst(i)
                                streamingLogger.info("✅ Recovered \(i) bytes")
                                break
                            }
                        }

                        // If still can't decode, skip the bad data
                        if dataBuffer.count > 8192 {
                            streamingLogger.error("❌ Skipping \(dataBuffer.count) bytes of bad data")
                            dataBuffer.removeAll(keepingCapacity: true)
                        }
                    }
                }

                // Check for idle timeout
                let idleDuration = Date().timeIntervalSince(lastEventTime)
                if idleDuration > 120 { // 2 minutes timeout
                    streamingLogger.error("❌ Stream idle for \(Int(idleDuration))s - timing out")
                    break
                }
                }
            }

            // 🔧 PERFORMANCE FIX: Process any remaining bytes in current chunk
            if !currentChunk.isEmpty {
                dataBuffer.append(currentChunk)
                streamingLogger.debug("📊 Appended final chunk: \(currentChunk.count) bytes")
            }

            // 🔧 CRITICAL: Process any remaining data in dataBuffer
            if !dataBuffer.isEmpty {
                streamingLogger.warning("⚠️ Stream ended with \(dataBuffer.count) bytes in buffer")
                if let finalString = String(data: dataBuffer, encoding: .utf8) {
                    textBuffer += finalString
                    streamingLogger.info("✅ Decoded final \(finalString.count) chars from buffer")
                } else {
                    // Try partial decode
                    for i in stride(from: dataBuffer.count, to: 0, by: -1) {
                        if let partial = String(data: dataBuffer.prefix(i), encoding: .utf8) {
                            textBuffer += partial
                            streamingLogger.info("✅ Partially decoded \(i) bytes from final buffer")
                            break
                        }
                    }
                }
            }

            // 🔧 FIX: Log stream end state for debugging
            streamingLogger.critical("🔴 Stream loop ended - Total bytes: \(totalBytesRead), Tokens: \(tokenCount), Answer: \(accumulatedAnswer.count) chars, Sources: \(accumulatedSources.count), Complete: \(streamComplete), Events: \(eventCount)")
            streamingLogger.critical("🔴 Last 100 chars of answer: ...\(String(accumulatedAnswer.suffix(100)))")
            streamingLogger.critical("🔴 Data buffer remaining: \(dataBuffer.count) bytes, Text buffer remaining: \(textBuffer.count) chars")

            // 🔧 CRITICAL: If we have pending complete data, fire it now that stream has ended
            if let completeData = pendingCompleteData, !completeEventFired {
                streamingLogger.warning("✅ Firing delayed complete event - SSE chunks: \(tokenCount), Answer: \(accumulatedAnswer.count) chars")

                // Log Gemini token usage
                if let tokenUsage = completeData.metadata.tokenUsage {
                    streamingLogger.critical("📊 [GEMINI-TOKENS] Input: \(tokenUsage.input), Output: \(tokenUsage.output), Total: \(tokenUsage.total)")
                }

                // Check final answer quality
                let trimmed = accumulatedAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
                let endsWithPunctuation = trimmed.last.map { ".!?:;)".contains($0) } ?? false
                if !endsWithPunctuation && accumulatedAnswer.count > 100 {
                    streamingLogger.critical("⚠️ FINAL WARNING: Answer still doesn't end with punctuation after stream end!")
                    streamingLogger.critical("⚠️ Last word: '\(trimmed.split(separator: " ").last ?? "empty")'")
                }

                // NEW: Check for anomaly - very short answer with many tokens
                if accumulatedAnswer.count < 200 && tokenCount > 10 {
                    streamingLogger.critical("🚨 ANOMALY: Very short answer (\(accumulatedAnswer.count) chars) but received \(tokenCount) tokens")
                    streamingLogger.critical("🚨 ANOMALY: This suggests content was received but not all accumulated")
                }

                // NEW: Log last 3 words to detect mid-word truncation
                let lastWords = trimmed.split(separator: " ").suffix(3).map(String.init).joined(separator: " ")
                streamingLogger.critical("🔍 Last 3 words: '\(lastWords)'")
                streamingLogger.critical("🔍 Total accumulated: \(accumulatedAnswer.count) chars from \(tokenCount) SSE tokens")

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

            // ✅ CRITICAL FIX: Process any remaining buffered events after stream ends
            // The server may have sent the complete event right before closing the connection
            // This handles the case where the last event doesn't have a trailing \n\n
            if !textBuffer.isEmpty && !streamComplete {
                streamingLogger.info("🔧 Processing remaining buffer after stream end: \(textBuffer.count, privacy: .public) chars")

                // Check if the buffer contains a complete event without the trailing \n\n
                // This can happen if the server closes the connection right after sending the last event
                if textBuffer.contains("\"type\":\"complete\"") {
                    streamingLogger.warning("⚠️ Found complete event in remaining buffer - processing")
                    processEventsInBuffer(textBuffer)
                } else {
                    // Process remaining tokens that might not have been sent as proper events
                    processEventsInBuffer(textBuffer)
                }
            }

            // 🔧 CRITICAL FIX: If we have significant content but no complete event,
            // synthesize a complete event to prevent data loss
            if !streamComplete && !completeEventFired && pendingCompleteData == nil && accumulatedAnswer.count > 100 {
                streamingLogger.warning("⚠️ Synthesizing complete event - have \(accumulatedAnswer.count) chars but no complete signal")

                // Already processed dataBuffer above, no additional byte buffer to check

                // Synthesize complete event with what we have
                let syntheticComplete = ResearchSSEEvent.complete(
                    sources: accumulatedSources,
                    metadata: MetadataInfo(
                        processingTime: "unknown",
                        modelUsed: "unknown",
                        costTier: "unknown",
                        tokenUsage: nil
                    ),
                    researchSummary: nil,
                    processingTier: nil,
                    thinkingSummary: nil
                )

                // Process the synthetic complete event
                switch syntheticComplete {
                case .complete(let sources, let metadata, let researchSummary, let processingTier, let thinkingSummary):
                    streamingLogger.warning("✅ Synthetic complete event created with \(sources.count) sources")
                    streamComplete = true

                    let response = ResearchSearchResponse(
                        answer: accumulatedAnswer,
                        tier: detectedTier,
                        processingTier: processingTier,
                        thinkingSummary: thinkingSummary,
                        routing: RoutingInfo(
                            selectedTier: detectedTier,
                            reasoning: "",
                            confidence: 1.0
                        ),
                        sources: sources.map { convertToResearchSource($0) },
                        metadata: metadata,
                        researchSummary: researchSummary,
                        rateLimitInfo: nil
                    )

                    completeEventFired = true
                    onComplete(response)
                default:
                    break
                }
            }

            // Only treat as error if we have no content AND no complete event
            // If we have accumulated content, the stream was likely successful but cut off after sending complete event
            if !streamComplete {
                if accumulatedAnswer.isEmpty {
                    streamingLogger.error("❌ Stream ended with no content")
                    onError(ResearchSearchError.networkError)
                } else if accumulatedAnswer.count <= 100 {
                    // Too little content to be useful
                    streamingLogger.error("❌ Stream ended with insufficient content: \(accumulatedAnswer.count) chars")
                    onError(ResearchSearchError.streamingConnectionLost)
                } else {
                    // This case is now handled above with synthetic complete event
                    streamingLogger.info("✅ Response preserved via synthetic complete event")
                }
            }

        } catch let error as URLError {
            // 🔧 FIX: Distinguish timeout from other network errors
            if error.code == .timedOut {
                streamingLogger.critical("🚨 TIMEOUT after 360s - Answer: \(accumulatedAnswer.count) chars, Sources: \(accumulatedSources.count)")

                // Preserve partial response on timeout
                if !accumulatedAnswer.isEmpty {
                    streamingLogger.warning("⚠️ Preserving partial response from timeout")

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
            } else {
                streamingLogger.error("❌ Network error: \(error.localizedDescription, privacy: .public)")
                onError(ResearchSearchError.networkError)
            }
        } catch {
            streamingLogger.error("❌ Unexpected error: \(error.localizedDescription, privacy: .public)")
            onError(ResearchSearchError.networkError)
        }
    }

    /// Convert SourceResponse to DiabetesSource for compatibility
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

    /// Map CredibilityBadge to source type string
    private func mapBadgeToType(_ badge: CredibilityBadge) -> String {
        switch badge {
        case .peerReviewed: return "pubmed"
        case .clinicalTrial: return "clinical_trial"
        case .expert: return "knowledge_base"
        case .medicalSource: return "medical_source"
        }
    }

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
        // Build request body
        let requestBody: [String: Any] = [
            "messageId": messageId,
            "prompt": prompt,
            "response": response,
            "sources": sources.map { source in
                var sourceDict: [String: Any] = [
                    "id": source.id,
                    "url": source.url,
                    "domain": source.domain,
                    "title": source.title,
                    "snippet": source.snippet,
                    "credibilityBadge": source.credibilityBadge.rawValue
                ]
                if let publishDate = source.publishDate {
                    sourceDict["publishDate"] = publishDate
                }
                if let author = source.author {
                    sourceDict["author"] = author
                }
                return sourceDict
            },
            "tier": tier as Any,
            "rating": rating
        ]

        // Convert to JSON
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            throw ResearchSearchError.invalidRequest
        }

        // Create request
        guard let url = URL(string: self.feedbackURL) else {
            logger.error("Invalid feedback URL: \(self.feedbackURL, privacy: .public)")
            throw ResearchSearchError.invalidRequest
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        request.timeoutInterval = 30

        // Capture request as immutable for concurrency safety
        let immutableRequest = request

        // Make request with retry logic
        try await NetworkRetryHandler.retryWithBackoff(configuration: .quick) {
            let (data, response) = try await URLSession.shared.data(for: immutableRequest)

            // Check HTTP status
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ResearchSearchError.networkError
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                self.logger.error("Feedback submission failed: status \(httpResponse.statusCode, privacy: .public)")
                if let errorString = String(data: data, encoding: .utf8) {
                    self.logger.error("Error response: \(errorString, privacy: .public)")
                }

                // Log critical errors
                if httpResponse.statusCode == 429 {
                    self.logger.critical("🚨 FEEDBACK RATE LIMIT EXCEEDED")
                } else if httpResponse.statusCode == 503 {
                    self.logger.critical("🚨 FEEDBACK QUOTA EXCEEDED")
                }

                throw ResearchSearchError.serverError(statusCode: httpResponse.statusCode)
            }
        }

        logger.info("Feedback submitted for message: \(messageId, privacy: .public)")
    }
}

// MARK: - Response Models

/// Response from the diabetes assistant Cloud Function
struct ResearchSearchResponse: Codable, Sendable {
    // Firebase Callable Functions wrap response in "data" field
    // But URLSession.data() already unwraps it, so we receive the direct response
    let answer: String
    let tier: Int
    let processingTier: String?
    let thinkingSummary: String?
    let routing: RoutingInfo
    let sources: [DiabetesSource]
    let metadata: MetadataInfo
    let researchSummary: ResearchSummary?
    let rateLimitInfo: RateLimitInfo?

    // Convenience properties
    var sourcesFormatted: [SourceResponse] {
        sources.map { source in
            SourceResponse(
                id: UUID().uuidString,
                url: source.url ?? "",
                domain: extractDomain(from: source.url ?? ""),
                title: source.title,
                snippet: "",
                publishDate: nil,
                author: source.authors,
                credibilityBadge: mapSourceType(source.type),
                type: source.type
            )
        }
    }
    var searchStrategy: SearchStrategy {
        if let processingTier {
            switch processingTier {
            case ResponseTier.search.rawValue:
                return .medicalSources
            case ResponseTier.research.rawValue:
                return .deepResearch
            default:
                return .directKnowledge
            }
        }

        switch tier {
        case 2: return .medicalSources
        case 3: return .deepResearch
        default: return .directKnowledge
        }
    }
    var toolsCalled: [String] { [] }
    var confidence: Int { Int(routing.confidence * 100) }

    private func extractDomain(from urlString: String) -> String {
        guard let url = URL(string: urlString),
              let host = url.host else { return "" }
        return host.replacingOccurrences(of: "www.", with: "")
    }

    private func mapSourceType(_ type: String) -> CredibilityBadge {
        switch type {
        case "pubmed": return .peerReviewed
        case "clinical_trial": return .clinicalTrial
        case "knowledge_base": return .expert
        default: return .medicalSource
        }
    }
}

struct RateLimitInfo: Codable, Sendable {
    let remaining: Int
    let resetAt: String
}

struct RoutingInfo: Codable, Sendable {
    let selectedTier: Int
    let reasoning: String
    let confidence: Double
}

struct DiabetesSource: Codable, Sendable {
    let title: String
    let url: String?
    let type: String
    let authors: String?
    let journal: String?
    let year: String?
    let pmid: String?
}

struct MetadataInfo: Codable, Sendable {
    let processingTime: String
    let modelUsed: String
    let costTier: String
    let tokenUsage: TokenUsage?

    struct TokenUsage: Codable, Sendable {
        let input: Int
        let output: Int
        let total: Int
    }
}

struct ResearchSummary: Codable, Sendable {
    let totalStudies: Int
    let pubmedArticles: Int
    let clinicalTrials: Int
    let evidenceQuality: String
}

/// Source from the Cloud Function response
struct SourceResponse: Codable, Sendable {
    let id: String
    let url: String
    let domain: String
    let title: String
    let snippet: String
    let publishDate: String?
    let author: String?
    let credibilityBadge: CredibilityBadge
    let type: String  // "pubmed", "arxiv", "clinical_trial", "medical_source", "knowledge_base"
}

/// Search strategy used
enum SearchStrategy: String, Codable, Sendable {
    case directKnowledge = "direct_knowledge"
    case medicalSources = "medical_sources"
    case deepResearch = "deep_research"
}

/// Credibility badge types
enum CredibilityBadge: String, Codable, Sendable {
    case medicalSource = "medical_source"
    case peerReviewed = "peer_reviewed"
    case clinicalTrial = "clinical_trial"
    case expert = "expert"
}

// MARK: - Errors

enum ResearchSearchError: Error, LocalizedError {
    case invalidRequest
    case networkError
    case serverError(statusCode: Int)
    case decodingError(Error)

    // Firebase-specific errors for research
    case networkTimeout
    case firebaseQuotaExceeded
    case firebaseRateLimitExceeded(retryAfter: Int)
    case firebaseAuthenticationError
    case streamingConnectionLost

    var errorDescription: String? {
        switch self {
        case .invalidRequest:
            return "Geçersiz arama isteği. Lütfen farklı bir soru deneyin.\nInvalid search request. Try a different question."

        case .networkError:
            return "İnternet bağlantısı yok. Lütfen ağ bağlantınızı kontrol edin.\nNo internet connection. Check your network."

        case .networkTimeout:
            return "Arama zaman aşımına uğradı. Tekrar deneyin.\nSearch timed out. Try again."

        case .firebaseQuotaExceeded:
            return "Arama servisi limiti aşıldı. Lütfen birkaç dakika bekleyin.\nSearch quota exceeded. Wait a few minutes."

        case .firebaseRateLimitExceeded(let retryAfter):
            return "Çok fazla arama yapıldı. \(retryAfter) saniye sonra tekrar deneyin.\nToo many searches. Try again in \(retryAfter) seconds."

        case .firebaseAuthenticationError:
            return "Yetkilendirme hatası. Lütfen tekrar giriş yapın.\nAuthentication error. Please sign in again."

        case .streamingConnectionLost:
            return "Canlı yanıt bağlantısı kesildi. Tekrar deneyin.\nStreaming connection lost. Try again."

        case .serverError(let code):
            switch code {
            case 400:
                return "Geçersiz istek. Sorunuzu kontrol edin.\nInvalid request. Check your question."
            case 401, 403:
                return "Yetkilendirme hatası. Tekrar giriş yapın.\nAuthentication error. Sign in again."
            case 404:
                return "Arama servisi bulunamadı. Uygulamayı güncelleyin.\nSearch service not found. Update app."
            case 429:
                return "Çok fazla istek. Birkaç dakika bekleyin.\nToo many requests. Wait a few minutes."
            case 500...599:
                return "Sunucu hatası. Daha sonra tekrar deneyin.\nServer error. Try again later."
            default:
                return "Sunucu hatası (\(code)). Tekrar deneyin.\nServer error (\(code)). Try again."
            }

        case .decodingError:
            return "Arama sonuçları işlenemedi. Tekrar deneyin.\nSearch results could not be processed. Try again."
        }
    }

    var failureReason: String? {
        switch self {
        case .networkError, .networkTimeout:
            return "İnternet bağlantısı problemi"
        case .firebaseQuotaExceeded:
            return "Firebase quota limit exceeded (DEVELOPER: Check Firebase Console - Pro Research uses multiple APIs)"
        case .firebaseRateLimitExceeded:
            return "Firebase rate limit exceeded (DEVELOPER: Exponential backoff active)"
        case .streamingConnectionLost:
            return "SSE streaming connection interrupted"
        case .serverError(let code) where code >= 500:
            return "Firebase Functions backend error (DEVELOPER: Check Cloud Functions logs)"
        case .serverError(429):
            return "Rate limit exceeded"
        case .decodingError:
            return "Response parsing failed"
        default:
            return nil
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .invalidRequest:
            return "Sorunuzu daha açık bir şekilde ifade edin."
        case .networkError, .networkTimeout:
            return "İnternet bağlantınızı kontrol edin ve tekrar deneyin."
        case .firebaseQuotaExceeded:
            return "DEVELOPER: Check Firebase Console for quota usage. Research flow uses PubMed, Clinical Trials, Exa API."
        case .firebaseRateLimitExceeded(let retryAfter):
            return "\(retryAfter) saniye bekleyip tekrar deneyin."
        case .firebaseAuthenticationError:
            return "Uygulamadan çıkış yapıp tekrar giriş yapın."
        case .streamingConnectionLost:
            return "Bağlantı kesildi. Yeni bir arama yapın."
        case .serverError(429):
            return "Birkaç dakika bekleyip tekrar deneyin."
        case .serverError:
            return "Bir süre sonra tekrar deneyin."
        case .decodingError:
            return "Sorununuz devam ederse destek ile iletişime geçin."
        }
    }

    /// Check if error is retryable
    var isRetryable: Bool {
        switch self {
        case .networkError, .networkTimeout, .streamingConnectionLost:
            return true
        case .firebaseRateLimitExceeded:
            return true
        case .serverError(let code):
            return code >= 500 || code == 429
        default:
            return false
        }
    }

    /// Recommended retry delay
    var retryDelay: TimeInterval {
        switch self {
        case .firebaseRateLimitExceeded(let retryAfter):
            return TimeInterval(retryAfter)
        case .firebaseQuotaExceeded:
            return 300.0 // 5 minutes
        case .serverError(429):
            return 60.0
        case .networkTimeout, .streamingConnectionLost:
            return 5.0
        default:
            return 2.0
        }
    }
}

// MARK: - Research Progress Event

/// Progress event for T3 Deep Research tracking
enum ResearchProgressEvent: Sendable {
    case stage(stage: ResearchStage, message: String)
    case apiStarted(api: ResearchAPI, count: Int, message: String)
    case apiCompleted(api: ResearchAPI, count: Int, duration: Double, message: String, success: Bool)
    case progress(fetched: Int, total: Int, message: String)
}
