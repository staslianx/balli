//
//  ResearchResponseMapper.swift
//  balli
//
//  Response transformation and model mapping for research APIs
//  Swift 6 strict concurrency compliant
//

import Foundation

/// Handles response transformation and model mapping
/// Sendable struct for thread-safe transformations
struct ResearchResponseMapper: Sendable {

    // MARK: - Source Conversion

    /// Convert SourceResponse to DiabetesSource for compatibility
    static func convertToResearchSource(_ source: SourceResponse) -> DiabetesSource {
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
    static func mapBadgeToType(_ badge: CredibilityBadge) -> String {
        switch badge {
        case .peerReviewed: return "pubmed"
        case .clinicalTrial: return "clinical_trial"
        case .expert: return "knowledge_base"
        case .medicalSource: return "medical_source"
        }
    }

    /// Map source type string to CredibilityBadge
    static func mapSourceType(_ type: String) -> CredibilityBadge {
        switch type {
        case "pubmed": return .peerReviewed
        case "clinical_trial": return .clinicalTrial
        case "knowledge_base": return .expert
        default: return .medicalSource
        }
    }

    // MARK: - Domain Extraction

    /// Extract domain from URL string
    static func extractDomain(from urlString: String) -> String {
        guard let url = URL(string: urlString),
              let host = url.host else { return "" }
        return host.replacingOccurrences(of: "www.", with: "")
    }

    // MARK: - Response Building

    /// Build complete research response from accumulated data
    static func buildCompleteResponse(
        answer: String,
        tier: Int,
        processingTier: String?,
        thinkingSummary: String?,
        sources: [SourceResponse],
        metadata: MetadataInfo,
        researchSummary: ResearchSummary?
    ) -> ResearchSearchResponse {
        ResearchSearchResponse(
            answer: answer,
            tier: tier,
            processingTier: processingTier,
            thinkingSummary: thinkingSummary,
            routing: RoutingInfo(
                selectedTier: tier,
                reasoning: "",
                confidence: 1.0
            ),
            sources: sources.map { convertToResearchSource($0) },
            metadata: metadata,
            researchSummary: researchSummary,
            rateLimitInfo: nil
        )
    }

    /// Build synthetic response for timeout scenarios
    static func buildTimeoutResponse(
        answer: String,
        tier: Int,
        sources: [SourceResponse]
    ) -> ResearchSearchResponse {
        ResearchSearchResponse(
            answer: answer,
            tier: tier,
            processingTier: nil,
            thinkingSummary: nil,
            routing: RoutingInfo(
                selectedTier: tier,
                reasoning: "",
                confidence: 1.0
            ),
            sources: sources.map { convertToResearchSource($0) },
            metadata: MetadataInfo(
                processingTime: "timeout",
                modelUsed: "unknown",
                costTier: "unknown",
                tokenUsage: nil
            ),
            researchSummary: nil,
            rateLimitInfo: nil
        )
    }

    /// Build synthetic response when complete event is missing
    static func buildSyntheticResponse(
        answer: String,
        tier: Int,
        sources: [SourceResponse]
    ) -> ResearchSearchResponse {
        ResearchSearchResponse(
            answer: answer,
            tier: tier,
            processingTier: nil,
            thinkingSummary: nil,
            routing: RoutingInfo(
                selectedTier: tier,
                reasoning: "",
                confidence: 1.0
            ),
            sources: sources.map { convertToResearchSource($0) },
            metadata: MetadataInfo(
                processingTime: "unknown",
                modelUsed: "unknown",
                costTier: "unknown",
                tokenUsage: nil
            ),
            researchSummary: nil,
            rateLimitInfo: nil
        )
    }

    // MARK: - Feedback Payload Building

    /// Build feedback submission payload
    static func buildFeedbackPayload(
        messageId: String,
        prompt: String,
        response: String,
        sources: [SourceResponse],
        tier: String?,
        rating: String
    ) -> [String: Any] {
        [
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
    }

    // MARK: - Source Formatting

    /// Format DiabetesSource array as SourceResponse array
    static func formatSourcesFromDiabetesSources(_ sources: [DiabetesSource]) -> [SourceResponse] {
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

    // MARK: - Tier Mapping

    /// Get tier name for display
    static func getTierName(for tier: Int) -> String {
        switch tier {
        case 1: return "MODEL (Hızlı)"
        case 2: return "HYBRID_RESEARCH (Araştırma)"
        case 3: return "DEEP_RESEARCH (Derin)"
        default: return "UNKNOWN"
        }
    }

    /// Get search strategy from tier
    static func getSearchStrategy(from tier: Int, processingTier: String?) -> SearchStrategy {
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
}
