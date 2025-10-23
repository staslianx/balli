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
    let onFeedback: ((String, SearchAnswer) -> Void)? // Callback for feedback
    let onQuestionSelect: ((String) -> Void)? // Callback for follow-up question selection

    @Environment(\.colorScheme) private var colorScheme
    private let researchFontSize: Double = 19.0
    @State private var selectedCitationIndex: Int?
    @State private var showTaskSummary = true
    @State private var maxProgressReached: Double = 0.0 // Track highest progress to prevent backwards movement
    @State private var showBadge = false // Animate badge appearance
    @State private var showSourcePill = false // Animate source pill appearance

    init(
        answer: SearchAnswer,
        enableStreaming: Bool = true,
        isStreamingComplete: Bool = false,
        isSearchingSources: Bool = false,
        currentStage: String? = nil,
        shouldHoldStream: Bool = false,
        onFeedback: ((String, SearchAnswer) -> Void)? = nil,
        onQuestionSelect: ((String) -> Void)? = nil
    ) {
        self.answer = answer
        self.enableStreaming = enableStreaming
        self.isStreamingComplete = isStreamingComplete
        self.isSearchingSources = isSearchingSources
        self.currentStage = currentStage
        self.shouldHoldStream = shouldHoldStream
        self.onFeedback = onFeedback
        self.onQuestionSelect = onQuestionSelect
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Query - positioned right under toolbar
            Text(answer.query)
                .font(.system(size: 30, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Badges row - tier badge and source pill side by side
            // Reserve minimum height to prevent layout shift when sources appear
            HStack(spacing: 8) {
                // Research type badge - matched to source pill design
                // RULES:
                // 1. Model tiers (T1/T2) → CPU icon + "Model"
                // 2. Web Search (T2+) → Globe icon + "Web'de Arama"
                // 3. Deep Research (T3) → Gyroscope icon + "Derin Araştırma"
                if shouldShowBadge, let tier = answer.tier, showBadge {
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
            .frame(minHeight: 46) // Reserve vertical space to prevent shift when pill appears
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: showBadge)
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: showSourcePill)

            if let tier = answer.tier,
               tier.showsThinkingSummary,
               let thinkingSummary = answer.thinkingSummary?.trimmingCharacters(in: .whitespacesAndNewlines),
               !thinkingSummary.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text(thinkingSummary)
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(4)
                }
            }

            // Current research stage - shown during deep research with progress bar
            // Smooth fade in/out with increased spacing
            if let stageMessage = currentStage, !isStreamingComplete {
                ResearchStageStatusCard(
                    stageMessage: stageMessage,
                    progress: effectiveProgress(for: stageMessage)
                )
                .padding(.top, 12) // Increased spacing from badge row
                .transition(.opacity.animation(.easeInOut(duration: 0.4)))
                .onAppear {
                    // When progress card appears, permanently hide task summary
                    showTaskSummary = false

                    // Initialize max progress with current stage
                    let currentProgress = calculateProgress(for: stageMessage)
                    if maxProgressReached == 0.0 {
                        maxProgressReached = currentProgress
                    }
                }
                .onChange(of: stageMessage) { _, newStage in
                    // Update max progress when stage changes (only if higher)
                    let newProgress = calculateProgress(for: newStage)
                    if newProgress > maxProgressReached {
                        maxProgressReached = newProgress
                    }
                }
            }


            // Answer content - markdown rendered with smooth streaming
            // Hold display if shouldHoldStream flag is true (during "writing report" stage)
            if !answer.content.isEmpty && !shouldHoldStream {
                StreamingAnswerView(
                    content: answer.content,
                    isStreaming: !isStreamingComplete,
                    sourceCount: answer.sources.count,
                    sources: answer.sources,
                    fontSize: researchFontSize
                )
                .padding(.vertical, 8)
                .onAppear {
                    logger.debug("AnswerCardView displaying answer: \(answer.content.count) chars")
                    if answer.content.count > 100 {
                        logger.debug("Last 100 chars: ...\(answer.content.suffix(100))")
                    }
                }
                .onChange(of: answer.content) { oldValue, newValue in
                    logger.debug("AnswerCardView content changed: \(oldValue.count) → \(newValue.count) chars")
                    if newValue.count > 100 {
                        logger.debug("New last 100 chars: ...\(newValue.suffix(100))")
                    }
                }

                // Action row (single location)
                ResearchResponseActionRow(
                    content: answer.content,
                    shareSubject: answer.query
                ) { feedback in
                    guard let feedback else { return }
                    let rating = feedback == .positive ? "up" : "down"
                    onFeedback?(rating, answer)
                }
            }

            // Follow-up questions removed per user request
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .onAppear {
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
        .onChange(of: answer.id) { _, _ in
            // Reset visibility for new answers
            showTaskSummary = true
            showBadge = false
            showSourcePill = false

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

    /// Determine if shimmer effect should be active on badge text
    /// Shimmer shows from the beginning until response content appears on UI
    private var shouldShowShimmer: Bool {
        answer.content.isEmpty && // No content visible yet
        !isStreamingComplete &&   // Stream hasn't finished
        answer.tier != nil        // Badge is present
    }

    /// Calculate progress percentage based on current research stage
    /// Maps each stage message to a progress value from 0.0 to 1.0
    private func calculateProgress(for stageMessage: String) -> Double {
        switch stageMessage {
        case "Araştırma planını yapıyorum":        return 0.10  // Stage 1: Planning
        case "Araştırmaya başlıyorum":             return 0.20  // Stage 2: Starting research
        case "Kaynakları topluyorum":              return 0.35  // Stage 3: Collecting sources
        case "Kaynakları değerlendiriyorum":       return 0.50  // Stage 4: Evaluating sources
        case "Ek kaynaklar arıyorum":              return 0.60  // Stage 5: Searching additional
        case "Ek kaynakları inceliyorum":          return 0.70  // Stage 6: Examining additional
        case "En ilgili kaynakları seçiyorum":     return 0.80  // Stage 7: Selecting best
        case "Bilgileri bir araya getiriyorum":    return 0.90  // Stage 8: Gathering info
        case "Kapsamlı bir rapor yazıyorum":       return 0.95  // Stage 9: Writing report
        default:                                    return 0.50  // Unknown stage - show halfway
        }
    }

    /// Get effective progress - never goes backwards during multi-round research
    /// Returns max of current stage progress and highest reached so far
    private func effectiveProgress(for stageMessage: String) -> Double {
        let rawProgress = calculateProgress(for: stageMessage)

        // Always return the max between current and what we've reached
        // This prevents backwards movement during multi-round research
        return max(rawProgress, maxProgressReached)
    }

    // MARK: - Helper Types

    // Helper to make Int identifiable for sheet
    struct IndexWrapper: Identifiable {
        let id = UUID()
        let index: Int
    }
}

// MARK: - Previews

#Preview("Araştırma Badge with Shimmer") {
    AnswerCardView(
        answer: SearchAnswer(
            id: "preview-1",
            query: "What are the health benefits of Mediterranean diet?",
            content: "",
            sources: [],
            tier: .search // "Araştırma"
        ),
        enableStreaming: true,
        isStreamingComplete: false,
        isSearchingSources: true // Shimmer active
    )
    .padding()
}

#Preview("Derin Araştırma Badge with Shimmer") {
    AnswerCardView(
        answer: SearchAnswer(
            id: "preview-2",
            query: "How does quantum computing work?",
            content: "",
            sources: [],
            tier: .research // "Derin Araştırma"
        ),
        enableStreaming: true,
        isStreamingComplete: false,
        isSearchingSources: true // Shimmer active
    )
    .padding()
}

#Preview("Badge without Shimmer (Complete)") {
    AnswerCardView(
        answer: SearchAnswer(
            id: "preview-3",
            query: "What is Swift concurrency?",
            content: "Swift concurrency provides modern async/await patterns for handling asynchronous operations.",
            sources: [],
            tier: .search
        ),
        enableStreaming: false,
        isStreamingComplete: true,
        isSearchingSources: false // No shimmer when complete
    )
    .padding()
}

#Preview("Dark Mode with Shimmer") {
    AnswerCardView(
        answer: SearchAnswer(
            id: "preview-4",
            query: "Climate change impacts on oceans",
            content: "",
            sources: [],
            tier: .research
        ),
        enableStreaming: true,
        isStreamingComplete: false,
        isSearchingSources: true
    )
    .padding()
    .preferredColorScheme(.dark)
}

#Preview("Research Stage with Progress Card - Gathering Info") {
    AnswerCardView(
        answer: SearchAnswer(
            id: "preview-6",
            query: "What are the long-term effects of intermittent fasting?",
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

#Preview("Research Stage with Progress Card - Writing Report") {
    AnswerCardView(
        answer: SearchAnswer(
            id: "preview-7",
            query: "How does climate change affect ocean ecosystems?",
            content: "",
            sources: [],
            tier: .research
        ),
        enableStreaming: true,
        isStreamingComplete: false,
        isSearchingSources: false,
        currentStage: "Kapsamlı bir rapor yazıyorum"
    )
    .padding()
}

#Preview("Research Stage with Progress Card - Dark Mode") {
    AnswerCardView(
        answer: SearchAnswer(
            id: "preview-8",
            query: "What are the benefits of meditation?",
            content: "",
            sources: [],
            tier: .research
        ),
        enableStreaming: true,
        isStreamingComplete: false,
        isSearchingSources: false,
        currentStage: "Kaynakları değerlendiriyorum"
    )
    .padding()
    .preferredColorScheme(.dark)
}
