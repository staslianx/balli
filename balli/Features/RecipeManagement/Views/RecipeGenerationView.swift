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
    /// For manual recipes, requires non-empty name AND at least one ingredient
    /// For AI-generated recipes, always allowed
    private var canSaveRecipe: Bool {
        if generationViewModel.isManualRecipe {
            let hasRecipeName = !editableRecipeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let hasAtLeastOneIngredient = generationViewModel.manualIngredients.filter {
                !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }.count >= 1
            return hasRecipeName && hasAtLeastOneIngredient
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

    @ViewBuilder
    private var mainScrollContent: some View {
        GeometryReader { geometry in
            ScrollView {
                scrollViewContent(geometry: geometry)
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollIndicators(.hidden)
            .background(Color(.secondarySystemBackground))
            .ignoresSafeArea(edges: .top)
        }
    }

    @ViewBuilder
    private func scrollViewContent(geometry: GeometryProxy) -> some View {
        ZStack(alignment: .top) {
            recipeContentStack(geometry: geometry)
            recipeMetadataOverlay(geometry: geometry)
            storyCardOverlay(geometry: geometry)
        }
    }

    @ViewBuilder
    private func recipeContentStack(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
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

            Spacer().frame(height: 49)

            VStack(spacing: 0) {
                RecipeGenerationActionButtons(
                    isFavorited: actionsHandler.isFavorited,
                    hasUncheckedIngredientsInShoppingList: generationViewModel.hasUncheckedIngredients
                ) { action in
                    actionsHandler.handleAction(action, viewModel: viewModel)
                }
                .padding(.horizontal, 20)
                .padding(.top, 0)
                .padding(.bottom, 16)

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
                        logger.info("🎭 [ANIMATION-CALLBACK] isContentAnimating changing: \(isContentAnimating) → \(isAnimating)")
                        isContentAnimating = isAnimating
                        logger.info("🔄 [isEffectivelyGenerating] Now: \(isEffectivelyGenerating) (backend: \(viewModel.isGeneratingRecipe), animation: \(isContentAnimating))")
                    }
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .frame(maxWidth: .infinity)
            .background(Color(.secondarySystemBackground))
        }
    }

    @ViewBuilder
    private func recipeMetadataOverlay(geometry: GeometryProxy) -> some View {
        RecipeGenerationMetadata(
            recipeName: viewModel.recipeName,
            recipeContent: viewModel.formState.recipeContent,
            geometry: geometry,
            editableRecipeName: $editableRecipeName,
            isManualRecipe: generationViewModel.isManualRecipe,
            prepTime: viewModel.generationCoordinator.prepTime,
            cookTime: viewModel.generationCoordinator.cookTime,
            isStreaming: viewModel.isGeneratingRecipe,
            isNameFieldFocused: $isNameFieldFocused
        )
    }

    @ViewBuilder
    private func storyCardOverlay(geometry: GeometryProxy) -> some View {
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
                } else {
                    loadingHandler.startLoadingAnimation {
                        viewModel.nutritionHandler.isCalculatingNutrition
                    }
                }
            }
        )
    }

    @ViewBuilder
    private var mainContent: some View {
        ZStack {
            errorBanner
            mainScrollContent
        }
    }

    var body: some View {
        mainContent
            .toast($toastMessage)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar { toolbarConfiguration }
            .background(sheetConfigurations)
            .lifecycleModifiers(
                viewModel: viewModel,
                generationViewModel: generationViewModel,
                actionsHandler: actionsHandler,
                loadingHandler: loadingHandler,
                toastMessage: $toastMessage,
                showSaveButton: $showSaveButton,
                editableRecipeName: editableRecipeName,
                isEffectivelyGenerating: isEffectivelyGenerating,
                isContentAnimating: isContentAnimating,
                canSaveRecipe: canSaveRecipe,
                logger: logger
            )
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
        if viewModel.generationCoordinator.prepTime != nil || viewModel.generationCoordinator.cookTime != nil || viewModel.generationCoordinator.waitTime != nil {
            HStack(spacing: 8) {
                if let prep = viewModel.generationCoordinator.prepTime {
                    RecipeTimePill(icon: "circle.dotted", time: prep, label: "Hazırlık")
                }
                if let cook = viewModel.generationCoordinator.cookTime {
                    RecipeTimePill(icon: "flame", time: cook, label: "Pişirme")
                }
                if let wait = viewModel.generationCoordinator.waitTime {
                    RecipeTimePill(icon: "hourglass", time: wait, label: "Bekleme")
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
        }
        .buttonStyle(.balliBordered)
        .disabled(!canSaveRecipe)
        .opacity(canSaveRecipe ? 1.0 : 0.5)
    }

    @ViewBuilder
    private var generateButton: some View {
        // Determine which flow to use based on recipe state
        let flow = generationViewModel.determineGenerationFlow()

        if flow.shouldShowMenu {
            // Flows 1 & 2: Show menu to discover user intent
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
                    Label("Atıştırmalık", systemImage: "carrot.fill")
                }
            } label: {
                generateButtonContent
            }
        } else {
            // Flows 3 & 4: Skip menu, generate directly with user's notes/context
            Button {
                Task {
                    logger.info("📝 [FLOW] \(flow.reason)")
                    await generationViewModel.startGenerationWithDefaults()
                }
            } label: {
                generateButtonContent
            }
        }
    }

    @ViewBuilder
    private var generateButtonContent: some View {
        Image("balli-logo")
            .resizable()
            .scaledToFit()
            .frame(width: 26, height: 26)
            .rotationEffect(.degrees(isEffectivelyGenerating ? 360 : 0))
            .animation(
                isEffectivelyGenerating ?
                    // THERMAL FIX: Slower rotation (2s vs 1s) = 50% GPU reduction
                    // User-imperceptible difference but significant battery savings
                    .linear(duration: 2.0).repeatForever(autoreverses: false) :
                    .default,
                value: isEffectivelyGenerating
            )
            // THERMAL FIX: Enable GPU caching to reduce rendering overhead
            .drawingGroup()
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
            .alert("Recipe Already Exists", isPresented: $viewModel.persistenceCoordinator.showingDuplicateWarning) {
                Button("Cancel", role: .cancel) {
                    logger.info("❌ [DUPLICATE-CANCEL] User cancelled duplicate save")
                }
                Button("Save Anyway") {
                    logger.info("✅ [DUPLICATE-CONFIRM] User confirmed duplicate save")
                    Task {
                        if generationViewModel.isManualRecipe {
                            viewModel.recipeName = editableRecipeName.trimmingCharacters(in: .whitespacesAndNewlines)
                        }

                        // Force save ignoring duplicates
                        await viewModel.persistenceCoordinator.saveRecipeIgnoringDuplicates(
                            imageURL: viewModel.recipeImageURL,
                            imageData: viewModel.recipeImageData
                        )

                        if viewModel.persistenceCoordinator.showingSaveConfirmation {
                            generationViewModel.isSaved = true
                            toastMessage = .success("Tarif kaydedildi!")
                        }
                    }
                }
            } message: {
                Text(viewModel.persistenceCoordinator.duplicateWarningMessage)
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

#Preview("Default") {
    RecipeGenerationView(viewContext: PersistenceController.previewFast.container.viewContext)
}

#Preview("With Save Button") {
    struct PreviewWrapper: View {
        var body: some View {
            RecipeGenerationViewWithSaveButton()
        }
    }
    return PreviewWrapper()
}

// Helper view for preview with save button visible
private struct RecipeGenerationViewWithSaveButton: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var viewModel: RecipeViewModel
    @StateObject private var generationViewModel: RecipeGenerationViewModel
    @StateObject private var actionsHandler = RecipeGenerationActionsHandler()
    @StateObject private var loadingHandler = LoadingAnimationHandler()
    @State private var showSaveButton = true  // Always show for preview

    init() {
        let recipeVM = RecipeViewModel(context: PersistenceController.previewFast.container.viewContext)
        _viewModel = StateObject(wrappedValue: recipeVM)
        _generationViewModel = StateObject(wrappedValue: RecipeGenerationViewModel(
            viewContext: PersistenceController.previewFast.container.viewContext,
            recipeViewModel: recipeVM
        ))
    }

    var body: some View {
        NavigationStack {
            Text("Preview Content")
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {} label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(ThemeColors.primaryPurple)
                        }
                    }

                    if showSaveButton {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button {
                                print("Save tapped")
                            } label: {
                                Image(systemName: "checkmark")
                            }
                            .buttonStyle(.balliBordered)
                        }
                    }

                    ToolbarItem(placement: .navigationBarTrailing) {
                        Image("balli-logo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 26, height: 26)
                    }
                }
        }
    }
}

// MARK: - Lifecycle Modifiers ViewModifier

private struct LifecycleModifiers: ViewModifier {
    let viewModel: RecipeViewModel
    let generationViewModel: RecipeGenerationViewModel
    let actionsHandler: RecipeGenerationActionsHandler
    let loadingHandler: LoadingAnimationHandler
    @Binding var toastMessage: ToastType?
    @Binding var showSaveButton: Bool
    let editableRecipeName: String
    let isEffectivelyGenerating: Bool
    let isContentAnimating: Bool
    let canSaveRecipe: Bool
    let logger: Logger

    func body(content: Content) -> some View {
        content
            .onAppear {
                actionsHandler.onShowToast = { [weak actionsHandler] toast in
                    guard actionsHandler != nil else { return }
                    toastMessage = toast
                }
                actionsHandler.onShoppingListUpdated = { [weak generationViewModel] in
                    guard let generationViewModel else { return }
                    await generationViewModel.checkShoppingListStatus()
                }
            }
            .onDisappear {
                if viewModel.isGeneratingRecipe {
                    logger.info("🛑 [THERMAL] View disappeared during generation - cancelling stream")
                    Task {
                        await viewModel.generationCoordinator.streamingService.cancelActiveStream()
                    }
                }
            }
            .task(id: viewModel.isGeneratingRecipe) {
                if viewModel.isGeneratingRecipe {
                    logger.info("🔄 [LIFECYCLE] Backend streaming STARTED")
                } else {
                    logger.info("✅ [LIFECYCLE] Backend streaming COMPLETED (animation may still be running)")
                    logger.info("   isContentAnimating: \(isContentAnimating)")
                    logger.info("   isEffectivelyGenerating: \(isEffectivelyGenerating)")
                }
            }
            .task(id: viewModel.recipeName) {
                await generationViewModel.checkShoppingListStatus()
            }
            .onChange(of: isEffectivelyGenerating) { oldValue, newValue in
                logger.info("🔄 [isEffectivelyGenerating] Changed: \(oldValue) → \(newValue) (backend: \(viewModel.isGeneratingRecipe), animation: \(isContentAnimating))")
                if oldValue && !newValue && !generationViewModel.isSaved {
                    logger.info("💾 [SAVE-BUTTON] Generation complete - checking if save button should show...")
                    logger.info("   shouldShowSaveButton: \(generationViewModel.shouldShowSaveButton)")
                    logger.info("   isCalculatingNutrition: \(viewModel.isCalculatingNutrition)")
                    logger.info("   isGeneratingPhoto: \(viewModel.isGeneratingPhoto)")
                    showSaveButton = generationViewModel.shouldShowSaveButton
                    if showSaveButton {
                        logger.info("✅ [SAVE-BUTTON] SHOWING save button")
                    } else {
                        logger.info("⏳ [SAVE-BUTTON] NOT showing - waiting for nutrition/photo")
                    }
                }
            }
            .onChange(of: generationViewModel.isSaved) { _, newValue in
                if newValue {
                    showSaveButton = false
                }
            }
            .onChange(of: editableRecipeName) { _, _ in
                if generationViewModel.isManualRecipe {
                    showSaveButton = canSaveRecipe
                }
            }
            .onChange(of: generationViewModel.manualIngredients) { _, _ in
                if generationViewModel.isManualRecipe {
                    showSaveButton = canSaveRecipe
                }
            }
            .onChange(of: viewModel.nutritionHandler.isCalculatingNutrition) { oldValue, newValue in
                if oldValue && !newValue {
                    logger.info("✅ [NUTRITION] Calculation completed")
                    loadingHandler.clearLoadingStep()
                }
            }
    }
}

private extension View {
    func lifecycleModifiers(
        viewModel: RecipeViewModel,
        generationViewModel: RecipeGenerationViewModel,
        actionsHandler: RecipeGenerationActionsHandler,
        loadingHandler: LoadingAnimationHandler,
        toastMessage: Binding<ToastType?>,
        showSaveButton: Binding<Bool>,
        editableRecipeName: String,
        isEffectivelyGenerating: Bool,
        isContentAnimating: Bool,
        canSaveRecipe: Bool,
        logger: Logger
    ) -> some View {
        modifier(LifecycleModifiers(
            viewModel: viewModel,
            generationViewModel: generationViewModel,
            actionsHandler: actionsHandler,
            loadingHandler: loadingHandler,
            toastMessage: toastMessage,
            showSaveButton: showSaveButton,
            editableRecipeName: editableRecipeName,
            isEffectivelyGenerating: isEffectivelyGenerating,
            isContentAnimating: isContentAnimating,
            canSaveRecipe: canSaveRecipe,
            logger: logger
        ))
    }
}
