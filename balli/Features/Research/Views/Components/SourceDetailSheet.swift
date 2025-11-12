//
//  SourceDetailSheet.swift
//  balli
//
//  Detailed source information sheet with iOS 26 Liquid Glass design
//  Swift 6 strict concurrency compliant
//

import SwiftUI

struct SourceDetailSheet: View {
    let source: ResearchSource
    let index: Int
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ResponsiveDesign.Spacing.large) {
                    // Header card with unified citation badge
                    HStack(spacing: ResponsiveDesign.Spacing.medium) {
                        // Unified citation number badge (matches SourceListRow)
                        ZStack {
                            Circle()
                                .fill(AppTheme.primaryPurple.opacity(0.15))
                                .frame(width: 56, height: 56)
                                .glassEffect(.regular.interactive(), in: Circle())

                            Text("\(index)")
                                .font(.system(size: ResponsiveDesign.Font.scaledSize(24), weight: .bold, design: .rounded))
                                .foregroundStyle(AppTheme.primaryPurple)
                        }

                        VStack(alignment: .leading, spacing: ResponsiveDesign.Spacing.xxSmall) {
                            // Domain
                            Text(source.domain)
                                .font(.system(size: ResponsiveDesign.Font.scaledSize(18), weight: .semibold, design: .rounded))
                                .foregroundStyle(.primary)
                        }

                        Spacer()

                        // Favicon
                        AsyncImage(url: source.faviconURL) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            case .failure, .empty:
                                ZStack {
                                    Circle()
                                        .fill(AppTheme.primaryPurple.opacity(0.1))

                                    Text(source.domain.prefix(1).uppercased())
                                        .font(.system(size: ResponsiveDesign.Font.scaledSize(20), weight: .semibold, design: .rounded))
                                        .foregroundStyle(AppTheme.primaryPurple)
                                }
                            @unknown default:
                                EmptyView()
                            }
                        }
                        .frame(width: 56, height: 56)
                        .clipShape(Circle())
                    }
                    .padding(ResponsiveDesign.Spacing.large)
                    .background(.clear)
                    .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.card, style: .continuous))
                    .clipShape(RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.card, style: .continuous))
                    .shadow(color: .black.opacity(0.06), radius: ResponsiveDesign.height(8), x: 0, y: ResponsiveDesign.height(4))

                    // Title card
                    VStack(alignment: .leading, spacing: ResponsiveDesign.Spacing.small) {
                        Text(source.title)
                            .font(.system(size: ResponsiveDesign.Font.scaledSize(24), weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(ResponsiveDesign.Spacing.large)
                    .background(.clear)
                    .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.card, style: .continuous))
                    .clipShape(RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.card, style: .continuous))
                    .shadow(color: .black.opacity(0.06), radius: ResponsiveDesign.height(8), x: 0, y: ResponsiveDesign.height(4))

                    // Metadata card
                    VStack(alignment: .leading, spacing: ResponsiveDesign.Spacing.medium) {
                        if let date = source.publishDate {
                            MetadataRow(icon: "calendar", label: "Yayın Tarihi", value: date.formatted(date: .long, time: .omitted))
                        }

                        if let author = source.author {
                            MetadataRow(icon: "person.fill", label: "Yazar", value: author)
                        }

                        MetadataRow(icon: "link", label: "URL", value: source.url.host() ?? source.url.absoluteString)
                    }
                    .padding(ResponsiveDesign.Spacing.large)
                    .background(.clear)
                    .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.card, style: .continuous))
                    .clipShape(RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.card, style: .continuous))
                    .shadow(color: .black.opacity(0.06), radius: ResponsiveDesign.height(8), x: 0, y: ResponsiveDesign.height(4))

                    // Snippet card
                    if let snippet = source.snippet, !snippet.isEmpty {
                        VStack(alignment: .leading, spacing: ResponsiveDesign.Spacing.medium) {
                            Label("Özet", systemImage: "text.alignleft")
                                .font(.system(size: ResponsiveDesign.Font.scaledSize(16), weight: .semibold, design: .rounded))
                                .foregroundStyle(.secondary)

                            Text(snippet)
                                .font(.system(size: ResponsiveDesign.Font.scaledSize(16), weight: .regular, design: .rounded))
                                .foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(ResponsiveDesign.Spacing.large)
                        .background(.clear)
                        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.card, style: .continuous))
                        .clipShape(RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.card, style: .continuous))
                        .shadow(color: .black.opacity(0.06), radius: ResponsiveDesign.height(8), x: 0, y: ResponsiveDesign.height(4))
                    }

                    // Action buttons
                    VStack(spacing: ResponsiveDesign.Spacing.medium) {
                        // Primary action - Read article
                        Button {
                            openURL(source.url)
                            dismiss()
                        } label: {
                            HStack(spacing: ResponsiveDesign.Spacing.small) {
                                Image(systemName: "safari")
                                    .font(.system(size: ResponsiveDesign.Font.scaledSize(18), weight: .semibold))

                                Text("Makaleyi Oku")
                                    .font(.system(size: ResponsiveDesign.Font.scaledSize(18), weight: .semibold, design: .rounded))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.primaryPurple)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .shadow(color: AppTheme.primaryPurple.opacity(0.3), radius: ResponsiveDesign.height(4), x: 0, y: ResponsiveDesign.height(2))

                        // Secondary action - Share
                        ShareLink(item: source.url, subject: Text(source.title)) {
                            HStack(spacing: ResponsiveDesign.Spacing.small) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: ResponsiveDesign.Font.scaledSize(18), weight: .semibold))

                                Text("Paylaş")
                                    .font(.system(size: ResponsiveDesign.Font.scaledSize(18), weight: .semibold, design: .rounded))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                        }
                        .buttonStyle(.bordered)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    }
                }
                .padding(.horizontal, ResponsiveDesign.Spacing.medium)
                .padding(.vertical, ResponsiveDesign.Spacing.large)
            }
            .background(Color(.systemBackground).ignoresSafeArea())
            .navigationTitle("Kaynak")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Metadata Row Component

struct MetadataRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: ResponsiveDesign.Spacing.medium) {
            Image(systemName: icon)
                .font(.system(size: ResponsiveDesign.Font.scaledSize(18), weight: .semibold))
                .foregroundStyle(AppTheme.primaryPurple)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: ResponsiveDesign.Spacing.xxSmall) {
                Text(label)
                    .font(.system(size: ResponsiveDesign.Font.scaledSize(13), weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.system(size: ResponsiveDesign.Font.scaledSize(15), weight: .regular, design: .rounded))
                    .foregroundStyle(.primary)
            }

            Spacer(minLength: 0)
        }
    }
}

// MARK: - Preview

#Preview("Peer Reviewed Source") {
    if let url = URL(string: "https://pubmed.ncbi.nlm.nih.gov/123456") {
        SourceDetailSheet(
            source: ResearchSource(
                id: "1",
                url: url,
                domain: "pubmed.ncbi.nlm.nih.gov",
                title: "Long-term Effects of Metformin on Type 2 Diabetes Management: A Comprehensive Study",
                snippet: "This comprehensive study examines the long-term efficacy and safety profile of metformin in managing type 2 diabetes mellitus, with particular focus on cardiovascular outcomes and metabolic parameters.",
                publishDate: Date(),
                author: "Dr. Sarah Johnson, Dr. Michael Chen",
                credibilityBadge: .peerReviewed,
                faviconURL: URL(string: "https://pubmed.ncbi.nlm.nih.gov/favicon.ico")
            ),
            index: 3
        )
    }
}

#Preview("Medical Source") {
    if let url = URL(string: "https://diabetes.org/research/article") {
        SourceDetailSheet(
            source: ResearchSource(
                id: "2",
                url: url,
                domain: "diabetes.org",
                title: "Diabetes Management Guidelines 2025",
                snippet: "Updated clinical practice guidelines for comprehensive diabetes care.",
                publishDate: Date(),
                author: "American Diabetes Association",
                credibilityBadge: .medicalSource,
                faviconURL: URL(string: "https://diabetes.org/favicon.ico")
            ),
            index: 1
        )
    }
}

#Preview("Academic Source") {
    if let url = URL(string: "https://science.org/article") {
        SourceDetailSheet(
            source: ResearchSource(
                id: "3",
                url: url,
                domain: "science.org",
                title: "Academic Research on Diabetes Pathophysiology",
                snippet: "Comprehensive academic review of current diabetes research and treatment methodologies.",
                publishDate: Date(),
                author: "University Research Team",
                credibilityBadge: .academic,
                faviconURL: URL(string: "https://science.org/favicon.ico")
            ),
            index: 2
        )
    }
}

#Preview("Government Source") {
    if let url = URL(string: "https://cdc.gov/diabetes") {
        SourceDetailSheet(
            source: ResearchSource(
                id: "4",
                url: url,
                domain: "cdc.gov",
                title: "Official CDC Diabetes Guidelines",
                snippet: "Government health authority recommendations for diabetes management.",
                publishDate: Date(),
                author: "Centers for Disease Control",
                credibilityBadge: .government,
                faviconURL: URL(string: "https://cdc.gov/favicon.ico")
            ),
            index: 4
        )
    }
}
