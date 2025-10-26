//
//  ResearchSearchCoordinator.swift
//  balli
//
//  Handles search orchestration, tier prediction, and API calls
//  Split from MedicalResearchViewModel for better organization
//  Swift 6 strict concurrency compliant
//

import Foundation
import SwiftUI
import OSLog

/// Coordinates search operations including tier prediction and API calls
@MainActor
final class ResearchSearchCoordinator {
    // MARK: - Properties

    private let searchService = ResearchStreamingAPIClient()
    private let logger = AppLoggers.Research.search
    private let currentUserId = "demo_user"

    // MARK: - Search Orchestration

    /// Predict tier based on query complexity and keywords
    /// Shows "Derin Araştırma" upfront for queries likely to be Pro tier
    func predictTier(for query: String) -> ResponseTier? {
        let lowercaseQuery = query.lowercased()

        // Pro tier indicators (medical decisions, treatments, complex questions)
        let proKeywords = [
            "tedavi", "treatment", "ilaç", "medication", "insülin değiştir",
            "geçmeli miyim", "should i switch", "yan etki", "side effect",
            "komplikasyon", "complication", "araştırma", "research",
            "çalışma", "study", "kanıt", "evidence", "karşılaştır", "compare",
            "fark", "difference", "hangisi daha iyi", "which is better",
            "risk", "tehlike", "danger", "güvenli mi", "is it safe",
            "ameliyat", "surgery", "transplant", "transplantasyon",
            "klinik", "clinical", "deneme", "trial"
        ]

        // Check for Pro tier keywords
        let hasProKeyword = proKeywords.contains { lowercaseQuery.contains($0) }

        // Check query length (longer queries often need comprehensive research)
        let isLongQuery = query.count > 60

        // Check for question words that indicate decision-making
        let hasDecisionQuestion = lowercaseQuery.contains("meli") || // "geçmeli", "kullanmalı"
                                  lowercaseQuery.contains("should") ||
                                  lowercaseQuery.contains("hangisi") ||
                                  lowercaseQuery.contains("which")

        // TEMPORARILY DISABLED: Deep Research (T3) tier
        // TODO: Re-enable after fixing deep research issues
        // Predict Research tier (T3) if:
        // - Has Pro keyword + decision question, OR
        // - Has Pro keyword + long query
        // if (hasProKeyword && hasDecisionQuestion) || (hasProKeyword && isLongQuery) {
        //     return .research
        // }

        // Default to Model tier (T1/T2 only - T3 disabled)
        return nil
    }

    /// Submit feedback for an answer
    func submitFeedback(rating: String, answer: SearchAnswer) async {
        logger.info("Submitting \(rating, privacy: .public) feedback for message: \(answer.id, privacy: .public)")

        do {
            // Convert answer sources to SourceResponse format
            let sources = answer.sources.compactMap { source -> SourceResponse? in
                guard let credibilityType = source.credibilityBadge,
                      let credibilityBadge = mapCredibilityType(credibilityType) else {
                    return nil
                }

                // Map credibility badge to type string
                let type: String = switch credibilityBadge {
                case .peerReviewed: "pubmed"
                case .medicalSource: "medical_source"
                case .clinicalTrial: "clinical_trial"
                case .expert: "knowledge_base"
                }

                return SourceResponse(
                    id: source.id,
                    url: source.url.absoluteString,
                    domain: source.domain,
                    title: source.title,
                    snippet: source.snippet ?? "",
                    publishDate: source.publishDate?.formatted(),
                    author: source.author,
                    credibilityBadge: credibilityBadge,
                    type: type
                )
            }

            try await searchService.submitFeedback(
                messageId: answer.id,
                prompt: answer.query,
                response: answer.content,
                sources: sources,
                tier: answer.tier?.rawValue,
                rating: rating
            )

            logger.info("Feedback submitted successfully")
        } catch {
            logger.error("Failed to submit feedback: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Helper Methods

    /// Convert Cloud Function source to app Source model
    func convertToResearchSource(_ response: SourceResponse) -> ResearchSource {
        // Map credibility badge
        let badge: ResearchSource.CredibilityType = switch response.credibilityBadge {
        case .medicalSource:
            .medicalSource
        case .peerReviewed:
            .peerReviewed
        case .clinicalTrial:
            .peerReviewed // Map clinical trial to peer reviewed
        case .expert:
            .medicalSource // Map expert to medical source
        }

        // Handle sources without URLs (like knowledge_base type)
        // Provide fallback URL if URL parsing fails (shouldn't happen in practice)
        let sourceURL: URL
        if let parsedURL = URL(string: response.url) {
            sourceURL = parsedURL
        } else if let fallbackURL = URL(string: "https://balli.app") {
            sourceURL = fallbackURL
            logger.warning("Failed to create URL from: \(response.url, privacy: .public), using fallback")
        } else {
            // Last resort: create a safe placeholder URL
            // This should never happen as "https://balli.app" is a valid URL
            logger.error("Critical: Failed to create any valid URL for source: \(response.url, privacy: .public)")
            return ResearchSource(
                id: response.id,
                url: URL(fileURLWithPath: "/"), // Safe system URL
                domain: response.domain,
                title: response.title,
                snippet: response.snippet,
                publishDate: parseDate(response.publishDate),
                author: response.author,
                credibilityBadge: badge,
                faviconURL: nil
            )
        }

        return ResearchSource(
            id: response.id,
            url: sourceURL,
            domain: response.domain,
            title: response.title,
            snippet: response.snippet,
            publishDate: parseDate(response.publishDate),
            author: response.author,
            credibilityBadge: badge,
            faviconURL: ResearchSource.generateFaviconURL(from: sourceURL)
        )
    }

    /// Parse date string from Cloud Function
    private func parseDate(_ dateString: String?) -> Date? {
        guard let dateString = dateString else { return nil }

        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString) {
            return date
        }

        // Try simple date format (YYYY-MM-DD)
        let simpleDateFormatter = DateFormatter()
        simpleDateFormatter.dateFormat = "yyyy-MM-dd"
        return simpleDateFormatter.date(from: dateString)
    }

    /// Map Source.CredibilityType to CredibilityBadge
    private func mapCredibilityType(_ type: ResearchSource.CredibilityType) -> CredibilityBadge? {
        switch type {
        case .peerReviewed:
            return .peerReviewed
        case .medicalSource:
            return .medicalSource
        case .majorNews:
            return .medicalSource // Map major news to medical source
        case .government:
            return .medicalSource // Map government to medical source
        case .academic:
            return .peerReviewed // Map academic to peer reviewed
        }
    }
}
