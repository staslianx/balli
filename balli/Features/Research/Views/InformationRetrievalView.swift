//
//  InformationRetrievalView.swift
//  balli
//
//  Perplexity-style information retrieval interface
//  Swift 6 strict concurrency compliant
//

import SwiftUI
import OSLog

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.balli",
    category: "InformationRetrievalView"
)

struct InformationRetrievalView: View {
    @StateObject private var viewModel = MedicalResearchViewModel()
    @Environment(\.colorScheme) private var colorScheme
    @State private var searchQuery = ""
    @State private var attachedImage: UIImage? = nil
    @State private var showLibrary = false
    @State private var showingSettings = false
    @State private var displayedAnswerIds: Set<String> = []
    @State private var showScrollPadding = false // Smart padding for scroll-to-top
    @State private var animatingAnswerIds: Set<String> = [] // Track which answers are still animating
    @FocusState private var isSearchFocused: Bool // KEYBOARD FIX: Track search bar focus

    private var isEffectivelySearching: Bool {
        // Still searching if backend is searching OR any animation is running
        viewModel.isSearching || !animatingAnswerIds.isEmpty
    }

    var body: some View {
        ZStack {
            // Background
            Color(.systemBackground)
                .ignoresSafeArea()

            // Results area
            if viewModel.answers.isEmpty && !viewModel.isSearching {
                // Empty state - centered
                emptyStateView
            } else {
                GeometryReader { geometry in
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(alignment: .leading, spacing: 12) {
                                // Answer cards in chronological order: oldest → newest
                                ForEach(viewModel.answersInChronologicalOrder) { answer in
                                    AnswerCardView(
                                        answer: answer,
                                        enableStreaming: !displayedAnswerIds.contains(answer.id),
                                        isStreamingComplete: !isEffectivelySearching,  // Wait for BOTH backend AND typewriter animation
                                        isSearchingSources: viewModel.searchingSourcesForAnswer[answer.id] ?? false,
                                        currentStage: viewModel.currentStages[answer.id],
                                        shouldHoldStream: viewModel.shouldHoldStream[answer.id] ?? false,
                                        reconnectionState: viewModel.reconnectionState,
                                        onViewReady: { answerId in
                                            viewModel.signalViewReady(for: answerId)
                                        },
                                        onFeedback: { rating, answer in
                                            Task {
                                                await viewModel.submitFeedback(rating: rating, answer: answer)
                                            }
                                        },
                                        onQuestionSelect: { question in
                                            Task {
                                                await viewModel.search(query: question)
                                            }
                                        },
                                        onAnimationStateChange: { answerId, isAnimating in
                                            logger.info("🎭 [RESEARCH-ANIMATION-CALLBACK] Answer \(answerId): \(isAnimating ? "START" : "STOP")")
                                            logger.info("   Before: animatingAnswerIds = \(animatingAnswerIds)")
                                            if isAnimating {
                                                animatingAnswerIds.insert(answerId)
                                            } else {
                                                animatingAnswerIds.remove(answerId)
                                            }
                                            logger.info("   After: animatingAnswerIds = \(animatingAnswerIds)")
                                            logger.info("   isEffectivelySearching: \(isEffectivelySearching) (backend: \(viewModel.isSearching), animating: \(!animatingAnswerIds.isEmpty))")
                                        }
                                    )
                                    .id(answer.id)
                                    .onAppear {
                                        let answerId = answer.id
                                        Task { @MainActor in
                                            try? await Task.sleep(for: .milliseconds(500))
                                            displayedAnswerIds.insert(answerId)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 0)
                            .padding(.top, 4)
                            // ✅ SMART PADDING: Large padding when showing new question, small when scrolling
                            .padding(.bottom, showScrollPadding ? geometry.size.height - 100 : 32)
                        }
                        .scrollDismissesKeyboard(.immediately)
                        .simultaneousGesture(
                            // KEYBOARD FIX: Dismiss keyboard on any scroll or drag gesture
                            DragGesture(minimumDistance: 10)
                                .onChanged { _ in
                                    isSearchFocused = false
                                }
                        )
                        .onChange(of: viewModel.answers.count) { oldCount, newCount in
                            // ONLY scroll when a NEW question is added (count increases)
                            if newCount > oldCount, let latestAnswer = viewModel.answers.first {
                                // Step 1: Enable padding for scroll
                                showScrollPadding = true

                                // Step 2: Scroll to top with padding (removes 100ms delay you wanted gone)
                                withAnimation(.easeOut(duration: 0.3)) {
                                    proxy.scrollTo(latestAnswer.id, anchor: .top)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                // Library button (conversation history)
                Button {
                    showLibrary = true
                } label: {
                    Image(systemName: "book.pages")
                        .font(.system(size: 17))
                        .foregroundColor(ThemeColors.primaryPurple)
                }
            }

            // Logo with long-press gesture for settings
            ToolbarItem(placement: .principal) {
                HStack(spacing: 8) {
                    Image(colorScheme == .dark ? "balli-text-logo-dark" : "balli-text-logo")
                        .resizable()
                        .renderingMode(.original)
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 35, height: 35)
                        .onLongPressGesture(minimumDuration: 0.5) {
                            showingSettings = true
                        }
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                // New conversation button
                Button {
                    // KEYBOARD FIX: Dismiss keyboard when starting new conversation
                    isSearchFocused = false

                    // Immediately clear UI state for instant visual feedback
                    searchQuery = ""
                    displayedAnswerIds.removeAll()
                    showScrollPadding = false

                    // Then save and clear conversation data
                    Task {
                        await viewModel.startNewConversation()
                    }
                } label: {
                    Image(systemName: "plus.message")
                        .font(.system(size: 17))
                        .foregroundColor(ThemeColors.primaryPurple)
                }
            }
        }
        .onChange(of: viewModel.isSearching) { oldValue, newValue in
            logger.info("🔄 [RESEARCH-BACKEND] isSearching changed: \(oldValue) → \(newValue)")
            logger.info("   animatingAnswerIds: \(animatingAnswerIds)")
            logger.info("   isEffectivelySearching: \(isEffectivelySearching)")
        }
        .onChange(of: animatingAnswerIds) { oldValue, newValue in
            logger.info("🔄 [RESEARCH-ANIMATING-SET] animatingAnswerIds changed")
            logger.info("   Before: \(oldValue)")
            logger.info("   After: \(newValue)")
            logger.info("   isEffectivelySearching: \(isEffectivelySearching) (backend: \(viewModel.isSearching), animating: \(!newValue.isEmpty))")
        }
        .safeAreaInset(edge: .bottom) {
            // Fixed search bar at bottom
            SearchBarView(
                searchQuery: $searchQuery,
                attachedImage: $attachedImage,
                onSubmit: {
                    performSearch()
                },
                onCancel: {
                    viewModel.cancelCurrentSearch()
                },
                isSearching: isEffectivelySearching,
                isFocused: $isSearchFocused
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .sheet(isPresented: $showLibrary) {
            SearchLibraryView()
        }
        .sheet(isPresented: $showingSettings) {
            AppSettingsView()
        }
        .task {
            // LIFECYCLE FIX: Ensure answers are loaded when view appears
            // This handles tab switching and lock/unlock scenarios
            // Only triggers if answers are empty and data exists in persistence
            if viewModel.answers.isEmpty {
                await viewModel.recoverSessionIfNeeded()
            }
        }
        .task(id: viewModel.isSearching) {
            // P0.8 FIX: Monitor search state for automatic cancellation
            // CRITICAL: When user navigates away or switches tabs, streaming stops
            // This prevents wasted token generation for invisible research results
            if viewModel.isSearching {
                AppLoggers.Research.search.info("🔍 [LIFECYCLE] Research search started - monitoring for cancellation")
            } else {
                AppLoggers.Research.search.info("✅ [LIFECYCLE] Research search completed or stopped")
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack {
            Spacer()
            TimeBasedGreetingView()
            Spacer()
        }
    }

    // MARK: - Actions

    private func performSearch() {
        let hasText = !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty
        let hasImage = attachedImage != nil

        guard hasText || hasImage else { return }

        // KEYBOARD FIX: Dismiss keyboard immediately when search starts
        isSearchFocused = false

        // Capture image before clearing for async task
        let imageToSend = attachedImage

        // Clear image IMMEDIATELY (not after search completes)
        attachedImage = nil

        Task {
            await viewModel.search(query: searchQuery, image: imageToSend)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        InformationRetrievalView()
    }
}
