//
//  RecipeDetailView.swift
//  balli
//
//  iOS 26 recipe detail screen with hero image and glass UI
//  Matches Apple News+ recipe presentation style
//

import SwiftUI
import CoreData
import OSLog

/// Full-screen recipe detail with hero image and interactive elements
struct RecipeDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext

    let recipeData: RecipeDetailData

    // ViewModel handles all business logic
    @StateObject private var viewModel: RecipeDetailViewModel

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.balli", category: "RecipeDetailView")

    // MARK: - Initialization

    init(recipeData: RecipeDetailData) {
        self.recipeData = recipeData

        // Must use _viewModel for @StateObject initialization
        _viewModel = StateObject(wrappedValue: RecipeDetailViewModel(
            recipeData: recipeData,
            viewContext: recipeData.recipe.managedObjectContext ?? PersistenceController.shared.container.viewContext
        ))
    }

    // MARK: - Computed Properties

    var body: some View {
        GeometryReader { geometry in
            // Calculate consistent hero image height (50% of screen including safe area)
            let safeAreaTop = geometry.safeAreaInsets.top
            let screenHeight = geometry.size.height + safeAreaTop
            let heroImageHeight = screenHeight * 0.5

            ZStack {
                ScrollView {
                    ZStack(alignment: .top) {
                        VStack(spacing: 0) {
                            // Hero image that scrolls with content
                            RecipeHeroImageSection(
                                geometry: geometry,
                                imageData: recipeData.imageData,
                                imageURL: recipeData.imageURL,
                                generatedImageData: viewModel.generatedImageData,
                                isGeneratingPhoto: viewModel.isGeneratingPhoto,
                                onGeneratePhoto: {
                                    Task {
                                        await viewModel.generatePhoto()
                                    }
                                }
                            )
                            .ignoresSafeArea(edges: .top)

                            // Spacer to accommodate story card overlap
                            Spacer()
                                .frame(height: 49)

                            // All content below story card
                            VStack(spacing: 0) {
                                // Action buttons
                                RecipeActionButtonsSection(
                                    recipe: recipeData.recipe,
                                    isEditing: viewModel.isEditing,
                                    hasUncheckedIngredientsInShoppingList: viewModel.hasUncheckedIngredients,
                                    onAction: { action in
                                        viewModel.handleAction(action)
                                    }
                                )
                                .padding(.horizontal, 20)
                                .padding(.top, 0)
                                .padding(.bottom, 16)

                                // Recipe Content (Ingredients + Instructions)
                                RecipeContentSection(
                                    recipe: recipeData.recipe,
                                    isEditing: viewModel.isEditing,
                                    editedIngredients: $viewModel.editedIngredients,
                                    editedInstructions: $viewModel.editedInstructions
                                )
                                .padding(.horizontal, 20)
                                .padding(.bottom, 40)
                            }
                        }

                        // Recipe metadata - positioned absolutely over hero image
                        VStack(spacing: 0) {
                            Spacer(minLength: 0)

                            RecipeMetadataSection(
                                recipeSource: recipeData.recipe.source,
                                author: recipeData.author,
                                recipeName: recipeData.recipeName,
                                isEditing: viewModel.isEditing,
                                editedName: $viewModel.editedName
                            )
                            .padding(.horizontal, 20)
                            .padding(.bottom, 12)
                        }
                        .frame(height: heroImageHeight - 49)

                        // Story card - positioned absolutely at fixed offset
                        if recipeData.hasStory {
                            VStack(spacing: 0) {
                                Spacer()
                                    .frame(height: heroImageHeight - 49)

                                RecipeStoryCardSection(
                                    hasStory: recipeData.hasStory,
                                    isCalculatingNutrition: viewModel.isCalculatingNutrition,
                                    currentLoadingStep: viewModel.currentLoadingStep,
                                    nutritionCalculationProgress: viewModel.nutritionCalculationProgress,
                                    hasNutritionData: viewModel.hasNutritionData,
                                    onTap: {
                                        viewModel.handleStoryCardTap()
                                    }
                                )
                                .padding(.horizontal, 20)
                            }
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .safeAreaInset(edge: .top, spacing: 0) {
                    Color.clear.frame(height: 0)
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .toast($viewModel.toastMessage)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                if viewModel.isEditing {
                    Button("İptal") {
                        viewModel.cancelEditing()
                    }
                    .foregroundStyle(ThemeColors.primaryPurple)
                } else {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(ThemeColors.primaryPurple)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                if viewModel.isEditing {
                    Button("Kaydet") {
                        viewModel.saveChanges()
                    }
                    .foregroundStyle(ThemeColors.primaryPurple)
                } else {
                    Menu {
                        Button {
                            viewModel.startEditing()
                        } label: {
                            Label("Düzenle", systemImage: "pencil")
                        }

                        Button {
                            viewModel.toggleFavorite()
                        } label: {
                            Label(
                                recipeData.recipe.isFavorite ? "Favorilerden Çıkar" : "Favorilere Ekle",
                                systemImage: recipeData.recipe.isFavorite ? "star.fill" : "star"
                            )
                        }

                        Button(role: .destructive) {
                            viewModel.deleteRecipe(dismiss: dismiss)
                        } label: {
                            Label("Sil", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(ThemeColors.primaryPurple)
                    }
                }
            }
        }
        .toolbarBackground(.automatic, for: .navigationBar)
        .sheet(isPresented: $viewModel.showingNutritionalValues) {
            NutritionalValuesView(
                recipe: ObservableRecipeWrapper(recipe: recipeData.recipe),
                recipeName: recipeData.recipeName,
                calories: String(format: "%.0f", recipeData.recipe.calories),
                carbohydrates: String(format: "%.1f", recipeData.recipe.totalCarbs),
                fiber: String(format: "%.1f", recipeData.recipe.fiber),
                sugar: String(format: "%.1f", recipeData.recipe.sugars),
                protein: String(format: "%.1f", recipeData.recipe.protein),
                fat: String(format: "%.1f", recipeData.recipe.totalFat),
                glycemicLoad: String(format: "%.0f", recipeData.recipe.glycemicLoad),
                caloriesPerServing: String(format: "%.0f", recipeData.recipe.caloriesPerServing),
                carbohydratesPerServing: String(format: "%.1f", recipeData.recipe.carbsPerServing),
                fiberPerServing: String(format: "%.1f", recipeData.recipe.fiberPerServing),
                sugarPerServing: String(format: "%.1f", recipeData.recipe.sugarsPerServing),
                proteinPerServing: String(format: "%.1f", recipeData.recipe.proteinPerServing),
                fatPerServing: String(format: "%.1f", recipeData.recipe.fatPerServing),
                glycemicLoadPerServing: String(format: "%.0f", recipeData.recipe.glycemicLoadPerServing),
                totalRecipeWeight: String(format: "%.0f", recipeData.recipe.totalRecipeWeight),
                digestionTiming: viewModel.digestionTimingInsights,
                portionMultiplier: Binding(
                    get: { recipeData.recipe.portionMultiplier },
                    set: { newValue in
                        recipeData.recipe.portionMultiplier = newValue
                        Task { @MainActor in
                            viewModel.savePortionMultiplier()
                        }
                    }
                )
            )
            .presentationDetents([.large])
        }
        .sheet(isPresented: $viewModel.showingNotesModal) {
            UserNotesModalView(notes: $viewModel.userNotes) { newNotes in
                logger.info("💬 [NOTES] User saved notes: '\(newNotes.prefix(50))...'")
                viewModel.saveUserNotes(newNotes)
            }
        }
        .onAppear {
            // Track recipe opening by updating lastModified
            recipeData.recipe.lastModified = Date()
            do {
                try viewContext.save()
                logger.debug("📖 Recipe opened, lastModified updated for tracking")
            } catch {
                logger.error("❌ Failed to update recipe lastModified: \(error.localizedDescription)")
            }

            // Check shopping list status on view appear
            Task {
                await viewModel.checkShoppingListStatus()
            }
        }
        .onChange(of: recipeData.recipe.id) { _, _ in
            Task {
                await viewModel.checkShoppingListStatus()
            }
        }
    }
}

// MARK: - Preview

#Preview("Tamarind-Peach Lassi") {
    let recipeData = RecipeDetailData.preview()
    let controller = Persistence.PersistenceController(inMemory: true)

    return NavigationStack {
        RecipeDetailView(recipeData: recipeData)
            .environment(\.managedObjectContext, controller.viewContext)
    }
}

#Preview("Without Story Card") {
    let controller = Persistence.PersistenceController(inMemory: true)
    let context = controller.viewContext
    let recipe = Recipe(context: context)

    recipe.id = UUID()
    recipe.name = "Classic Hummus"
    recipe.servings = 6
    recipe.imageURL = nil
    recipe.dateCreated = Date()
    recipe.lastModified = Date()
    recipe.source = "manual"
    recipe.isVerified = false
    recipe.isFavorite = false
    recipe.timesCooked = 0
    recipe.userRating = 0
    recipe.calories = 120
    recipe.totalCarbs = 15
    recipe.fiber = 4
    recipe.sugars = 1
    recipe.protein = 5
    recipe.totalFat = 6
    recipe.glycemicLoad = 5
    recipe.prepTime = 10
    recipe.cookTime = 0
    recipe.ingredients = ["1 can chickpeas", "1/4 cup tahini", "2 tbsp lemon juice", "2 cloves garlic", "2 tbsp olive oil", "Salt to taste"] as NSArray
    recipe.instructions = ["Drain chickpeas", "Blend all ingredients", "Adjust seasoning", "Serve with olive oil drizzle"] as NSArray

    let detailData = RecipeDetailData(
        recipe: recipe,
        recipeSource: "Mediterranean Kitchen",
        author: "Chef Maria",
        yieldText: "6",
        recipeDescription: "This creamy, smooth hummus is perfect for dipping or spreading.",
        storyTitle: nil,
        storyDescription: nil,
        storyThumbnailURL: nil
    )

    return NavigationStack {
        RecipeDetailView(recipeData: detailData)
            .environment(\.managedObjectContext, context)
    }
}
