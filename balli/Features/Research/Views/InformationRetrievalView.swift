//
//  InformationRetrievalView.swift
//  balli
//
//  Perplexity-style information retrieval interface
//  Swift 6 strict concurrency compliant
//

import SwiftUI

struct InformationRetrievalView: View {
    @StateObject private var viewModel = MedicalResearchViewModel()
    @Environment(\.colorScheme) private var colorScheme
    @State private var searchQuery = ""
    @State private var attachedImage: UIImage? = nil
    @State private var showLibrary = false
    @State private var showingSettings = false
    @State private var displayedAnswerIds: Set<String> = []
    @State private var showScrollPadding = false // Smart padding for scroll-to-top

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
                                // viewModel.answers is [newest, older, oldest], so reverse it
                                ForEach(viewModel.answers.reversed()) { answer in
                                    AnswerCardView(
                                        answer: answer,
                                        enableStreaming: !displayedAnswerIds.contains(answer.id),
                                        isStreamingComplete: !viewModel.isSearching,
                                        isSearchingSources: viewModel.searchingSourcesForAnswer[answer.id] ?? false,
                                        currentStage: viewModel.currentStages[answer.id],
                                        shouldHoldStream: viewModel.shouldHoldStream[answer.id] ?? false,
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
                    Image("balli-text-logo")
                        .resizable()
                        .renderingMode(.original)
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 28, height: 28)
                        .onLongPressGesture(minimumDuration: 0.5) {
                            showingSettings = true
                        }
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                // New conversation button
                Button {
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
                isSearching: viewModel.isSearching
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
