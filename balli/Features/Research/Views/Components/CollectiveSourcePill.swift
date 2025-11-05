//
//  CollectiveSourcePill.swift
//  balli
//
//  Collective source pill with overlapping favicons (Perplexity-style)
//  Swift 6 strict concurrency compliant
//

import SwiftUI

struct CollectiveSourcePill: View {
    let sources: [ResearchSource]
    @State private var showSourcesList = false
    @Environment(\.colorScheme) private var colorScheme

    // Get unique sources by domain (max 4)
    private var uniqueSources: [ResearchSource] {
        var seen = Set<String>()
        var unique: [ResearchSource] = []

        for source in sources {
            if !seen.contains(source.domain) {
                seen.insert(source.domain)
                unique.append(source)
                if unique.count >= 4 {
                    break
                }
            }
        }

        return unique
    }

    var body: some View {
        Button {
            showSourcesList = true
        } label: {
            HStack(spacing: 0) {
                // Overlapping favicons using HStack with negative spacing
                HStack(spacing: -10) {
                    ForEach(Array(uniqueSources.enumerated()), id: \.offset) { index, source in
                        FaviconView(source: source, index: index)
                            .zIndex(Double(uniqueSources.count - index)) // Higher z-index for earlier sources
                    }
                }

                // Spacing before text
                Spacer()
                    .frame(width: 10)

                // Source count
                Text("\(sources.count)")
                    .font(.system(size: 14, weight: .semibold, design: .default))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .frame(height: 30)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background {
                Capsule()
                    .fill(Color(.systemBackground))
            }
            .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showSourcesList) {
            SourcesListSheet(sources: sources)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - Favicon View with Lazy Loading

struct FaviconView: View {
    let source: ResearchSource
    let index: Int
    @State private var shouldLoad = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            // Adaptive background circle for ALL logos (prevents transparency issues)
            Circle()
                .fill(AppTheme.overlayBackground(for: colorScheme))
                .frame(width: 22, height: 22)

            if shouldLoad {
                AsyncImage(url: source.faviconURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure, .empty:
                        faviconPlaceholder
                    @unknown default:
                        faviconPlaceholder
                    }
                }
                .frame(width: 22, height: 22)
                .clipShape(Circle())
            } else {
                faviconPlaceholder
                    .frame(width: 22, height: 22)
            }
        }
        .overlay {
            Circle()
                .strokeBorder(Color(.systemBackground), lineWidth: 2)
        }
        .task(priority: .background) {
            // Stagger favicon loading to prevent UI freezing
            // Load with increasing delay based on index
            try? await Task.sleep(for: .milliseconds(index * 100))
            shouldLoad = true
        }
    }

    private var faviconPlaceholder: some View {
        ZStack {
            Circle()
                .fill(AppTheme.primaryPurple.opacity(0.1))

            Text(source.domain.prefix(1).uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.primaryPurple)
        }
    }
}

// MARK: - Preview

#Preview("3 Sources") {
    var sources: [ResearchSource] = []

    if let url1 = URL(string: "https://pubmed.ncbi.nlm.nih.gov/123"),
       let url2 = URL(string: "https://diabetes.org/article"),
       let url3 = URL(string: "https://mayo.edu/research") {
        sources = [
            ResearchSource(
                id: "1",
                url: url1,
                domain: "pubmed.ncbi.nlm.nih.gov",
                title: "Type 2 Diabetes Study",
                snippet: "Research on diabetes management",
                publishDate: Date(),
                author: "Dr. Smith",
                credibilityBadge: .peerReviewed,
                faviconURL: URL(string: "https://pubmed.ncbi.nlm.nih.gov/favicon.ico")
            ),
            ResearchSource(
                id: "2",
                url: url2,
                domain: "diabetes.org",
                title: "Diabetes Guidelines",
                snippet: "Official diabetes guidelines",
                publishDate: Date(),
                author: "ADA",
                credibilityBadge: .medicalSource,
                faviconURL: URL(string: "https://diabetes.org/favicon.ico")
            ),
            ResearchSource(
                id: "3",
                url: url3,
                domain: "mayo.edu",
                title: "Clinical Research",
                snippet: "Mayo Clinic diabetes research",
                publishDate: Date(),
                author: "Mayo Clinic",
                credibilityBadge: .peerReviewed,
                faviconURL: URL(string: "https://mayo.edu/favicon.ico")
            )
        ]
    }

    return CollectiveSourcePill(sources: sources)
        .padding()
}

#Preview("4+ Sources") {
    var sources: [ResearchSource] = []

    if let url1 = URL(string: "https://pubmed.ncbi.nlm.nih.gov/123"),
       let url2 = URL(string: "https://diabetes.org/article"),
       let url3 = URL(string: "https://mayo.edu/research"),
       let url4 = URL(string: "https://ncbi.nlm.nih.gov/pmc"),
       let url5 = URL(string: "https://who.int/diabetes") {
        sources = [
            ResearchSource(
                id: "1",
                url: url1,
                domain: "pubmed.ncbi.nlm.nih.gov",
                title: "Type 2 Diabetes Study",
                snippet: "Research on diabetes management",
                publishDate: Date(),
                author: "Dr. Smith",
                credibilityBadge: .peerReviewed,
                faviconURL: URL(string: "https://pubmed.ncbi.nlm.nih.gov/favicon.ico")
            ),
            ResearchSource(
                id: "2",
                url: url2,
                domain: "diabetes.org",
                title: "Diabetes Guidelines",
                snippet: "Official diabetes guidelines",
                publishDate: Date(),
                author: "ADA",
                credibilityBadge: .medicalSource,
                faviconURL: URL(string: "https://diabetes.org/favicon.ico")
            ),
            ResearchSource(
                id: "3",
                url: url3,
                domain: "mayo.edu",
                title: "Clinical Research",
                snippet: "Mayo Clinic diabetes research",
                publishDate: Date(),
                author: "Mayo Clinic",
                credibilityBadge: .peerReviewed,
                faviconURL: URL(string: "https://mayo.edu/favicon.ico")
            ),
            ResearchSource(
                id: "4",
                url: url4,
                domain: "ncbi.nlm.nih.gov",
                title: "PMC Article",
                snippet: "PubMed Central article",
                publishDate: Date(),
                author: "Various",
                credibilityBadge: .peerReviewed,
                faviconURL: URL(string: "https://ncbi.nlm.nih.gov/favicon.ico")
            ),
            ResearchSource(
                id: "5",
                url: url5,
                domain: "who.int",
                title: "WHO Guidelines",
                snippet: "World Health Organization guidelines",
                publishDate: Date(),
                author: "WHO",
                credibilityBadge: .medicalSource,
                faviconURL: URL(string: "https://who.int/favicon.ico")
            )
        ]
    }

    return CollectiveSourcePill(sources: sources)
        .padding()
}
