//
//  SearchLibraryView.swift
//  balli
//
//  Saved search history and collections
//  Swift 6 strict concurrency compliant
//

import SwiftUI
import OSLog

struct SearchLibraryView: View {
    @State private var threads: [SearchAnswer] = []
    @State private var isLoading = true
    @State private var searchText = ""
    @State private var isShowingHighlightsOnly = false
    @State private var allHighlights: [(question: String, answerId: String, highlight: TextHighlight)] = []

    private let repository = ResearchHistoryRepository()
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.balli",
        category: "Research"
    )

    /// Filtered threads based on search text (when showing all answers)
    private var filteredThreads: [SearchAnswer] {
        if searchText.isEmpty {
            return threads
        }

        let lowercasedSearch = searchText.lowercased()
        return threads.filter { thread in
            // Search in query text
            thread.query.lowercased().contains(lowercasedSearch) ||
            // Search in answer content
            thread.content.lowercased().contains(lowercasedSearch)
        }
    }

    /// Filtered highlights based on search text (when showing highlights only)
    private var filteredHighlights: [(question: String, answerId: String, highlight: TextHighlight)] {
        if searchText.isEmpty {
            return allHighlights
        }

        let lowercasedSearch = searchText.lowercased()
        return allHighlights.filter { item in
            // Search in question
            item.question.lowercased().contains(lowercasedSearch) ||
            // Search in highlighted text
            item.highlight.text.lowercased().contains(lowercasedSearch)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if isShowingHighlightsOnly {
                    // Highlight-only view
                    highlightsOnlyView
                } else {
                    // Normal full answers view
                    fullAnswersView
                }
            }
            .searchable(text: $searchText, prompt: isShowingHighlightsOnly ? "Vurgularda ara" : "Araştırmalarda ara")
            .navigationTitle("Kütüphane")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            isShowingHighlightsOnly.toggle()
                            if isShowingHighlightsOnly {
                                loadHighlights()
                            }
                        }
                    } label: {
                        Label(
                            isShowingHighlightsOnly ? "Tümünü Göster" : "Sadece Vurgular",
                            systemImage: isShowingHighlightsOnly ? "doc.text" : "highlighter"
                        )
                        .foregroundStyle(isShowingHighlightsOnly ? .purple : .primary)
                        .font(.system(size: 15, weight: .medium))
                    }
                }
            }
            .onAppear {
                loadThreadsFromPersistence()
            }
            .refreshable {
                if isShowingHighlightsOnly {
                    loadHighlights()
                } else {
                    loadThreadsFromPersistence()
                }
            }
        }
    }

    // MARK: - View Components

    private var fullAnswersView: some View {
        List {
            if isLoading {
                ProgressView("Yükleniyor...")
                    .frame(maxWidth: .infinity, alignment: .center)
            } else if threads.isEmpty {
                ContentUnavailableView(
                    "Henüz araştırma yok",
                    systemImage: "book.closed",
                    description: Text("Yaptığın araştırmalar burada görünecek")
                )
            } else if filteredThreads.isEmpty {
                ContentUnavailableView(
                    "Sonuç bulunamadı",
                    systemImage: "magnifyingglass",
                    description: Text("'\(searchText)' için eşleşen araştırma bulunamadı")
                )
            } else {
                Section("Son Araştırmalar") {
                    ForEach(filteredThreads) { thread in
                        NavigationLink(destination: SearchDetailView(answer: thread)) {
                            SearchAnswerRow(answer: thread)
                                .equatable()
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                deleteThread(thread)
                            } label: {
                                Label("Sil", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private var highlightsOnlyView: some View {
        ScrollView {
            if isLoading {
                ProgressView("Vurgular yükleniyor...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if allHighlights.isEmpty {
                ContentUnavailableView(
                    "Henüz vurgu yok",
                    systemImage: "highlighter",
                    description: Text("Araştırmalarda metin vurguladıkça burada görünecek")
                )
                .frame(maxHeight: .infinity)
            } else if filteredHighlights.isEmpty {
                ContentUnavailableView(
                    "Sonuç bulunamadı",
                    systemImage: "magnifyingglass",
                    description: Text("'\(searchText)' için eşleşen vurgu bulunamadı")
                )
                .frame(maxHeight: .infinity)
            } else {
                LazyVStack(spacing: 16) {
                    ForEach(Array(filteredHighlights.enumerated()), id: \.offset) { index, item in
                        HighlightCard(
                            question: item.question,
                            highlight: item.highlight,
                            answerId: item.answerId,
                            onTap: {
                                // Navigate to full answer with this highlight
                                if let thread = threads.first(where: { $0.id == item.answerId }) {
                                    // TODO: Navigate to SearchDetailView with thread
                                }
                            }
                        )
                    }
                }
                .padding()
            }
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Actions

    private func loadThreadsFromPersistence() {
        Task {
            isLoading = true
            do {
                let persistedThreads = try await repository.loadAll()
                await MainActor.run {
                    self.threads = persistedThreads
                    self.isLoading = false
                }
            } catch {
                logger.error("Failed to load threads from persistence: \(error.localizedDescription)")
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }

    private func deleteThread(_ thread: SearchAnswer) {
        Task {
            do {
                // Delete from repository
                try await repository.delete(id: thread.id)

                // Update UI by removing from local state
                await MainActor.run {
                    withAnimation {
                        threads.removeAll { $0.id == thread.id }
                    }
                }

                logger.info("✅ Deleted research thread: \(thread.id)")
            } catch {
                logger.error("Failed to delete thread: \(error.localizedDescription)")
            }
        }
    }

    private func loadHighlights() {
        Task {
            isLoading = true
            do {
                let highlights = try await repository.loadAllHighlights()
                await MainActor.run {
                    self.allHighlights = highlights
                    self.isLoading = false
                }
                logger.info("✅ Loaded \(highlights.count) highlights")
            } catch {
                logger.error("Failed to load highlights: \(error.localizedDescription)")
                await MainActor.run {
                    self.allHighlights = []
                    self.isLoading = false
                }
            }
        }
    }
}

// MARK: - Equatable Row Component

/// PERFORMANCE: Equatable row view prevents unnecessary re-renders when answer data hasn't changed
/// Card-based design matching shopping list cards with glass effect
struct SearchAnswerRow: View, Equatable {
    let answer: SearchAnswer
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.Spacing.small) {
            // Header: Question text with tier badge
            HStack(alignment: .top, spacing: ResponsiveDesign.Spacing.small) {
                // Question text (card title)
                Text(answer.query)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Research type badge (compact, top-right)
                if let tier = answer.tier {
                    HStack(spacing: 4) {
                        Image(systemName: tier.iconName)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(tier.badgeForegroundColor(for: colorScheme))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background {
                        Capsule()
                            .fill(tier.badgeBackgroundColor(for: colorScheme))
                    }
                }
            }

            // Answer preview (3 lines maximum)
            Text(answer.content)
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundColor(.secondary)
                .lineLimit(3)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, ResponsiveDesign.Spacing.medium)
        .padding(.horizontal, ResponsiveDesign.Spacing.medium)
        .frame(maxWidth: .infinity)
        .background(.clear)
        .glassEffect(
            .regular.interactive(),
            in: RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.card, style: .continuous)
        )
    }

    // Only re-render if these properties change
    nonisolated static func == (lhs: SearchAnswerRow, rhs: SearchAnswerRow) -> Bool {
        lhs.answer.id == rhs.answer.id &&
        lhs.answer.query == rhs.answer.query &&
        lhs.answer.content == rhs.answer.content &&
        lhs.answer.tier?.rawValue == rhs.answer.tier?.rawValue
    }
}

// MARK: - Previews

#Preview("Library with Different Tiers") {
    NavigationStack {
        List {
            Section("Son Araştırmalar") {
                // Model tier
                SearchAnswerRow(answer: SearchAnswer(
                    query: "Hızlı bir soru sordum",
                    content: "Model yanıtı",
                    sources: [],
                    tier: .model
                ))

                // Search tier
                SearchAnswerRow(answer: SearchAnswer(
                    query: "Diyabette karbonhidrat sayımı nasıl yapılır?",
                    content: "Web araştırması yanıtı",
                    sources: [],
                    tier: .search
                ))

                // Research tier
                SearchAnswerRow(answer: SearchAnswer(
                    query: "CGM sensörlerinin doğruluğu hakkında bilimsel araştırmalar neler?",
                    content: "Derin araştırma yanıtı",
                    sources: [],
                    tier: .research
                ))
            }
        }
        .navigationTitle("Kütüphane")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("Full Library View") {
    SearchLibraryView()
}
