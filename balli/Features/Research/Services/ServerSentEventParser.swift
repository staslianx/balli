//
//  ServerSentEventParser.swift
//  balli
//
//  Lightweight Server-Sent Events parser for streaming responses
//  Swift 6 strict concurrency compliant
//

import Foundation
import OSLog

/// SSE event types from the research streaming endpoint
enum ResearchSSEEvent: Sendable {
    case routing(message: String)
    case tierSelected(tier: Int, reasoning: String, confidence: Double)
    case extractingKeywords
    case keywordsExtracted(keywords: String)
    case searching(source: String)
    case searchComplete(count: Int, source: String)
    case sourcesReady(sources: [SourceResponse])
    // NEW: Granular deep research progress events
    case researchStage(stage: ResearchStage, message: String)
    case apiStarted(api: ResearchAPI, count: Int, message: String)
    case apiCompleted(api: ResearchAPI, count: Int, duration: Double, message: String, success: Bool)
    case researchProgress(fetched: Int, total: Int, message: String)
    case generating(message: String)
    case token(content: String)
    case flushTokens  // Backend signal: all tokens sent, ensure display complete before metadata
    case complete(sources: [SourceResponse], metadata: MetadataInfo, researchSummary: ResearchSummary?, processingTier: String?, thinkingSummary: String?)
    case error(message: String)

    // MARK: - Multi-Round Deep Research V2 Events
    case planningStarted(message: String, sequence: Int)
    case planningComplete(plan: ResearchPlan, sequence: Int)
    case roundStarted(round: Int, query: String, estimatedSources: Int, sequence: Int)
    case roundComplete(round: Int, sources: [SourceResponse], status: RoundStatus, sequence: Int)
    case reflectionStarted(round: Int, sequence: Int)
    case reflectionComplete(round: Int, reflection: ResearchReflection, sequence: Int)
    case sourceSelectionStarted(message: String, sequence: Int) // NEW: Stage 7
    case synthesisPreparation(message: String, sequence: Int)   // NEW: Stage 8
    case synthesisStarted(totalRounds: Int, totalSources: Int, sequence: Int)
}

/// Research stage types
enum ResearchStage: String, Sendable {
    case starting = "starting"
    case scanning = "scanning"
    case fetching = "fetching"
    case synthesizing = "synthesizing"
}

/// Research API types
enum ResearchAPI: String, Sendable {
    case pubmed = "pubmed"
    case arxiv = "arxiv"
    case clinicaltrials = "clinicaltrials"
    case exa = "exa"
}

// MARK: - SSE Event Tracker

/// Tracks processed events to prevent duplicates from being processed twice
/// Thread-safe actor for managing event deduplication
actor SSEEventTracker {
    private var processedEvents: Set<String> = []

    /// Check if an event has been processed
    func hasProcessed(eventId: String) -> Bool {
        processedEvents.contains(eventId)
    }

    /// Mark an event as processed
    func markProcessed(eventId: String) {
        processedEvents.insert(eventId)
    }

    /// Generate unique event ID for deduplication
    static func generateEventId(type: String, sequence: Int) -> String {
        "\(type):\(sequence)"
    }

    /// Reset tracker (for new search)
    func reset() {
        processedEvents.removeAll()
    }
}

/// SSE Parser for Firebase Cloud Function research streaming
/// CONCURRENCY FIX: Removed @MainActor - parser should run on background thread for performance
/// All parsing is synchronous and returns Sendable types, safe for any context
class ResearchSSEParser {

    // MARK: - Logger

    private static let logger = AppLoggers.Research.streaming

    /// Parse SSE event from data line
    /// Thread-safe: Returns Sendable types, no mutable state, safe to call from any context
    static func parseEvent(from data: String) -> ResearchSSEEvent? {
        // Handle SSE comment events (e.g., ": flush-tokens", ": keepalive")
        if data.hasPrefix(": ") {
            let comment = String(data.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines)
            if comment == "flush-tokens" {
                return .flushTokens
            }
            // Ignore other comments (keepalive, etc.)
            return nil
        }

        // SSE format: "data: {json}\n\n"
        guard data.hasPrefix("data: ") else { return nil }

        let jsonString = String(data.dropFirst(6)) // Remove "data: " prefix
        guard let jsonData = jsonString.data(using: .utf8) else { return nil }

        do {
            guard let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                  let type = json["type"] as? String else {
                return nil
            }

            switch type {
            case "routing":
                guard let message = json["message"] as? String else { return nil }
                return .routing(message: message)

            case "tier_selected":
                guard let tier = json["tier"] as? Int,
                      let reasoning = json["reasoning"] as? String,
                      let confidence = json["confidence"] as? Double else { return nil }
                return .tierSelected(tier: tier, reasoning: reasoning, confidence: confidence)

            case "extracting_keywords":
                return .extractingKeywords

            case "keywords_extracted":
                guard let keywords = json["keywords"] as? String else { return nil }
                return .keywordsExtracted(keywords: keywords)

            case "searching":
                guard let source = json["source"] as? String else { return nil }
                return .searching(source: source)

            case "search_complete":
                guard let count = json["count"] as? Int,
                      let source = json["source"] as? String else { return nil }
                return .searchComplete(count: count, source: source)

            case "sources_ready":
                guard let sourcesArray = json["sources"] as? [[String: Any]] else { return nil }
                let sources = sourcesArray.compactMap { parseResearchSource($0) }
                return .sourcesReady(sources: sources)

            case "research_stage":
                guard let stageString = json["stage"] as? String,
                      let stage = ResearchStage(rawValue: stageString),
                      let message = json["message"] as? String else { return nil }
                return .researchStage(stage: stage, message: message)

            case "api_started":
                guard let apiString = json["api"] as? String,
                      let api = ResearchAPI(rawValue: apiString),
                      let count = json["count"] as? Int,
                      let message = json["message"] as? String else { return nil }
                return .apiStarted(api: api, count: count, message: message)

            case "api_completed":
                guard let apiString = json["api"] as? String,
                      let api = ResearchAPI(rawValue: apiString),
                      let count = json["count"] as? Int,
                      let duration = json["duration"] as? Double,
                      let message = json["message"] as? String,
                      let success = json["success"] as? Bool else { return nil }
                return .apiCompleted(api: api, count: count, duration: duration, message: message, success: success)

            case "research_progress":
                guard let fetched = json["fetched"] as? Int,
                      let total = json["total"] as? Int,
                      let message = json["message"] as? String else { return nil }
                return .researchProgress(fetched: fetched, total: total, message: message)

            case "generating":
                guard let message = json["message"] as? String else { return nil }
                return .generating(message: message)

            case "token":
                guard let content = json["content"] as? String else { return nil }

                // 🔍 FORENSIC: Detailed token analysis
                // Token parsed - content ready for display

                return .token(content: content)

            case "complete":
                // Parse sources
                guard let sourcesArray = json["sources"] as? [[String: Any]] else { return nil }
                let sources = sourcesArray.compactMap { parseResearchSource($0) }

                // Parse metadata
                guard let metadataDict = json["metadata"] as? [String: Any],
                      let processingTime = metadataDict["processingTime"] as? String,
                      let modelUsed = metadataDict["modelUsed"] as? String,
                      let costTier = metadataDict["costTier"] as? String else { return nil }

                // Parse optional token usage
                var tokenUsage: MetadataInfo.TokenUsage? = nil
                if let tokenUsageDict = metadataDict["tokenUsage"] as? [String: Any],
                   let input = tokenUsageDict["input"] as? Int,
                   let output = tokenUsageDict["output"] as? Int,
                   let total = tokenUsageDict["total"] as? Int {
                    tokenUsage = MetadataInfo.TokenUsage(input: input, output: output, total: total)
                }

                let metadata = MetadataInfo(
                    processingTime: processingTime,
                    modelUsed: modelUsed,
                    costTier: costTier,
                    tokenUsage: tokenUsage
                )

                // Parse optional research summary
                var researchSummary: ResearchSummary? = nil
                if let summaryDict = json["researchSummary"] as? [String: Any],
                   let totalStudies = summaryDict["totalStudies"] as? Int,
                   let pubmedArticles = summaryDict["pubmedArticles"] as? Int,
                   let clinicalTrials = summaryDict["clinicalTrials"] as? Int,
                   let evidenceQuality = summaryDict["evidenceQuality"] as? String {
                    researchSummary = ResearchSummary(
                        totalStudies: totalStudies,
                        pubmedArticles: pubmedArticles,
                        clinicalTrials: clinicalTrials,
                        evidenceQuality: evidenceQuality
                    )
                }

                let processingTier = json["processingTier"] as? String
                let thinkingSummary = json["thinkingSummary"] as? String

                return .complete(
                    sources: sources,
                    metadata: metadata,
                    researchSummary: researchSummary,
                    processingTier: processingTier,
                    thinkingSummary: thinkingSummary
                )

            case "error":
                guard let message = json["message"] as? String else { return nil }
                return .error(message: message)

            // MARK: - Multi-Round Deep Research V2 Events

            case "planning_started":
                let message = json["message"] as? String ?? "Planning research strategy..."
                let sequence = json["sequence"] as? Int ?? 0
                return .planningStarted(message: message, sequence: sequence)

            case "planning_complete":
                guard let planDict = json["plan"] as? [String: Any] else { return nil }
                let sequence = json["sequence"] as? Int ?? 0

                // Parse ResearchPlan - handle both old and new formats
                // Old format: estimatedRounds, strategy, focusAreas
                // New format: subQuestions, primarySourceTypes, estimatedRounds, searchStrategy, complexity

                if let estimatedRounds = planDict["estimatedRounds"] as? Int,
                   let strategy = planDict["strategy"] as? String,
                   let focusAreas = planDict["focusAreas"] as? [String] {
                    // Old format - convert to new format
                    let plan = ResearchPlan(
                        subQuestions: focusAreas, // Use focus areas as questions
                        primarySourceTypes: [.pubmed, .trials], // Default
                        estimatedRounds: estimatedRounds,
                        searchStrategy: strategy,
                        complexity: estimatedRounds >= 3 ? .complex : .moderate
                    )
                    return .planningComplete(plan: plan, sequence: sequence)
                }

                // New format
                guard let subQuestions = planDict["subQuestions"] as? [String],
                      let primarySourceTypesRaw = planDict["primarySourceTypes"] as? [String],
                      let estimatedRounds = planDict["estimatedRounds"] as? Int,
                      let searchStrategy = planDict["searchStrategy"] as? String,
                      let complexityRaw = planDict["complexity"] as? String,
                      let complexity = ResearchPlan.ComplexityLevel(rawValue: complexityRaw) else { return nil }

                let primarySourceTypes = primarySourceTypesRaw.compactMap { ResearchPlan.SourceType(rawValue: $0) }

                let plan = ResearchPlan(
                    subQuestions: subQuestions,
                    primarySourceTypes: primarySourceTypes,
                    estimatedRounds: estimatedRounds,
                    searchStrategy: searchStrategy,
                    complexity: complexity
                )

                return .planningComplete(plan: plan, sequence: sequence)

            case "round_started":
                guard let round = json["round"] as? Int,
                      let query = json["query"] as? String else { return nil }
                let estimatedSources = json["estimatedSources"] as? Int ?? 25
                let sequence = json["sequence"] as? Int ?? round * 10
                return .roundStarted(round: round, query: query, estimatedSources: estimatedSources, sequence: sequence)

            case "round_complete":
                guard let round = json["round"] as? Int else { return nil }

                // Handle different formats
                let sources: [SourceResponse]
                if let sourcesArray = json["sources"] as? [[String: Any]] {
                    sources = sourcesArray.compactMap { parseResearchSource($0) }
                } else {
                    sources = [] // Will be populated by api_completed events
                }

                let statusRaw = json["status"] as? String ?? "complete"
                let status = RoundStatus(rawValue: statusRaw) ?? .complete
                let sequence = json["sequence"] as? Int ?? round * 10 + 5

                return .roundComplete(round: round, sources: sources, status: status, sequence: sequence)

            case "reflection_started":
                guard let round = json["round"] as? Int else { return nil }
                let sequence = json["sequence"] as? Int ?? round * 10 + 6
                return .reflectionStarted(round: round, sequence: sequence)

            case "reflection_complete":
                guard let round = json["round"] as? Int,
                      let reflectionDict = json["reflection"] as? [String: Any] else { return nil }
                let sequence = json["sequence"] as? Int ?? round * 10 + 7

                // Parse ResearchReflection - handle both old and new formats
                // Old format: evidenceQuality, gapsIdentified, shouldContinue, reasoning
                // New format: hasEnoughEvidence, conflictingFindings, criticalGaps, etc.

                if let evidenceQualityStr = reflectionDict["evidenceQuality"] as? String,
                   let gapsIdentified = reflectionDict["gapsIdentified"] as? [String],
                   let shouldContinue = reflectionDict["shouldContinue"] as? Bool,
                   let reasoning = reflectionDict["reasoning"] as? String {
                    // Old format - convert to new format
                    let evidenceQuality: EvidenceQuality = switch evidenceQualityStr {
                    case "high": .high
                    case "limited": .limited
                    default: .moderate
                    }

                    let reflection = ResearchReflection(
                        hasEnoughEvidence: evidenceQualityStr == "high",
                        conflictingFindings: false,
                        criticalGaps: gapsIdentified,
                        suggestedNextQuery: nil,
                        evidenceQuality: evidenceQuality,
                        reasoning: reasoning,
                        shouldContinue: shouldContinue,
                        sequence: sequence
                    )
                    return .reflectionComplete(round: round, reflection: reflection, sequence: sequence)
                }

                // New format
                guard let hasEnoughEvidence = reflectionDict["hasEnoughEvidence"] as? Bool,
                      let conflictingFindings = reflectionDict["conflictingFindings"] as? Bool,
                      let criticalGaps = reflectionDict["criticalGaps"] as? [String],
                      let evidenceQualityRaw = reflectionDict["evidenceQuality"] as? String,
                      let evidenceQuality = EvidenceQuality(rawValue: evidenceQualityRaw),
                      let reasoning = reflectionDict["reasoning"] as? String,
                      let shouldContinue = reflectionDict["shouldContinue"] as? Bool else { return nil }

                let suggestedNextQuery = reflectionDict["suggestedNextQuery"] as? String

                let reflection = ResearchReflection(
                    hasEnoughEvidence: hasEnoughEvidence,
                    conflictingFindings: conflictingFindings,
                    criticalGaps: criticalGaps,
                    suggestedNextQuery: suggestedNextQuery,
                    evidenceQuality: evidenceQuality,
                    reasoning: reasoning,
                    shouldContinue: shouldContinue,
                    sequence: sequence
                )

                return .reflectionComplete(round: round, reflection: reflection, sequence: sequence)

            case "source_selection_started":
                let message = json["message"] as? String ?? "En ilgili kaynakları seçiyorum"
                let sequence = json["sequence"] as? Int ?? 200
                return .sourceSelectionStarted(message: message, sequence: sequence)

            case "synthesis_preparation":
                let message = json["message"] as? String ?? "Bilgileri bir araya getiriyorum"
                let sequence = json["sequence"] as? Int ?? 210
                return .synthesisPreparation(message: message, sequence: sequence)

            case "synthesis_started":
                let totalRounds = json["totalRounds"] as? Int ?? 0
                let totalSources = json["totalSources"] as? Int ?? 0
                let sequence = json["sequence"] as? Int ?? 100
                return .synthesisStarted(totalRounds: totalRounds, totalSources: totalSources, sequence: sequence)

            default:
                return nil
            }

        } catch {
            logger.error("SSE JSON parse error: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// Parse source object from JSON
    private static func parseResearchSource(_ json: [String: Any]) -> SourceResponse? {
        guard let title = json["title"] as? String,
              let type = json["type"] as? String else { return nil }

        let url = json["url"] as? String ?? ""
        let domain = json["domain"] as? String ?? extractDomain(from: url)
        let snippet = json["snippet"] as? String ?? ""
        let publishDate = json["publishDate"] as? String
        let author = json["author"] as? String ?? json["authors"] as? String

        // Map source type to credibility badge
        let badge: CredibilityBadge = switch type {
        case "pubmed": .peerReviewed
        case "clinical_trial": .clinicalTrial
        case "arxiv": .peerReviewed
        case "knowledge_base": .expert
        default: .medicalSource
        }

        return SourceResponse(
            id: UUID().uuidString,
            url: url,
            domain: domain,
            title: title,
            snippet: snippet,
            publishDate: publishDate,
            author: author,
            credibilityBadge: badge,
            type: type
        )
    }

    /// Extract domain from URL
    private static func extractDomain(from urlString: String) -> String {
        guard let url = URL(string: urlString),
              let host = url.host else { return "" }
        return host.replacingOccurrences(of: "www.", with: "")
    }
}
