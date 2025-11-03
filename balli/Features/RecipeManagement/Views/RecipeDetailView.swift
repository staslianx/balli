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

    @State private var showingShareSheet = false
    @State private var showingNutritionalValues = false
    @State private var showingNotesModal = false
    @State private var isGeneratingPhoto = false
    @State private var generatedImageData: Data?
    @State private var isCalculatingNutrition = false
    @State private var nutritionCalculationProgress = 0
    @State private var currentLoadingStep: String?
    @State private var digestionTimingInsights: DigestionTiming? = nil
    @State private var toastMessage: ToastType? = nil

    // Inline editing state
    @State private var isEditing = false
    @State private var editedName: String = ""
    @State private var editedIngredients: [String] = []
    @State private var editedInstructions: [String] = []
    @State private var editedNotes: String = ""
    @State private var userNotes: String = ""

    // MARK: - Services
    private let nutritionRepository = RecipeNutritionRepository()

    // MARK: - Data Manager
    private var dataManager: RecipeDataManager {
        RecipeDataManager(context: viewContext)
    }

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.balli", category: "RecipeDetailView")

    // MARK: - Shopping List Query for Dynamic Basket Icon
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \ShoppingListItem.dateCreated, ascending: false)],
        animation: .default
    )
    private var allShoppingItems: FetchedResults<ShoppingListItem>

    // Loading animation steps for nutrition calculation
    private let loadingSteps: [(label: String, duration: TimeInterval, progress: Int)] = [
        ("Tarife tekrar bakıyorum", 5.0, 6),
        ("Malzemeleri inceliyorum", 6.0, 13),
        ("Ağırlıkları belirliyorum", 7.0, 21),
        ("Ham besin değerlerini hesaplıyorum", 7.0, 30),
        ("Pişirme yöntemlerini analiz ediyorum", 7.0, 39),
        ("Pişirme etkilerini belirliyorum", 7.0, 48),
        ("Pişirme kayıplarını hesaplıyorum", 7.0, 57),
        ("Sıvı emilimini hesaplıyorum", 7.0, 66),
        ("100g için değerleri hesaplıyorum", 7.0, 75),
        ("1 porsiyon için değerleri hesaplıyorum", 7.0, 84),
        ("Glisemik yükü hesaplıyorum", 7.0, 92),
        ("Sağlamasını yapıyorum", 8.0, 100)
    ]

    // MARK: - Computed Properties

    /// Check if this recipe has unchecked ingredients in shopping list (for dynamic basket icon)
    private var hasUncheckedIngredientsForRecipe: Bool {
        allShoppingItems.contains { item in
            item.recipeId == recipeData.recipe.id && !item.isCompleted
        }
    }

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
                                generatedImageData: generatedImageData,
                                isGeneratingPhoto: isGeneratingPhoto,
                                onGeneratePhoto: generatePhoto
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
                                    isEditing: isEditing,
                                    hasUncheckedIngredientsInShoppingList: hasUncheckedIngredientsForRecipe,
                                    onAction: handleAction
                                )
                                .padding(.horizontal, 20)
                                .padding(.top, 0)
                                .padding(.bottom, 16)

                                // Recipe Content (Ingredients + Instructions)
                                RecipeContentSection(
                                    recipe: recipeData.recipe,
                                    isEditing: isEditing,
                                    editedIngredients: $editedIngredients,
                                    editedInstructions: $editedInstructions
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
                                isEditing: isEditing,
                                editedName: $editedName
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
                                    isCalculatingNutrition: isCalculatingNutrition,
                                    currentLoadingStep: currentLoadingStep,
                                    nutritionCalculationProgress: nutritionCalculationProgress,
                                    onTap: handleStoryCardTap
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
        .toast($toastMessage)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                if isEditing {
                    Button("İptal") {
                        cancelEditing()
                    }
                    .foregroundStyle(ThemeColors.primaryPurple)
                } else {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(ThemeColors.primaryPurple)
                    }
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                if isEditing {
                    Button("Kaydet") {
                        saveChanges()
                    }
                    .foregroundStyle(ThemeColors.primaryPurple)
                } else {
                    Menu {
                        Button {
                            startEditing()
                        } label: {
                            Label("Düzenle", systemImage: "pencil")
                        }

                        Button {
                            toggleFavorite()
                        } label: {
                            Label(
                                recipeData.recipe.isFavorite ? "Favorilerden Çıkar" : "Favorilere Ekle",
                                systemImage: recipeData.recipe.isFavorite ? "star.fill" : "star"
                            )
                        }

                        Button(role: .destructive) {
                            deleteRecipe()
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
        .sheet(isPresented: $showingNutritionalValues) {
            NutritionalValuesView(
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
                digestionTiming: digestionTimingInsights,
                portionMultiplier: Binding(
                    get: { recipeData.recipe.portionMultiplier },
                    set: { newValue in
                        recipeData.recipe.portionMultiplier = newValue
                        Task { @MainActor in
                            savePortionMultiplier()
                        }
                    }
                )
            )
            .presentationDetents([.large])
        }
        .sheet(isPresented: $showingNotesModal) {
            UserNotesModalView(notes: $userNotes) { newNotes in
                logger.info("💬 [NOTES] User saved notes: '\(newNotes.prefix(50))...'")
                userNotes = newNotes
                saveUserNotes(newNotes)
            }
        }
        .onChange(of: isCalculatingNutrition) { oldValue, newValue in
            if oldValue && !newValue {
                logger.info("✅ [NUTRITION] Calculation completed, showing modal")
                currentLoadingStep = nil
                showingNutritionalValues = true
            } else if !oldValue && newValue {
                logger.info("🔄 [NUTRITION] Calculation started, beginning loading animation")
                startLoadingAnimation()
            }
        }
        .onAppear {
            userNotes = recipeData.recipe.notes ?? ""

            // Track recipe opening by updating lastModified
            recipeData.recipe.lastModified = Date()
            do {
                try viewContext.save()
                logger.debug("📖 Recipe opened, lastModified updated for tracking")
            } catch {
                logger.error("❌ Failed to update recipe lastModified: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Actions

    private func toggleFavorite() {
        recipeData.recipe.toggleFavorite()

        do {
            try viewContext.save()
            logger.info("✅ Recipe favorite status toggled: \(recipeData.recipe.isFavorite)")
        } catch {
            logger.error("❌ Failed to toggle favorite status: \(error.localizedDescription)")
        }
    }

    private func deleteRecipe() {
        logger.info("🗑️ Deleting recipe: \(recipeData.recipeName)")

        viewContext.delete(recipeData.recipe)

        do {
            try viewContext.save()
            logger.info("✅ Recipe deleted successfully")
            dismiss()
        } catch {
            logger.error("❌ Failed to delete recipe: \(error.localizedDescription)")
        }
    }

    // MARK: - Inline Editing Functions

    private func startEditing() {
        editedName = recipeData.recipeName

        var ingredients = recipeData.recipe.ingredientsArray
        var instructions = recipeData.recipe.instructionsArray

        if ingredients.isEmpty || instructions.isEmpty {
            let markdown = recipeData.recipe.recipeContent ?? ""
            let parsed = parseMarkdownContent(markdown)
            ingredients = parsed.ingredients
            instructions = parsed.instructions
        }

        editedIngredients = ingredients
        editedInstructions = instructions
        editedNotes = recipeData.recipe.notes ?? ""

        logger.info("📝 [EDIT] Starting edit mode")
        isEditing = true
    }

    private func parseMarkdownContent(_ markdown: String) -> (ingredients: [String], instructions: [String]) {
        var ingredients: [String] = []
        var instructions: [String] = []

        let lines = markdown.components(separatedBy: .newlines)
        var currentSection: String? = nil

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.starts(with: "## Malzemeler") || trimmed.starts(with: "##Malzemeler") {
                currentSection = "ingredients"
                continue
            } else if trimmed.starts(with: "## Yapılışı") || trimmed.starts(with: "##Yapılışı") {
                currentSection = "instructions"
                continue
            }

            if trimmed.isEmpty {
                continue
            }

            if currentSection == "ingredients" && trimmed.starts(with: "- ") {
                let ingredient = String(trimmed.dropFirst(2))
                ingredients.append(ingredient)
            } else if currentSection == "instructions" {
                if let match = trimmed.range(of: "^\\d+[\\.\\)]\\s+", options: .regularExpression) {
                    let instruction = String(trimmed[match.upperBound...])
                    instructions.append(instruction)
                }
            }
        }

        return (ingredients, instructions)
    }

    private func saveChanges() {
        recipeData.recipe.name = editedName
        recipeData.recipe.ingredients = editedIngredients.filter { !$0.isEmpty } as NSArray
        recipeData.recipe.instructions = editedInstructions.filter { !$0.isEmpty } as NSArray
        recipeData.recipe.notes = editedNotes.isEmpty ? nil : editedNotes
        recipeData.recipe.lastModified = Date()
        recipeData.recipe.recipeContent = buildMarkdownFromEdited()

        do {
            try viewContext.save()
            logger.info("✅ Recipe changes saved successfully")
        } catch {
            logger.error("❌ Failed to save recipe changes: \(error.localizedDescription)")
        }

        isEditing = false
    }

    private func cancelEditing() {
        isEditing = false
    }

    private func buildMarkdownFromEdited() -> String {
        var markdown = ""

        let ingredients = editedIngredients.filter { !$0.isEmpty }
        if !ingredients.isEmpty {
            markdown += "## Malzemeler\n\n"
            for ingredient in ingredients {
                markdown += "- \(ingredient)\n"
            }
            markdown += "\n"
        }

        let instructions = editedInstructions.filter { !$0.isEmpty }
        if !instructions.isEmpty {
            markdown += "## Yapılışı\n\n"
            for (index, instruction) in instructions.enumerated() {
                markdown += "\(index + 1). \(instruction)\n"
            }
        }

        return markdown
    }

    private func handleAction(_ action: RecipeAction) {
        switch action {
        case .favorite:
            handleFavorite()
        case .notes:
            showingNotesModal = true
        case .shopping:
            handleShopping()
        default:
            break
        }
    }

    private func handleFavorite() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            recipeData.recipe.toggleFavorite()
        }

        do {
            try viewContext.save()
            logger.info("✅ Recipe favorite status toggled: \(recipeData.recipe.isFavorite)")
        } catch {
            logger.error("❌ Failed to toggle favorite status: \(error.localizedDescription)")
        }
    }

    private func handleShopping() {
        logger.info("🛒 [DETAIL] Adding ingredients to shopping list for: \(recipeData.recipeName)")

        Task {
            do {
                let ingredients = isEditing ? editedIngredients : recipeData.recipe.ingredientsArray

                guard !ingredients.isEmpty else {
                    logger.warning("⚠️ [DETAIL] No ingredients found in recipe")
                    return
                }

                _ = try await dataManager.addIngredientsToShoppingList(
                    ingredients: ingredients,
                    sentIngredients: [],
                    recipeName: recipeData.recipeName,
                    recipeId: recipeData.recipe.id
                )

                logger.info("✅ [DETAIL] Successfully added \(ingredients.count) ingredients to shopping list")

                await MainActor.run {
                    toastMessage = .success("Alışveriş listesine eklendi!")
                }

            } catch {
                logger.error("❌ [DETAIL] Failed to add ingredients to shopping list: \(error.localizedDescription)")
                ErrorHandler.shared.handle(error)
            }
        }
    }

    // MARK: - Photo Generation

    private func generatePhoto() async {
        logger.info("🎬 [DETAIL] Photo generation started for recipe: \(recipeData.recipeName)")

        isGeneratingPhoto = true

        do {
            let ingredients = recipeData.recipe.ingredientsArray
            let directions = recipeData.recipe.instructionsArray

            let photoService = RecipePhotoGenerationService.shared
            let imageURL = try await photoService.generateRecipePhoto(
                recipeName: recipeData.recipeName,
                ingredients: ingredients,
                directions: directions,
                mealType: "Genel",
                styleType: "Klasik"
            )

            logger.info("✅ [DETAIL] Photo generated successfully")

            if let imageData = extractImageData(from: imageURL) {
                await saveGeneratedImage(imageData)
            } else {
                logger.error("❌ [DETAIL] Failed to extract image data from URL")
            }

            isGeneratingPhoto = false

        } catch {
            logger.error("❌ [DETAIL] Photo generation failed: \(error.localizedDescription)")
            isGeneratingPhoto = false
            ErrorHandler.shared.handle(error)
        }
    }

    private func extractImageData(from imageURL: String) -> Data? {
        guard imageURL.hasPrefix("data:image") else {
            logger.warning("⚠️ [DETAIL] Image URL is not a data URL")
            return nil
        }

        let base64String = imageURL
            .replacingOccurrences(of: "data:image/jpeg;base64,", with: "")
            .replacingOccurrences(of: "data:image/png;base64,", with: "")

        return Data(base64Encoded: base64String)
    }

    @MainActor
    private func saveGeneratedImage(_ imageData: Data) async {
        generatedImageData = imageData
        recipeData.recipe.imageData = imageData
        recipeData.recipe.lastModified = Date()

        do {
            try viewContext.save()
            logger.info("✅ [DETAIL] Image saved to recipe successfully")
        } catch {
            logger.error("❌ [DETAIL] Failed to save image: \(error.localizedDescription)")
            ErrorHandler.shared.handle(error)
        }
    }

    // MARK: - Story Card Tap Handler

    private func handleStoryCardTap() {
        logger.info("🔍 [STORY] Story card tapped")

        let hasNutrition = recipeData.recipe.calories > 0 &&
                          recipeData.recipe.totalCarbs > 0 &&
                          recipeData.recipe.protein > 0

        if hasNutrition {
            logger.info("✅ [STORY] Nutrition data exists, showing modal")
            showingNutritionalValues = true
        } else {
            logger.info("🔄 [STORY] Starting nutrition calculation")
            Task {
                await calculateNutritionValues()
            }
        }
    }

    // MARK: - Loading Animation

    private func startLoadingAnimation() {
        Task {
            for step in loadingSteps {
                guard await MainActor.run(body: { isCalculatingNutrition }) else {
                    logger.info("⏹️ [LOADING] Calculation completed early, stopping animation")
                    return
                }

                await MainActor.run {
                    currentLoadingStep = step.label
                }

                try? await Task.sleep(for: .seconds(step.duration))
            }

            await MainActor.run {
                currentLoadingStep = nil
            }
            logger.info("✅ [LOADING] Animation sequence completed")
        }
    }

    // MARK: - Calculate Nutrition

    @MainActor
    private func calculateNutritionValues() async {
        guard let recipeContent = recipeData.recipe.recipeContent,
              !recipeData.recipeName.isEmpty else {
            logger.error("❌ [NUTRITION] Missing recipe data for calculation")
            return
        }

        isCalculatingNutrition = true
        nutritionCalculationProgress = 1

        do {
            logger.info("🍽️ [NUTRITION] Calling nutrition repository...")

            let result = try await nutritionRepository.calculateNutrition(
                recipeName: recipeData.recipeName,
                recipeContent: recipeContent,
                servings: 1
            )

            logger.info("✅ [NUTRITION] Received response from API")

            recipeData.recipe.calories = result.calories
            recipeData.recipe.totalCarbs = result.carbohydrates
            recipeData.recipe.fiber = result.fiber
            recipeData.recipe.sugars = result.sugar
            recipeData.recipe.protein = result.protein
            recipeData.recipe.totalFat = result.fat
            recipeData.recipe.glycemicLoad = result.glycemicLoad

            recipeData.recipe.caloriesPerServing = result.caloriesPerServing
            recipeData.recipe.carbsPerServing = result.carbohydratesPerServing
            recipeData.recipe.fiberPerServing = result.fiberPerServing
            recipeData.recipe.sugarsPerServing = result.sugarPerServing
            recipeData.recipe.proteinPerServing = result.proteinPerServing
            recipeData.recipe.fatPerServing = result.fatPerServing
            recipeData.recipe.glycemicLoadPerServing = result.glycemicLoadPerServing
            recipeData.recipe.totalRecipeWeight = result.totalRecipeWeight

            digestionTimingInsights = result.digestionTiming

            try viewContext.save()

            isCalculatingNutrition = false
            nutritionCalculationProgress = 100

            logger.info("✅ [NUTRITION] Values saved successfully")
        } catch {
            logger.error("❌ [NUTRITION] Calculation failed: \(error.localizedDescription)")
            isCalculatingNutrition = false
            nutritionCalculationProgress = 0
            ErrorHandler.shared.handle(error)
        }
    }

    // MARK: - Save User Notes

    @MainActor
    private func saveUserNotes(_ notes: String) {
        recipeData.recipe.notes = notes

        do {
            try viewContext.save()
            logger.info("✅ [NOTES] User notes saved successfully")
        } catch {
            logger.error("❌ [NOTES] Failed to save notes: \(error.localizedDescription)")
            ErrorHandler.shared.handle(error)
        }
    }

    // MARK: - Save Portion Multiplier

    @MainActor
    private func savePortionMultiplier() {
        do {
            try viewContext.save()
            logger.info("✅ [NUTRITION] Portion multiplier saved: \(recipeData.recipe.portionMultiplier)")
        } catch {
            logger.error("❌ [NUTRITION] Failed to save portion multiplier: \(error.localizedDescription)")
            ErrorHandler.shared.handle(error)
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
