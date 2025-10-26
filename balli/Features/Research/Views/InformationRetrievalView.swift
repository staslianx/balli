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
    @State private var showLibrary = false
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
                            .padding(.top, 16)
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

            ToolbarItem(placement: .principal) {
                HStack(spacing: 8) {
                    Image("balli-text-logo")
                        .resizable()
                        .renderingMode(.original)
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 28, height: 28)

                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                // New conversation button
                Button {
                    // Save current conversation to library before starting new one
                    Task {
                        await viewModel.startNewConversation()
                        searchQuery = ""
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
        guard !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        Task {
            await viewModel.search(query: searchQuery)
            // Don't clear query to allow easy refinement
        }
    }
}

// MARK: - Suggestion Button

struct SuggestionButton: View {
    let icon: String
    let text: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(AppTheme.primaryPurple)
                    .frame(width: 24)

                Text(text)
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)

                Spacer()

                Image(systemName: "arrow.right")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Search Loading View

struct SearchLoadingView: View {
    let message: String
    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(AppTheme.primaryPurple)

            Text(message)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        InformationRetrievalView()
    }
}
