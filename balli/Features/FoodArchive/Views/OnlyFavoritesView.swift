//
//  OnlyFavoritesView.swift
//  balli
//
//  Display-only view for all favorited product labels
//  Accessed from the "Tümünü Gör" button in FavoritesSection
//

import SwiftUI
import CoreData
import OSLog

struct OnlyFavoritesView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @State private var favoriteItems: [FoodItem] = []
    @State private var refreshID = UUID()
    @State private var selectedFoodItem: FoodItem? // For showing label details
    private let logger = AppLoggers.UI.rendering

    let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Favorites Grid
                if favoriteItems.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "star")
                            .font(.system(size: 48, design: .rounded))
                            .foregroundColor(.secondary.opacity(0.5))

                        Text("Henüz favori ürün yok")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(favoriteItems) { item in
                                Button(action: {
                                    selectedFoodItem = item
                                }) {
                                    ProductCardView(
                                        brand: item.brand ?? "Marka Yok",
                                        name: item.name,
                                        portion: "\(Int(item.servingSize))\(item.servingUnit)'da",
                                        carbs: "\(item.totalCarbs.asLocalizedDecimal(decimalPlaces: 1)) gr Karb.",
                                        width: nil,
                                        isFavorite: true,
                                        impactLevel: item.impactLevelDetailed,
                                        onToggleFavorite: {
                                            toggleFavorite(item)
                                        }
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(16)
                    }
                    .scrollContentBackground(.hidden)
                    .background(Color(.systemBackground))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))
            .navigationTitle("Favoriler")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .id(refreshID) // Force refresh when data changes
        }
        .onAppear {
            Task {
                await fetchAllFavorites()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name.NSManagedObjectContextDidSave)) { _ in
            Task {
                await fetchAllFavorites()
            }
        }
        .fullScreenCover(item: $selectedFoodItem) { foodItem in
            NavigationStack {
                FoodItemDetailView(foodItem: foodItem)
                    .environment(\.managedObjectContext, viewContext)
            }
        }
    }

    @MainActor
    private func fetchAllFavorites() async {
        do {
            let request = FoodItem.fetchRequest()
            request.predicate = NSPredicate(format: "isFavorite == YES")
            request.sortDescriptors = [
                NSSortDescriptor(keyPath: \FoodItem.lastUsed, ascending: false),
                NSSortDescriptor(keyPath: \FoodItem.dateAdded, ascending: false)
            ]
            request.returnsObjectsAsFaults = false

            let results = try viewContext.fetch(request)
            logger.info("📦 Fetched \(results.count) total favorite items")

            // Update UI on main thread
            withAnimation {
                favoriteItems = results
                refreshID = UUID()
            }
        } catch {
            logger.error("❌ Failed to fetch all favorites: \(error.localizedDescription)")
        }
    }

    private func toggleFavorite(_ foodItem: FoodItem) {
        Task { @MainActor in
            let itemName = foodItem.name
            let newStatus = !foodItem.isFavorite

            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                foodItem.isFavorite.toggle()
            }

            do {
                try viewContext.save()
                logger.info("✅ Toggled favorite status for '\(itemName)': \(newStatus)")
                await fetchAllFavorites()
            } catch {
                logger.error("❌ Failed to toggle favorite: \(error.localizedDescription)")
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    foodItem.isFavorite.toggle()
                }
            }
        }
    }
}

#Preview {
    OnlyFavoritesView()
        .environment(\.managedObjectContext, PersistenceController.previewFast.container.viewContext)
}
