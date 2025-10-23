//
//  SearchLibraryView.swift
//  balli
//
//  Saved search history and collections
//  Swift 6 strict concurrency compliant
//

import SwiftUI

struct SearchLibraryView: View {
    @State private var threads: [SearchAnswer] = []
    @State private var isLoading = true
    @State private var selectedTab: ResearchTab = .search

    private let repository = ResearchHistoryRepository()

    enum ResearchTab: String, CaseIterable {
        case search = "Araştırma"
        case deepResearch = "Derin Araştırma"
    }

    var filteredAnswers: [SearchAnswer] {
        threads.filter { answer in
            switch selectedTab {
            case .search:
                // Show search tier (HYBRID_RESEARCH) and model tier answers
                return answer.tier?.rawValue == ResponseTier.search.rawValue ||
                       answer.tier?.rawValue == ResponseTier.model.rawValue
            case .deepResearch:
                // Show deep research tier (DEEP_RESEARCH) answers
                return answer.tier?.rawValue == ResponseTier.research.rawValue
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Segmented Picker
                Picker("Araştırma Türü", selection: $selectedTab) {
                    ForEach(ResearchTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                // List
                List {
                    if isLoading {
                        ProgressView("Yükleniyor...")
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else if filteredAnswers.isEmpty {
                        ContentUnavailableView(
                            "Henüz araştırma yok",
                            systemImage: "book.closed",
                            description: Text("Yaptığın araştırmalar burada görünecek")
                        )
                    } else {
                        Section("Son Araştırmalar") {
                            ForEach(filteredAnswers) { thread in
                                NavigationLink(destination: SearchDetailView(answer: thread)) {
                                    SearchAnswerRow(answer: thread)
                                        .equatable()
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Kütüphane")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                loadThreadsFromPersistence()
            }
            .refreshable {
                loadThreadsFromPersistence()
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
                print("❌ Failed to load threads from persistence: \(error)")
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
}

// MARK: - Equatable Row Component

/// PERFORMANCE: Equatable row view prevents unnecessary re-renders when answer data hasn't changed
struct SearchAnswerRow: View, Equatable {
    let answer: SearchAnswer

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(answer.query)
                .font(.headline)
                .lineLimit(2)
                .foregroundStyle(.primary)

            Text(answer.timestamp, style: .relative)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    // Only re-render if these properties change
    nonisolated static func == (lhs: SearchAnswerRow, rhs: SearchAnswerRow) -> Bool {
        lhs.answer.id == rhs.answer.id &&
        lhs.answer.query == rhs.answer.query &&
        lhs.answer.timestamp == rhs.answer.timestamp
    }
}
