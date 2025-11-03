//
//  PaginationManager.swift
//  balli
//
//  Generic pagination infrastructure for efficient data loading
//  PERFORMANCE: Reduces memory footprint and improves scroll performance
//

import Foundation
import SwiftUI

// MARK: - Pagination State

/// Tracks pagination state for a data source
@MainActor
@Observable
final class PaginationManager<Item: Identifiable & Sendable> {

    // MARK: - Configuration

    struct Configuration {
        /// Number of items per page
        let pageSize: Int

        /// Prefetch threshold (load next page when this many items from end)
        let prefetchThreshold: Int

        /// Enable automatic prefetching
        let autoPrefetch: Bool
    }

    // MARK: - Published State

    /// All loaded items
    private(set) var items: [Item] = []

    /// Whether currently loading a page
    private(set) var isLoading = false

    /// Whether all pages have been loaded
    private(set) var hasReachedEnd = false

    /// Current error if any
    private(set) var error: Error?

    /// Current page number
    private(set) var currentPage = 0

    // MARK: - Private Properties

    private let configuration: Configuration
    private let loadPage: @Sendable (Int, Int) async throws -> [Item]
    private var loadTask: Task<Void, Never>?

    // MARK: - Initialization

    init(
        configuration: Configuration = Configuration(pageSize: 20, prefetchThreshold: 5, autoPrefetch: true),
        loadPage: @escaping @Sendable (Int, Int) async throws -> [Item]
    ) {
        self.configuration = configuration
        self.loadPage = loadPage
    }

    // MARK: - Public API

    /// Load the first page
    func loadInitialPage() async {
        guard !isLoading else { return }

        currentPage = 0
        items = []
        hasReachedEnd = false
        error = nil

        await loadNextPage()
    }

    /// Load the next page
    func loadNextPage() async {
        guard !isLoading && !hasReachedEnd else { return }

        loadTask?.cancel()
        loadTask = Task { @MainActor in
            isLoading = true
            error = nil

            do {
                let newItems = try await loadPage(currentPage, configuration.pageSize)

                // Check if we've reached the end
                if newItems.count < configuration.pageSize {
                    hasReachedEnd = true
                }

                // Append new items
                items.append(contentsOf: newItems)
                currentPage += 1

            } catch {
                self.error = error
            }

            isLoading = false
        }

        await loadTask?.value
    }

    /// Refresh data (reload from page 0)
    func refresh() async {
        await loadInitialPage()
    }

    /// Check if should prefetch based on current item
    func shouldPrefetch(for item: Item) -> Bool {
        guard configuration.autoPrefetch else { return false }
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return false }

        return items.count - index <= configuration.prefetchThreshold
    }

    /// Handle item appearance for auto-prefetch
    func handleItemAppeared(_ item: Item) async {
        if shouldPrefetch(for: item) {
            await loadNextPage()
        }
    }

    /// Reset pagination state
    func reset() {
        loadTask?.cancel()
        items = []
        currentPage = 0
        hasReachedEnd = false
        isLoading = false
        error = nil
    }
}

// MARK: - View Modifier

extension View {
    /// Add pagination support to a list
    func onReachingEnd<Item>(
        of items: [Item],
        threshold: Int = 5,
        action: @escaping () async -> Void
    ) -> some View where Item: Identifiable {
        self.onAppear {
            Task {
                if let lastItem = items.suffix(threshold).first,
                   let index = items.firstIndex(where: { $0.id == lastItem.id }),
                   items.count - index <= threshold {
                    await action()
                }
            }
        }
    }
}

// MARK: - Pagination View Helper

/// Reusable pagination loading indicator
struct PaginationLoadingView: View {
    let isLoading: Bool
    let hasReachedEnd: Bool
    let error: Error?
    let onRetry: () async -> Void

    var body: some View {
        VStack(spacing: 12) {
            if isLoading {
                HStack {
                    ProgressView()
                        .tint(.secondary)
                    Text("Loading...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
            } else if error != nil {
                VStack(spacing: 8) {
                    Text("Failed to load")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Retry") {
                        Task {
                            await onRetry()
                        }
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                }
                .padding()
            } else if hasReachedEnd {
                Text("No more items")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding()
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Example Usage

/*
 Example: Paginated list view

 struct MyListView: View {
     @State private var paginationManager = PaginationManager<MyItem> { page, pageSize in
         // Load page from your data source
         try await MyDataSource.fetchItems(page: page, limit: pageSize)
     }

     var body: some View {
         List {
             ForEach(paginationManager.items) { item in
                 ItemRow(item: item)
                     .onAppear {
                         Task {
                             await paginationManager.handleItemAppeared(item)
                         }
                     }
             }

             PaginationLoadingView(
                 isLoading: paginationManager.isLoading,
                 hasReachedEnd: paginationManager.hasReachedEnd,
                 error: paginationManager.error,
                 onRetry: { await paginationManager.loadNextPage() }
             )
         }
         .task {
             await paginationManager.loadInitialPage()
         }
         .refreshable {
             await paginationManager.refresh()
         }
     }
 }
 */
