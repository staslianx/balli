//
//  SourcePillsView.swift
//  balli
//
//  Horizontal scrolling source pills
//  Swift 6 strict concurrency compliant
//

import SwiftUI

struct SourcePillsView: View {
    let sources: [ResearchSource]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(sources.enumerated()), id: \.offset) { index, source in
                    SourcePill(source: source, index: index + 1)
                }
            }
        }
    }
}

struct SourcePill: View {
    let source: ResearchSource
    let index: Int
    @State private var showDetail = false
    @Environment(\.colorScheme) private var colorScheme

    // Truncate title to max characters
    private var truncatedTitle: String {
        let maxLength = 40
        if source.title.count > maxLength {
            return String(source.title.prefix(maxLength)) + "..."
        }
        return source.title
    }

    var body: some View {
        Button {
            showDetail = true
        } label: {
            HStack(spacing: 6) {
                // Numbered badge
                Text("\(index)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.foregroundOnColor(for: colorScheme))
                    .frame(width: 18, height: 18)
                    .background(AppTheme.primaryPurple)
                    .clipShape(Circle())

                // Favicon with background for narrow logos like arXiv
                ZStack {
                    // Background circle for arXiv (transparent logo fix)
                    if source.domain.lowercased().contains("arxiv") {
                        Circle()
                            .fill(AppTheme.overlayBackground(for: colorScheme))
                            .frame(width: 16, height: 16)
                    }

                    AsyncImage(url: source.faviconURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } placeholder: {
                        Image(systemName: "globe")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 12, height: 12)
                }
                .frame(width: 16, height: 16)

                // Article Title (truncated)
                Text(truncatedTitle)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .lineLimit(1)
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background {
                Capsule()
                    .fill(Color(.systemBackground))
            }
            .overlay {
                Capsule()
                    .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showDetail) {
            SourceDetailSheet(source: source, index: index)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - Comprehensive Previews

#Preview("Single Source") {
    SourcePillsView(sources: [PreviewMockData.Research.sampleSources[0]])
        .previewWithPadding()
}

#Preview("Multiple Sources - All Types") {
    SourcePillsView(sources: PreviewMockData.Research.sampleSources)
        .previewWithPadding()
}

#Preview("Three Sources") {
    SourcePillsView(sources: Array(PreviewMockData.Research.sampleSources.prefix(3)))
        .previewWithPadding()
}

#Preview("Long Source Titles") {
    var longTitleSources: [ResearchSource] = []

    if let url1 = URL(string: "https://example.com"),
       let url2 = URL(string: "https://example2.com") {
        longTitleSources = [
            ResearchSource(
                id: "1",
                url: url1,
                domain: "example.com",
                title: "This is an extremely long article title that should be truncated to prevent overflow",
                snippet: nil,
                publishDate: nil,
                author: nil,
                credibilityBadge: .peerReviewed,
                faviconURL: nil
            ),
            ResearchSource(
                id: "2",
                url: url2,
                domain: "example2.com",
                title: "Another incredibly verbose and lengthy title for testing truncation behavior",
                snippet: nil,
                publishDate: nil,
                author: nil,
                credibilityBadge: .government,
                faviconURL: nil
            )
        ]
    }

    return SourcePillsView(sources: longTitleSources)
        .previewWithPadding()
}

#Preview("Dark Mode") {
    SourcePillsView(sources: PreviewMockData.Research.sampleSources)
        .previewWithPadding()
        .preferredColorScheme(.dark)
}

#Preview("Light Mode") {
    SourcePillsView(sources: PreviewMockData.Research.sampleSources)
        .previewWithPadding()
        .preferredColorScheme(.light)
}

#Preview("Individual Source Pill") {
    VStack(spacing: 16) {
        SourcePill(source: PreviewMockData.Research.sampleSources[0], index: 1)
        SourcePill(source: PreviewMockData.Research.sampleSources[1], index: 2)
        SourcePill(source: PreviewMockData.Research.sampleSources[2], index: 3)
    }
    .previewWithPadding()
}
