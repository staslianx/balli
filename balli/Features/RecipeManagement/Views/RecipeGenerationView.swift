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

    @State private var showingMealSelection = false
    @State private var showingNutritionModal = false
    @State private var selectedMealType = "Kahvaltı"
    @State private var selectedStyleType = ""
    @State private var isGenerating = false
    @State private var isSaved = false
    @State private var showingSaveConfirmation = false
    @State private var isAddingIngredient = false
    @State private var isAddingStep = false
    @State private var newIngredientText = ""
    @State private var newStepText = ""
    @State private var manualIngredients: [RecipeItem] = []
    @State private var manualSteps: [RecipeItem] = []
    @State private var storyCardTitle = "balli'nin Tarif Analizi"
    @State private var userNotes: String = ""
    @FocusState private var focusedField: FocusField?

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.balli",
        category: "RecipeGenerationView"
    )

    enum FocusField {
        case ingredient
        case step
    }

    init(viewContext: NSManagedObjectContext) {
        _viewModel = StateObject(wrappedValue: RecipeViewModel(context: viewContext))
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // MARK: - Scrollable Content
                ScrollView {
                    ZStack(alignment: .top) {
                        VStack(spacing: 0) {
                            // Hero section with fixed positioning
                            RecipeGenerationCompleteHero(
                                recipeName: viewModel.recipeName,
                                preparedImage: viewModel.preparedImage,
                                isGeneratingPhoto: viewModel.isGeneratingPhoto,
                                recipeContent: viewModel.formState.recipeContent,
                                storyCardTitle: storyCardTitle,
                                isCalculatingNutrition: viewModel.isCalculatingNutrition,
                                currentLoadingStep: loadingHandler.currentLoadingStep,
                                nutritionCalculationProgress: viewModel.nutritionCalculationProgress,
                                geometry: geometry,
                                onGeneratePhoto: {
                                    Task {
                                        await generatePhoto()
                                    }
                                },
                                onStoryCardTap: handleStoryCardTap
                            )

                            // All content below story card
                            VStack(spacing: 0) {
                                // Action buttons
                                RecipeGenerationActionButtons(
                                    isFavorited: actionsHandler.isFavorited
                                ) { action in
                                    actionsHandler.handleAction(action, viewModel: viewModel)
                                }

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
                            .background(Color(.secondarySystemBackground))
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .background(Color(.secondarySystemBackground))

                // MARK: - Confirmation Overlays
                RecipeGenerationOverlays(
                    showingSaveConfirmation: showingSaveConfirmation,
                    showingShoppingConfirmation: actionsHandler.showingShoppingConfirmation
                )
            }
            .ignoresSafeArea(edges: .top)
        }
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
                    // Save button (only visible when recipe generated and not saved)
                    if !viewModel.recipeName.isEmpty && !isSaved {
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
                        showingMealSelection = true
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
                digestionTiming: viewModel.digestionTiming
            )
            .presentationDetents([.large])
        }
        .sheet(isPresented: $actionsHandler.showingNotesModal) {
            UserNotesModalView(notes: $userNotes) { newNotes in
                logger.info("💬 [NOTES] User saved notes: '\(newNotes.prefix(50))...'")
                userNotes = newNotes
            }
        }
        .onChange(of: viewModel.isCalculatingNutrition) { oldValue, newValue in
            handleNutritionCalculationChange(oldValue: oldValue, newValue: newValue)
        }
    }

    // MARK: - Generation

    private func startGeneration() async {
        isGenerating = true
        isSaved = false
        storyCardTitle = "balli'nin notu"

        await viewModel.generationCoordinator.generateRecipeWithStreaming(
            mealType: selectedMealType,
            styleType: selectedStyleType
        )
        isGenerating = false
    }

    // MARK: - Save Recipe

    private func saveRecipe() async {
        logger.info("💾 [VIEW] saveRecipe() called")

        // Build manual recipe content if needed
        if !manualIngredients.isEmpty || !manualSteps.isEmpty {
            buildManualRecipeContent()
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
            showingSaveConfirmation = true

            // Hide confirmation after 2 seconds
            try? await Task.sleep(for: .seconds(2))
            showingSaveConfirmation = false
        } else {
            logger.warning("⚠️ [VIEW] Save confirmation not shown")
        }
    }

    private func buildManualRecipeContent() {
        var sections: [String] = []

        if !manualIngredients.isEmpty {
            var ingredientLines = ["## Malzemeler", "---"]
            ingredientLines.append(contentsOf: manualIngredients.map { "- \($0.text)" })
            sections.append(ingredientLines.joined(separator: "\n"))
        }

        if !manualSteps.isEmpty {
            var stepLines = ["## Yapılışı", "---"]
            stepLines.append(contentsOf: manualSteps.enumerated().map { "\($0.offset + 1). \($0.element.text)" })
            sections.append(stepLines.joined(separator: "\n"))
        }

        viewModel.recipeContent = sections.joined(separator: "\n\n")
        viewModel.ingredients = manualIngredients.map { $0.text }
        viewModel.directions = manualSteps.map { $0.text }
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

        let hasNutrition = !viewModel.calories.isEmpty &&
                          !viewModel.carbohydrates.isEmpty &&
                          !viewModel.protein.isEmpty

        if hasNutrition {
            logger.info("✅ [STORY] Nutrition data exists, showing modal")
            showingNutritionModal = true
        } else {
            logger.info("🔄 [STORY] Starting nutrition calculation")
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
