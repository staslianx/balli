//
//  FavoritesSection.swift
//  balli
//
//  Favorites section with Core Data integration
//

import SwiftUI
import CoreData
import OSLog

struct FavoritesSection: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.selectedTab) private var selectedTab
    private let logger = AppLoggers.UI.rendering

    // State tracking for Core Data readiness
    // Start as true to avoid showing loading spinner on every app open
    // Will be set to false only if fetch actually fails
    @State private var isCoreDataReady = true
    @State private var favoriteItems: [FoodItem] = []
    @State private var fetchError: Error?
    @State private var refreshID = UUID() // Force view refresh when data changes
    @State private var showingAllFavorites = false // Navigation to OnlyFavoritesView
    @State private var selectedFoodItem: FoodItem? // For showing label details

    // Limit displayed items to avoid memory issues
    private let maxDisplayedItems = 6

    // PERFORMANCE: Helper struct to create stable, content-based IDs
    // This allows SwiftUI to detect when data actually changes without rebuilding everything
    // Uses UUID instead of objectID to ensure hash changes when properties change
    private struct FoodItemSnapshot: Hashable {
        let id: UUID
        let name: String
        let brand: String?
        let servingSize: Double
        let totalCarbs: Double
        let impactLevel: ImpactLevel

        init(from foodItem: FoodItem) {
            self.id = foodItem.id
            self.name = foodItem.name
            self.brand = foodItem.brand
            self.servingSize = foodItem.servingSize
            self.totalCarbs = foodItem.totalCarbs
            self.impactLevel = foodItem.impactLevel
        }
    }

    // PERFORMANCE: Wrapper to combine snapshot ID with FoodItem for ForEach
    private struct FoodItemWrapper: Identifiable {
        let snapshot: FoodItemSnapshot
        let item: FoodItem

        var id: FoodItemSnapshot { snapshot }

        init(item: FoodItem) {
            self.item = item
            self.snapshot = FoodItemSnapshot(from: item)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.Spacing.medium) {
            headerView

            if !isCoreDataReady {
                loadingStateView
            } else if let error = fetchError {
                errorStateView(error)
            } else if favoriteItems.isEmpty {
                emptyStateView
            } else {
                favoritesGridView
            }
        }
        .onAppear {
            Task {
                await ensureCoreDataReadyAndFetch()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .coreDataReady)) { _ in
            Task {
                await fetchFavorites()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name.NSManagedObjectContextDidSave)) { notification in
            // PERFORMANCE FIX: Only refetch if FoodItem entities were actually modified
            // This prevents infinite loop where fetch → save → fetch → save...
            guard let userInfo = notification.userInfo else { return }

            // Check if any FoodItem was inserted, updated, or deleted
            let hasFoodItemChanges =
                (userInfo[NSInsertedObjectsKey] as? Set<NSManagedObject>)?.contains(where: { $0 is FoodItem }) == true ||
                (userInfo[NSUpdatedObjectsKey] as? Set<NSManagedObject>)?.contains(where: { $0 is FoodItem }) == true ||
                (userInfo[NSDeletedObjectsKey] as? Set<NSManagedObject>)?.contains(where: { $0 is FoodItem }) == true

            guard hasFoodItemChanges else {
                logger.debug("⏭️ Ignoring save notification - no FoodItem changes")
                return
            }

            logger.info("🔔 FoodItem changed - refreshing favorites")
            Task {
                await fetchFavorites()
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var loadingStateView: some View {
        VStack(spacing: ResponsiveDesign.Spacing.small) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(AppTheme.primaryPurple)

            Text("Favoriler yükleniyor...")
                .font(.system(size: 15, weight: .regular, design: .rounded))
                .foregroundColor(.secondary)
        }
        .frame(height: calculateFavoritesHeight())
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func errorStateView(_ error: Error) -> some View {
        VStack(spacing: ResponsiveDesign.Spacing.small) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32, design: .rounded))
                .foregroundColor(.orange.opacity(0.7))

            Text("Favoriler yüklenemedi")
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .foregroundColor(.primary)

            Text(error.localizedDescription)
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, ResponsiveDesign.Spacing.large)

            Button("Tekrar Dene") {
                Task {
                    await fetchFavorites()
                }
            }
            .font(.system(size: 14, weight: .medium, design: .rounded))
            .foregroundColor(AppTheme.primaryPurple)
            .padding(.top, ResponsiveDesign.Spacing.xSmall)
        }
        .frame(height: calculateFavoritesHeight())
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var headerView: some View {
        HStack {
            Text("Favoriler")
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)

            Spacer()

            Button("Tümünü Gör") {
                showingAllFavorites = true
            }
            .font(.system(size: 15, weight: .regular, design: .rounded))
            .foregroundColor(AppTheme.primaryPurple)
        }
        .padding(.horizontal)
        .sheet(isPresented: $showingAllFavorites) {
            OnlyFavoritesView()
                .environment(\.managedObjectContext, viewContext)
        }
        .fullScreenCover(item: $selectedFoodItem) { foodItem in
            NavigationStack {
                FoodItemDetailView(foodItem: foodItem)
                    .environment(\.managedObjectContext, viewContext)
            }
        }
    }

    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: ResponsiveDesign.Spacing.small) {
            Image(systemName: "star")
                .font(.system(size: 32, design: .rounded))
                .foregroundColor(.secondary.opacity(0.5))

        }
        .frame(height: calculateFavoritesHeight())
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var favoritesGridView: some View {
        GeometryReader { geometry in
            let horizontalPadding: CGFloat = 16
            let spacing: CGFloat = ResponsiveDesign.height(13)
            let availableWidth = geometry.size.width - (horizontalPadding * 2)
            let cardWidth = (availableWidth - spacing) / 2
            let extraTopSpace: CGFloat = ResponsiveDesign.height(20) // Room for shadow/scale

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: spacing) {
                    // PERFORMANCE FIX: Wrap items with content-based IDs
                    // This ensures SwiftUI detects when FoodItem properties change (name, brand, carbs, etc.)
                    // objectID alone doesn't change when properties change, causing stale UI
                    let wrappedItems = favoriteItems.prefix(maxDisplayedItems).map { FoodItemWrapper(item: $0) }

                    ForEach(wrappedItems) { wrapper in
                        Button(action: {
                            selectedFoodItem = wrapper.item
                        }) {
                            ProductCardView(
                                brand: wrapper.item.brand ?? "Marka Yok",
                                name: wrapper.item.name,
                                portion: "\(Int(wrapper.item.servingSize))\(wrapper.item.servingUnit)'da",
                                carbs: "\(wrapper.item.totalCarbs.asLocalizedDecimal(decimalPlaces: 1)) gr Karb.",
                                width: cardWidth,
                                isFavorite: true,
                                impactLevel: wrapper.item.impactLevelDetailed,
                                onToggleFavorite: {
                                    toggleFavorite(wrapper.item)
                                }
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.top, extraTopSpace + ResponsiveDesign.Spacing.xxSmall)
                .padding(.bottom, ResponsiveDesign.height(20))
                .id(refreshID) // Force view rebuild when refreshID changes
            }
            .scrollClipDisabled() // Allow cards to scale beyond scroll bounds
            .offset(y: -extraTopSpace) // Shift content up to maintain visual position
        }
        .frame(height: calculateFavoritesHeight())
    }

    // MARK: - Helper Methods

    private func calculateFavoritesHeight() -> CGFloat {
        let screenWidth = ResponsiveDesign.safeScreenWidth()
        guard screenWidth > 0 && !screenWidth.isNaN && !screenWidth.isInfinite else {
            return 200
        }
        let spacing = ResponsiveDesign.height(13)
        let extraTopSpace = ResponsiveDesign.height(20) // Extra room for shadow/scale
        let padding = extraTopSpace + ResponsiveDesign.Spacing.xxSmall + ResponsiveDesign.height(20)
        let cardHeight = (screenWidth - 32 - spacing) / 2
        let totalHeight = cardHeight + padding
        guard !totalHeight.isNaN && !totalHeight.isInfinite && totalHeight > 0 else {
            return 200
        }
        return totalHeight
    }

    // MARK: - Core Data Operations

    @MainActor
    private func ensureCoreDataReadyAndFetch() async {
        // Optimistically fetch - Core Data is almost always ready in production
        // Only show error if fetch actually fails
        await fetchFavorites()
    }

    @MainActor
    private func fetchFavorites() async {
        do {
            // Create fetch request
            let request = FoodItem.fetchRequest()
            request.predicate = NSPredicate(format: "isFavorite == YES")
            request.sortDescriptors = [
                NSSortDescriptor(keyPath: \FoodItem.lastUsed, ascending: false),
                NSSortDescriptor(keyPath: \FoodItem.dateAdded, ascending: false)
            ]
            request.fetchLimit = maxDisplayedItems
            request.returnsObjectsAsFaults = false

            // Perform fetch on main context (safe because we're on MainActor)
            let results = try viewContext.fetch(request)

            // Check if data actually changed
            let itemsChanged = favoriteItems.count != results.count ||
                zip(favoriteItems, results).contains { old, new in
                    old.servingSize != new.servingSize ||
                    old.totalCarbs != new.totalCarbs ||
                    old.name != new.name
                }

            #if DEBUG
            if itemsChanged {
                logger.debug("Favorites updated: \(results.count) items")
            }
            #endif

            // Always update to ensure favorites list reflects latest changes
            // Content-based IDs on ProductCardView will trigger re-renders only for changed items
            favoriteItems = results
            fetchError = nil
            refreshID = UUID() // Force SwiftUI to refresh the view

        } catch {
            logger.error("Failed to fetch favorites: \(error.localizedDescription)")
            fetchError = error
            // Don't clear favoriteItems - keep showing last known state
        }
    }

    private func toggleFavorite(_ foodItem: FoodItem) {
        Task { @MainActor in
            let itemName = foodItem.name
            let newFavoriteStatus = !foodItem.isFavorite

            // Toggle the favorite status with animation
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                foodItem.isFavorite.toggle()
            }

            do {
                // Save to Core Data
                try viewContext.save()
                logger.info("✅ Persisted favorite status for '\(itemName)': \(newFavoriteStatus)")

                // NO NEED to call fetchFavorites() here - NSManagedObjectContextDidSave notification will trigger it
            } catch {
                logger.error("❌ Failed to save favorite for '\(itemName)': \(error.localizedDescription)")
                // Revert on error
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    foodItem.isFavorite.toggle()
                }
            }
        }
    }
}

// MARK: - Favorites Fetch Error

enum FavoritesFetchError: LocalizedError {
    case coreDataNotReady

    var errorDescription: String? {
        switch self {
        case .coreDataNotReady:
            return "Veritabanı henüz hazır değil. Lütfen bir süre sonra tekrar deneyin."
        }
    }
}
