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
struct ArdiyeItem: Identifiable, Equatable {
    let id: UUID
    let name: String
    let displayTitle: String
    let subtitle: String
    let totalCarbs: Double
    let servingSize: Double
    let servingUnit: String
    let isFavorite: Bool
    let isRecipe: Bool

    // Optional references to actual entities
    let recipe: Recipe?
    let foodItem: FoodItem?

    static func == (lhs: ArdiyeItem, rhs: ArdiyeItem) -> Bool {
        lhs.id == rhs.id
    }
}

enum ArdiyeFilter: String, CaseIterable {
    case recipes = "tarif"
    case products = "ürün"
}

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

    // Core Data fetch request for Shopping List items to show dynamic basket icon
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \ShoppingListItem.dateCreated, ascending: false)],
        animation: .default
    )
    private var allShoppingItems: FetchedResults<ShoppingListItem>

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

    // Check if there are any unchecked items in shopping list (for dynamic basket icon)
    private var hasUncheckedItems: Bool {
        allShoppingItems.contains { !$0.isCompleted }
    }

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
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.automatic, for: .navigationBar)
        .toolbar {
            // Logo with long-press gesture for settings
            ToolbarItem(placement: .principal) {
                Image("balli-text-logo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 28)
                    .onLongPressGesture(minimumDuration: 0.5) {
                        showingSettings = true
                    }
            }

            // Shopping basket — top-left (dynamic: filled when unchecked items exist)
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    showingShoppingList = true
                }) {
                    Image(systemName: hasUncheckedItems ? "basket.fill" : "basket")
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
                    Image(systemName: selectedFilter == .recipes ? "book.closed.fill" : "laser.burst")
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundColor(AppTheme.primaryPurple)
                }
            }
        }
        .onAppear {
            // Add demo products on first appearance
            addDemoProductsIfNeeded()
            // Initial load of cached items - preserve data operations
            updateCachedItems()
        }
        .onChange(of: recipes.count) { _, _ in
            updateCachedItems()
        }
        .onChange(of: foodItems.count) { _, _ in
            updateCachedItems()
        }
        .onReceive(
            NotificationCenter.default.publisher(for: NSNotification.Name.NSManagedObjectContextDidSave),
            perform: { notification in
                logger.info("🔔 [ARDIYE] NSManagedObjectContextDidSave notification received")

                // Log what was updated/inserted
                if let userInfo = notification.userInfo {
                    if let inserted = userInfo[NSInsertedObjectsKey] as? Set<NSManagedObject> {
                        logger.info("  - Inserted objects: \(inserted.count)")
                        for obj in inserted {
                            if let recipe = obj as? Recipe {
                                if let imageData = recipe.imageData {
                                    logger.info("    • Recipe inserted: '\(recipe.name)' - imageData: \(imageData.count) bytes")
                                } else {
                                    logger.info("    • Recipe inserted: '\(recipe.name)' - imageData: nil")
                                }
                            }
                        }
                    }

                    if let updated = userInfo[NSUpdatedObjectsKey] as? Set<NSManagedObject> {
                        logger.info("  - Updated objects: \(updated.count)")
                        for obj in updated {
                            if let recipe = obj as? Recipe {
                                if let imageData = recipe.imageData {
                                    logger.info("    • Recipe updated: '\(recipe.name)' - imageData: \(imageData.count) bytes")
                                } else {
                                    logger.info("    • Recipe updated: '\(recipe.name)' - imageData: nil")
                                }
                            } else if let foodItem = obj as? FoodItem {
                                logger.info("    • FoodItem: \(foodItem.name) - \(foodItem.servingSize)g")
                            }
                        }
                    }
                }

                // Refresh all objects in the view context to ensure we have latest data
                logger.info("🔄 [ARDIYE] Refreshing all Core Data objects")
                viewContext.refreshAllObjects()

                // Refresh cached items when Core Data is saved (e.g., from detail view)
                logger.info("🔄 [ARDIYE] Calling updateCachedItems() to refresh display")
                updateCachedItems()
                logger.info("✅ [ARDIYE] updateCachedItems() completed")
            }
        )
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
                                Image(systemName: "trash")
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
                                carbs: "\(Int(foodItem.totalCarbs)) gr Karb.",
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
        Group {
            if item.isRecipe, let recipe = item.recipe {
                // Recipe - Open as full screen modal
                Button(action: {
                    selectedRecipe = recipe
                }) {
                    recipeCardContent(for: item)
                }
                .buttonStyle(CardButtonStyle())
            } else if let foodItem = item.foodItem {
                // Scanned packaged food product - Open product detail view
                Button(action: {
                    selectedFoodItem = foodItem
                }) {
                    recipeCardContent(for: item)
                }
                .buttonStyle(CardButtonStyle())
            } else {
                // Fallback for items without proper entity reference
                recipeCardContent(for: item)
            }
        }
    }

    @ViewBuilder
    private func recipeCardContent(for item: ArdiyeItem) -> some View {
        if item.isRecipe, let recipe = item.recipe {
            // Recipe card layout
            recipeCardLayout(item: item, recipe: recipe)
        } else {
            // Fallback layout
            recipeCardLayout(item: item, recipe: nil)
        }
    }

    // MARK: - Recipe Card Layout

    @ViewBuilder
    private func recipeCardLayout(item: ArdiyeItem, recipe: Recipe?) -> some View {
        HStack(spacing: 0) {
            // Left side - Text content
            VStack(alignment: .leading, spacing: 8) {
                // Recipe name
                Text(item.name)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundColor(.primary)

                Spacer()

                // Serving size
                Text("\(Int(item.servingSize)) \(item.servingUnit)")
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(.primary.opacity(0.7))

                // Carb amount
                Text("\(Int(item.totalCarbs)) gr Karb.")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.primary)
            }
            .padding(.vertical, 16)
            .padding(.leading, 16)
            .frame(maxWidth: .infinity, alignment: .leading)

            // Right side - Photo (if recipe exists)
            if let recipe = recipe {
                ZStack(alignment: .bottomTrailing) {
                    recipePhoto(for: recipe)

                    // Yellow star on bottom right if favorited
                    if recipe.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.system(size: ResponsiveDesign.Font.scaledSize(20), weight: .semibold))
                            .foregroundColor(Color(red: 1, green: 0.85, blue: 0, opacity: 1))
                            .padding(.bottom, 16)
                            .padding(.trailing, 16)
                    }
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
    @ViewBuilder
    private func recipePhoto(for recipe: Recipe) -> some View {
        if let imageData = recipe.imageData, let uiImage = UIImage(data: imageData) {
            let _ = logger.debug("🖼️ [ARDIYE] Displaying photo for recipe '\(recipe.name)' (\(imageData.count) bytes)")
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 140, height: 140)
                .clipShape(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                )
        } else {
            let _ = logger.debug("📷 [ARDIYE] No photo for recipe '\(recipe.name)' - showing placeholder")
            // Placeholder for recipes without photos
            ZStack {
                Color.secondary.opacity(0.1)
                Image(systemName: "photo")
                    .font(.system(size: 32))
                    .foregroundStyle(.secondary.opacity(0.3))
            }
            .frame(width: 140, height: 140)
            .clipShape(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
            )
        }
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
        let demoProducts = [
            (
                name: "Whole Wheat Bread",
                brand: "Deli's Best",
                carbs: 42.0,
                protein: 4.0,
                totalFat: 2.0,
                fiber: 3.0,
                sugars: 3.0,
                servingSize: 50.0,
                servingUnit: "gr",
                calories: 200.0
            ),
            (
                name: "Greek Yogurt",
                brand: "Fage",
                carbs: 6.5,
                protein: 10.0,
                totalFat: 3.0,
                fiber: 0.0,
                sugars: 4.0,
                servingSize: 150.0,
                servingUnit: "gr",
                calories: 100.0
            ),
            (
                name: "Granola Cereal",
                brand: "Nature Valley",
                carbs: 35.0,
                protein: 6.0,
                totalFat: 8.0,
                fiber: 2.0,
                sugars: 12.0,
                servingSize: 40.0,
                servingUnit: "gr",
                calories: 180.0
            ),
            (
                name: "Almond Butter",
                brand: "Justin's",
                carbs: 4.0,
                protein: 7.0,
                totalFat: 9.0,
                fiber: 2.5,
                sugars: 1.0,
                servingSize: 32.0,
                servingUnit: "gr",
                calories: 190.0
            )
        ]

        for product in demoProducts {
            let foodItem = FoodItem(context: viewContext)
            foodItem.id = UUID()
            foodItem.name = product.name
            foodItem.brand = product.brand
            foodItem.totalCarbs = product.carbs
            foodItem.protein = product.protein
            foodItem.totalFat = product.totalFat
            foodItem.fiber = product.fiber
            foodItem.sugars = product.sugars
            // Calculate calories from macros to ensure validation passes
            let carbCals = product.carbs * 4
            let proteinCals = product.protein * 4
            let fatCals = product.totalFat * 9
            let calculatedCalories = carbCals + proteinCals + fatCals
            foodItem.calories = calculatedCalories
            foodItem.servingSize = product.servingSize
            foodItem.servingUnit = product.servingUnit
            foodItem.source = "ai_scanned"
            foodItem.dateAdded = Date()
            foodItem.lastModified = Date()
            foodItem.lastUsed = Date()
            foodItem.isFavorite = false
            foodItem.overallConfidence = 85.0
            foodItem.carbsConfidence = 90.0
            foodItem.ocrConfidence = 80.0
            foodItem.isVerified = true
            foodItem.gramWeight = product.servingSize
        }

        saveContext()
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
        // Check if demo products already exist
        let fetchRequest = FoodItem.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "source == %@", "ai_scanned")

        guard (try? context.fetch(fetchRequest))?.isEmpty ?? true else {
            return // Products already exist
        }

        let demoProducts = [
            (
                name: "Whole Wheat Bread",
                brand: "Deli's Best",
                carbs: 42.0,
                protein: 4.0,
                totalFat: 2.0,
                fiber: 3.0,
                sugars: 3.0,
                servingSize: 50.0,
                servingUnit: "gr",
                calories: 200.0
            ),
            (
                name: "Greek Yogurt",
                brand: "Fage",
                carbs: 6.5,
                protein: 10.0,
                totalFat: 3.0,
                fiber: 0.0,
                sugars: 4.0,
                servingSize: 150.0,
                servingUnit: "gr",
                calories: 100.0
            ),
            (
                name: "Granola Cereal",
                brand: "Nature Valley",
                carbs: 35.0,
                protein: 6.0,
                totalFat: 8.0,
                fiber: 2.0,
                sugars: 12.0,
                servingSize: 40.0,
                servingUnit: "gr",
                calories: 180.0
            ),
            (
                name: "Almond Butter",
                brand: "Justin's",
                carbs: 4.0,
                protein: 7.0,
                totalFat: 9.0,
                fiber: 2.5,
                sugars: 1.0,
                servingSize: 32.0,
                servingUnit: "gr",
                calories: 190.0
            )
        ]

        for product in demoProducts {
            let foodItem = FoodItem(context: context)
            foodItem.id = UUID()
            foodItem.name = product.name
            foodItem.brand = product.brand
            foodItem.totalCarbs = product.carbs
            foodItem.protein = product.protein
            foodItem.totalFat = product.totalFat
            foodItem.fiber = product.fiber
            foodItem.sugars = product.sugars
            foodItem.calories = product.calories
            foodItem.servingSize = product.servingSize
            foodItem.servingUnit = product.servingUnit
            foodItem.source = "ai_scanned"
            foodItem.dateAdded = Date()
            foodItem.lastModified = Date()
            foodItem.lastUsed = Date()
            foodItem.isFavorite = false
            foodItem.overallConfidence = 85.0
            foodItem.carbsConfidence = 90.0
            foodItem.ocrConfidence = 80.0
            foodItem.isVerified = true
            foodItem.gramWeight = product.servingSize
        }

        do {
            try context.save()
        } catch {
            print("Preview: Failed to save demo products: \(error.localizedDescription)")
        }
    }
}

  
