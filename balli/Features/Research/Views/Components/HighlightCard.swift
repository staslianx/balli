//
//  HighlightCard.swift
//  balli
//
//  Purpose: "Window view" card for displaying highlighted text exactly as it appears in research
//  Matches SearchAnswerRow design with rounded corners and glass effect
//  Swift 6 strict concurrency compliant
//

import SwiftUI

/// Window-style card showing highlighted text exactly as it appears in the research answer
/// Matches SearchAnswerRow card design for visual consistency
struct HighlightCard: View {
    let question: String
    let highlight: TextHighlight
    let answerId: String
    let onTap: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private let cornerRadius: CGFloat = 24
    private let researchFontSize: Double = 19.0

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.Spacing.medium) {
            // Question header - matching SearchAnswerRow style
            Text(question)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            // "Window" showing highlighted text exactly as it appears in research
            // Same font, same size, same rendering as SearchDetailView
            Text(highlight.text)
                .font(.custom("Manrope", size: researchFontSize))
                .foregroundStyle(.primary)
                .padding(ResponsiveDesign.Spacing.medium)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    // Exact same highlight appearance as in SelectableMarkdownText
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(uiColor: highlight.color.uiColor).opacity(0.3))
                )
                .overlay(
                    // Subtle border to enhance "window" effect
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color(uiColor: highlight.color.uiColor).opacity(0.2), lineWidth: 1)
                )

            // Metadata footer - minimal, matching SearchAnswerRow
            HStack(spacing: ResponsiveDesign.Spacing.small) {
                // Date only (no color label)
                Text(highlight.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.tertiary)

                Spacer()

                // Subtle chevron indicating it's tappable
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.quaternary)
            }
        }
        .padding(ResponsiveDesign.Spacing.large)
        .background {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color(.systemBackground))
        }
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .onTapGesture {
            onTap()
        }
    }
}

// MARK: - Preview

#Preview("Highlight Card") {
    ScrollView {
        VStack(spacing: 16) {
            HighlightCard(
                question: "Tip 2 diyabetinde en iyi tedavi yöntemi nedir?",
                highlight: TextHighlight(
                    color: .yellow,
                    startOffset: 0,
                    length: 50,
                    text: "Düzenli egzersiz ve sağlıklı beslenme, kan şekeri kontrolünde en etkili yöntemlerdir."
                ),
                answerId: "preview-1",
                onTap: {}
            )

            HighlightCard(
                question: "Swift concurrency nedir?",
                highlight: TextHighlight(
                    color: .blue,
                    startOffset: 0,
                    length: 30,
                    text: "async/await söz dizimi ile yapılandırılmış eşzamanlılık"
                ),
                answerId: "preview-2",
                onTap: {}
            )

            HighlightCard(
                question: "İnsülin direnci nasıl gelişir?",
                highlight: TextHighlight(
                    color: .orange,
                    startOffset: 0,
                    length: 80,
                    text: "Hücreler insüline karşı duyarsızlaşır ve pankreas daha fazla insülin üretmek zorunda kalır."
                ),
                answerId: "preview-3",
                onTap: {}
            )
        }
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}
