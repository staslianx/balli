//
//  SearchAnswer.swift
//  balli
//
//  Search answer with sources and citations
//  Swift 6 strict concurrency compliant
//

import Foundation
import SwiftUI

/// Complete answer to a search query with sources
struct SearchAnswer: Identifiable, Codable, Sendable, Equatable {
    static func == (lhs: SearchAnswer, rhs: SearchAnswer) -> Bool {
        // Compare content, not just ID, so SwiftUI detects changes
        lhs.id == rhs.id &&
        lhs.content == rhs.content &&
        lhs.sources.count == rhs.sources.count &&
        lhs.thinkingSummary == rhs.thinkingSummary &&
        lhs.processingTierRaw == rhs.processingTierRaw &&
        lhs.completedRounds.count == rhs.completedRounds.count &&
        lhs.imageAttachment == rhs.imageAttachment &&
        lhs.highlights.count == rhs.highlights.count
    }
    let id: String
    let query: String
    let content: String  // Raw text without any formatting
    let sources: [ResearchSource]
    let citations: [InlineCitation]  // Parsed citation positions
    let timestamp: Date
    let tokenCount: Int?
    let tier: ResponseTier?  // Which tier/model was used
    let thinkingSummary: String?
    let processingTierRaw: String?

    // Multi-round research journey
    let completedRounds: [ResearchRound]

    // Image attachment (if user sent a photo with their question)
    let imageAttachment: ImageAttachment?

    // Text highlights (user-created annotations)
    let highlights: [TextHighlight]

    init(
        id: String = UUID().uuidString,
        query: String,
        content: String,
        sources: [ResearchSource],
        citations: [InlineCitation] = [],
        timestamp: Date = Date(),
        tokenCount: Int? = nil,
        tier: ResponseTier? = nil,
        thinkingSummary: String? = nil,
        processingTierRaw: String? = nil,
        completedRounds: [ResearchRound] = [],
        imageAttachment: ImageAttachment? = nil,
        highlights: [TextHighlight] = []
    ) {
        self.id = id
        self.query = query
        self.content = content
        self.sources = sources
        self.citations = citations
        self.timestamp = timestamp
        self.tokenCount = tokenCount
        self.tier = tier
        self.thinkingSummary = thinkingSummary
        self.processingTierRaw = processingTierRaw
        self.completedRounds = completedRounds
        self.imageAttachment = imageAttachment
        self.highlights = highlights
    }
}

/// Response tier indicating which execution mode was used
enum ResponseTier: String, Codable, Sendable {
    case model = "MODEL"
    case search = "HYBRID_RESEARCH"  // T2: Hybrid Research (Flash + 15 Exa sources)
    case research = "DEEP_RESEARCH"  // T3: Deep Research (Pro + 25 sources) - CURRENTLY DISABLED

    init?(tier: Int?, processingTier: String?) {
        if let processingTier, let resolved = ResponseTier(rawValue: processingTier) {
            self = resolved
            return
        }

        guard let tier else { return nil }
        switch tier {
        case 3:
            self = .research
        case 2:
            self = .search
        case 1:
            self = .model
        default:
            return nil
        }
    }

    var label: String {
        switch self {
        case .model:
            return "Hızlı"
        case .search:
            return "Araştırma"
        case .research:
            return "Derin Araştırma"
        }
    }

    var iconName: String {
        switch self {
        case .model:
            return "bolt.fill"
        case .search:
            return "globe"
        case .research:
            return "gyroscope"
        }
    }

    /// Get the color for this research tier
    /// - Parameter colorScheme: Current color scheme (light/dark mode)
    /// - Returns: SwiftUI Color optimized for the current color scheme
    func color(for colorScheme: ColorScheme) -> Color {
        switch self {
        case .model:
            return AppTheme.modelColor(for: colorScheme)
        case .search:
            return AppTheme.webSearchColor(for: colorScheme)
        case .research:
            return AppTheme.deepResearchColor(for: colorScheme)
        }
    }

    /// Background color for the badge with appropriate opacity
    func badgeBackgroundColor(for colorScheme: ColorScheme) -> Color {
        color(for: colorScheme).opacity(0.15)
    }

    /// Foreground color for badge text and icon
    func badgeForegroundColor(for colorScheme: ColorScheme) -> Color {
        color(for: colorScheme)
    }

    var shouldShowBadge: Bool {
        // Always show badge for these tiers per latest UX guidance
        true
    }

    var showsThinkingSummary: Bool {
        switch self {
        case .search, .research:
            return true
        default:
            return false
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let stringValue = try? container.decode(String.self), let resolved = ResponseTier(rawValue: stringValue) {
            self = resolved
            return
        }

        if let intValue = try? container.decode(Int.self) {
            switch intValue {
            case 3:
                self = .research
            case 2:
                self = .search
            case 1:
                self = .model
            default:
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported tier value: \(intValue)")
            }
            return
        }

        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unable to decode ResponseTier")
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// Research mode for different query types
enum ResearchMode: String, CaseIterable, Sendable {
    case all = "Tümü"
    case medical = "Tıbbi"
    case nutrition = "Beslenme"
    case myData = "Verilerim"
    case recipes = "Tarifler"

    var icon: String {
        switch self {
        case .all: return "globe"
        case .medical: return "cross.case"
        case .nutrition: return "leaf"
        case .myData: return "chart.xyaxis.line"
        case .recipes: return "fork.knife"
        }
    }

    var description: String {
        switch self {
        case .all: return "Tüm kaynaklarda ara"
        case .medical: return "Bilimsel tıbbi kaynaklar"
        case .nutrition: return "Beslenme veritabanları"
        case .myData: return "Glükoz ve öğün geçmişin"
        case .recipes: return "Sağlıklı tarifler"
        }
    }
}
