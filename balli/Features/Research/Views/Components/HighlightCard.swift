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
        // Highlighted text filling entire card (max 8 lines, wrapped, then truncate)
        Text(highlight.text)
            .font(.custom("Manrope-Medium", size: researchFontSize))
            .foregroundStyle(.primary)
            .lineLimit(8)
            .truncationMode(.tail)
            .padding(ResponsiveDesign.Spacing.large)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(highlight.color.swiftUIColor.opacity(0.3))
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
                    color: .cyan,
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
                    color: .purple,
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
