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
    @Environment(\.managedObjectContext) private var viewContext

    @StateObject private var viewModel: RecipeViewModel
    @StateObject private var generationViewModel: RecipeGenerationViewModel
    @StateObject private var actionsHandler = RecipeGenerationActionsHandler()
    @StateObject private var loadingHandler = LoadingAnimationHandler()

    // Pure UI state (stays in View)
    @State private var showingMealSelection = false
    @State private var showingNutritionModal = false
    @State private var isAddingIngredient = false
    @State private var isAddingStep = false
    @State private var newIngredientText = ""
    @State private var newStepText = ""
    @State private var toastMessage: ToastType? = nil
    @State private var editableRecipeName = ""
    @FocusState private var focusedField: FocusField?
    @FocusState private var isNameFieldFocused: Bool

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.balli",
        category: "RecipeGenerationView"
    )

    enum FocusField {
        case ingredient
        case step
    }

    init(viewContext: NSManagedObjectContext) {
        let recipeVM = RecipeViewModel(context: viewContext)
        _viewModel = StateObject(wrappedValue: recipeVM)
        _generationViewModel = StateObject(wrappedValue: RecipeGenerationViewModel(
            viewContext: viewContext,
            recipeViewModel: recipeVM
        ))
    }

    // MARK: - Computed Properties

    /// Determines if recipe can be saved
    /// For manual recipes, requires non-empty name
    /// For AI-generated recipes, always allowed
    private var canSaveRecipe: Bool {
        if generationViewModel.isManualRecipe {
            return !editableRecipeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return true
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
                                        await generationViewModel.generatePhoto()
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
                                    hasUncheckedIngredientsInShoppingList: generationViewModel.hasUncheckedIngredients
                                ) { action in
                                    actionsHandler.handleAction(action, viewModel: viewModel)
                                }
                                .padding(.horizontal, 20)
                                .padding(.top, 0)
                                .padding(.bottom, 16)

                                // Recipe content (markdown or manual input)
                                RecipeGenerationContentSection(
                                    recipeContent: viewModel.recipeContent,
                                    manualIngredients: $generationViewModel.manualIngredients,
                                    manualSteps: $generationViewModel.manualSteps,
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
                            geometry: geometry,
                            editableRecipeName: $editableRecipeName,
                            isManualRecipe: generationViewModel.isManualRecipe,
                            isNameFieldFocused: $isNameFieldFocused
                        )

                        // Story card - positioned absolutely at fixed offset
                        RecipeGenerationStoryCard(
                            storyCardTitle: generationViewModel.storyCardTitle,
                            isCalculatingNutrition: viewModel.isCalculatingNutrition,
                            currentLoadingStep: loadingHandler.currentLoadingStep,
                            nutritionCalculationProgress: viewModel.nutritionCalculationProgress,
                            hasNutritionData: generationViewModel.hasNutritionData,
                            geometry: geometry,
                            onTap: {
                                let shouldShowModal = generationViewModel.handleStoryCardTap()
                                if shouldShowModal {
                                    showingNutritionModal = true
                                }
                            }
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

            // Save button (circular, independent button)
            if generationViewModel.shouldShowSaveButton {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task {
                            // For manual recipes, use the editable name
                            if generationViewModel.isManualRecipe {
                                viewModel.recipeName = editableRecipeName.trimmingCharacters(in: .whitespacesAndNewlines)
                            }

                            await generationViewModel.saveRecipe()
                            if generationViewModel.isSaved {
                                toastMessage = .success("Tarif kaydedildi!")
                            } else if generationViewModel.isManualRecipe && editableRecipeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                toastMessage = .error("Lütfen tarif ismi girin")
                            }
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(canSaveRecipe ? ThemeColors.primaryPurple : ThemeColors.primaryPurple.opacity(0.2))
                                .frame(width: 36, height: 36)

                            Image(systemName: "checkmark")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSaveRecipe)
                }
            }

            // Generate menu button (balli logo - separate toolbar item)
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    let (shouldShowMenu, reason) = generationViewModel.determineGenerationFlow()
                    logger.info("\(reason)")

                    if shouldShowMenu {
                        showingMealSelection = true
                    } else {
                        Task {
                            await generationViewModel.startGenerationWithDefaults()
                        }
                    }
                } label: {
                    Image("balli-logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                        .rotationEffect(.degrees(viewModel.isRotatingLogo ? 360 : 0))
                        .animation(
                            viewModel.isRotatingLogo ?
                                .linear(duration: 1.0).repeatForever(autoreverses: false) :
                                .default,
                            value: viewModel.isRotatingLogo
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .toolbarBackground(.automatic, for: .navigationBar)
        .toolbarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .sheet(isPresented: $showingMealSelection) {
            RecipeMealSelectionView(
                selectedMealType: $generationViewModel.selectedMealType,
                selectedStyleType: $generationViewModel.selectedStyleType,
                onGenerate: {
                    Task {
                        await generationViewModel.startGeneration()
                    }
                }
            )
            .presentationDetents([.fraction(0.4)])
        }
        .sheet(isPresented: $showingNutritionModal) {
            NutritionalValuesView(
                recipe: nil,  // Recipe not saved yet during generation
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
            UserNotesModalView(notes: $generationViewModel.userNotes) { newNotes in
                logger.info("💬 [NOTES] User saved notes: '\(newNotes.prefix(50))...'")
            }
        }
        .onAppear {
            // Set up toast callback
            actionsHandler.onShowToast = { toast in
                toastMessage = toast
            }

            // Set up shopping list update callback
            actionsHandler.onShoppingListUpdated = {
                await generationViewModel.checkShoppingListStatus()
            }

            // Check shopping list status on view appear
            Task {
                await generationViewModel.checkShoppingListStatus()
            }
        }
        .onChange(of: viewModel.recipeName) { _, _ in
            Task {
                await generationViewModel.checkShoppingListStatus()
            }
        }
        .onChange(of: viewModel.isCalculatingNutrition) { oldValue, newValue in
            if oldValue && !newValue {
                // Calculation completed
                logger.info("✅ [NUTRITION] Calculation completed")
                logger.info("📊 [NUTRITION] Values at modal show:")
                logger.info("  Per-100g: cal=\(viewModel.calories), carbs=\(viewModel.carbohydrates), protein=\(viewModel.protein)")
                logger.info("  Per-serving: cal=\(viewModel.caloriesPerServing), carbs=\(viewModel.carbohydratesPerServing), protein=\(viewModel.proteinPerServing)")
                loadingHandler.clearLoadingStep()

                // Small delay to ensure formState is fully updated
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(100))
                    showingNutritionModal = true
                }
            } else if !oldValue && newValue {
                // Calculation started
                logger.info("🔄 [NUTRITION] Calculation started, beginning loading animation")
                loadingHandler.startLoadingAnimation {
                    viewModel.isCalculatingNutrition
                }
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
