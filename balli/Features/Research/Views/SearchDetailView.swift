//
//  SearchDetailView.swift
//  balli
//
//  Detailed view for a research answer with full content and sources
//  Swift 6 strict concurrency compliant
//

import SwiftUI

struct SearchDetailView: View {
    let answer: SearchAnswer
    @Environment(\.colorScheme) private var colorScheme
    @State private var showBadge = false
    @State private var showSourcePill = false

    private let researchFontSize: Double = 19.0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // Query - matching AnswerCardView style
                Text(answer.query)
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Badges row - tier badge and source pill side by side (matching AnswerCardView)
                HStack(spacing: 8) {
                    // Research type badge
                    if let tier = answer.tier, showBadge {
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
                    if !answer.sources.isEmpty && showSourcePill {
                        CollectiveSourcePill(sources: answer.sources)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .transition(.scale.combined(with: .opacity))
                            .layoutPriority(1)
                    }

                    Spacer()
                }
                .frame(minHeight: 46)
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: showBadge)
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: showSourcePill)

                // Answer Content - matching AnswerCardView style
                if !answer.content.isEmpty {
                    MarkdownText(
                        content: answer.content,
                        fontSize: researchFontSize,
                        enableSelection: true,
                        sourceCount: answer.sources.count,
                        sources: answer.sources,
                        headerFontSize: researchFontSize * 1.88,
                        fontName: "Manrope"
                    )
                    .padding(.vertical, 8)

                    // Action row (matching AnswerCardView)
                    ResearchResponseActionRow(
                        content: answer.content,
                        shareSubject: answer.query
                    )
                }

                Spacer()
                    .frame(height: 32)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Animate badge appearance
            if answer.tier != nil {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7).delay(0.1)) {
                    showBadge = true
                }
            }

            // Animate source pill appearance
            if !answer.sources.isEmpty {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7).delay(0.15)) {
                    showSourcePill = true
                }
            }
        }
    }
}

// Preview removed - sources are now shown via CollectiveSourcePill

#Preview("Research Answer") {
    NavigationStack {
        SearchDetailView(
            answer: SearchAnswer(
                id: "preview-1",
                query: "Tip 2 diyabetinde en iyi tedavi yöntemi nedir?",
                content: """
                **Tip 2 diyabet**, vücudun insülini etkili bir şekilde kullanamadığı kronik bir durumdur.

                ## Tedavi Yöntemleri

                1. **Yaşam Tarzı Değişiklikleri** - Düzenli egzersiz ve sağlıklı beslenme
                2. **İlaç Tedavisi** - Metformin ve diğer antidiyabetik ilaçlar
                3. **Kan Şekeri Takibi** - Düzenli izleme

                > Önemli: Tedavi planınızı değiştirmeden önce doktorunuza danışın.
                """,
                sources: [
                    ResearchSource(
                        id: "1",
                        url: URL(string: "https://example.com")!,
                        domain: "mayoclinic.org",
                        title: "Type 2 Diabetes Management",
                        snippet: "Evidence-based approaches to managing type 2 diabetes...",
                        publishDate: Date(),
                        author: "Mayo Clinic Staff",
                        credibilityBadge: .medicalSource,
                        faviconURL: nil
                    )
                ],
                timestamp: Date(),
                tier: .research
            )
        )
    }
}

#Preview("Search Answer") {
    NavigationStack {
        SearchDetailView(
            answer: SearchAnswer(
                id: "preview-2",
                query: "Swift concurrency nedir?",
                content: """
                **Swift concurrency**, modern asenkron programlama için async/await deseni sağlar.

                ### Temel Özellikler

                - `async/await` söz dizimi
                - Yapılandırılmış eşzamanlılık
                - Actor isolation

                Kod örneği:
                ```swift
                func fetchData() async throws -> Data {
                    let (data, _) = try await URLSession.shared.data(from: url)
                    return data
                }
                ```
                """,
                sources: [],
                timestamp: Date(),
                tier: .search
            )
        )
    }
}
