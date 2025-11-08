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
    @State private var showingNutritionModal = false
    @State private var isAddingIngredient = false
    @State private var isAddingStep = false
    @State private var newIngredientText = ""
    @State private var newStepText = ""
    @State private var toastMessage: ToastType? = nil
    @State private var editableRecipeName = ""
    @State private var showSaveButton = false
    @State private var isContentAnimating = false  // Track typewriter animation state
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

    /// True if backend is generating OR animation is still running
    /// Prevents button rotation from stopping prematurely
    private var isEffectivelyGenerating: Bool {
        viewModel.isGeneratingRecipe || isContentAnimating
    }

    @ViewBuilder
    private var errorBanner: some View {
        if let errorMessage = viewModel.generationError {
            VStack {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.white)
                        .font(.system(size: 20))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Tarif Oluşturulamadı")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)

                        Text(errorMessage)
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.9))
                    }

                    Spacer()

                    Button {
                        Task {
                            await generationViewModel.startGenerationWithDefaults()
                        }
                    } label: {
                        Text("Tekrar Dene")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(8)
                    }
                }
                .padding(16)
                .background(Color.red.gradient)
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                .padding(.horizontal, 20)
                .padding(.top, 60)

                Spacer()
            }
            .zIndex(100)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    var body: some View {
        ZStack {
            errorBanner

                // MARK: - Scrollable Content
                GeometryReader { geometry in
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
                                    isStreaming: viewModel.isGeneratingRecipe,
                                    manualIngredients: $generationViewModel.manualIngredients,
                                    manualSteps: $generationViewModel.manualSteps,
                                    isAddingIngredient: $isAddingIngredient,
                                    isAddingStep: $isAddingStep,
                                    newIngredientText: $newIngredientText,
                                    newStepText: $newStepText,
                                    focusedField: $focusedField,
                                    onAnimationStateChange: { isAnimating in
                                        isContentAnimating = isAnimating
                                    }
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
                            prepTime: viewModel.generationCoordinator.prepTime,
                            cookTime: viewModel.generationCoordinator.cookTime,
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
                .scrollDismissesKeyboard(.interactively)
                .scrollIndicators(.hidden)
                .background(Color(.secondarySystemBackground))
                .ignoresSafeArea(edges: .top)
            }
        }
        .toast($toastMessage)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            toolbarConfiguration
        }
        .background(sheetConfigurations)
        .onAppear {
            // Set up toast callback with weak self to prevent retain cycles
            actionsHandler.onShowToast = { [weak actionsHandler] toast in
                guard actionsHandler != nil else { return }
                toastMessage = toast
            }

            // Set up shopping list update callback with weak self to prevent retain cycles
            actionsHandler.onShoppingListUpdated = { [weak generationViewModel] in
                guard let generationViewModel else { return }
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
        .onChange(of: isEffectivelyGenerating) { oldValue, newValue in
            // Show save button ONLY when generation fully completes (backend + animation)
            // This ensures button appears in sync with logo rotation stopping
            if oldValue && !newValue && !generationViewModel.isSaved {
                showSaveButton = generationViewModel.shouldShowSaveButton
                logger.info("💾 [SAVE-BUTTON] Showing save button - generation fully complete")
            }
        }
        .onChange(of: generationViewModel.isSaved) { _, newValue in
            // Hide save button after recipe is saved
            if newValue {
                showSaveButton = false
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

                // Don't auto-open modal - user taps story card to view nutrition
                logger.info("📌 [NUTRITION] Modal ready - user can tap story card to view")
            } else if !oldValue && newValue {
                // Calculation started
                logger.info("🔄 [NUTRITION] Calculation started, beginning loading animation")
                loadingHandler.startLoadingAnimation {
                    viewModel.isCalculatingNutrition
                }
            }
        }
    }

    // MARK: - Toolbar Configuration

    @ToolbarContentBuilder
    private var toolbarConfiguration: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(ThemeColors.primaryPurple)
            }
        }

        ToolbarItem(placement: .principal) {
            centerToolbarItem
        }

        if showSaveButton {
            ToolbarItem(placement: .navigationBarTrailing) {
                saveButton
            }
        }

        ToolbarItem(placement: .navigationBarTrailing) {
            generateButton
        }
    }

    @ViewBuilder
    private var centerToolbarItem: some View {
        if viewModel.generationCoordinator.prepTime != nil || viewModel.generationCoordinator.cookTime != nil {
            HStack(spacing: 8) {
                if let prep = viewModel.generationCoordinator.prepTime {
                    RecipeTimePill(icon: "timer", time: prep, label: "Hazırlık")
                }
                if let cook = viewModel.generationCoordinator.cookTime {
                    RecipeTimePill(icon: "flame", time: cook, label: "Pişirme")
                }
            }
            .fixedSize()
        }
    }

    @ViewBuilder
    private var saveButton: some View {
        Button {
            Task {
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
            Image(systemName: "checkmark")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(canSaveRecipe ? ThemeColors.primaryPurple : ThemeColors.primaryPurple.opacity(0.3))
        }
        .buttonStyle(.plain)
        .disabled(!canSaveRecipe)
    }

    @ViewBuilder
    private var generateButton: some View {
        Menu {
            // Kahvaltı (no subcategories)
            Button {
                Task {
                    generationViewModel.selectedMealType = "Kahvaltı"
                    generationViewModel.selectedStyleType = ""
                    await generationViewModel.startGeneration()
                }
            } label: {
                Label("Kahvaltı", systemImage: "sun.max.fill")
            }

            // Salatalar with submenu
            Menu {
                Button("Doyurucu Salata") {
                    Task {
                        generationViewModel.selectedMealType = "Salatalar"
                        generationViewModel.selectedStyleType = "Doyurucu Salata"
                        await generationViewModel.startGeneration()
                    }
                }
                Button("Hafif Salata") {
                    Task {
                        generationViewModel.selectedMealType = "Salatalar"
                        generationViewModel.selectedStyleType = "Hafif Salata"
                        await generationViewModel.startGeneration()
                    }
                }
            } label: {
                Label("Salatalar", systemImage: "leaf.fill")
            }

            // Akşam yemeği with submenu
            Menu {
                Button("Karbonhidrat ve Protein Uyumu") {
                    Task {
                        generationViewModel.selectedMealType = "Akşam yemeği"
                        generationViewModel.selectedStyleType = "Karbonhidrat ve Protein Uyumu"
                        await generationViewModel.startGeneration()
                    }
                }
                Button("Tam Buğday Makarna") {
                    Task {
                        generationViewModel.selectedMealType = "Akşam yemeği"
                        generationViewModel.selectedStyleType = "Tam Buğday Makarna"
                        await generationViewModel.startGeneration()
                    }
                }
            } label: {
                Label("Akşam yemeği", systemImage: "fork.knife")
            }

            // Tatlılar with submenu
            Menu {
                Button("Sana Özel Tatlılar") {
                    Task {
                        generationViewModel.selectedMealType = "Tatlılar"
                        generationViewModel.selectedStyleType = "Sana Özel Tatlılar"
                        await generationViewModel.startGeneration()
                    }
                }
                Button("Dondurma") {
                    Task {
                        generationViewModel.selectedMealType = "Tatlılar"
                        generationViewModel.selectedStyleType = "Dondurma"
                        await generationViewModel.startGeneration()
                    }
                }
                Button("Meyve Salatası") {
                    Task {
                        generationViewModel.selectedMealType = "Tatlılar"
                        generationViewModel.selectedStyleType = "Meyve Salatası"
                        await generationViewModel.startGeneration()
                    }
                }
            } label: {
                Label("Tatlılar", systemImage: "sparkles")
            }

            // Atıştırmalık (no subcategories)
            Button {
                Task {
                    generationViewModel.selectedMealType = "Atıştırmalık"
                    generationViewModel.selectedStyleType = ""
                    await generationViewModel.startGeneration()
                }
            } label: {
                Label("Atıştırmalık", systemImage: "circle.hexagongrid.fill")
            }
        } label: {
            generateButtonContent
        }
    }

    @ViewBuilder
    private var generateButtonContent: some View {
        Image("balli-logo")
            .resizable()
            .scaledToFit()
            .frame(width: 20, height: 20)
            .rotationEffect(.degrees(isEffectivelyGenerating ? 360 : 0))
            .animation(
                isEffectivelyGenerating ?
                    .linear(duration: 1.0).repeatForever(autoreverses: false) :
                    .default,
                value: isEffectivelyGenerating
            )
            .onChange(of: isEffectivelyGenerating) { oldValue, newValue in
                logger.info("🔄 [VIEW] isEffectivelyGenerating changed: \(oldValue) → \(newValue)")
            }
    }
}

// MARK: - Sheet Configurations

extension RecipeGenerationView {
    @ViewBuilder
    var sheetConfigurations: some View {
        EmptyView()
            .sheet(isPresented: $showingNutritionModal) {
                nutritionModalSheet
            }
            .sheet(isPresented: $actionsHandler.showingNotesModal) {
                notesModalSheet
            }
    }

    @ViewBuilder
    private var nutritionModalSheet: some View {
        NutritionalValuesView(
            recipe: ObservableRecipeWrapper(recipe: nil),
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

    @ViewBuilder
    private var notesModalSheet: some View {
        UserNotesModalView(notes: $generationViewModel.userNotes) { newNotes in
            logger.info("💬 [NOTES] User saved notes: '\(newNotes.prefix(50))...'")
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
    RecipeGenerationView(viewContext: PersistenceController.previewFast.container.viewContext)
}
