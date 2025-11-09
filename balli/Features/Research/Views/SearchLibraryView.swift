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
    @State private var selectedThread: SearchAnswer?
    @State private var selectedThreadHighlights: [TextHighlight] = []
    @State private var isShowingDetail = false

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
            .background(Color(.systemBackground))
            .searchable(text: $searchText, prompt: isShowingHighlightsOnly ? "Vurgularda ara" : "Araştırmalarda ara")
            .navigationTitle("Araştırmalar")
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
                            systemImage: isShowingHighlightsOnly ? "highlighter" : "text.quote"
                        )
                        .foregroundStyle(isShowingHighlightsOnly ? ThemeColors.primaryPurple : .primary)
                        .font(.system(size: 15, weight: .medium))
                    }
                }
            }
            .onAppear {
                if isShowingHighlightsOnly {
                    loadHighlights()
                } else {
                    loadThreadsFromPersistence()
                }
            }
            .refreshable {
                if isShowingHighlightsOnly {
                    loadHighlights()
                } else {
                    loadThreadsFromPersistence()
                }
            }
            .navigationDestination(isPresented: $isShowingDetail) {
                if let selectedThread {
                    SearchDetailView(answer: selectedThread, preloadedHighlights: selectedThreadHighlights)
                }
            }
        }
    }

    // MARK: - View Components

    private var fullAnswersView: some View {
        Group {
            if isLoading {
                ProgressView("Yükleniyor...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else if threads.isEmpty {
                ContentUnavailableView(
                    "Henüz araştırma yok",
                    systemImage: "text.quote",
                    description: Text("Yaptığın araştırmalar burada görünecek")
                )
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(ThemeColors.primaryPurple)
                .frame(maxHeight: .infinity)
            } else if filteredThreads.isEmpty {
                ContentUnavailableView(
                    "Sonuç bulunamadı",
                    systemImage: "magnifyingglass",
                    description: Text("'\(searchText)' için eşleşen araştırma bulunamadı")
                )
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(ThemeColors.primaryPurple)
                .frame(maxHeight: .infinity)
            } else {
                List {
                    ForEach(filteredThreads) { thread in
                        SearchAnswerRow(answer: thread)
                            .equatable()
                            .contentShape(Rectangle())
                            .onTapGesture {
                                // Load highlights synchronously before navigation to prevent flicker
                                Task { @MainActor in
                                    do {
                                        let highlights = try await repository.loadHighlights(for: thread.id)
                                        selectedThreadHighlights = highlights
                                        selectedThread = thread
                                        isShowingDetail = true
                                    } catch {
                                        // If loading fails, navigate without highlights
                                        logger.error("Failed to load highlights for navigation: \(error.localizedDescription)")
                                        selectedThreadHighlights = []
                                        selectedThread = thread
                                        isShowingDetail = true
                                    }
                                }
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
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
    }

    private var highlightsOnlyView: some View {
        Group {
            if isLoading {
                ProgressView("Vurgular yükleniyor...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if allHighlights.isEmpty {
                ContentUnavailableView(
                    "Henüz vurgu yok",
                    systemImage: "highlighter",
                    description: Text("Araştırmalarda metin vurguladıkça burada görünecek")
                )
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(ThemeColors.primaryPurple)
                .frame(maxHeight: .infinity)
            } else if filteredHighlights.isEmpty {
                ContentUnavailableView(
                    "Sonuç bulunamadı",
                    systemImage: "magnifyingglass",
                    description: Text("'\(searchText)' için eşleşen vurgu bulunamadı")
                )
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(ThemeColors.primaryPurple)
                .frame(maxHeight: .infinity)
            } else {
                List {
                    ForEach(Array(filteredHighlights.enumerated()), id: \.offset) { index, item in
                        HighlightCard(
                            question: item.question,
                            highlight: item.highlight,
                            answerId: item.answerId,
                            onTap: {
                                // Navigate to full answer with this highlight
                                if let thread = threads.first(where: { $0.id == item.answerId }) {
                                    // Load highlights synchronously before navigation to prevent flicker
                                    Task { @MainActor in
                                        do {
                                            let highlights = try await repository.loadHighlights(for: thread.id)
                                            selectedThreadHighlights = highlights
                                            selectedThread = thread
                                            isShowingDetail = true
                                        } catch {
                                            // If loading fails, navigate without highlights
                                            logger.error("Failed to load highlights for navigation: \(error.localizedDescription)")
                                            selectedThreadHighlights = []
                                            selectedThread = thread
                                            isShowingDetail = true
                                        }
                                    }
                                }
                            }
                        )
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                deleteHighlight(item.highlight.id, from: item.answerId)
                            } label: {
                                Label("Sil", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
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

    private func deleteHighlight(_ highlightId: UUID, from answerId: String) {
        logger.debug("🔍 [DELETE-FLOW] Starting highlight deletion - ID: \(highlightId), Answer: \(answerId)")
        Task {
            do {
                // Delete highlight from repository
                logger.debug("🔍 [DELETE-FLOW] Calling repository.deleteHighlight...")
                try await repository.deleteHighlight(highlightId, from: answerId)
                logger.debug("🔍 [DELETE-FLOW] Repository deletion successful")

                // Update UI by removing from local state
                await MainActor.run {
                    let beforeCount = allHighlights.count
                    withAnimation {
                        allHighlights.removeAll { $0.highlight.id == highlightId }
                    }
                    let afterCount = allHighlights.count
                    logger.debug("🔍 [DELETE-FLOW] UI updated - highlights: \(beforeCount) → \(afterCount)")
                }

                // Post notification to sync with preview views
                logger.debug("🔍 [DELETE-FLOW] Posting highlightDeleted notification...")
                NotificationCenter.default.post(
                    name: Notification.Name.highlightDeleted,
                    object: nil,
                    userInfo: ["highlightId": highlightId, "answerId": answerId]
                )
                logger.debug("🔍 [DELETE-FLOW] Notification posted successfully")

                logger.info("✅ Deleted highlight: \(highlightId) from answer: \(answerId)")
            } catch {
                logger.error("❌ [DELETE-FLOW] Failed to delete highlight: \(error.localizedDescription)")
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
                // Question text (up to 3 lines, wrapped, truncate only if exceeds)
                Text(answer.query)
                    .font(.system(size: ResponsiveDesign.Font.scaledSize(16), weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(3)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)

                // Research type badge (compact, top-right)
                if let tier = answer.tier {
                    ResearchLibraryTierBadge(tier: tier, colorScheme: colorScheme)
                }
            }

            // Answer preview (up to 3 lines, wrapped, last line truncates)
            Text(answer.content)
                .font(.custom("Manrope-Medium", size: ResponsiveDesign.Font.scaledSize(13)))
                .foregroundColor(.secondary)
                .lineLimit(3)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(ResponsiveDesign.Spacing.large)
        .frame(maxWidth: .infinity, alignment: .topLeading)
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

// MARK: - Research Library Tier Badge

/// Tier badge specifically styled for the research library card view
/// Customize appearance here without affecting other tier badge usages
struct ResearchLibraryTierBadge: View {
    let tier: ResponseTier
    let colorScheme: ColorScheme

    // Customizable badge styling parameters
    private let iconSize: CGFloat = 18
    private let horizontalPadding: CGFloat = ResponsiveDesign.Spacing.xSmall
    private let verticalPadding: CGFloat = ResponsiveDesign.Spacing.xxSmall
    private let iconSpacing: CGFloat = 4

    var body: some View {
        HStack(spacing: iconSpacing) {
            Image(systemName: tier.iconName)
                .font(.system(size: ResponsiveDesign.Font.scaledSize(iconSize), weight: .medium))
                .foregroundStyle(tier.badgeForegroundColor(for: colorScheme))
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .background {
            Capsule()
                .fill(tier.badgeBackgroundColor(for: colorScheme))
        }
        .fixedSize()
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
        .navigationTitle("Araştırmalar")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("Full Library View") {
    SearchLibraryView()
}
