//
//  ResearchAPIModels.swift
//  balli
//
//  API models for Research Streaming - Response types and error handling
//  Swift 6 strict concurrency compliant
//

import Foundation

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
// NOTE: ResponseTier enum is defined in SearchAnswer.swift to avoid duplication

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
