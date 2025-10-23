//
//  ExpandableText.swift
//  balli
//
//  Expandable text component with line limit and MORE button
//  Shows truncated text with expansion control
//

import SwiftUI

/// Text view that shows limited lines with expand/collapse functionality
struct ExpandableText: View {
    let text: String
    let lineLimit: Int
    let font: Font
    let moreText: String

    @State private var isExpanded = false
    @State private var isTruncated = false

    init(
        _ text: String,
        lineLimit: Int = 3,
        font: Font = .body,
        moreText: String = "MORE"
    ) {
        self.text = text
        self.lineLimit = lineLimit
        self.font = font
        self.moreText = moreText
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(text)
                .font(font)
                .lineLimit(isExpanded ? nil : lineLimit)
                .background(
                    // Hidden text to detect truncation
                    Text(text)
                        .font(font)
                        .lineLimit(lineLimit)
                        .background(
                            GeometryReader { geometry in
                                Color.clear.onAppear {
                                    determineTruncation(geometry: geometry)
                                }
                            }
                        )
                        .hidden()
                )

            if isTruncated && !isExpanded {
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isExpanded = true
                    }
                }) {
                    Text(moreText)
                        .font(font.weight(.semibold))
                        .foregroundColor(.primary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func determineTruncation(geometry: GeometryProxy) {
        // Simple heuristic: if text is long, assume it will truncate
        // A more accurate implementation would measure actual rendered height
        let charCount = text.count
        let estimatedLines = charCount / 50 // Rough estimate: ~50 chars per line
        isTruncated = estimatedLines > lineLimit
    }
}

// MARK: - Preview

#Preview("Expandable Text") {
    ScrollView {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Short Text (No Truncation)")
                    .font(.headline)

                ExpandableText(
                    "This is a short text that won't be truncated.",
                    lineLimit: 3
                )
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)

            VStack(alignment: .leading, spacing: 8) {
                Text("Long Text (Will Truncate)")
                    .font(.headline)

                ExpandableText(
                    "Tamarind pulp can be found in jars on the international foods aisle. Or look for tamarind pods in the produce section and peel the sticky pulp away from the seeds. Using peaches adds fresh sweetness to balance the tart tamarind flavor. This tropical-inspired lassi is perfect for hot summer days and brings a unique twist to the traditional yogurt-based drink.",
                    lineLimit: 3,
                    font: .body
                )
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)

            VStack(alignment: .leading, spacing: 8) {
                Text("Recipe Description")
                    .font(.headline)

                ExpandableText(
                    "Tamarind pulp can be found in jars on the international foods aisle. Or look for tamarind pods in the produce section and peel the sticky pulp away from the seeds. Using peaches adds fresh sweetness to balance the tart tamarind flavor.",
                    lineLimit: 2,
                    font: .sfRoundedBody
                )
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
        .padding()
    }
}

#Preview("Dark Mode") {
    ScrollView {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recipe Description")
                .font(.headline)

            ExpandableText(
                "Tamarind pulp can be found in jars on the international foods aisle. Or look for tamarind pods in the produce section and peel the sticky pulp away from the seeds. Using peaches adds fresh sweetness to balance the tart tamarind flavor.",
                lineLimit: 2,
                font: .sfRoundedBody
            )
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .padding()
    }
    .preferredColorScheme(.dark)
}
