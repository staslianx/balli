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

// MARK: - RecipeItem Model

struct RecipeItem: Identifiable, Equatable, Sendable {
    let id = UUID()
    var text: String

    static func == (lhs: RecipeItem, rhs: RecipeItem) -> Bool {
        lhs.id == rhs.id && lhs.text == rhs.text
    }
}

struct RecipeGenerationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @StateObject private var viewModel: RecipeViewModel
    @State private var showingMealSelection = false
    @State private var showingNutritionModal = false
    @State private var selectedMealType = "Kahvaltı"
    @State private var selectedStyleType = ""  // Empty for categories without subcategories
    @State private var isGenerating = false
    @State private var isSaved = false
    @State private var isFavorited = false
    @State private var showingSaveConfirmation = false
    @State private var isAddingIngredient = false
    @State private var isAddingStep = false
    @State private var newIngredientText = ""
    @State private var newStepText = ""
    @State private var manualIngredients: [RecipeItem] = []
    @State private var manualSteps: [RecipeItem] = []
    @State private var storyCardTitle = "Tarif notu"  // Default title for user-created recipes
    @FocusState private var focusedField: FocusField?

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.balli", category: "RecipeGenerationView")

    enum FocusField {
        case ingredient
        case step
    }

    init(viewContext: NSManagedObjectContext) {
        _viewModel = StateObject(wrappedValue: RecipeViewModel(context: viewContext))
    }

    var body: some View {
        ZStack {
            // MARK: - Scrollable Content
            ScrollView {
                ZStack(alignment: .top) {
                    VStack(spacing: 0) {
                        // Hero image placeholder
                        heroImagePlaceholder

                        // Spacer to accommodate story card overlap
                        // Story card is 82px tall + 16px padding = 98px
                        // We want it half-over image, so subtract half its height
                        Spacer()
                            .frame(height: 49)

                        // All content below story card
                        VStack(spacing: 0) {
                            // Action buttons
                            actionButtonsPlaceholder
                                .padding(.horizontal, 20)
                                .padding(.top, 16)
                                .padding(.bottom, 32)

                            // Recipe content (markdown)
                            recipeContentSection
                                .padding(.horizontal, 20)
                                .padding(.bottom, 40)
                        }
                        .background(Color(.secondarySystemBackground))
                    }

                    // Recipe metadata - positioned absolutely over hero image
                    // Uses bottom alignment to grow upward when text is longer
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)

                        metadataPlaceholder
                            .padding(.horizontal, 20)
                            .padding(.bottom, 24) // Minimum gap between name and story card
                    }
                    .frame(height: UIScreen.main.bounds.height * 0.5 - 49) // Ends where story card begins

                    // Story card - positioned absolutely at fixed offset
                    // This stays in place regardless of recipe name length
                    VStack {
                        Spacer()
                            .frame(height: UIScreen.main.bounds.height * 0.5 - 49)

                        storyCardPlaceholder
                            .padding(.horizontal, 20)

                        Spacer()
                    }
                }
            }
            .scrollIndicators(.hidden)
            .background(Color(.secondarySystemBackground))

            // MARK: - Navigation Overlay
            navigationOverlay

            // MARK: - Save Confirmation Overlay
            if showingSaveConfirmation {
                VStack {
                    Spacer()
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(ThemeColors.primaryPurple)
                        Text("Tarif kaydedildi!")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .recipeGlass(tint: .warm, cornerRadius: 100) // Pill-shaped with very large corner radius
                    .padding(.bottom, 100)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showingSaveConfirmation)
            }
        }
        .navigationBarHidden(true)
        .ignoresSafeArea()
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
                glycemicLoad: viewModel.glycemicLoad
            )
            .presentationDetents([.fraction(0.7)])
        }
    }

    // MARK: - Hero Image Placeholder

    private var heroImagePlaceholder: some View {
        GeometryReader { geometry in
            let imageHeight = UIScreen.main.bounds.height * 0.5

            ZStack(alignment: .top) {
                // Show generated image if available, otherwise show placeholder gradient
                if let image = viewModel.preparedImage {
                    // Display generated image
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: imageHeight)
                        .clipped()

                    // Dark gradient overlay for text readability
                    RecipeImageGradient.textOverlay
                        .frame(width: geometry.size.width, height: imageHeight)
                } else {
                    // Placeholder gradient (purple like recipe detail view)
                    LinearGradient(
                        colors: [
                            ThemeColors.primaryPurple,
                            ThemeColors.lightPurple
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(width: geometry.size.width, height: imageHeight)

                    // Dark gradient overlay
                    RecipeImageGradient.textOverlay
                        .frame(width: geometry.size.width, height: imageHeight)
                }

                // Photo generation button or loading indicator
                if !viewModel.recipeName.isEmpty {
                    if viewModel.isGeneratingPhoto {
                        // Show pulsing spatial.capture icon while generating
                        VStack(spacing: 12) {
                            Image(systemName: "spatial.capture")
                                .font(.system(size: 64, weight: .light))
                                .foregroundStyle(.white.opacity(0.8))
                                .scaleEffect(viewModel.isGeneratingPhoto ? 1.2 : 1.0)
                                .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: viewModel.isGeneratingPhoto)
                            Text("Fotoğraf Oluşturuluyor...")
                                .font(.system(size: 17, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if viewModel.preparedImage == nil {
                        // Show photo generation button if no image yet
                        Button(action: {
                            Task {
                                await generatePhoto()
                            }
                        }) {
                            VStack(spacing: 12) {
                                Image(systemName: "spatial.capture")
                                    .font(.system(size: 64, weight: .light))
                                    .foregroundStyle(.white.opacity(0.8))
                                Text("Fotoğraf Oluştur")
                                    .font(.system(size: 17, weight: .medium, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .frame(height: UIScreen.main.bounds.height * 0.5)
    }

    // MARK: - Navigation

    private var navigationOverlay: some View {
        VStack {
            HStack {
                // Back button
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Circle())
                }
                .buttonStyle(RecipeButtonStyle())
                .recipeCircularGlass(size: 44, tint: .warm)

                Spacer()

                // Save button (only visible when recipe generated and not saved)
                if !viewModel.recipeName.isEmpty && !isSaved {
                    Button(action: {
                        Task {
                            await saveRecipe()
                        }
                    }) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .contentShape(Circle())
                    }
                    .buttonStyle(RecipeButtonStyle())
                    .recipeCircularGlass(size: 44, tint: .warm)
                }

                // Generate menu button (balli logo)
                Button(action: { showingMealSelection = true }) {
                    Image("balli-logo")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(8)
                        .contentShape(Circle())
                }
                .buttonStyle(RecipeButtonStyle())
                .recipeCircularGlass(size: 44, tint: .warm)
            }
            .padding(.horizontal, 20)
            .padding(.top, 60) // Account for status bar

            Spacer()
        }
    }

    // MARK: - Metadata Placeholder

    private var metadataPlaceholder: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Logo - Shows balli logo if AI-generated recipe
            if !viewModel.formState.recipeContent.isEmpty {
                Image("balli-text-logo-dark")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 20)
            }

            // Recipe title
            if !viewModel.recipeName.isEmpty {
                Text(viewModel.recipeName)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
            } else {
                Text("Tarif ismi")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.3))
                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Author Section

    private var authorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Only show logo/author for AI-generated recipes
            if !viewModel.formState.recipeContent.isEmpty {
                // Recipe was AI-generated - show balli logo above recipe name
                Image("balli-text-logo-dark")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 20)
            }
        }
    }

    // MARK: - Story Card Placeholder

    private var storyCardPlaceholder: some View {
        RecipeStoryCard(
            title: storyCardTitle,
            description: viewModel.notes.isEmpty
                ? "Tarif oluşturulduğunda notlar burada görünecek"
                : viewModel.notes,
            thumbnailURL: nil
        ) {
            // No action for placeholder
        }
    }

    // MARK: - Action Buttons

    private var actionButtonsPlaceholder: some View {
        RecipeActionRow(
            actions: [.favorite, .values, .shopping],
            activeStates: [isFavorited, false, false]
        ) { action in
            handleAction(action)
        }
    }

    private func handleAction(_ action: RecipeAction) {
        switch action {
        case .favorite:
            toggleFavorite()
        case .values:
            showingNutritionModal = true
        case .shopping:
            handleShopping()
        default:
            break
        }
    }

    private func toggleFavorite() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isFavorited.toggle()
        }

        // Only update the form state, don't save
        // Favoriting is just a UI state change until user explicitly saves
        viewModel.formState.isFavorite = isFavorited
    }

    private func handleShopping() {
        logger.info("🛒 [VIEW] Adding \(viewModel.ingredients.count) ingredients to shopping list")
        logger.debug("📋 [VIEW] Recipe name: '\(viewModel.recipeName)'")
        logger.debug("📋 [VIEW] First 3 ingredients: \(viewModel.ingredients.prefix(3).joined(separator: ", "))")

        Task {
            await viewModel.addIngredientsToShoppingList()
            logger.info("✅ [VIEW] Ingredients successfully added to shopping list")
        }
    }

    // MARK: - Recipe Content (Markdown)

    private var recipeContentSection: some View {
        Group {
            if !viewModel.recipeContent.isEmpty {
                MarkdownText(
                    content: viewModel.recipeContent,
                    fontSize: 20,  // Increased from 17 to 20
                    enableSelection: true,
                    sourceCount: 0,
                    sources: [],
                    headerFontSize: 20 * 2.0,  // Proportionally bigger headers (40pt)
                    fontName: "Manrope"
                )
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                // Interactive placeholder - let user add their own recipe
                VStack(alignment: .leading, spacing: 32) {
                    ManualIngredientsSection(
                        ingredients: $manualIngredients,
                        isAddingIngredient: $isAddingIngredient,
                        newIngredientText: $newIngredientText,
                        focusedField: $focusedField
                    )

                    ManualStepsSection(
                        steps: $manualSteps,
                        isAddingStep: $isAddingStep,
                        newStepText: $newStepText,
                        focusedField: $focusedField
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Generation

    private func startGeneration() async {
        isGenerating = true
        // Reset saved state when generating new recipe
        isSaved = false
        // Change story card title to "balli'nin notu" for AI-generated recipes
        storyCardTitle = "balli'nin notu"

        // Use streaming version for real-time updates
        await viewModel.generationCoordinator.generateRecipeWithStreaming(
            mealType: selectedMealType,
            styleType: selectedStyleType
        )
        isGenerating = false

        // After generation completes, view shows generated content
        // User can tap spatial.capture icon to generate photo
    }

    // MARK: - Save Recipe

    private func saveRecipe() async {
        logger.info("💾 [VIEW] saveRecipe() called")

        // If user has manually created a recipe, build markdown content
        if !manualIngredients.isEmpty || !manualSteps.isEmpty {
            buildManualRecipeContent()
        }

        // CRITICAL: Load image data from generated URL if present (before saving)
        if viewModel.generatedPhotoURL != nil {
            logger.info("🖼️ [VIEW] Photo URL present - loading image data before save...")
            await viewModel.loadImageFromGeneratedURL()
            logger.info("✅ [VIEW] Image data loaded - proceeding with save")
        } else {
            logger.debug("ℹ️ [VIEW] No generated photo URL - saving without image")
        }

        // Call ViewModel saveRecipe which passes image data to persistence coordinator
        logger.info("💾 [VIEW] Calling viewModel.saveRecipe()...")
        viewModel.saveRecipe()

        // Wait a moment for async save to complete
        try? await Task.sleep(for: .milliseconds(100))

        // Check if save was successful by checking coordinator's confirmation state
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

        // Add ingredients section
        if !manualIngredients.isEmpty {
            var ingredientLines = ["## Malzemeler", "---"]
            ingredientLines.append(contentsOf: manualIngredients.map { "- \($0.text)" })
            sections.append(ingredientLines.joined(separator: "\n"))
        }

        // Add steps section
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
        logger.debug("📋 [VIEW] ViewModel state before generation:")
        logger.debug("  - recipeName: '\(viewModel.recipeName)'")
        logger.debug("  - isGeneratingPhoto: \(viewModel.isGeneratingPhoto)")
        logger.debug("  - generatedPhotoURL: \(viewModel.generatedPhotoURL ?? "nil")")
        logger.debug("  - preparedImage: \(viewModel.preparedImage != nil ? "present" : "nil")")

        logger.info("🎬 [VIEW] Calling viewModel.generateRecipePhoto()...")
        // Call photo coordinator to generate AI image
        await viewModel.generateRecipePhoto()

        logger.info("✅ [VIEW] viewModel.generateRecipePhoto() returned")
        logger.debug("📋 [VIEW] ViewModel state after generation:")
        logger.debug("  - isGeneratingPhoto: \(viewModel.isGeneratingPhoto)")
        logger.debug("  - generatedPhotoURL: \(viewModel.generatedPhotoURL ?? "nil")")
        logger.debug("  - preparedImage: \(viewModel.preparedImage != nil ? "present" : "nil")")

        // After generation completes, load the image from the generated URL
        if viewModel.generatedPhotoURL != nil {
            logger.info("🖼️ [VIEW] generatedPhotoURL is present - calling loadImageFromGeneratedURL()")
            await viewModel.loadImageFromGeneratedURL()
            logger.info("✅ [VIEW] loadImageFromGeneratedURL() completed")
            logger.debug("  - preparedImage after load: \(viewModel.preparedImage != nil ? "present" : "nil")")
        } else {
            logger.warning("⚠️ [VIEW] generatedPhotoURL is nil - skipping image load")
        }

        logger.info("🏁 [VIEW] generatePhoto() completed")
    }
}

// MARK: - Helper Views

struct ManualIngredientsSection: View {
    @Binding var ingredients: [RecipeItem]
    @Binding var isAddingIngredient: Bool
    @Binding var newIngredientText: String
    var focusedField: FocusState<RecipeGenerationView.FocusField?>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Malzemeler")
                .font(.playfairDisplay(33.32, weight: .bold))
                .foregroundColor(.primary.opacity(0.3))

            // Show existing manual ingredients
            ForEach(ingredients) { item in
                HStack(spacing: 8) {
                    Text("•")
                        .font(.custom("Manrope", size: 20))
                        .foregroundColor(.primary)
                    Text(item.text)
                        .font(.custom("Manrope", size: 20))
                        .foregroundColor(.primary)

                    Spacer()

                    Button(action: {
                        ingredients.removeAll { $0.id == item.id }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.secondary.opacity(0.5))
                    }
                }
            }

            // Inline input or add button
            if isAddingIngredient {
                HStack(spacing: 8) {
                    Text("•")
                        .font(.custom("Manrope", size: 20))
                        .foregroundColor(.primary)
                    TextField("Örn: 250g tavuk göğsü", text: $newIngredientText)
                        .font(.custom("Manrope", size: 20))
                        .focused(focusedField, equals: .ingredient)
                        .submitLabel(.done)
                        .onSubmit {
                            addIngredient()
                        }
                }
            } else {
                Button(action: {
                    isAddingIngredient = true
                    focusedField.wrappedValue = .ingredient
                }) {
                    HStack(spacing: 8) {
                        Text("•")
                            .font(.custom("Manrope", size: 20))
                            .foregroundColor(.primary.opacity(0.7))
                        Text("Malzeme Ekle")
                            .font(.custom("Manrope", size: 20))
                            .foregroundColor(.primary.opacity(0.7))
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func addIngredient() {
        guard !newIngredientText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            isAddingIngredient = false
            return
        }
        ingredients.append(RecipeItem(text: newIngredientText))
        newIngredientText = ""
        focusedField.wrappedValue = .ingredient
    }
}

struct ManualStepsSection: View {
    @Binding var steps: [RecipeItem]
    @Binding var isAddingStep: Bool
    @Binding var newStepText: String
    var focusedField: FocusState<RecipeGenerationView.FocusField?>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Yapılışı")
                .font(.playfairDisplay(33.32, weight: .bold))
                .foregroundColor(.primary.opacity(0.3))

            // Show existing manual steps
            ForEach(Array(steps.enumerated()), id: \.element.id) { index, item in
                HStack(spacing: 8) {
                    Text("\(index + 1).")
                        .font(.custom("Manrope", size: 20))
                        .foregroundColor(.primary)
                    Text(item.text)
                        .font(.custom("Manrope", size: 20))
                        .foregroundColor(.primary)

                    Spacer()

                    Button(action: {
                        steps.removeAll { $0.id == item.id }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.secondary.opacity(0.5))
                    }
                }
            }

            // Inline input or add button
            if isAddingStep {
                HStack(spacing: 8) {
                    Text("\(steps.count + 1).")
                        .font(.custom("Manrope", size: 20))
                        .foregroundColor(.primary)
                    TextField("Örn: Tavukları zeytinyağında sotele", text: $newStepText)
                        .font(.custom("Manrope", size: 20))
                        .focused(focusedField, equals: .step)
                        .submitLabel(.done)
                        .onSubmit {
                            addStep()
                        }
                }
            } else {
                Button(action: {
                    isAddingStep = true
                    focusedField.wrappedValue = .step
                }) {
                    HStack(spacing: 8) {
                        Text("\(steps.count + 1).")
                            .font(.custom("Manrope", size: 20))
                            .foregroundColor(.primary.opacity(0.7))
                        Text("Adım Ekle")
                            .font(.custom("Manrope", size: 20))
                            .foregroundColor(.primary.opacity(0.7))
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func addStep() {
        guard !newStepText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            isAddingStep = false
            return
        }
        steps.append(RecipeItem(text: newStepText))
        newStepText = ""
        focusedField.wrappedValue = .step
    }
}

// MARK: - Custom Button Style

/// Button style that provides subtle opacity feedback without the glass interactive effect
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
