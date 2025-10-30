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
    @State private var showingShoppingConfirmation = false
    @State private var isCalculatingNutrition = false
    @State private var nutritionCalculationProgress = 0
    @State private var currentLoadingStep: String?
    @State private var digestionTimingInsights: DigestionTiming? = nil

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

    // Loading animation steps for nutrition calculation
    // Loading animation steps for nutrition calculation (total ~82 seconds to match API)
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

    var body: some View {
        ZStack {
            ScrollView {
            ZStack(alignment: .top) {
                VStack(spacing: 0) {
                    // Hero image that scrolls with content
                    heroImageSection

                    // Spacer to accommodate story card overlap
                    // Story card is 82px tall + 16px padding = 98px
                    // We want it half-over image, so subtract half its height
                    Spacer()
                        .frame(height: 49)

                    // All content below story card
                    VStack(spacing: 0) {
                        // Action buttons
                        actionButtonsSection
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                            .padding(.bottom, 32)

                        // Recipe Content (Ingredients + Instructions)
                        recipeContentSection
                            .padding(.horizontal, 20)
                            .padding(.bottom, 40)
                    }
                }

                // Recipe metadata - positioned absolutely over hero image
                // Uses bottom alignment to grow upward when text is longer
                VStack(spacing: 0) {
                    Spacer(minLength: 0)

                    recipeMetadataSection
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24) // Minimum gap between name and story card
                }
                .frame(height: UIScreen.main.bounds.height * 0.5 - 49) // Ends where story card begins

                // Story card - positioned absolutely at fixed offset
                // This stays in place regardless of recipe name length
                if recipeData.hasStory {
                    VStack {
                        Spacer()
                            .frame(height: UIScreen.main.bounds.height * 0.5 - 49)

                        storyCardSection
                            .padding(.horizontal, 20)

                        Spacer()
                    }
                }
            }
            }
            .scrollIndicators(.hidden)
            .safeAreaInset(edge: .top, spacing: 0) {
                Color.clear.frame(height: 0)
            }

            // Shopping confirmation toast
            if showingShoppingConfirmation {
                VStack {
                    Spacer()
                    HStack(spacing: 12) {
                        Image(systemName: "cart.fill.badge.plus")
                            .font(.system(size: 20))
                            .foregroundColor(ThemeColors.primaryPurple)
                        Text("Alışveriş listesine eklendi!")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .recipeGlass(tint: .warm, cornerRadius: 100)
                    .padding(.bottom, 100)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showingShoppingConfirmation)
            }
        }
        .ignoresSafeArea(edges: .top)
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
                // Per-100g values
                calories: String(format: "%.0f", recipeData.recipe.calories),
                carbohydrates: String(format: "%.1f", recipeData.recipe.totalCarbs),
                fiber: String(format: "%.1f", recipeData.recipe.fiber),
                sugar: String(format: "%.1f", recipeData.recipe.sugars),
                protein: String(format: "%.1f", recipeData.recipe.protein),
                fat: String(format: "%.1f", recipeData.recipe.totalFat),
                glycemicLoad: String(format: "%.0f", recipeData.recipe.glycemicLoad),
                // Per-serving values
                caloriesPerServing: String(format: "%.0f", recipeData.recipe.caloriesPerServing),
                carbohydratesPerServing: String(format: "%.1f", recipeData.recipe.carbsPerServing),
                fiberPerServing: String(format: "%.1f", recipeData.recipe.fiberPerServing),
                sugarPerServing: String(format: "%.1f", recipeData.recipe.sugarsPerServing),
                proteinPerServing: String(format: "%.1f", recipeData.recipe.proteinPerServing),
                fatPerServing: String(format: "%.1f", recipeData.recipe.fatPerServing),
                glycemicLoadPerServing: String(format: "%.0f", recipeData.recipe.glycemicLoadPerServing),
                totalRecipeWeight: String(format: "%.0f", recipeData.recipe.totalRecipeWeight),
                // API insights
                digestionTiming: digestionTimingInsights
            )
            .presentationDetents([.large])
        }
        .sheet(isPresented: $showingNotesModal) {
            UserNotesModalView(notes: $userNotes) { newNotes in
                logger.info("💬 [NOTES] User saved notes: '\(newNotes.prefix(50))...'")
                userNotes = newNotes
                // Save notes to recipe
                saveUserNotes(newNotes)
            }
        }
        .onChange(of: isCalculatingNutrition) { oldValue, newValue in
            if oldValue && !newValue {
                // Calculation just completed
                logger.info("✅ [NUTRITION] Calculation completed, showing modal")
                currentLoadingStep = nil
                showingNutritionalValues = true
            } else if !oldValue && newValue {
                // Calculation just started
                logger.info("🔄 [NUTRITION] Calculation started, beginning loading animation")
                startLoadingAnimation()
            }
        }
        .onAppear {
            // Load existing user notes
            userNotes = recipeData.recipe.notes ?? ""
        }
    }

    // MARK: - Hero Image Section

    private var heroImageSection: some View {
        GeometryReader { geometry in
            let imageHeight = UIScreen.main.bounds.height * 0.5

            ZStack(alignment: .top) {
                // Show generated image if available, otherwise show existing or placeholder
                if let generatedData = generatedImageData,
                   let uiImage = UIImage(data: generatedData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: imageHeight)
                        .clipped()
                } else if let imageData = recipeData.imageData,
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: imageHeight)
                        .clipped()
                } else if let imageURL = recipeData.imageURL, let url = URL(string: imageURL) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: geometry.size.width, height: imageHeight)
                                .clipped()
                        default:
                            placeholderImage(width: geometry.size.width, height: imageHeight)
                        }
                    }
                } else {
                    placeholderImage(width: geometry.size.width, height: imageHeight)
                }

                // Dark gradient overlay for text readability
                RecipeImageGradient.textOverlay
                    .frame(width: geometry.size.width, height: imageHeight)

                // Photo generation button or loading indicator (only if no image exists)
                if recipeData.imageData == nil && recipeData.imageURL == nil && generatedImageData == nil {
                    if isGeneratingPhoto {
                        // Show pulsing icon while generating
                        PulsingPhotoIcon()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        // Show photo generation button
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

    private func placeholderImage(width: CGFloat, height: CGFloat) -> some View {
        LinearGradient(
            colors: [
                ThemeColors.primaryPurple,
                ThemeColors.lightPurple
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .frame(width: width, height: height)
    }

    // MARK: - Recipe Metadata

    private var recipeMetadataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Balli logo for AI-generated recipes
            if recipeData.recipe.source == RecipeConstants.Source.ai {
                Image("balli-text-logo-dark")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 40)
            }

            // Author
            if let author = recipeData.author {
                Text(author)
                    .font(.sfRounded(17, weight: .regular))
                    .foregroundColor(.white.opacity(0.95))
            }

            // Recipe title - conditionally editable
            if isEditing {
                TextField("", text: $editedName, axis: .vertical)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .textFieldStyle(.plain)
                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
            } else {
                Text(recipeData.recipeName)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Story Card

    private var storyCardSection: some View {
        RecipeStoryCard(
            title: "balli'nin Tarif Analizi",
            description: "Besin değeri analizi",
            thumbnailURL: nil,
            isLoading: isCalculatingNutrition,
            loadingStep: currentLoadingStep,
            loadingProgress: Double(nutritionCalculationProgress)
        ) {
            handleStoryCardTap()
        }
    }

    // MARK: - Action Buttons

    private var actionButtonsSection: some View {
        RecipeActionRow(
            actions: [.favorite, .notes, .shopping],
            activeStates: [recipeData.recipe.isFavorite, false, false],
            loadingStates: [false, false, false],
            completedStates: [false, false, false],
            progressStates: [0, 0, 0]
        ) { action in
            handleAction(action)
        }
    }

    // MARK: - Recipe Content

    private var recipeContentSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isEditing {
                // Edit mode: Show editable text fields
                editableRecipeContent
            } else {
                // Read mode: Show markdown
                let markdownContent = recipeData.recipe.recipeContent ?? buildMarkdownContent()

                if !markdownContent.isEmpty {
                    MarkdownText(
                        content: markdownContent,
                        fontSize: 20,
                        enableSelection: true,
                        sourceCount: 0,
                        sources: [],
                        headerFontSize: 20 * 2.0,
                        fontName: "Manrope",
                        headerFontName: "PlayfairDisplay"
                    )
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text("No recipe content available")
                        .font(.sfRounded(17, weight: .regular))
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var editableRecipeContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Editable Ingredients Section
            VStack(alignment: .leading, spacing: 8) {
                Text("Malzemeler")
                    .font(.custom("GalanoGrotesqueAlt-Bold", size: 33))
                    .foregroundColor(.primary)
                    .padding(.bottom, 0)

                ForEach(Array(editedIngredients.enumerated()), id: \.offset) { index, ingredient in
                    HStack(alignment: .top, spacing: 16) {
                        Text("•")
                            .font(.custom("Manrope", size: 20))
                            .foregroundColor(AppTheme.primaryPurple)
                            .padding(.top, 8)

                        TextEditor(text: Binding(
                            get: { editedIngredients[index] },
                            set: { editedIngredients[index] = $0 }
                        ))
                        .font(.custom("Manrope", size: 20))
                        .foregroundColor(.primary)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                        .frame(minHeight: 30)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding(.bottom, 24)

            // Editable Instructions Section
            VStack(alignment: .leading, spacing: 8) {
                Text("Yapілışі")
                    .font(.custom("GalanoGrotesqueAlt-Bold", size: 33))
                    .foregroundColor(.primary)
                    .padding(.bottom, 0)

                ForEach(Array(editedInstructions.enumerated()), id: \.offset) { index, instruction in
                    HStack(alignment: .top, spacing: 16) {
                        Text("\(index + 1).")
                            .font(.custom("Manrope", size: 20))
                            .foregroundColor(AppTheme.primaryPurple)
                            .padding(.top, 8)

                        TextEditor(text: Binding(
                            get: { editedInstructions[index] },
                            set: { editedInstructions[index] = $0 }
                        ))
                        .font(.custom("Manrope", size: 20))
                        .foregroundColor(.primary)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                        .frame(minHeight: 30)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private func buildMarkdownContent() -> String {
        var markdown = ""

        // Add ingredients section
        let ingredients = recipeData.recipe.ingredientsArray
        if !ingredients.isEmpty {
            markdown += "## Malzemeler\n\n"
            for ingredient in ingredients {
                markdown += "- \(ingredient)\n"
            }
            markdown += "\n"
        }

        // Add instructions section
        let instructions = recipeData.recipe.instructionsArray
        if !instructions.isEmpty {
            markdown += "## Yapılışı\n\n"
            for (index, instruction) in instructions.enumerated() {
                markdown += "\(index + 1). \(instruction)\n"
            }
        }

        return markdown
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

        // Try to get ingredients/instructions from arrays first
        var ingredients = recipeData.recipe.ingredientsArray
        var instructions = recipeData.recipe.instructionsArray

        // If arrays are empty, parse from markdown content
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
        logger.info("   Name: \(editedName)")
        logger.info("   Ingredients count: \(editedIngredients.count)")
        logger.info("   Instructions count: \(editedInstructions.count)")
        if !editedIngredients.isEmpty {
            logger.info("   First ingredient: \(editedIngredients[0])")
        }

        isEditing = true
    }

    private func parseMarkdownContent(_ markdown: String) -> (ingredients: [String], instructions: [String]) {
        var ingredients: [String] = []
        var instructions: [String] = []

        let lines = markdown.components(separatedBy: .newlines)
        var currentSection: String? = nil

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Check for section headers
            if trimmed.starts(with: "## Malzemeler") || trimmed.starts(with: "##Malzemeler") {
                currentSection = "ingredients"
                continue
            } else if trimmed.starts(with: "## Yapılışı") || trimmed.starts(with: "##Yapılışı") {
                currentSection = "instructions"
                continue
            }

            // Skip empty lines
            if trimmed.isEmpty {
                continue
            }

            // Parse ingredients (lines starting with -)
            if currentSection == "ingredients" && trimmed.starts(with: "- ") {
                let ingredient = String(trimmed.dropFirst(2)) // Remove "- "
                ingredients.append(ingredient)
            }
            // Parse instructions (lines starting with numbers)
            else if currentSection == "instructions" {
                // Match patterns like "1. " or "1) " at the start
                if let match = trimmed.range(of: "^\\d+[\\.\\)]\\s+", options: .regularExpression) {
                    let instruction = String(trimmed[match.upperBound...])
                    instructions.append(instruction)
                }
            }
        }

        logger.info("📄 [PARSE] Parsed markdown: \(ingredients.count) ingredients, \(instructions.count) instructions")

        return (ingredients, instructions)
    }

    private func saveChanges() {
        // Update recipe in Core Data
        recipeData.recipe.name = editedName
        recipeData.recipe.ingredients = editedIngredients.filter { !$0.isEmpty } as NSArray
        recipeData.recipe.instructions = editedInstructions.filter { !$0.isEmpty } as NSArray
        recipeData.recipe.notes = editedNotes.isEmpty ? nil : editedNotes
        recipeData.recipe.lastModified = Date()

        // Rebuild markdown content
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

        // Add ingredients section
        let ingredients = editedIngredients.filter { !$0.isEmpty }
        if !ingredients.isEmpty {
            markdown += "## Malzemeler\n\n"
            for ingredient in ingredients {
                markdown += "- \(ingredient)\n"
            }
            markdown += "\n"
        }

        // Add instructions section
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
                // Use edited ingredients if in edit mode, otherwise use saved ingredients
                let ingredients = isEditing ? editedIngredients : recipeData.recipe.ingredientsArray

                guard !ingredients.isEmpty else {
                    logger.warning("⚠️ [DETAIL] No ingredients found in recipe")
                    return
                }

                logger.debug("📦 [DETAIL] Processing \(ingredients.count) ingredients (isEditing: \(isEditing))")

                // Add ingredients to shopping list with recipe context
                let updatedSent = try await dataManager.addIngredientsToShoppingList(
                    ingredients: ingredients,
                    sentIngredients: [],
                    recipeName: recipeData.recipeName,
                    recipeId: recipeData.recipe.id
                )

                logger.info("✅ [DETAIL] Successfully added \(ingredients.count) ingredients to shopping list")
                logger.debug("📋 [DETAIL] Recipe context: recipeId=\(recipeData.recipe.id), recipeName=\(recipeData.recipeName)")
                logger.debug("📋 [DETAIL] Updated sent ingredients: \(updatedSent.count) total")

                // Show confirmation feedback
                await MainActor.run {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        showingShoppingConfirmation = true
                    }
                }

                // Hide confirmation after 2 seconds
                try? await Task.sleep(for: .seconds(2))
                await MainActor.run {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        showingShoppingConfirmation = false
                    }
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
            // Extract recipe data
            let ingredients = recipeData.recipe.ingredientsArray
            let directions = recipeData.recipe.instructionsArray

            logger.debug("📋 [DETAIL] Recipe data: \(ingredients.count) ingredients, \(directions.count) directions")

            // Generate photo using shared service
            let photoService = RecipePhotoGenerationService.shared
            let imageURL = try await photoService.generateRecipePhoto(
                recipeName: recipeData.recipeName,
                ingredients: ingredients,
                directions: directions,
                mealType: "Genel",
                styleType: "Klasik"
            )

            logger.info("✅ [DETAIL] Photo generated successfully")

            // Convert base64 data URL to image data
            if let imageData = extractImageData(from: imageURL) {
                logger.info("✅ [DETAIL] Image data extracted (\(imageData.count) bytes)")

                // Update UI and save to Core Data
                await saveGeneratedImage(imageData)
            } else {
                logger.error("❌ [DETAIL] Failed to extract image data from URL")
            }

            isGeneratingPhoto = false
            logger.info("🏁 [DETAIL] Photo generation completed")

        } catch {
            logger.error("❌ [DETAIL] Photo generation failed: \(error.localizedDescription)")
            isGeneratingPhoto = false
            ErrorHandler.shared.handle(error)
        }
    }

    /// Extract image data from base64 data URL
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

    /// Save generated image to Core Data
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

        // Check if nutrition values are already calculated
        let hasNutrition = recipeData.recipe.calories > 0 &&
                          recipeData.recipe.totalCarbs > 0 &&
                          recipeData.recipe.protein > 0

        if hasNutrition {
            // Nutrition already calculated, show modal immediately
            logger.info("✅ [STORY] Nutrition data exists, showing modal")
            showingNutritionalValues = true
        } else {
            // Start calculation - loading animation will show in card
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
                // Check if calculation is still in progress
                guard await MainActor.run(body: { isCalculatingNutrition }) else {
                    logger.info("⏹️ [LOADING] Calculation completed early, stopping animation")
                    return
                }

                // Update current step
                await MainActor.run {
                    currentLoadingStep = step.label
                }

                logger.debug("📝 [LOADING] Step: '\(step.label)' (target: \(step.progress)%)")

                // Wait for step duration
                try? await Task.sleep(for: .seconds(step.duration))
            }

            // Clear loading step when done
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
                servings: 1  // Always 1 = entire recipe as one portion
            )

            logger.info("✅ [NUTRITION] Received response from API")

            // Update recipe with nutrition values
            recipeData.recipe.calories = result.calories
            recipeData.recipe.totalCarbs = result.carbohydrates
            recipeData.recipe.fiber = result.fiber
            recipeData.recipe.sugars = result.sugar
            recipeData.recipe.protein = result.protein
            recipeData.recipe.totalFat = result.fat
            recipeData.recipe.glycemicLoad = result.glycemicLoad

            // Per-serving values (computed properties from result)
            recipeData.recipe.caloriesPerServing = result.caloriesPerServing
            recipeData.recipe.carbsPerServing = result.carbohydratesPerServing
            recipeData.recipe.fiberPerServing = result.fiberPerServing
            recipeData.recipe.sugarsPerServing = result.sugarPerServing
            recipeData.recipe.proteinPerServing = result.proteinPerServing
            recipeData.recipe.fatPerServing = result.fatPerServing
            recipeData.recipe.glycemicLoadPerServing = result.glycemicLoadPerServing
            recipeData.recipe.totalRecipeWeight = result.totalRecipeWeight

            // Store digestion timing insights for modal
            digestionTimingInsights = result.digestionTiming

            // Save to Core Data
            try viewContext.save()

            isCalculatingNutrition = false
            nutritionCalculationProgress = 100

            logger.info("✅ [NUTRITION] Values saved successfully")
            if let insights = result.digestionTiming {
                logger.info("   Digestion timing: \(insights.hasMismatch ? "mismatch detected" : "no mismatch"), peak at \(insights.glucosePeakTime)h")
            }
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

    // Set all required properties
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
        recipeDescription: "This creamy, smooth hummus is perfect for dipping or spreading. Made with chickpeas, tahini, lemon juice, and garlic, it's a healthy and delicious snack that comes together in minutes.",
        storyTitle: nil,
        storyDescription: nil,
        storyThumbnailURL: nil
    )

    return NavigationStack {
        RecipeDetailView(recipeData: detailData)
            .environment(\.managedObjectContext, context)
    }
}

#Preview("Long Description") {
    let controller = Persistence.PersistenceController(inMemory: true)
    let context = controller.viewContext
    let recipe = Recipe(context: context)

    // Set all required properties
    recipe.id = UUID()
    recipe.name = "Homemade Sourdough Bread"
    recipe.servings = 1
    recipe.dateCreated = Date()
    recipe.lastModified = Date()
    recipe.source = "manual"
    recipe.isVerified = false
    recipe.isFavorite = false
    recipe.timesCooked = 0
    recipe.userRating = 0
    recipe.calories = 250
    recipe.totalCarbs = 48
    recipe.fiber = 3
    recipe.sugars = 2
    recipe.protein = 8
    recipe.totalFat = 2
    recipe.glycemicLoad = 15
    recipe.prepTime = 240
    recipe.cookTime = 40
    recipe.ingredients = ["500g bread flour", "350ml water", "100g active sourdough starter", "10g salt"] as NSArray
    recipe.instructions = ["Mix flour and water", "Let autolyse for 30 minutes", "Add starter and salt", "Knead until smooth", "Bulk fermentation 4 hours", "Shape into loaf", "Final proof 2 hours", "Score and bake at 450°F"] as NSArray

    let detailData = RecipeDetailData(
        recipe: recipe,
        recipeSource: "The Bread Lab",
        author: "Baker John Smith",
        yieldText: "1 loaf",
        recipeDescription: "Making sourdough bread at home is a rewarding process that requires patience and practice. This recipe walks you through creating and maintaining a sourdough starter, then using it to bake a beautiful artisan loaf with a crispy crust and chewy interior. The natural fermentation process not only develops incredible flavor but also makes the bread easier to digest. Perfect for beginners and experienced bakers alike.",
        storyTitle: "The Ancient Art of Sourdough: A Journey Through Time and Taste",
        storyDescription: "Learn how ancient bakers discovered wild fermentation and how this time-honored technique creates the most flavorful bread. From Egyptian pyramids to modern artisan bakeries, sourdough has been feeding humanity for millennia.",
        storyThumbnailURL: nil
    )

    return NavigationStack {
        RecipeDetailView(recipeData: detailData)
            .environment(\.managedObjectContext, context)
    }
}
