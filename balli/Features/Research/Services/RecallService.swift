//
//  RecallService.swift
//  balli
//
//  Service for calling backend recall endpoint to generate answers from past sessions
//  Swift 6 strict concurrency compliant
//

import Foundation
import OSLog

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.balli",
    category: "RecallService"
)

/// Service for generating answers from past research sessions
actor RecallService {
    private let baseURL: String
    private let urlSession: URLSession

    init(baseURL: String? = nil) {
        self.baseURL = baseURL ?? NetworkConfiguration.shared.baseURL

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 120

        self.urlSession = URLSession(configuration: config)
        logger.info("RecallService initialized with base URL: \(self.baseURL)")
    }

    // MARK: - Request/Response Models

    struct RecallRequest: Codable {
        let question: String
        let userId: String
        let matchedSessions: [MatchedSessionData]
    }

    struct MatchedSessionData: Codable {
        let sessionId: String
        let title: String?
        let summary: String?
        let keyTopics: [String]
        let createdAt: String // ISO 8601
        let conversationHistory: [MessageData]
        let relevanceScore: Double
    }

    struct MessageData: Codable {
        let role: String
        let content: String
    }

    struct RecallResponse: Codable {
        let success: Bool
        let answer: String?
        let sessionReference: SessionReference?
        let multipleMatches: MultipleMatches?
        let noMatch: NoMatch?
    }

    struct SessionReference: Codable {
        let sessionId: String
        let title: String
        let date: String
    }

    struct MultipleMatches: Codable {
        let sessions: [SessionSummary]
        let message: String
    }

    struct SessionSummary: Codable {
        let sessionId: String
        let title: String
        let date: String
        let summary: String
    }

    struct NoMatch: Codable {
        let message: String
        let suggestNewResearch: Bool
    }

    // MARK: - Public API

    /// Generates an answer from past research session(s)
    func generateAnswer(
        question: String,
        userId: String,
        matchedSessions: [RecallSearchResult],
        fullConversationHistory: [(sessionId: UUID, messages: [SessionMessageData])]
    ) async throws -> RecallResponse {
        logger.info("📚 Generating recall answer for: \(question)")

        // Convert RecallSearchResult to backend format with full conversation
        let sessionData = matchedSessions.compactMap { result -> MatchedSessionData? in
            // Find matching conversation history
            guard let conversationPair = fullConversationHistory.first(where: { $0.sessionId == result.sessionId }) else {
                logger.warning("No conversation history found for session: \(result.sessionId)")
                return nil
            }

            let messages = conversationPair.messages.map { msg in
                MessageData(
                    role: msg.role == .user ? "user" : "model",
                    content: msg.content
                )
            }

            return MatchedSessionData(
                sessionId: result.sessionId.uuidString,
                title: result.title,
                summary: result.summary,
                keyTopics: result.keyTopics,
                createdAt: ISO8601DateFormatter().string(from: result.createdAt),
                conversationHistory: messages,
                relevanceScore: result.relevanceScore
            )
        }

        guard !sessionData.isEmpty else {
            throw RecallServiceError.noConversationHistory
        }

        let request = RecallRequest(
            question: question,
            userId: userId,
            matchedSessions: sessionData
        )

        let response = try await performRequest(request: request)

        logger.info("✅ Recall answer generated successfully")

        return response
    }

    // MARK: - Private Helpers

    private func performRequest(request: RecallRequest) async throws -> RecallResponse {
        guard let url = URL(string: "\(baseURL)/recallFromPastSessions") else {
            throw RecallServiceError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(request)

        logger.debug("📤 Sending recall request to: \(url.absoluteString)")

        let (data, response) = try await urlSession.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw RecallServiceError.invalidResponse
        }

        logger.debug("📥 Received response with status: \(httpResponse.statusCode)")

        guard 200...299 ~= httpResponse.statusCode else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            logger.error("❌ HTTP error \(httpResponse.statusCode): \(message)")
            throw RecallServiceError.httpError(statusCode: httpResponse.statusCode, message: message)
        }

        let decoder = JSONDecoder()
        let recallResponse = try decoder.decode(RecallResponse.self, from: data)

        return recallResponse
    }
}

// MARK: - Errors

enum RecallServiceError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, message: String)
    case noConversationHistory
    case fts5Unavailable

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Geçersiz API adresi"
        case .invalidResponse:
            return "Sunucudan geçersiz yanıt alındı"
        case .httpError(let statusCode, let message):
            return "HTTP Hatası \(statusCode): \(message)"
        case .noConversationHistory:
            return "Oturum konuşma geçmişi bulunamadı"
        case .fts5Unavailable:
            return "Geçmiş araştırma araması şu anda kullanılamıyor"
        }
    }
}
