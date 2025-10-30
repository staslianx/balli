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

    private let repository = ResearchHistoryRepository()
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.balli",
        category: "Research"
    )

    var body: some View {
        NavigationStack {
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
                } else {
                    Section("Son Araştırmalar") {
                        ForEach(threads) { thread in
                            NavigationLink(destination: SearchDetailView(answer: thread)) {
                                SearchAnswerRow(answer: thread)
                                    .equatable()
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
                logger.error("Failed to load threads from persistence: \(error.localizedDescription)")
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
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Research type badge on the left
            if let tier = answer.tier {
                VStack(spacing: 4) {
                    Image(systemName: tier.iconName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(tier.badgeForegroundColor(for: colorScheme))
                        .frame(width: 24, height: 24)
                        .background {
                            Circle()
                                .fill(tier.badgeBackgroundColor(for: colorScheme))
                        }
                }
            }

            // Question and timestamp
            VStack(alignment: .leading, spacing: 4) {
                Text(answer.query)
                    .font(.headline)
                    .lineLimit(2)
                    .foregroundStyle(.primary)

                Text(answer.timestamp, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    // Only re-render if these properties change
    nonisolated static func == (lhs: SearchAnswerRow, rhs: SearchAnswerRow) -> Bool {
        lhs.answer.id == rhs.answer.id &&
        lhs.answer.query == rhs.answer.query &&
        lhs.answer.timestamp == rhs.answer.timestamp &&
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
