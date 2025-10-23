//
//  ResearchJourneyView.swift
//  balli
//
//  Shows the multi-round research journey with expandable rounds
//  Swift 6 strict concurrency compliant
//

import SwiftUI

/// Shows the multi-round research journey with expandable rounds
struct ResearchJourneyView: View {
    let rounds: [ResearchRound]
    @State private var isExpanded = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header button
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "map.circle")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryPurple)

                    Text("Araştırma Süreci (\(rounds.count) tur)")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .buttonStyle(.plain)

            // Expandable content
            if isExpanded {
                VStack(spacing: 12) {
                    ForEach(rounds, id: \.roundNumber) { round in
                        RoundCard(round: round, colorScheme: colorScheme)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.secondary.opacity(0.08))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1)
        }
    }
}

/// Individual round card showing details
private struct RoundCard: View {
    let round: ResearchRound
    let colorScheme: ColorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Round header
            HStack(spacing: 8) {
                Text("Tur \(round.roundNumber)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Spacer()

                // Status badge
                StatusBadge(status: round.status)
            }

            // Query (if available)
            if !round.query.isEmpty {
                Text(round.query)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            // Source breakdown
            HStack(spacing: 8) {
                if round.sourceMix.pubmedCount > 0 {
                    RoundSourcePill(count: round.sourceMix.pubmedCount, icon: "doc.text.fill", color: .blue, label: "PubMed")
                }
                if round.sourceMix.clinicalTrialsCount > 0 {
                    RoundSourcePill(count: round.sourceMix.clinicalTrialsCount, icon: "cross.case.fill", color: .green, label: "Trials")
                }
                if round.sourceMix.arxivCount > 0 {
                    RoundSourcePill(count: round.sourceMix.arxivCount, icon: "book.fill", color: .orange, label: "ArXiv")
                }
                if round.sourceMix.exaCount > 0 {
                    RoundSourcePill(count: round.sourceMix.exaCount, icon: "globe", color: .purple, label: "Exa")
                }
            }

            // Reflection reasoning (if available)
            if let reflection = round.reflection {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Değerlendirme:")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)

                    Text(reflection.reasoning)
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundStyle(.tertiary)
                        .lineLimit(3)
                }
                .padding(.top, 4)
            }
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.secondary.opacity(0.05))
        }
    }
}

/// Status badge for round completion status
private struct StatusBadge: View {
    let status: RoundStatus

    var body: some View {
        let (text, color) = statusInfo

        Text(text)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background {
                Capsule()
                    .fill(color.opacity(0.15))
            }
    }

    private var statusInfo: (String, Color) {
        switch status {
        case .complete:
            return ("Tamamlandı", .green)
        case .partial:
            return ("Kısmi", .orange)
        case .failed:
            return ("Başarısız", .red)
        case .fetching:
            return ("Aranıyor", .blue)
        case .reflecting:
            return ("Değerlendiriliyor", .purple)
        }
    }
}

/// Source count pill for research rounds
private struct RoundSourcePill: View {
    let count: Int
    let icon: String
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
            Text("\(count)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background {
            Capsule()
                .fill(color.opacity(0.12))
        }
    }
}

// MARK: - Previews

#Preview("Research Journey - 3 Rounds") {
    let mockRounds = [
        ResearchRound(
            roundNumber: 1,
            query: "insulin glargine vs degludec efficacy",
            keywords: "insulin, LADA, basal",
            sourceMix: ResearchRound.SourceMix(pubmedCount: 12, arxivCount: 2, clinicalTrialsCount: 3, exaCount: 10),
            results: ResearchRound.RoundResults(exa: [], pubmed: [], arxiv: [], clinicalTrials: []),
            sourcesFound: 27,
            timings: ResearchRound.RoundTimings(keywordExtraction: 1000, fetch: 5000, total: 6000),
            reflection: ResearchReflection(
                hasEnoughEvidence: false,
                conflictingFindings: false,
                criticalGaps: ["LADA-specific data"],
                suggestedNextQuery: "insulin degludec LADA type 1 diabetes",
                evidenceQuality: .moderate,
                reasoning: "Good efficacy data, but need LADA-specific studies",
                shouldContinue: true,
                sequence: 1
            ),
            status: .complete,
            sequence: 1
        ),
        ResearchRound(
            roundNumber: 2,
            query: "insulin degludec LADA type 1 diabetes",
            keywords: "degludec, LADA, type 1",
            sourceMix: ResearchRound.SourceMix(pubmedCount: 8, arxivCount: 1, clinicalTrialsCount: 5, exaCount: 7),
            results: ResearchRound.RoundResults(exa: [], pubmed: [], arxiv: [], clinicalTrials: []),
            sourcesFound: 21,
            timings: ResearchRound.RoundTimings(keywordExtraction: 900, fetch: 4500, total: 5400),
            reflection: ResearchReflection(
                hasEnoughEvidence: true,
                conflictingFindings: false,
                criticalGaps: [],
                suggestedNextQuery: nil,
                evidenceQuality: .high,
                reasoning: "Sufficient LADA-specific evidence found from clinical trials",
                shouldContinue: false,
                sequence: 2
            ),
            status: .complete,
            sequence: 2
        )
    ]

    ResearchJourneyView(rounds: mockRounds)
        .padding()
}
