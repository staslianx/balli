import Foundation
import OSLog

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.balli",
    category: "SessionMetadata"
)

/// Service for generating metadata for completed research sessions using Gemini
actor SessionMetadataGenerator {
    // MARK: - Configuration

    private let baseURL: String
    private let urlSession: URLSession

    // MARK: - Request/Response Models

    struct GenerateMetadataRequest: Codable {
        let conversationHistory: [MessageData]
        let userId: String
    }

    struct MessageData: Codable {
        let role: String
        let content: String
    }

    struct GenerateMetadataResponse: Codable {
        let success: Bool
        let data: MetadataData
    }

    struct MetadataData: Codable {
        let title: String
        let summary: String
        let keyTopics: [String]
    }

    // MARK: - Initialization

    init(baseURL: String? = nil) {
        self.baseURL = baseURL ?? NetworkConfiguration.shared.baseURL

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60

        self.urlSession = URLSession(configuration: config)
        logger.info("SessionMetadataGenerator initialized")
    }

    // MARK: - Public API

    /// Generates a title for a completed research session
    /// - Parameter conversationHistory: Array of messages in the session
    /// - Returns: Generated title (e.g., "Dawn Phenomenon ve Somogyi Etkisi Karşılaştırması")
    func generateTitle(_ conversationHistory: [SessionMessageData]) async throws -> String {
        logger.info("Generating title for session with \(conversationHistory.count) messages")

        // TODO: Backend implementation needed
        // Create a Cloud Function endpoint: /generateSessionTitle
        // Input: conversationHistory array
        // Output: { success: bool, data: { title: string } }
        // Use Gemini Flash for fast, cheap metadata generation

        // For now, generate a simple title from first user message
        if let firstMessage = conversationHistory.first(where: { $0.role == .user }) {
            let preview = String(firstMessage.content.prefix(60))
            let title = preview.count < firstMessage.content.count ? "\(preview)..." : preview
            logger.info("Generated fallback title: \(title)")
            return title
        }

        return "Araştırma Oturumu"
    }

    /// Generates a summary of a completed research session
    /// - Parameter conversationHistory: Array of messages in the session
    /// - Returns: Generated summary (2-3 sentences)
    func generateSummary(_ conversationHistory: [SessionMessageData]) async throws -> String {
        logger.info("Generating summary for session with \(conversationHistory.count) messages")

        // TODO: Backend implementation needed
        // Create a Cloud Function endpoint: /generateSessionSummary
        // Input: conversationHistory array
        // Output: { success: bool, data: { summary: string } }
        // Prompt: "Summarize this medical research conversation in 2-3 sentences in Turkish"

        // For now, generate a simple summary
        let userQuestionCount = conversationHistory.filter { $0.role == .user }.count
        let summary = "\(userQuestionCount) soru soruldu ve cevaplandı."
        logger.info("Generated fallback summary: \(summary)")
        return summary
    }

    /// Extracts key topics from a completed research session
    /// - Parameter conversationHistory: Array of messages in the session
    /// - Returns: Array of key topics (e.g., ["Dawn phenomenon", "Somogyi etkisi", "sabah hiperglisemisi"])
    func extractKeyTopics(_ conversationHistory: [SessionMessageData]) async throws -> [String] {
        logger.info("Extracting key topics for session with \(conversationHistory.count) messages")

        // TODO: Backend implementation needed
        // Create a Cloud Function endpoint: /extractSessionKeyTopics
        // Input: conversationHistory array
        // Output: { success: bool, data: { keyTopics: [string] } }
        // Prompt: "Extract 3-5 key medical topics discussed in this conversation"

        // For now, extract simple keywords from user messages
        var topics: Set<String> = []

        for message in conversationHistory where message.role == .user {
            // Simple word extraction (words longer than 5 characters)
            let words = message.content.components(separatedBy: .whitespacesAndNewlines)
            let keywords = words.filter { $0.count > 5 }
            topics.formUnion(keywords.prefix(2))
        }

        let result = Array(topics.prefix(5))
        logger.info("Generated fallback topics: \(result)")
        return result
    }

    /// Generates all metadata (title, summary, key topics) in a single call
    /// - Parameters:
    ///   - conversationHistory: Array of messages in the session
    ///   - userId: User ID for the session
    /// - Returns: Tuple containing title, summary, and key topics
    func generateAllMetadata(_ conversationHistory: [SessionMessageData], userId: String) async throws -> (title: String, summary: String, keyTopics: [String]) {
        logger.info("Generating all metadata for session with \(conversationHistory.count) messages")

        // Convert SessionMessageData to MessageData
        let messages = conversationHistory.map { message in
            MessageData(role: message.role.rawValue, content: message.content)
        }

        // Create request
        let request = GenerateMetadataRequest(
            conversationHistory: messages,
            userId: userId
        )

        // Call backend endpoint
        let response: GenerateMetadataResponse = try await performRequest(
            endpoint: "generateSessionMetadata",
            request: request
        )

        logger.info("✅ Generated metadata - Title: \(response.data.title)")
        logger.info("✅ Key topics: \(response.data.keyTopics.joined(separator: ", "))")

        return (
            title: response.data.title,
            summary: response.data.summary,
            keyTopics: response.data.keyTopics
        )
    }

    // MARK: - Private Helpers (Future Backend Implementation)

    /// Performs request to metadata generation endpoint
    /// NOTE: Not currently used - placeholder for when backend is ready
    private func performRequest<Request: Codable, Response: Codable>(
        endpoint: String,
        request: Request
    ) async throws -> Response {
        guard let url = URL(string: "\(baseURL)/\(endpoint)") else {
            throw MetadataGeneratorError.invalidURL(endpoint: endpoint)
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(request)

        let (data, response) = try await urlSession.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw MetadataGeneratorError.invalidResponse
        }

        guard 200...299 ~= httpResponse.statusCode else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw MetadataGeneratorError.httpError(statusCode: httpResponse.statusCode, message: message)
        }

        let decoder = JSONDecoder()
        return try decoder.decode(Response.self, from: data)
    }
}

// MARK: - Errors

enum MetadataGeneratorError: LocalizedError {
    case invalidURL(endpoint: String)
    case invalidResponse
    case httpError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidURL(let endpoint):
            return "Geçersiz URL: \(endpoint)"
        case .invalidResponse:
            return "Sunucudan geçersiz yanıt alındı"
        case .httpError(let statusCode, let message):
            return "HTTP Hatası \(statusCode): \(message)"
        }
    }
}

// MARK: - Backend Implementation Guide

/*
 TODO: Firebase Cloud Function Implementation

 Create these endpoints in your Cloud Functions:

 1. generateSessionTitle
    - Input: { conversationHistory: [{role: string, content: string}] }
    - LLM Prompt: "Generate a concise Turkish title (max 60 chars) for this medical research conversation"
    - Use: Gemini Flash (cheap, fast)
    - Output: { success: true, data: { title: string } }

 2. generateSessionSummary
    - Input: { conversationHistory: [{role: string, content: string}] }
    - LLM Prompt: "Summarize this Turkish medical conversation in 2-3 sentences"
    - Use: Gemini Flash
    - Output: { success: true, data: { summary: string } }

 3. extractSessionKeyTopics
    - Input: { conversationHistory: [{role: string, content: string}] }
    - LLM Prompt: "Extract 3-5 key medical topics from this conversation (Turkish terms)"
    - Use: Gemini Flash
    - Output: { success: true, data: { keyTopics: [string] } }

 RECOMMENDED: Combine all three into single endpoint:

 4. generateSessionMetadata (BEST APPROACH)
    - Input: { conversationHistory: [{role: string, content: string}] }
    - LLM Prompt: "Analyze this medical research conversation and provide:
                   1. A concise title (max 60 chars)
                   2. A 2-3 sentence summary
                   3. 3-5 key topics discussed
                   Output as JSON: {title: string, summary: string, keyTopics: string[]}"
    - Use: Gemini Flash (single LLM call more efficient than 3 separate)
    - Output: { success: true, data: { title: string, summary: string, keyTopics: [string] } }

 Example Genkit Flow (TypeScript):

 ```typescript
 import { genkit } from 'genkit';
 import { gemini15Flash } from '@genkit-ai/googleai';

 export const generateSessionMetadata = genkit({
   name: 'generateSessionMetadata',
   model: gemini15Flash,
   inputSchema: z.object({
     conversationHistory: z.array(z.object({
       role: z.string(),
       content: z.string()
     }))
   }),
   async handler(request) {
     const conversation = request.conversationHistory
       .map(m => `${m.role === 'user' ? 'Kullanıcı' : 'Asistan'}: ${m.content}`)
       .join('\n\n');

     const prompt = `Aşağıdaki tıbbi araştırma konuşmasını analiz et ve JSON formatında şunları sağla:
     - title: Konuşma için özlü bir başlık (max 60 karakter)
     - summary: 2-3 cümlelik özet
     - keyTopics: Tartışılan 3-5 anahtar konu (array)

     Konuşma:
     ${conversation}

     Sadece JSON döndür, başka açıklama ekleme.`;

     const response = await gemini15Flash.generate(prompt);
     return JSON.parse(response.text);
   }
 });
 ```
*/
