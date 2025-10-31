//
//  ResearchNetworkService.swift
//  balli
//
//  Network layer for Research API - HTTP requests, URL session configuration, retry logic
//  Swift 6 strict concurrency compliant
//

import Foundation
import OSLog

/// Network service handling HTTP requests for research APIs
/// Actor-isolated for thread-safe network operations
actor ResearchNetworkService {

    // MARK: - Logger

    private let logger = AppLoggers.Research.network

    // MARK: - Configuration

    private let functionURL = "https://us-central1-balli-project.cloudfunctions.net/diabetesAssistant"
    private let streamingURL = "https://us-central1-balli-project.cloudfunctions.net/diabetesAssistantStream"
    private let feedbackURL = "https://us-central1-balli-project.cloudfunctions.net/submitResearchFeedback"

    // MARK: - Request Building

    /// Build JSON request body for search
    func buildSearchRequestBody(query: String, userId: String, conversationHistory: [[String: String]]? = nil) throws -> Data {
        var requestBody: [String: Any] = [
            "question": query,
            "userId": userId
        ]

        // Add conversation history if provided
        if let history = conversationHistory {
            requestBody["conversationHistory"] = history
        }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            throw ResearchSearchError.invalidRequest
        }

        return jsonData
    }

    /// Build JSON request body for non-streaming search
    func buildNonStreamingSearchRequestBody(query: String, userId: String) throws -> Data {
        let requestBody: [String: Any] = [
            "data": [
                "question": query,
                "userId": userId
            ]
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            throw ResearchSearchError.invalidRequest
        }

        return jsonData
    }

    /// Build JSON request body for feedback submission
    func buildFeedbackRequestBody(
        messageId: String,
        prompt: String,
        response: String,
        sources: [SourceResponse],
        tier: String?,
        rating: String
    ) throws -> Data {
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

        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            throw ResearchSearchError.invalidRequest
        }

        return jsonData
    }

    // MARK: - Request Creation

    /// Create URLRequest for non-streaming search
    func createNonStreamingRequest(jsonData: Data) throws -> URLRequest {
        guard let url = URL(string: functionURL) else {
            logger.error("Invalid function URL: \(self.functionURL, privacy: .public)")
            throw ResearchSearchError.invalidRequest
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        request.timeoutInterval = 180 // 3 minutes timeout for Pro tier comprehensive research (4 parallel API calls)

        return request
    }

    /// Create URLRequest for streaming search
    func createStreamingRequest(jsonData: Data) throws -> URLRequest {
        guard let url = URL(string: streamingURL) else {
            throw ResearchSearchError.invalidRequest
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        request.timeoutInterval = 360 // 6 minutes - T3 deep research can take 5+ minutes with 25 sources

        return request
    }

    /// Create URLRequest for feedback submission
    func createFeedbackRequest(jsonData: Data) throws -> URLRequest {
        guard let url = URL(string: feedbackURL) else {
            logger.error("Invalid feedback URL: \(self.feedbackURL, privacy: .public)")
            throw ResearchSearchError.invalidRequest
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        request.timeoutInterval = 30

        return request
    }

    // MARK: - URL Session Configuration

    /// Create URLSession configured for SSE streaming
    func createStreamingURLSession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 360
        configuration.timeoutIntervalForResource = 360
        configuration.waitsForConnectivity = false
        configuration.httpMaximumConnectionsPerHost = 1
        // Ensure connection stays alive for streaming
        configuration.httpAdditionalHeaders = [
            "Connection": "keep-alive",
            "Cache-Control": "no-cache",
            "Accept": "text/event-stream"
        ]

        return URLSession(configuration: configuration)
    }

    // MARK: - HTTP Response Handling

    /// Validate HTTP response status code
    nonisolated func validateHTTPResponse(_ response: URLResponse, data: Data? = nil) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ResearchSearchError.networkError
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            // Log critical Firebase errors prominently for developer debugging
            switch httpResponse.statusCode {
            case 429:
                logger.critical("🚨 RESEARCH RATE LIMIT EXCEEDED - Check Firebase Console (Pro Research uses 4 parallel APIs)")
                throw ResearchSearchError.firebaseRateLimitExceeded(retryAfter: 60)
            case 503:
                logger.critical("🚨 RESEARCH QUOTA EXCEEDED - Check PubMed, Clinical Trials, Exa API quotas")
                throw ResearchSearchError.firebaseQuotaExceeded
            case 401, 403:
                logger.error("🔒 Research Authentication Error - Check Firebase Auth")
                throw ResearchSearchError.firebaseAuthenticationError
            default:
                throw ResearchSearchError.serverError(statusCode: httpResponse.statusCode)
            }
        }
    }

    /// Validate streaming HTTP response
    func validateStreamingResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw ResearchSearchError.networkError
        }
    }

    // MARK: - Non-Streaming Request Execution

    /// Execute non-streaming search request with retry logic
    func executeNonStreamingSearch(request: URLRequest) async throws -> Data {
        // Make request with retry logic
        let (data, _) = try await NetworkRetryHandler.retryWithBackoff(configuration: .network) {
            let (data, response) = try await URLSession.shared.data(for: request)
            try self.validateHTTPResponse(response, data: data)
            return (data, response)
        }

        return data
    }

    /// Execute feedback submission with retry logic
    func submitFeedback(request: URLRequest) async throws {
        try await NetworkRetryHandler.retryWithBackoff(configuration: .quick) {
            let (data, response) = try await URLSession.shared.data(for: request)

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

            return (data, response)
        }
    }

    // MARK: - Response Decoding

    /// Decode non-streaming search response
    func decodeSearchResponse(from data: Data) throws -> ResearchSearchResponse {
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
}
