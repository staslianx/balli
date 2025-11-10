//
//  SearchDetailView.swift
//  balli
//
//  Detailed view for a research answer with full content and sources
//  Swift 6 strict concurrency compliant
//

import SwiftUI
import SwiftData
import OSLog

struct SearchDetailView: View {
    let answer: SearchAnswer
    let preloadedHighlights: [TextHighlight]

    @Environment(\.colorScheme) private var colorScheme
    @State private var showBadge = false
    @State private var showSourcePill = false

    // Highlight management
    @StateObject private var highlightManager: HighlightManager
    @State private var toastMessage: ToastType?
    @State private var showHighlightMenu = false
    @State private var overlappingHighlight: TextHighlight?

    // Note: Toolbar button is always enabled to avoid SwiftUI re-renders
    // that would dismiss the context menu. Instead, we show a toast
    // if user taps highlighter without selecting text first.
    // Selection is stored in TextSelectionStorage.shared (not @State) to prevent re-renders

    private let researchFontSize: Double = 19.0
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.balli", category: "SearchDetailView")

    init(answer: SearchAnswer, preloadedHighlights: [TextHighlight] = []) {
        self.answer = answer
        self.preloadedHighlights = preloadedHighlights

        // Initialize HighlightManager with pre-loaded highlights for instant display
        let initialHighlights = [answer.id: preloadedHighlights]
        _highlightManager = StateObject(wrappedValue: HighlightManager(initialHighlights: initialHighlights))
    }

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
                    SelectableMarkdownText(
                        content: answer.content,
                        fontSize: researchFontSize,
                        sources: answer.sources,
                        headerFontSize: researchFontSize * 1.88,
                        fontName: "Manrope",
                        highlights: highlightManager.highlights[answer.id] ?? []
                        // No onSelectionChange - avoids SwiftUI re-renders that dismiss context menu
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
        .scrollDismissesKeyboard(.interactively)
        .navigationBarTitleDisplayMode(.inline)
        .toast($toastMessage)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    // Color options for adding new highlights
                    ForEach(TextHighlight.HighlightColor.allCases, id: \.self) { color in
                        Button {
                            addHighlight(with: color)
                        } label: {
                            Label {
                                Text(color.displayName)
                            } icon: {
                                Circle()
                                    .fill(color.swiftUIColor)
                                    .frame(width: 16, height: 16)
                            }
                        }
                    }

                    // Show "Remove highlight" option only if selection overlaps with existing highlight
                    if overlappingHighlight != nil {
                        Divider()
                        Button(role: .destructive) {
                            removeHighlightIfOverlapping()
                        } label: {
                            Label("Vurguyu kaldır", systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "highlighter")
                        .foregroundStyle(ThemeColors.primaryPurple)
                        .font(.system(size: 20))
                }
                .simultaneousGesture(
                    TapGesture().onEnded {
                        // Update overlapping highlight state when menu is tapped
                        overlappingHighlight = getOverlappingHighlight()
                    }
                )
            }
        }
        .task {

            // Initialize session manager using storage configuration
            let storageState = ResearchStorageConfiguration.configureStorage()

            switch storageState {
            case .persistent(let container), .inMemory(let container):
                // Storage available - set up session manager
                let metadataGenerator = SessionMetadataGenerator()
                let sessionManager = ResearchSessionManager(
                    modelContainer: container,
                    userId: "demo_user",
                    metadataGenerator: metadataGenerator
                )
                highlightManager.setSessionManager(sessionManager)

                // Load existing highlights
                await highlightManager.loadHighlights(for: answer.id)

            case .unavailable(let error):
                // Storage unavailable - continue without persistence
                logger.error("Storage unavailable in SearchDetailView: \(error.localizedDescription)")
                toastMessage = .error(ResearchStorageConfiguration.degradedModeMessage())
            }
        }
        .onAppear {
            logger.debug("🔍 [DETAIL-VIEW] onAppear triggered for answer: \(answer.id)")

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

            // CRITICAL: Reload highlights from database when view reappears
            // This ensures we always show the latest state after deletions in other views
            Task {
                logger.debug("🔍 [DETAIL-VIEW] Loading highlights for answer: \(answer.id)")
                let beforeCount = highlightManager.highlights[answer.id]?.count ?? 0
                await highlightManager.loadHighlights(for: answer.id)
                let afterCount = highlightManager.highlights[answer.id]?.count ?? 0
                logger.debug("🔍 [DETAIL-VIEW] Highlights loaded - count: \(beforeCount) → \(afterCount)")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name.highlightDeleted)) { notification in
            logger.debug("🔍 [DETAIL-VIEW] Received highlightDeleted notification")

            // When a highlight is deleted from library, sync with preview
            guard let userInfo = notification.userInfo,
                  let highlightId = userInfo["highlightId"] as? UUID,
                  let answerId = userInfo["answerId"] as? String else {
                logger.debug("🔍 [DETAIL-VIEW] Missing userInfo in notification")
                return
            }

            logger.debug("🔍 [DETAIL-VIEW] Notification data - highlightId: \(highlightId), answerId: \(answerId), myAnswerId: \(answer.id)")

            guard answerId == answer.id else {
                logger.debug("🔍 [DETAIL-VIEW] Notification for different answer, ignoring")
                return
            }

            // Remove from highlight manager's cache (already persisted by library)
            let beforeCount = highlightManager.highlights[answer.id]?.count ?? 0
            highlightManager.syncRemoveFromCache(highlightId, from: answer.id)
            let afterCount = highlightManager.highlights[answer.id]?.count ?? 0
            logger.debug("🔍 [DETAIL-VIEW] Synced deletion - highlights: \(beforeCount) → \(afterCount)")
            logger.info("🔄 Synced deleted highlight from library: \(highlightId)")
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name.highlightAdded)) { notification in
            // When a highlight is added in another view, sync with preview
            guard let userInfo = notification.userInfo,
                  let highlight = userInfo["highlight"] as? TextHighlight,
                  let answerId = userInfo["answerId"] as? String,
                  answerId == answer.id else {
                return
            }

            // Add to highlight manager's cache (already persisted by other view)
            highlightManager.syncAddToCache(highlight, to: answer.id)
            logger.info("🔄 Synced added highlight from other view: \(highlight.id)")
        }
    }

    // MARK: - Highlight Actions

    /// Check if current selection overlaps with any existing highlight
    private func getOverlappingHighlight() -> TextHighlight? {
        guard let selection = TextSelectionStorage.shared.getSelection() else {
            return nil
        }

        let selectionRange = selection.range
        let highlights = highlightManager.highlights[answer.id] ?? []


        // Find any highlight that overlaps with the selection
        return highlights.first { highlight in
            let highlightRange = NSRange(location: highlight.startOffset, length: highlight.length)
            let intersection = NSIntersectionRange(selectionRange, highlightRange)
            return intersection.length > 0
        }
    }

    private func addHighlight(with color: TextHighlight.HighlightColor) {
        // Read selection from shared storage (no SwiftUI state)
        guard let selection = TextSelectionStorage.shared.getSelection() else {
            toastMessage = .error("Lütfen metin seçin")
            return
        }

        let highlight = TextHighlight(
            color: color,
            startOffset: selection.range.location,
            length: selection.range.length,
            text: selection.text
        )


        Task {
            do {
                try await highlightManager.addHighlight(
                    highlight,
                    to: answer.id
                )
                toastMessage = .success("Vurgu eklendi")

                // Clear selection after adding highlight
                TextSelectionStorage.shared.clearSelection()
            } catch {
                toastMessage = .error("Vurgu eklenemedi: \(error.localizedDescription)")
            }
        }
    }

    private func removeHighlightIfOverlapping() {
        // Check if there's a selection that overlaps with a highlight
        guard let overlappingHighlight = getOverlappingHighlight() else {
            toastMessage = .error("Vurgulu metin seçin")
            return
        }


        Task {
            do {
                try await highlightManager.deleteHighlight(
                    overlappingHighlight.id,
                    from: answer.id
                )
                toastMessage = .success("Vurgu kaldırıldı")

                // Clear selection after removing highlight
                TextSelectionStorage.shared.clearSelection()
            } catch {
                toastMessage = .error("Vurgu kaldırılamadı: \(error.localizedDescription)")
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
