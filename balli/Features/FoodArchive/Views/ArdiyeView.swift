//
//  ArdiyeView.swift
//  balli
//
//  Food library with search and filtering capabilities
//

import CoreData
import SwiftUI
import UIKit
import OSLog


// MARK: - Data Models


/// Unified item structure for displaying both recipes and food products
@MainActor
struct ArdiyeView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) private var colorScheme
    private let logger = AppLoggers.Food.archive
    @Binding var searchText: String
    @State private var selectedRecipe: Recipe? = nil
    @State private var selectedFoodItem: FoodItem? = nil
    @State private var showingShoppingList = false
    @State private var selectedFilter: ArdiyeFilter = .recipes
    @State private var showingSettings = false

    // Cache for items to prevent recreation
    @State private var cachedItems: [ArdiyeItem] = []
    @State private var lastRefreshDate = Date()

    // Toast notification for save feedback
    @State private var toastMessage: ToastType? = nil

    // Lazy loading configuration
    private let initialBatchSize = 30
    private let loadMoreThreshold = 5 // Load more when 5 items from end

    // Core Data fetch request for FoodItems with fetch limits for performance
    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \FoodItem.lastUsed, ascending: false),
            NSSortDescriptor(keyPath: \FoodItem.dateAdded, ascending: false)
        ],
        animation: .default
    )
    private var foodItems: FetchedResults<FoodItem>

    // Removed dynamic basket icon logic to prevent UI freeze
    // Now using static basket icon always

    // Core Data fetch request for Recipes with fetch limits for performance
    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \Recipe.lastModified, ascending: false),
            NSSortDescriptor(keyPath: \Recipe.dateCreated, ascending: false)
        ],
        animation: .default
    )
    private var recipes: FetchedResults<Recipe>

    // Update cached items only when data changes
    private func updateCachedItems() {
        var items: [ArdiyeItem] = []

        // Add recipes
        for recipe in recipes {
            // Calculate carbs based on portion multiplier
            let actualPortions = recipe.portionMultiplier > 0 ? recipe.portionMultiplier : 1.0
            let carbsForPortions = recipe.carbsPerServing * actualPortions

            items.append(
                ArdiyeItem(
                    id: recipe.id,
                    name: recipe.name,
                    displayTitle: recipe.name,
                    subtitle: "",  // No subtitle for recipes - just show recipe name
                    totalCarbs: carbsForPortions,
                    servingSize: actualPortions,
                    servingUnit: "porsiyon",
                    isFavorite: recipe.isFavorite,
                    isRecipe: true,
                    recipe: recipe,
                    foodItem: nil
                ))
        }

        // Add scanned packaged food products (from label scanning)
        for foodItem in foodItems {
            items.append(
                ArdiyeItem(
                    id: foodItem.id,
                    name: foodItem.name,
                    displayTitle: foodItem.brand ?? "Marka Yok",
                    subtitle: foodItem.name,
                    totalCarbs: foodItem.totalCarbs,
                    servingSize: foodItem.servingSize,
                    servingUnit: foodItem.servingUnit,
                    isFavorite: foodItem.isFavorite,
                    isRecipe: false,
                    recipe: nil,
                    foodItem: foodItem
                ))
        }

        // Sort by most recently modified/created
        cachedItems = items.sorted { item1, item2 in
            let date1 =
                item1.recipe?.lastModified ?? item1.foodItem?.lastModified ?? Date.distantPast
            let date2 =
                item2.recipe?.lastModified ?? item2.foodItem?.lastModified ?? Date.distantPast
            return date1 > date2
        }

        lastRefreshDate = Date()
    }

    // Removed updateBasketIcon() function - no longer needed with static icon

    // Get filtered items based on selected filter and search text
    private var displayedItems: [ArdiyeItem] {
        // First filter by type (recipes or products)
        let typeFilteredItems: [ArdiyeItem]
        switch selectedFilter {
        case .recipes:
            typeFilteredItems = cachedItems.filter { $0.isRecipe }
        case .products:
            // Only show scanned products (ai_scanned), exclude voice-logged meals (voice)
            typeFilteredItems = cachedItems.filter { !$0.isRecipe && $0.foodItem?.source == "ai_scanned" }
        }

        // Then apply search filter if needed
        if searchText.isEmpty {
            return typeFilteredItems
        }

        let lowercasedSearch = searchText.lowercased()

        return typeFilteredItems.filter { item in
            // Search by name
            let itemName = item.name.lowercased()
            let nameMatches = itemName.contains(lowercasedSearch)

            // Search by carb amount
            let carbAmount = item.totalCarbs
            let searchWithoutSpaces = lowercasedSearch.replacingOccurrences(of: " ", with: "")

            var carbMatches = false

            // Try to match as number
            if let searchNumber = Double(searchWithoutSpaces) {
                // Allow ±5g tolerance for number searches
                carbMatches = abs(carbAmount - searchNumber) < 5
            }

            // Also match if searching with "gr" or "karb" keywords
            if !carbMatches && (lowercasedSearch.contains("gr") || lowercasedSearch.contains("karb")) {
                let carbText = "\(Int(carbAmount)) gr Karb."
                carbMatches = carbText.lowercased().contains(lowercasedSearch)
            }

            // Search by ingredient (only for recipes)
            var ingredientMatches = false
            if item.isRecipe, let recipe = item.recipe {
                if let ingredientsObject = recipe.ingredients as? [String] {
                    ingredientMatches = ingredientsObject.contains { ingredient in
                        ingredient.lowercased().contains(lowercasedSearch)
                    }
                }
            }

            return nameMatches || carbMatches || ingredientMatches
        }
    }

    // MARK: - Save Helper

    /// Save viewContext with proper error handling and user feedback
    private func saveContext() {
        guard viewContext.hasChanges else { return }

        do {
            try viewContext.save()
            toastMessage = .success("Kaydedildi")
            logger.debug("Successfully saved food archive changes")
        } catch {
            logger.error("Failed to save food archive: \(error.localizedDescription)")
            toastMessage = .error("Kaydetme başarısız oldu")
        }
    }

    var body: some View {
        GlassEffectContainer {
            // Conditionally use different layouts based on filter
            if selectedFilter == .recipes {
                // Recipe list layout (full-width cards)
                recipeListView
            } else {
                // Product grid layout (2-column grid)
                productGridLayout
            }
        }
        .background(Color(.systemBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.automatic, for: .navigationBar)
        .toolbar {
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

            // Shopping basket — top-left (static icon)
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    showingShoppingList = true
                }) {
                    Image(systemName: "basket")
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundColor(AppTheme.primaryPurple)
                }
            }

            // Filter button — top-right
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    withAnimation {
                        selectedFilter = selectedFilter == .recipes ? .products : .recipes
                    }
                }) {
                    Image(systemName: selectedFilter == .recipes ? "book.closed" : "laser.burst")
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundColor(AppTheme.primaryPurple)
                }
            }
        }
        .onAppear {
            // Add demo products on first appearance
            addDemoProductsIfNeeded()
            // Initial load of cached items
            updateCachedItems()
        }
        .onChange(of: recipes.count) { _, _ in
            updateCachedItems()
        }
        .onChange(of: foodItems.count) { _, _ in
            updateCachedItems()
        }
        .onChange(of: recipes.map { $0.lastModified }) { _, _ in
            updateCachedItems()
        }
        .sheet(isPresented: $showingShoppingList) {
            ShoppingListViewSimple()
        }
        .sheet(isPresented: $showingSettings) {
            AppSettingsView()
        }
        .fullScreenCover(item: $selectedRecipe) { recipe in
            NavigationStack {
                RecipeDetailView(
                    recipeData: RecipeDetailData(recipe: recipe)
                )
            }
        }
        .fullScreenCover(item: $selectedFoodItem) { foodItem in
            NavigationStack {
                FoodItemDetailView(foodItem: foodItem)
                    .environment(\.managedObjectContext, viewContext)
            }
        }
        .toast($toastMessage)
    }


    // MARK: - Layout Views

    @ViewBuilder
    private var recipeListView: some View {
        List {
            ForEach(displayedItems) { item in
                recipeCard(for: item)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .contextMenu {
                        if let recipe = item.recipe {
                            Button(action: {
                                withAnimation {
                                    let newStatus = !recipe.isFavorite
                                    recipe.toggleFavorite()
                                    saveContext()
                                    logger.info("✅ Recipe '\(recipe.name)' favorite status changed: \(newStatus)")
                                    updateCachedItems()
                                }
                            }) {
                                Label(recipe.isFavorite ? "Favoriden Çıkar" : "Favorilere Ekle", systemImage: recipe.isFavorite ? "star.fill" : "star")
                            }

                            Button(role: .destructive, action: {
                                deleteItem(item)
                            }) {
                                Label("Sil", systemImage: "trash")
                            }
                        }
                    }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    @ViewBuilder
    private var productGridLayout: some View {
        let columns = [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ]

        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(displayedItems) { item in
                    if let foodItem = item.foodItem {
                        Button(action: {
                            selectedFoodItem = foodItem
                        }) {
                            ProductCardView(
                                brand: foodItem.brand ?? "Marka Yok",
                                name: foodItem.name,
                                portion: "\(Int(foodItem.servingSize))\(foodItem.servingUnit)'da",
                                carbs: String(format: "%.1f gr Karb.", foodItem.totalCarbs),
                                width: nil, // Let ProductCardView use default size
                                isFavorite: foodItem.isFavorite,
                                impactLevel: foodItem.impactLevelDetailed,
                                onToggleFavorite: {
                                    withAnimation {
                                        let newStatus = !foodItem.isFavorite
                                        foodItem.toggleFavorite()
                                        saveContext()
                                        logger.info("✅ Product '\(foodItem.name)' favorite status changed: \(newStatus)")
                                        updateCachedItems()
                                    }
                                },
                                onDelete: {
                                    deleteItem(item)
                                }
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(16)
        }
        .scrollContentBackground(.hidden)
    }

    // MARK: - Card View

    @ViewBuilder
    private func recipeCard(for item: ArdiyeItem) -> some View {
        RecipeCardView(
            item: item,
            onRecipeTap: { recipe in
                selectedRecipe = recipe
            },
            onFoodItemTap: { foodItem in
                selectedFoodItem = foodItem
            }
        )
    }

    // MARK: - Helper Functions

    private func toggleFavoriteItem(_ item: ArdiyeItem) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            if let recipe = item.recipe {
                recipe.toggleFavorite()
            } else if let foodItem = item.foodItem {
                foodItem.toggleFavorite()
            }

            saveContext()
            // Update cache after save
            updateCachedItems()
        }
    }

    private func deleteItems(at offsets: IndexSet) {
        withAnimation(.easeOut(duration: 0.3)) {
            for index in offsets {
                let item = displayedItems[index]
                if let recipe = item.recipe {
                    viewContext.delete(recipe)
                } else if let foodItem = item.foodItem {
                    viewContext.delete(foodItem)
                }
            }

            saveContext()
            // Update cache after delete
            updateCachedItems()
        }
    }

    private func deleteItem(_ item: ArdiyeItem) {
        withAnimation(.easeOut(duration: 0.3)) {
            if let recipe = item.recipe {
                viewContext.delete(recipe)
            } else if let foodItem = item.foodItem {
                viewContext.delete(foodItem)
            }

            saveContext()
            // Update cache after delete
            updateCachedItems()
        }
    }

    // MARK: - Demo Data

    private func addDemoProductsIfNeeded() {
        // Check if demo products already exist
        let fetchRequest = FoodItem.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "source == %@", "ai_scanned")

        do {
            let existingItems = try viewContext.fetch(fetchRequest)
            // Only add demo products if none exist
            if existingItems.isEmpty {
                addDemoProducts()
            }
        } catch {
            logger.error("Failed to fetch food items: \(error.localizedDescription)")
        }
    }

    private func addDemoProducts() {
        DemoDataService.addDemoProducts(to: viewContext)
        updateCachedItems()
    }
}

// MARK: - Interactive Card Button Style

struct CardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Preview Helper
struct ArdiyeView_Previews: PreviewProvider {
    static var previews: some View {
        // Use the shared preview controller which seeds sample data
        let controller = PersistenceController.preview

        // Add demo product cards
        addDemoProducts(to: controller.viewContext)

        return NavigationStack {
            ArdiyeView(searchText: .constant(""))
                .environment(\.managedObjectContext, controller.viewContext)
        }
    }

    static func addDemoProducts(to context: NSManagedObjectContext) {
        DemoDataService.addDemoProducts(to: context)
    }
}

  
