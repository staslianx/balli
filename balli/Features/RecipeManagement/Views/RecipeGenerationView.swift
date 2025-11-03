//
//  RecipeGenerationView.swift
//  balli
//
//  Recipe generation view with streaming markdown content
//  Shows generated recipe with ingredients, instructions, and photo generation
//

import SwiftUI
import CoreData
import OSLog

struct RecipeGenerationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @StateObject private var viewModel: RecipeViewModel
    @StateObject private var actionsHandler = RecipeGenerationActionsHandler()
    @StateObject private var loadingHandler = LoadingAnimationHandler()

    private let helper = RecipeGenerationViewHelper()

    @State private var showingMealSelection = false
    @State private var showingNutritionModal = false
    @State private var selectedMealType = "Kahvaltı"
    @State private var selectedStyleType = ""
    @State private var isGenerating = false
    @State private var isSaved = false
    @State private var isAddingIngredient = false
    @State private var isAddingStep = false
    @State private var newIngredientText = ""
    @State private var newStepText = ""
    @State private var manualIngredients: [RecipeItem] = []
    @State private var manualSteps: [RecipeItem] = []
    @State private var storyCardTitle = "balli'nin tarif analizi"
    @State private var userNotes: String = ""
    @State private var toastMessage: ToastType? = nil
    @FocusState private var focusedField: FocusField?

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.balli",
        category: "RecipeGenerationView"
    )

    // MARK: - Shopping List Query for Dynamic Basket Icon
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \ShoppingListItem.dateCreated, ascending: false)],
        animation: .default
    )
    private var allShoppingItems: FetchedResults<ShoppingListItem>

    enum FocusField {
        case ingredient
        case step
    }

    init(viewContext: NSManagedObjectContext) {
        _viewModel = StateObject(wrappedValue: RecipeViewModel(context: viewContext))
    }

    // MARK: - Computed Properties

    /// Determines if save button should be visible
    /// Shows for AI-generated recipes OR manual recipes with content
    private var shouldShowSaveButton: Bool {
        if isSaved { return false }

        // AI-generated recipe
        if !viewModel.recipeName.isEmpty {
            return true
        }

        // Manual recipe with ingredients or steps
        let hasManualContent = !manualIngredients.isEmpty || !manualSteps.isEmpty
        return hasManualContent
    }

    /// Determines if recipe is a manual entry (vs AI-generated)
    private var isManualRecipe: Bool {
        viewModel.recipeName.isEmpty && (!manualIngredients.isEmpty || !manualSteps.isEmpty)
    }

    /// Check if this recipe has unchecked ingredients in shopping list (for dynamic basket icon)
    /// Matches by recipe name since generated recipes may not be saved yet
    private var hasUncheckedIngredientsForRecipe: Bool {
        let recipeName = viewModel.recipeName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !recipeName.isEmpty else { return false }

        return allShoppingItems.contains { item in
            item.recipeName == recipeName && !item.isCompleted
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // MARK: - Scrollable Content
                ScrollView {
                    ZStack(alignment: .top) {
                        VStack(spacing: 0) {
                            // Hero image
                            RecipeGenerationHeroImage(
                                recipeName: viewModel.recipeName,
                                preparedImage: viewModel.preparedImage,
                                isGeneratingPhoto: viewModel.isGeneratingPhoto,
                                recipeContent: viewModel.formState.recipeContent,
                                geometry: geometry,
                                onGeneratePhoto: {
                                    Task {
                                        await generatePhoto()
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
                                RecipeGenerationActionButtons(
                                    isFavorited: actionsHandler.isFavorited,
                                    hasUncheckedIngredientsInShoppingList: hasUncheckedIngredientsForRecipe
                                ) { action in
                                    actionsHandler.handleAction(action, viewModel: viewModel)
                                }
                                .padding(.horizontal, 20)
                                .padding(.top, 0)
                                .padding(.bottom, 16)

                                // Recipe content (markdown or manual input)
                                RecipeGenerationContentSection(
                                    recipeContent: viewModel.recipeContent,
                                    manualIngredients: $manualIngredients,
                                    manualSteps: $manualSteps,
                                    isAddingIngredient: $isAddingIngredient,
                                    isAddingStep: $isAddingStep,
                                    newIngredientText: $newIngredientText,
                                    newStepText: $newStepText,
                                    focusedField: $focusedField
                                )
                                .padding(.horizontal, 20)
                                .padding(.bottom, 40)
                            }
                            .frame(maxWidth: .infinity)
                            .background(Color(.secondarySystemBackground))
                        }

                        // Recipe metadata - positioned absolutely over hero image
                        RecipeGenerationMetadata(
                            recipeName: viewModel.recipeName,
                            recipeContent: viewModel.formState.recipeContent,
                            geometry: geometry
                        )

                        // Story card - positioned absolutely at fixed offset
                        RecipeGenerationStoryCard(
                            storyCardTitle: storyCardTitle,
                            isCalculatingNutrition: viewModel.isCalculatingNutrition,
                            currentLoadingStep: loadingHandler.currentLoadingStep,
                            nutritionCalculationProgress: viewModel.nutritionCalculationProgress,
                            geometry: geometry,
                            onTap: handleStoryCardTap
                        )
                    }
                }
                .scrollIndicators(.hidden)
                .background(Color(.secondarySystemBackground))
                .ignoresSafeArea(edges: .top)
            }
        }
        .toast($toastMessage)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(ThemeColors.primaryPurple)
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                    // Save button (visible for AI-generated recipes or manual entries)
                    if shouldShowSaveButton {
                        Button {
                            Task {
                                await saveRecipe()
                            }
                        } label: {
                            Image(systemName: "checkmark")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(ThemeColors.primaryPurple)
                        }
                    }

                    // Generate menu button (balli logo)
                    Button {
                        // EDGE CASE PROTECTION: If recipe already exists, treat notes as personal notes (not prompts)
                        // This prevents accidental regeneration when user writes post-generation notes
                        let hasExistingRecipe = !viewModel.recipeName.isEmpty

                        if hasExistingRecipe {
                            // Recipe exists → User's notes are personal, not prompts
                            // Always show menu for explicit "regenerate" intent
                            logger.info("⚠️ [EDGE-CASE] Recipe exists - treating notes as personal, showing menu for explicit regenerate")
                            showingMealSelection = true
                            return
                        }

                        // Smart behavior based on recipe generation flow logic:
                        // Flow 1: No ingredients + No notes → Show menu (need user intent)
                        // Flow 2: Ingredients only + No notes → Show menu (ingredients ambiguous without context)
                        // Flow 3: No ingredients + Notes → Skip menu (notes contain explicit intent)
                        // Flow 4: Ingredients + Notes → Skip menu (user being specific)

                        let hasIngredients = !manualIngredients.isEmpty
                        let hasUserNotes = !userNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

                        if hasUserNotes {
                            // Flows 3 & 4: Has notes (with or without ingredients) → Skip menu
                            if hasIngredients {
                                logger.info("🎯 [FLOW-4] Ingredients + Notes - skipping menu, user is specific")
                            } else {
                                logger.info("🎯 [FLOW-3] Notes only - skipping menu, notes contain intent")
                            }
                            Task {
                                await startGenerationWithDefaults()
                            }
                        } else {
                            // Flows 1 & 2: No notes → Show menu
                            if hasIngredients {
                                logger.info("🥕 [FLOW-2] Ingredients only - showing menu for context")
                            } else {
                                logger.info("📋 [FLOW-1] Empty state - showing menu for intent")
                            }
                            showingMealSelection = true
                        }
                    } label: {
                        Image("balli-logo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                    }
                }
            }
        }
        .toolbarBackground(.automatic, for: .navigationBar)
        .sheet(isPresented: $showingMealSelection) {
            RecipeMealSelectionView(
                selectedMealType: $selectedMealType,
                selectedStyleType: $selectedStyleType,
                onGenerate: {
                    Task {
                        await startGeneration()
                    }
                }
            )
            .presentationDetents([.fraction(0.4)])
        }
        .sheet(isPresented: $showingNutritionModal) {
            NutritionalValuesView(
                recipeName: viewModel.recipeName,
                calories: viewModel.calories,
                carbohydrates: viewModel.carbohydrates,
                fiber: viewModel.fiber,
                sugar: viewModel.sugar,
                protein: viewModel.protein,
                fat: viewModel.fat,
                glycemicLoad: viewModel.glycemicLoad,
                caloriesPerServing: viewModel.caloriesPerServing,
                carbohydratesPerServing: viewModel.carbohydratesPerServing,
                fiberPerServing: viewModel.fiberPerServing,
                sugarPerServing: viewModel.sugarPerServing,
                proteinPerServing: viewModel.proteinPerServing,
                fatPerServing: viewModel.fatPerServing,
                glycemicLoadPerServing: viewModel.glycemicLoadPerServing,
                totalRecipeWeight: viewModel.totalRecipeWeight,
                digestionTiming: viewModel.digestionTiming,
                portionMultiplier: $viewModel.portionMultiplier
            )
            .presentationDetents([.large])
        }
        .sheet(isPresented: $actionsHandler.showingNotesModal) {
            UserNotesModalView(notes: $userNotes) { newNotes in
                logger.info("💬 [NOTES] User saved notes: '\(newNotes.prefix(50))...'")
                userNotes = newNotes
            }
        }
        .onAppear {
            // Set up toast callback
            actionsHandler.onShowToast = { toast in
                toastMessage = toast
            }
        }
        .onChange(of: viewModel.isCalculatingNutrition) { oldValue, newValue in
            handleNutritionCalculationChange(oldValue: oldValue, newValue: newValue)
        }
    }

    // MARK: - Generation

    /// Generate recipe with user-selected meal type and style (called from meal selection modal)
    private func startGeneration() async {
        isGenerating = true
        isSaved = false

        // Extract ingredients from manual ingredients list
        let ingredientsList: [String]? = manualIngredients.isEmpty ? nil : manualIngredients.map { $0.text }

        // Extract user context from notes
        let contextText: String? = userNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : userNotes

        // Log what we're passing
        if let ingredients = ingredientsList {
            logger.info("🥕 [VIEW] Starting generation with \(ingredients.count) ingredients: \(ingredients.joined(separator: ", "))")
        }
        if let context = contextText {
            logger.info("📝 [VIEW] User context: '\(context)'")
        }

        // Smart routing: Use ingredients-based generation if ingredients exist, otherwise spontaneous
        await viewModel.generationCoordinator.generateRecipeSmartRouting(
            mealType: selectedMealType,
            styleType: selectedStyleType,
            ingredients: ingredientsList,
            userContext: contextText
        )
        isGenerating = false
    }

    /// Generate recipe with default meal type when user has provided notes (skips meal selection)
    /// Uses generic defaults since the user's notes contain all the specificity needed
    private func startGenerationWithDefaults() async {
        isGenerating = true
        isSaved = false

        // Extract ingredients from manual ingredients list
        let ingredientsList: [String]? = manualIngredients.isEmpty ? nil : manualIngredients.map { $0.text }

        // Extract user context from notes
        let contextText: String? = userNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : userNotes

        // Use generic defaults - the AI will follow the user's notes instead
        let defaultMealType = "Akşam Yemeği"  // Generic meal type
        let defaultStyleType = "Karbonhidrat ve Protein Uyumu"  // Generic style type

        logger.info("🎯 [VIEW] Starting generation with defaults (user notes contain specificity)")
        if let ingredients = ingredientsList {
            logger.info("🥕 [VIEW] With \(ingredients.count) ingredients: \(ingredients.joined(separator: ", "))")
        }
        if let context = contextText {
            logger.info("📝 [VIEW] User context: '\(context)'")
        }

        // Smart routing: Use ingredients-based generation if ingredients exist, otherwise spontaneous
        await viewModel.generationCoordinator.generateRecipeSmartRouting(
            mealType: defaultMealType,
            styleType: defaultStyleType,
            ingredients: ingredientsList,
            userContext: contextText
        )
        isGenerating = false
    }

    // MARK: - Save Recipe

    private func saveRecipe() async {
        logger.info("💾 [VIEW] saveRecipe() called")

        // Build manual recipe content if needed
        if !manualIngredients.isEmpty || !manualSteps.isEmpty {
            buildManualRecipeContent()

            // Generate default name for manual recipes
            if viewModel.recipeName.isEmpty {
                viewModel.recipeName = generateDefaultRecipeName()
                logger.info("📝 [VIEW] Generated default recipe name: \(viewModel.recipeName)")
            }
        }

        // Load image data if present
        if viewModel.generatedPhotoURL != nil {
            logger.info("🖼️ [VIEW] Photo URL present - loading image data before save...")
            await viewModel.loadImageFromGeneratedURL()
            logger.info("✅ [VIEW] Image data loaded - proceeding with save")
        }

        // Save recipe
        logger.info("💾 [VIEW] Calling viewModel.saveRecipe()...")
        viewModel.saveRecipe()

        // Wait for save to complete
        try? await Task.sleep(for: .milliseconds(100))

        // Show confirmation if successful
        if viewModel.persistenceCoordinator.showingSaveConfirmation {
            logger.info("✅ [VIEW] Save confirmed - showing success state")
            isSaved = true
            toastMessage = .success("Tarif kaydedildi!")
        } else {
            logger.warning("⚠️ [VIEW] Save confirmation not shown")
        }
    }

    private func buildManualRecipeContent() {
        let result = helper.buildManualRecipeContent(
            ingredients: manualIngredients,
            steps: manualSteps
        )

        viewModel.recipeContent = result.content
        viewModel.ingredients = result.ingredientList
        viewModel.directions = result.directions
    }

    /// Generate a default name for manually entered recipes
    private func generateDefaultRecipeName() -> String {
        return helper.generateDefaultRecipeName(from: manualIngredients)
    }

    // MARK: - Photo Generation

    private func generatePhoto() async {
        logger.info("🎬 [VIEW] Photo generation button tapped")
        await viewModel.generateRecipePhoto()

        if viewModel.generatedPhotoURL != nil {
            logger.info("🖼️ [VIEW] Loading image from generated URL")
            await viewModel.loadImageFromGeneratedURL()
        }
        logger.info("🏁 [VIEW] Photo generation completed")
    }

    // MARK: - Story Card Handler

    private func handleStoryCardTap() {
        logger.info("🔍 [STORY] Story card tapped")

        let hasNutrition = helper.hasNutritionData(
            calories: viewModel.calories,
            carbohydrates: viewModel.carbohydrates,
            protein: viewModel.protein
        )

        if hasNutrition {
            logger.info("✅ [STORY] Nutrition data exists, showing modal")
            showingNutritionModal = true
        } else {
            logger.info("🔄 [STORY] Starting nutrition calculation")

            // Build manual recipe content if needed before calculating nutrition
            if isManualRecipe {
                buildManualRecipeContent()

                // Generate default name for manual recipes
                if viewModel.recipeName.isEmpty {
                    viewModel.recipeName = generateDefaultRecipeName()
                    logger.info("📝 [STORY] Generated default recipe name for nutrition: \(viewModel.recipeName)")
                }
            }

            viewModel.calculateNutrition()
        }
    }

    // MARK: - Nutrition Calculation Handler

    private func handleNutritionCalculationChange(oldValue: Bool, newValue: Bool) {
        if oldValue && !newValue {
            // Calculation completed
            logger.info("✅ [NUTRITION] Calculation completed, showing modal")
            loadingHandler.clearLoadingStep()
            showingNutritionModal = true
        } else if !oldValue && newValue {
            // Calculation started
            logger.info("🔄 [NUTRITION] Calculation started, beginning loading animation")
            loadingHandler.startLoadingAnimation {
                viewModel.isCalculatingNutrition
            }
        }
    }
}

// MARK: - Custom Button Style

struct RecipeButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.6 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

#Preview {
    RecipeGenerationView(viewContext: PersistenceController.preview.container.viewContext)
}
