//
//  SourcesListSheet.swift
//  balli
//
//  Modal list of all sources for an answer (Perplexity-style)
//  Swift 6 strict concurrency compliant
//

import SwiftUI

struct SourcesListSheet: View {
    let sources: [ResearchSource]
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(Array(sources.enumerated()), id: \.offset) { index, source in
                        SourceListRow(source: source, index: index + 1)
                            .onTapGesture {
                                // Open URL directly - no second sheet
                                openURL(source.url)
                            }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color.appBackground(for: colorScheme).ignoresSafeArea())
            .navigationTitle("Kaynaklar")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Source List Row

struct SourceListRow: View {
    let source: ResearchSource
    let index: Int
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            // Citation number badge
            ZStack {
                Circle()
                    .fill(AppTheme.primaryPurple.opacity(0.1))
                    .frame(width: 28, height: 28)

                Text("\(index)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.primaryPurple)
            }

            // Favicon
            AsyncImage(url: source.faviconURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure, .empty:
                    // Fallback: Use domain initial
                    ZStack {
                        Circle()
                            .fill(Color.secondary.opacity(0.1))

                        Text(source.domain.prefix(1).uppercased())
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                @unknown default:
                    EmptyView()
                }
            }
            .frame(width: 32, height: 32)
            .clipShape(Circle())

            // Source info
            VStack(alignment: .leading, spacing: 4) {
                // Title
                Text(source.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                // Domain
                Text(source.domain)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            // Chevron indicator
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Credibility Badge View

struct CredibilityBadgeView: View {
    let type: ResearchSource.CredibilityType

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .semibold))

            Text(label)
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background {
            Capsule()
                .fill(color.opacity(0.15))
        }
    }

    private var icon: String {
        switch type {
        case .peerReviewed:
            return "checkmark.seal.fill"
        case .medicalSource:
            return "cross.case.fill"
        case .majorNews:
            return "newspaper.fill"
        case .government:
            return "building.columns.fill"
        case .academic:
            return "book.fill"
        }
    }

    private var label: String {
        switch type {
        case .peerReviewed:
            return "Hakemli"
        case .medicalSource:
            return "Tıbbi"
        case .majorNews:
            return "Haber"
        case .government:
            return "Resmi"
        case .academic:
            return "Akademik"
        }
    }

    private var color: Color {
        switch type {
        case .peerReviewed:
            return .blue
        case .medicalSource:
            return .green
        case .majorNews:
            return .orange
        case .government:
            return .purple
        case .academic:
            return .indigo
        }
    }
}

// MARK: - Preview

#Preview {
    var sources: [ResearchSource] = []

    if let url1 = URL(string: "https://pubmed.ncbi.nlm.nih.gov/123"),
       let url2 = URL(string: "https://diabetes.org/article"),
       let url3 = URL(string: "https://mayo.edu/research"),
       let url4 = URL(string: "https://ncbi.nlm.nih.gov/pmc") {
        sources = [
            ResearchSource(
                id: "1",
                url: url1,
                domain: "pubmed.ncbi.nlm.nih.gov",
                title: "Type 2 Diabetes Study: Long-term Effects of Medication",
                snippet: "Research on diabetes management",
                publishDate: Date(),
                author: "Dr. Smith et al.",
                credibilityBadge: .peerReviewed,
                faviconURL: URL(string: "https://pubmed.ncbi.nlm.nih.gov/favicon.ico")
            ),
            ResearchSource(
                id: "2",
                url: url2,
                domain: "diabetes.org",
                title: "Diabetes Guidelines 2025",
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
                title: "Clinical Research on Insulin Therapy",
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
                title: "Comprehensive Review of Diabetes Management",
                snippet: "PubMed Central article",
                publishDate: Date(),
                author: "Various Authors",
                credibilityBadge: .peerReviewed,
                faviconURL: URL(string: "https://ncbi.nlm.nih.gov/favicon.ico")
            )
        ]
    }

    return SourcesListSheet(sources: sources)
}
