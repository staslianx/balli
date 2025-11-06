//
//  AnswerCardView.swift
//  balli
//
//  Answer card with sources and citations (Perplexity-style)
//  Swift 6 strict concurrency compliant
//

import SwiftUI
import OSLog

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.balli",
    category: "AnswerCard"
)

struct AnswerCardView: View {
    let answer: SearchAnswer
    let enableStreaming: Bool
    let isStreamingComplete: Bool
    let isSearchingSources: Bool
    let currentStage: String? // User-friendly research stage message
    let shouldHoldStream: Bool // Flag to delay stream display until stage completes
    let onViewReady: ((String) -> Void)? // Callback to signal view is ready for stages
    let onFeedback: ((String, SearchAnswer) -> Void)? // Callback for feedback
    let onQuestionSelect: ((String) -> Void)? // Callback for follow-up question selection

    @Environment(\.colorScheme) private var colorScheme
    private let researchFontSize: Double = 19.0
    @State private var selectedCitationIndex: Int?
    @State private var showTaskSummary = true
    @State private var progressCalculator = ResearchProgressCalculator() // Track progress without backwards movement
    @State private var showBadge = false // Animate badge appearance
    @State private var showSourcePill = false // Animate source pill appearance

    // Track last stage seen to keep displaying it
    @State private var lastStageBeforeContent: String? = nil

    init(
        answer: SearchAnswer,
        enableStreaming: Bool = true,
        isStreamingComplete: Bool = false,
        isSearchingSources: Bool = false,
        currentStage: String? = nil,
        shouldHoldStream: Bool = false,
        onViewReady: ((String) -> Void)? = nil,
        onFeedback: ((String, SearchAnswer) -> Void)? = nil,
        onQuestionSelect: ((String) -> Void)? = nil
    ) {
        self.answer = answer
        self.enableStreaming = enableStreaming
        self.isStreamingComplete = isStreamingComplete
        self.isSearchingSources = isSearchingSources
        self.currentStage = currentStage
        self.shouldHoldStream = shouldHoldStream
        self.onViewReady = onViewReady
        self.onFeedback = onFeedback
        self.onQuestionSelect = onQuestionSelect
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header section - query, image, badges, thinking summary
            AnswerCardHeaderSection(
                query: answer.query,
                imageAttachment: answer.imageAttachment,
                tier: answer.tier,
                sources: answer.sources,
                thinkingSummary: answer.thinkingSummary,
                showBadge: showBadge,
                showSourcePill: showSourcePill
            )

            // Current research stage - shown during deep research with progress bar
            renderStageCard()


            // Answer content - markdown rendered directly from SSE streaming
            // Raw streaming without character-by-character animation
            if !answer.content.isEmpty {
                StreamingAnswerView(
                    content: answer.content,
                    isStreaming: !isStreamingComplete,
                    sourceCount: answer.sources.count,
                    sources: answer.sources,
                    fontSize: researchFontSize
                )
                .padding(.vertical, 8)
                .transition(.opacity.animation(.easeIn(duration: 0.15)))

                // Action row - only show when streaming is complete
                if isStreamingComplete {
                    ResearchResponseActionRow(
                        content: answer.content,
                        shareSubject: answer.query
                    ) { feedback in
                        guard let feedback else { return }
                        let rating = feedback == .positive ? "up" : "down"
                        onFeedback?(rating, answer)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }

            // Follow-up questions removed per user request
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .onAppear {
            // Signal that view is ready to display stages
            onViewReady?(answer.id)
            logger.debug("📺 [UI-RENDER] View ready signal sent for: \(answer.id)")

            // Animate badge appearance on initial load
            if shouldShowBadge, answer.tier != nil {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7).delay(0.1)) {
                    showBadge = true
                }
            }

            // Animate source pill appearance on initial load
            if !answer.sources.isEmpty {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7).delay(0.15)) {
                    showSourcePill = true
                }
            }
        }
        .onChange(of: answer.tier) { _, newTier in
            // Animate badge when tier becomes available
            if shouldShowBadge, newTier != nil, !showBadge {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    showBadge = true
                }

            }
        }
        .onChange(of: answer.sources.count) { oldCount, newCount in
            // Animate source pill when sources become available
            if newCount > 0, oldCount == 0 {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    showSourcePill = true
                }
            }
        }
        .onChange(of: currentStage) { _, newStage in
            // Track the last stage we saw so we can keep showing it until content arrives
            if let stage = newStage {
                lastStageBeforeContent = stage
                logger.debug("📊 Backend stage: \(stage)")
            }
        }
        .onChange(of: answer.id) { _, _ in
            // Reset visibility for new answers
            showTaskSummary = true
            showBadge = false
            showSourcePill = false
            lastStageBeforeContent = nil
            progressCalculator.reset() // Reset progress tracking for new answer

            // Re-trigger animations for new answer
            if shouldShowBadge, answer.tier != nil {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7).delay(0.1)) {
                    showBadge = true
                }
            }

            if !answer.sources.isEmpty {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7).delay(0.15)) {
                    showSourcePill = true
                }
            }
        }
        .sheet(item: Binding(
            get: {
                MainActor.assumeIsolated {
                    selectedCitationIndex.map { IndexWrapper(index: $0) }
                }
            },
            set: { newValue in
                MainActor.assumeIsolated {
                    selectedCitationIndex = newValue?.index
                }
            }
        )) { wrapper in
            if wrapper.index < answer.sources.count {
                SourceDetailSheet(source: answer.sources[wrapper.index], index: wrapper.index + 1)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: - Computed Properties

    /// Determine if badge should be shown based on tier and sources
    private var shouldShowBadge: Bool {
        answer.tier?.shouldShowBadge ?? false
    }

    /// Render stage card based on tier
    @ViewBuilder
    private func renderStageCard() -> some View {
        // Display backend stages (the REAL stages from coordinator)
        // Key: Keep showing the last stage until content arrives
        let displayStage = currentStage ?? lastStageBeforeContent

        if let stageMessage = displayStage, answer.content.isEmpty {
            ResearchStageStatusCard(
                stageMessage: stageMessage,
                progress: progressCalculator.effectiveProgress(for: stageMessage)
            )
            .padding(.top, 12)
            .transition(.asymmetric(
                insertion: .opacity.animation(.easeInOut(duration: 0.4)),
                removal: .opacity.animation(.easeOut(duration: 0.3))
            ))
            .onAppear {
                logger.debug("🎬 Stage card appeared: \(stageMessage)")
                showTaskSummary = false
            }
        }
    }


    /// Determine if shimmer effect should be active on badge text
    /// Shimmer shows from the beginning until response content appears on UI
    private var shouldShowShimmer: Bool {
        answer.content.isEmpty && // No content visible yet
        !isStreamingComplete &&   // Stream hasn't finished
        answer.tier != nil        // Badge is present
    }

    /// Calculate progress percentage based on current research stage
    /// Maps each stage message to a progress value from 0.0 to 1.0

    // MARK: - Helper Types

    // Helper to make Int identifiable for sheet
    struct IndexWrapper: Identifiable {
        let id = UUID()
        let index: Int
    }
}

// MARK: - Previews

#Preview("Complete Answer with Sources") {
    AnswerCardView(
        answer: SearchAnswer(
            id: "preview-complete",
            query: "What are the health benefits of Mediterranean diet?",
            content: "The Mediterranean diet is associated with numerous health benefits including reduced risk of cardiovascular disease, improved cognitive function, and better metabolic health.",
            sources: [
                ResearchSource(id: "1", url: URL(string: "https://example.com")!, domain: "example.com", title: "Harvard Medical", snippet: nil, publishDate: nil, author: nil, credibilityBadge: nil, faviconURL: nil),
                ResearchSource(id: "2", url: URL(string: "https://example.com")!, domain: "example.com", title: "Mayo Clinic", snippet: nil, publishDate: nil, author: nil, credibilityBadge: nil, faviconURL: nil)
            ],
            tier: .research
        ),
        enableStreaming: false,
        isStreamingComplete: true,
        isSearchingSources: false
    )
    .padding()
}

#Preview("Research Stage with Progress") {
    AnswerCardView(
        answer: SearchAnswer(
            id: "preview-stage",
            query: "How does climate change affect ocean ecosystems?",
            content: "",
            sources: [],
            tier: .research
        ),
        enableStreaming: true,
        isStreamingComplete: false,
        isSearchingSources: false,
        currentStage: "Bilgileri bir araya getiriyorum"
    )
    .padding()
}

#Preview("Dark Mode") {
    AnswerCardView(
        answer: SearchAnswer(
            id: "preview-dark",
            query: "What is Swift concurrency?",
            content: "Swift concurrency provides modern async/await patterns.",
            sources: [],
            tier: .search
        ),
        enableStreaming: false,
        isStreamingComplete: true,
        isSearchingSources: false
    )
    .padding()
    .preferredColorScheme(.dark)
}
