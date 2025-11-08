//
//  ArdiyeSearchView.swift
//  balli
//
//  Search view for food archive - displays filtered recipes and products
//

import SwiftUI
import CoreData

struct ArdiyeSearchView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Binding var searchText: String
    @State private var selectedRecipe: Recipe? = nil
    @State private var selectedFoodItem: FoodItem? = nil
    @State private var selectedFilter: ArdiyeFilter = .recipes

    // Core Data fetch request for FoodItems
    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \FoodItem.lastUsed, ascending: false),
            NSSortDescriptor(keyPath: \FoodItem.dateAdded, ascending: false)
        ],
        animation: .default
    )
    private var foodItems: FetchedResults<FoodItem>

    // Core Data fetch request for Recipes
    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \Recipe.lastModified, ascending: false),
            NSSortDescriptor(keyPath: \Recipe.dateCreated, ascending: false)
        ],
        animation: .default
    )
    private var recipes: FetchedResults<Recipe>

    // Get recently opened recipes (latest 3)
    private var recentlyOpenedRecipes: [Recipe] {
        let sortedByLastOpened = recipes.filter { recipe in
            // Only include recipes that have been opened (lastModified is recent)
            // We'll use this as a proxy until we add dedicated tracking
            recipe.lastModified > Date().addingTimeInterval(-30 * 24 * 60 * 60) // Last 30 days
        }
        .sorted { $0.lastModified > $1.lastModified }

        return Array(sortedByLastOpened.prefix(3))
    }

    // Get all items and filter by search
    private var displayedItems: [ArdiyeItem] {
        var items: [ArdiyeItem] = []

        // Add recipes
        for recipe in recipes {
            items.append(
                ArdiyeItem(
                    id: recipe.id,
                    name: recipe.name,
                    displayTitle: recipe.name,
                    subtitle: "",
                    totalCarbs: recipe.totalCarbs,
                    servingSize: 100.0,
                    servingUnit: "gr",
                    isFavorite: recipe.isFavorite,
                    isRecipe: true,
                    recipe: recipe,
                    foodItem: nil
                ))
        }

        // Add scanned packaged food products
        for foodItem in foodItems where foodItem.source == "ai_scanned" {
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

        // Filter by type
        let typeFilteredItems: [ArdiyeItem]
        switch selectedFilter {
        case .recipes:
            typeFilteredItems = items.filter { $0.isRecipe }
        case .products:
            typeFilteredItems = items.filter { !$0.isRecipe }
        }

        // If search is empty, show recently opened recipes (only for recipes filter)
        if searchText.isEmpty {
            if selectedFilter == .recipes {
                return recentlyOpenedRecipes.map { recipe in
                    ArdiyeItem(
                        id: recipe.id,
                        name: recipe.name,
                        displayTitle: recipe.name,
                        subtitle: "",
                        totalCarbs: recipe.totalCarbs,
                        servingSize: 100.0,
                        servingUnit: "gr",
                        isFavorite: recipe.isFavorite,
                        isRecipe: true,
                        recipe: recipe,
                        foodItem: nil
                    )
                }
            }
            return []
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

    var body: some View {
        GlassEffectContainer {
            if displayedItems.isEmpty {
                // Empty state
                VStack(spacing: 20) {
                    Spacer()

                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 64, weight: .semibold))
                        .foregroundColor(.secondary.opacity(0.5))

                    if searchText.isEmpty {
                        VStack(spacing: 8) {
                            Text("Tarif veya Ürün Ara")
                                .font(.system(size: 20, weight: .semibold, design: .rounded))
                                .foregroundColor(.primary)

                            Text("İsme, malzemeye veya karbonhidrat miktarına göre ara")
                                .font(.system(size: 15, weight: .regular, design: .rounded))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    } else {
                        VStack(spacing: 8) {
                            Text("Sonuç Bulunamadı")
                                .font(.system(size: 20, weight: .semibold, design: .rounded))
                                .foregroundColor(.primary)

                            Text("Farklı bir arama terimi deneyin")
                                .font(.system(size: 15, weight: .regular, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()
                }
                .padding(.horizontal, 40)
            } else {
                // Results list
                if selectedFilter == .recipes {
                    recipeListViewWithHeader
                } else {
                    productGridLayout
                }
            }
        }
        .navigationTitle("Ara")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Filter button - only show when there's a search query
            if !searchText.isEmpty {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        withAnimation {
                            selectedFilter = selectedFilter == .recipes ? .products : .recipes
                        }
                    }) {
                        Image(systemName: selectedFilter == .recipes ? "book.closed" : "laser.burst")
                            .font(.system(size: 18, weight: .medium, design: .rounded))
                            .foregroundColor(.primary)
                    }
                }
            }
        }
        .fullScreenCover(item: $selectedRecipe) { recipe in
            NavigationStack {
                RecipeDetailView(recipeData: RecipeDetailData(recipe: recipe))
            }
        }
        .fullScreenCover(item: $selectedFoodItem) { foodItem in
            NavigationStack {
                FoodItemDetailView(foodItem: foodItem)
                    .environment(\.managedObjectContext, viewContext)
            }
        }
    }

    // MARK: - Recipe List View

    @ViewBuilder
    private var recipeListViewWithHeader: some View {
        List {
            // Show header only when displaying recently opened recipes
            if searchText.isEmpty && !displayedItems.isEmpty {
                Section {
                    ForEach(displayedItems) { item in
                        if let recipe = item.recipe {
                            Button(action: {
                                selectedRecipe = recipe
                            }) {
                                recipeCardContent(for: item, recipe: recipe)
                            }
                            .buttonStyle(.plain)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }
                    }
                } header: {
                    Text("Son Açılanlar")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.secondary)
                        .textCase(.none)
                        .padding(.leading, 4)
                        .padding(.top, 0)
                }
                .listRowBackground(Color.clear)
            } else {
                // Search results without header
                ForEach(displayedItems) { item in
                    if let recipe = item.recipe {
                        Button(action: {
                            selectedRecipe = recipe
                        }) {
                            recipeCardContent(for: item, recipe: recipe)
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .contentMargins(.top, 0, for: .scrollContent)
    }

    @ViewBuilder
    private var recipeListView: some View {
        List {
            ForEach(displayedItems) { item in
                if let recipe = item.recipe {
                    Button(action: {
                        selectedRecipe = recipe
                    }) {
                        recipeCardContent(for: item, recipe: recipe)
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Product Grid View

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
                                carbs: "\(Int(foodItem.totalCarbs)) gr Karb.",
                                width: nil,
                                isFavorite: foodItem.isFavorite,
                                impactLevel: foodItem.impactLevelDetailed,
                                onToggleFavorite: {
                                    foodItem.toggleFavorite()
                                    try? viewContext.save()
                                },
                                onDelete: {
                                    viewContext.delete(foodItem)
                                    try? viewContext.save()
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

    // MARK: - Recipe Card Content

    @ViewBuilder
    private func recipeCardContent(for item: ArdiyeItem, recipe: Recipe) -> some View {
        HStack(spacing: 0) {
            // Left side - Text content
            VStack(alignment: .leading, spacing: 8) {
                Text(item.name)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundColor(.primary)

                Spacer()

                Text("\(Int(item.servingSize)) \(item.servingUnit)")
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(.primary.opacity(0.7))

                Text("\(Int(item.totalCarbs)) gr Karb.")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.primary)
            }
            .padding(.vertical, 16)
            .padding(.leading, 16)
            .frame(maxWidth: .infinity, alignment: .leading)

            // Right side - Photo
            ZStack(alignment: .bottomTrailing) {
                if let imageData = recipe.imageData, let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 140, height: 140)
                        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                } else {
                    ZStack {
                        Color.secondary.opacity(0.1)
                        Image(systemName: "photo")
                            .font(.system(size: 32))
                            .foregroundStyle(.secondary.opacity(0.3))
                    }
                    .frame(width: 140, height: 140)
                    .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                }

                // Yellow star if favorited
                if recipe.isFavorite {
                    Image(systemName: "star.fill")
                        .font(.system(size: ResponsiveDesign.Font.scaledSize(20), weight: .semibold))
                        .foregroundColor(Color(red: 1, green: 0.85, blue: 0, opacity: 1))
                        .padding(.bottom, 16)
                        .padding(.trailing, 16)
                }
            }
        }
        .frame(height: 140)
        .background(.clear)
        .glassEffect(
            .regular.interactive(),
            in: RoundedRectangle(cornerRadius: 32, style: .continuous)
        )
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: ResponsiveDesign.height(8), x: 0, y: ResponsiveDesign.height(4))
        .contentShape(Rectangle())
    }
}

#Preview {
    NavigationStack {
        ArdiyeSearchView(searchText: .constant(""))
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
