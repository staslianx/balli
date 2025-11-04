//
//  AnswerCardHeaderSection.swift
//  balli
//
//  Header section for AnswerCardView
//  Displays query, image attachment, research badges, and thinking summary
//  Swift 6 strict concurrency compliant
//

import SwiftUI

/// Header section for research answer cards
/// Consolidates query text, image attachment, tier badge, source pill, and thinking summary
struct AnswerCardHeaderSection: View {
    // MARK: - Properties

    let query: String
    let imageAttachment: ImageAttachment?
    let tier: ResponseTier?
    let sources: [ResearchSource]
    let thinkingSummary: String?
    let showBadge: Bool
    let showSourcePill: Bool

    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Computed Properties

    /// Determine if badge should be visible based on tier and state
    private var shouldShowBadge: Bool {
        tier != nil
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Query - positioned right under toolbar
            Text(query)
                .font(.system(size: 30, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Image attachment (if present) - show thumbnail below question
            if let imageAttachment = imageAttachment,
               let thumbnail = imageAttachment.thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
            }

            // Badges row - tier badge and source pill side by side
            // Reserve minimum height to prevent layout shift when sources appear
            HStack(spacing: 8) {
                // Research type badge - matched to source pill design
                // RULES:
                // 1. Model tiers (T1/T2) → CPU icon + "Model"
                // 2. Web Search (T2+) → Globe icon + "Web'de Arama"
                // 3. Deep Research (T3) → Gyroscope icon + "Derin Araştırma"
                if shouldShowBadge, let tier = tier, showBadge {
                    HStack(spacing: 8) {
                        Image(systemName: tier.iconName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(tier.badgeForegroundColor(for: colorScheme))
                        Text(tier.label)
                            .font(.system(size: 14, weight: .semibold, design: .default))
                            .foregroundStyle(tier.badgeForegroundColor(for: colorScheme))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    .frame(height: 30)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background {
                        Capsule()
                            .fill(Color(.systemBackground))
                    }
                    .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .transition(.scale.combined(with: .opacity))
                    .layoutPriority(1)
                }

                // Collective source pill: only show when there are actual sources
                if !sources.isEmpty && showSourcePill {
                    CollectiveSourcePill(sources: sources)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .transition(.scale.combined(with: .opacity))
                        .layoutPriority(1)
                }

                Spacer()
            }
            .frame(minHeight: 46) // Reserve vertical space to prevent shift when pill appears
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: showBadge)
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: showSourcePill)

            // Thinking summary - shown for tiers that support it
            if let tier = tier,
               tier.showsThinkingSummary,
               let thinkingSummary = thinkingSummary?.trimmingCharacters(in: .whitespacesAndNewlines),
               !thinkingSummary.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text(thinkingSummary)
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(4)
                }
            }
        }
    }
}
