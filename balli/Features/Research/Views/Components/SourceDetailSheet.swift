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
                VStack(alignment: .leading, spacing: 24) {
                    // Header card with unified citation badge
                    HStack(spacing: 16) {
                        // Unified citation number badge (matches SourceListRow)
                        ZStack {
                            Circle()
                                .fill(AppTheme.primaryPurple.opacity(0.1))
                                .frame(width: 48, height: 48)

                            Text("\(index)")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundStyle(AppTheme.primaryPurple)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            // Domain
                            Text(source.domain)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.primary)

                            // Credibility badge
                            if let badge = source.credibilityBadge {
                                CredibilityBadgeView(type: badge)
                            }
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
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundStyle(AppTheme.primaryPurple)
                                }
                            @unknown default:
                                EmptyView()
                            }
                        }
                        .frame(width: 48, height: 48)
                        .clipShape(Circle())
                    }
                    .padding(20)
                    .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                    // Title card
                    VStack(alignment: .leading, spacing: 12) {
                        Text(source.title)
                            .font(.system(size: 22, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                    // Metadata card
                    VStack(alignment: .leading, spacing: 16) {
                        if let date = source.publishDate {
                            MetadataRow(icon: "calendar", label: "Yayın Tarihi", value: date.formatted(date: .long, time: .omitted))
                        }

                        if let author = source.author {
                            MetadataRow(icon: "person.fill", label: "Yazar", value: author)
                        }

                        MetadataRow(icon: "link", label: "URL", value: source.url.host() ?? source.url.absoluteString)
                    }
                    .padding(20)
                    .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                    // Snippet card
                    if let snippet = source.snippet, !snippet.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Özet", systemImage: "text.alignleft")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.secondary)

                            Text(snippet)
                                .font(.system(size: 16, weight: .regular, design: .rounded))
                                .foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(20)
                        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }

                    // Action buttons
                    VStack(spacing: 12) {
                        // Primary action - Read article
                        Button {
                            openURL(source.url)
                            dismiss()
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "safari")
                                    .font(.system(size: 16, weight: .semibold))

                                Text("Makaleyi Oku")
                                    .font(.system(size: 17, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.primaryPurple)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                        // Secondary action - Share
                        ShareLink(item: source.url, subject: Text(source.title)) {
                            HStack(spacing: 10) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 16, weight: .semibold))

                                Text("Paylaş")
                                    .font(.system(size: 17, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                        }
                        .buttonStyle(.bordered)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
            .background(Color.appBackground(for: colorScheme).ignoresSafeArea())
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
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(AppTheme.primaryPurple)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(.primary)
            }

            Spacer(minLength: 0)
        }
    }
}

// MARK: - Preview

#Preview("Light Mode") {
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

#Preview("Dark Mode") {
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
        .preferredColorScheme(.dark)
    }
}
