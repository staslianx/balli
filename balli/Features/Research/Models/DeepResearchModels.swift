//
//  DeepResearchModels.swift
//  balli
//
//  Core data models for Deep Research V2 multi-round research system
//  Swift 6 strict concurrency compliant
//

import Foundation

// MARK: - Research Plan

/// Research plan created during planning phase
/// Determines research strategy, source types, and estimated rounds
struct ResearchPlan: Codable, Sendable, Equatable {
    let subQuestions: [String]
    let primarySourceTypes: [SourceType]
    let estimatedRounds: Int  // 1-4
    let searchStrategy: String
    let complexity: ComplexityLevel

    enum SourceType: String, Codable, Sendable {
        case pubmed = "pubmed"
        case trials = "trials"
        case exa = "exa"
        case arxiv = "arxiv"
    }

    enum ComplexityLevel: String, Codable, Sendable {
        case simple = "simple"
        case moderate = "moderate"
        case complex = "complex"
    }
}

// MARK: - Research Round

/// Data from a single research round execution
struct ResearchRound: Codable, Sendable, Equatable {
    let roundNumber: Int  // 1, 2, 3, 4
    let query: String  // Search query used for this round
    let keywords: String  // Extracted English keywords
    let sourceMix: SourceMix
    let results: RoundResults
    let sourcesFound: Int  // Total count from this round
    let timings: RoundTimings
    let reflection: ResearchReflection?  // Reflection after this round
    let status: RoundStatus
    let sequence: Int  // Sequence number for deduplication

    struct SourceMix: Codable, Sendable, Equatable {
        let pubmedCount: Int
        let arxivCount: Int
        let clinicalTrialsCount: Int
        let exaCount: Int
    }

    struct RoundResults: Codable, Sendable, Equatable {
        let exa: [SourceWithMetadata]
        let pubmed: [SourceWithMetadata]
        let arxiv: [SourceWithMetadata]
        let clinicalTrials: [SourceWithMetadata]
    }

    struct RoundTimings: Codable, Sendable, Equatable {
        let keywordExtraction: Double  // milliseconds
        let fetch: Double
        let total: Double
    }
}

// MARK: - Round Status

/// Status of a research round
enum RoundStatus: String, Codable, Sendable {
    case fetching = "fetching"           // Currently fetching sources
    case reflecting = "reflecting"        // Evaluating results
    case complete = "complete"           // Completed successfully
    case partial = "partial"             // Completed with some failures
    case failed = "failed"               // Failed entirely
}

// MARK: - Source With Metadata

/// Source with additional metadata for tracking across rounds
struct SourceWithMetadata: Codable, Sendable, Equatable, Hashable {
    let source: SourceResponse
    let foundInRound: Int
    let originalIndex: Int  // Original index within round results
    let deduplicatedIndex: Int?  // Index after cross-round deduplication

    // For deduplication
    var deduplicationKey: String {
        // Prefer PMID for PubMed articles, fall back to normalized URL
        if let pmid = source.pmid, !pmid.isEmpty {
            return "pmid:\(pmid)"
        }
        return "url:\(source.url.normalizedForDeduplication)"
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(deduplicationKey)
    }

    static func == (lhs: SourceWithMetadata, rhs: SourceWithMetadata) -> Bool {
        lhs.deduplicationKey == rhs.deduplicationKey
    }
}

// MARK: - Research Reflection

/// Reflection on research quality after a round completes
struct ResearchReflection: Codable, Sendable, Equatable {
    let hasEnoughEvidence: Bool
    let conflictingFindings: Bool
    let criticalGaps: [String]  // e.g., "recent_evidence", "mechanistic_studies"
    let suggestedNextQuery: String?  // More specific search terms for next round
    let evidenceQuality: EvidenceQuality
    let reasoning: String  // Why this assessment
    let shouldContinue: Bool  // Proceed to next round?
    let sequence: Int  // Sequence number for deduplication

    /// Create synthetic reflection for timeout scenarios
    static func synthetic(round: Int, reason: String) -> ResearchReflection {
        ResearchReflection(
            hasEnoughEvidence: false,
            conflictingFindings: false,
            criticalGaps: ["timeout"],
            suggestedNextQuery: nil,
            evidenceQuality: .limited,
            reasoning: reason,
            shouldContinue: false,
            sequence: -1
        )
    }
}

// MARK: - Evidence Quality

/// Evidence quality assessment
enum EvidenceQuality: String, Codable, Sendable {
    case high = "high"              // 8+ strong sources, clear consensus
    case moderate = "moderate"       // 5+ sources, general agreement
    case limited = "limited"         // <5 sources or conflicts
    case insufficient = "insufficient" // Unable to answer question
}

// MARK: - Extended SourceResponse

/// Extended SourceResponse with optional PMID for deduplication
extension SourceResponse {
    var pmid: String? {
        // Extract PMID from URL or metadata
        // PubMed URLs: https://pubmed.ncbi.nlm.nih.gov/12345678/
        if url.contains("pubmed.ncbi.nlm.nih.gov") {
            let components = url.components(separatedBy: "/")
            if let pmidString = components.last(where: { !$0.isEmpty && CharacterSet.decimalDigits.isSuperset(of: CharacterSet(charactersIn: $0)) }) {
                return pmidString
            }
        }
        return nil
    }
}

// MARK: - String Extensions for Deduplication

extension String {
    /// Normalize URL for deduplication (remove trailing slashes, query params, fragments)
    var normalizedForDeduplication: String {
        guard let url = URL(string: self) else { return self.lowercased() }

        // Remove query and fragment
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.query = nil
        components?.fragment = nil

        // Remove trailing slash
        var normalized = components?.string?.lowercased() ?? self.lowercased()
        if normalized.hasSuffix("/") {
            normalized = String(normalized.dropLast())
        }

        return normalized
    }
}

// MARK: - Research Summary

/// Summary of all research conducted
struct DeepResearchSummary: Codable, Sendable, Equatable {
    let totalRounds: Int
    let totalSources: Int  // After deduplication
    let pubmedArticles: Int
    let clinicalTrials: Int
    let arxivPapers: Int
    let exaMedicalSources: Int
    let evidenceQuality: EvidenceQuality
    let processingTime: String  // "24.3s"
    let stoppedReason: StopReason?
}

// MARK: - Stop Reason

/// Reason why research stopped
enum StopReason: String, Codable, Sendable {
    case timeout = "timeout"                    // 45s timeout reached
    case roundLimit = "round_limit"             // 4 rounds completed
    case zeroSources = "zero_sources"           // Round 1 had zero sources
    case qualityGate = "quality_gate"           // High quality achieved
    case noProgress = "no_progress"             // Reflection had no next query
    case diminishingReturns = "diminishing_returns" // Last 2 reflections sufficient
    case userCancelled = "user_cancelled"       // User cancelled mid-research

    var userFriendlyMessage: String {
        switch self {
        case .timeout:
            return "Zaman sınırına ulaşıldı"
        case .roundLimit:
            return "Maksimum araştırma turuna ulaşıldı"
        case .zeroSources:
            return "Yeterli kaynak bulunamadı"
        case .qualityGate:
            return "Yüksek kaliteli kanıt elde edildi"
        case .noProgress:
            return "Ek araştırma gerekli değil"
        case .diminishingReturns:
            return "Yeterli kanıt toplandı"
        case .userCancelled:
            return "Kullanıcı tarafından iptal edildi"
        }
    }
}

// MARK: - Citation Mapping

/// Maps original citation indices to deduplicated indices
struct CitationMapping: Sendable {
    // Key: "round-originalIndex", Value: deduplicated index
    private let mapping: [String: Int]

    init(sourcesByRound: [[SourceWithMetadata]], deduplicatedSources: [SourceWithMetadata]) {
        var map: [String: Int] = [:]

        // Build mapping from original round-index to deduplicated index
        for round in sourcesByRound {
            for source in round {
                let key = "\(source.foundInRound)-\(source.originalIndex)"
                if let dedupIndex = deduplicatedSources.firstIndex(where: { $0.deduplicationKey == source.deduplicationKey }) {
                    map[key] = dedupIndex
                }
            }
        }

        self.mapping = map
    }

    /// Get deduplicated index for a citation from a specific round
    func deduplicatedIndex(round: Int, originalIndex: Int) -> Int? {
        let key = "\(round)-\(originalIndex)"
        return mapping[key]
    }
}

