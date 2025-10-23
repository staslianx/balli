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

    @State private var isSaved = false
    @State private var showingShareSheet = false
    @State private var showingNutritionalValues = false
    @State private var showingNoteDetail = false
    @State private var isGeneratingPhoto = false
    @State private var generatedImageData: Data?
    @State private var showingMoreMenu = false

    // Inline editing state
    @State private var isEditing = false
    @State private var editedName: String = ""
    @State private var editedIngredients: [String] = []
    @State private var editedInstructions: [String] = []
    @State private var editedNotes: String = ""

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.balli", category: "RecipeDetailView")

    var body: some View {
        ZStack {
            // MARK: - Scrollable Content (including hero image)
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

            // MARK: - Navigation Overlay
            navigationOverlay
        }
        .navigationBarHidden(true)
        .ignoresSafeArea()
        .sheet(isPresented: $showingNutritionalValues) {
            NutritionalValuesView(
                recipeName: recipeData.recipeName,
                calories: String(format: "%.0f", recipeData.recipe.calories),
                carbohydrates: String(format: "%.1f", recipeData.recipe.totalCarbs),
                fiber: String(format: "%.1f", recipeData.recipe.fiber),
                sugar: String(format: "%.1f", recipeData.recipe.sugars),
                protein: String(format: "%.1f", recipeData.recipe.protein),
                fat: String(format: "%.1f", recipeData.recipe.totalFat),
                glycemicLoad: String(format: "%.0f", recipeData.recipe.glycemicLoad)
            )
        }
        .sheet(isPresented: $showingNoteDetail) {
            RecipeNoteDetailView(
                title: recipeData.storyTitle ?? "balli'nin notu",
                note: recipeData.storyDescription ?? ""
            )
            .presentationDetents([.fraction(0.6)])
            .presentationDragIndicator(.visible)
        }
        .confirmationDialog("", isPresented: $showingMoreMenu, titleVisibility: .hidden) {
            Button("Düzenle") {
                startEditing()
            }
            Button("İptal", role: .cancel) { }
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
                        // Show loading indicator while generating
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
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

    // MARK: - Navigation

    private var navigationOverlay: some View {
        VStack {
            HStack {
                // Left button: Back (read mode) or İptal (edit mode)
                if isEditing {
                    Button(action: cancelEditing) {
                        Text("İptal")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                    }
                    .recipeGlass(tint: .warm, cornerRadius: 22)
                } else {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)
                    }
                    .recipeCircularGlass(size: 44, tint: .warm)
                }

                Spacer()

                // Right button: More menu (read mode) or Kaydet (edit mode)
                if isEditing {
                    Button(action: saveChanges) {
                        Text("Kaydet")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                    }
                    .recipeGlass(tint: .warm, cornerRadius: 22)
                } else {
                    Button(action: handleMoreMenu) {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)
                    }
                    .recipeCircularGlass(size: 44, tint: .warm)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 60) // Account for status bar

            Spacer()
        }
    }

    // MARK: - Recipe Metadata

    private var recipeMetadataSection: some View {
        VStack(alignment: .leading, spacing: 8) {
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
            title: recipeData.storyTitle ?? "",
            description: recipeData.storyDescription,
            thumbnailURL: recipeData.storyThumbnailURL
        ) {
            handleStoryTap()
        }
    }

    // MARK: - Action Buttons

    private var actionButtonsSection: some View {
        RecipeActionRow(
            actions: [.save, .values, .shopping],
            activeStates: [isSaved, false, false]
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
                    .font(.playfairDisplay(40, weight: .bold))
                    .foregroundColor(.primary)
                    .padding(.bottom, 8)

                ForEach(Array(editedIngredients.enumerated()), id: \.offset) { index, ingredient in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .font(.custom("Manrope", size: 20).weight(.semibold))
                            .foregroundColor(.primary)

                        TextField("", text: Binding(
                            get: { editedIngredients[index] },
                            set: { editedIngredients[index] = $0 }
                        ), axis: .vertical)
                        .font(.custom("Manrope", size: 20).weight(.semibold))
                        .foregroundColor(.primary)
                        .textFieldStyle(.plain)
                        .submitLabel(.done)
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding(.bottom, 24)

            // Editable Instructions Section
            VStack(alignment: .leading, spacing: 8) {
                Text("Yapілışı")
                    .font(.playfairDisplay(40, weight: .bold))
                    .foregroundColor(.primary)
                    .padding(.bottom, 8)

                ForEach(Array(editedInstructions.enumerated()), id: \.offset) { index, instruction in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(index + 1).")
                            .font(.custom("Manrope", size: 20).weight(.semibold))
                            .foregroundColor(.primary)

                        TextField("", text: Binding(
                            get: { editedInstructions[index] },
                            set: { editedInstructions[index] = $0 }
                        ), axis: .vertical)
                        .font(.custom("Manrope", size: 20).weight(.semibold))
                        .foregroundColor(.primary)
                        .textFieldStyle(.plain)
                        .submitLabel(.done)
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

    private func handleMoreMenu() {
        showingMoreMenu = true
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

    private func handleStoryTap() {
        print("🔍 Story tapped!")
        print("🔍 Story title: \(recipeData.storyTitle ?? "nil")")
        print("🔍 Story description: \(recipeData.storyDescription ?? "nil")")
        print("🔍 Recipe notes: \(recipeData.recipe.notes ?? "nil")")
        showingNoteDetail = true
    }

    private func handleAction(_ action: RecipeAction) {
        switch action {
        case .save:
            handleSave()
        case .values:
            handleValues()
        case .shopping:
            handleShopping()
        default:
            break
        }
    }

    private func handleSave() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            isSaved.toggle()
        }
        // TODO: Toggle favorite status in Core Data
        print("Save toggled: \(isSaved)")
    }

    private func handleValues() {
        showingNutritionalValues = true
    }

    private func handleShopping() {
        // TODO: Add recipe ingredients to shopping list
        print("Add to shopping list: \(recipeData.recipeName)")
    }

    // MARK: - Photo Generation

    private func generatePhoto() async {
        logger.info("🎬 [DETAIL] Photo generation button tapped for recipe: \(recipeData.recipeName)")

        isGeneratingPhoto = true

        do {
            logger.info("🌐 [DETAIL] Calling photo generation service...")

            // Extract ingredients and directions from recipe
            let ingredients = recipeData.recipe.ingredientsArray
            let directions = recipeData.recipe.instructionsArray

            logger.debug("📋 [DETAIL] Recipe data:")
            logger.debug("  - Name: \(recipeData.recipeName)")
            logger.debug("  - Ingredients: \(ingredients.count)")
            logger.debug("  - Directions: \(directions.count)")

            // Call photo generation service
            let photoService = RecipePhotoGenerationService.shared
            let imageURL = try await photoService.generateRecipePhoto(
                recipeName: recipeData.recipeName,
                ingredients: ingredients,
                directions: directions,
                mealType: "Genel",
                styleType: "Klasik"
            )

            logger.info("✅ [DETAIL] Received imageURL from service")
            logger.debug("🔍 [DETAIL] imageURL prefix: \(imageURL.prefix(60))...")

            // Convert base64 to Data
            if imageURL.hasPrefix("data:image") {
                logger.info("🖼️ [DETAIL] Converting base64 to image data...")
                let base64String = imageURL.replacingOccurrences(of: "data:image/jpeg;base64,", with: "")
                    .replacingOccurrences(of: "data:image/png;base64,", with: "")

                if let imageData = Data(base64Encoded: base64String) {
                    logger.info("✅ [DETAIL] Successfully converted to image data (\(imageData.count) bytes)")
                    generatedImageData = imageData

                    // Save to Core Data
                    logger.info("💾 [DETAIL] Saving image to Core Data...")
                    await MainActor.run {
                        recipeData.recipe.imageData = imageData
                        recipeData.recipe.lastModified = Date()

                        do {
                            try viewContext.save()
                            logger.info("✅ [DETAIL] Image saved to recipe successfully")
                        } catch {
                            logger.error("❌ [DETAIL] Failed to save image to Core Data: \(error.localizedDescription)")
                        }
                    }
                } else {
                    logger.error("❌ [DETAIL] Failed to decode base64 string")
                }
            }

            isGeneratingPhoto = false
            logger.info("🏁 [DETAIL] Photo generation completed")

        } catch {
            logger.error("❌ [DETAIL] Photo generation failed: \(error.localizedDescription)")
            isGeneratingPhoto = false
        }
    }
}

// MARK: - Sheet Modifiers

extension RecipeDetailView {
    func withSheets() -> some View {
        self
            .sheet(isPresented: $showingNutritionalValues) {
                NutritionalValuesView(
                    recipeName: recipeData.recipeName,
                    calories: String(format: "%.0f", recipeData.recipe.calories),
                    carbohydrates: String(format: "%.1f", recipeData.recipe.totalCarbs),
                    fiber: String(format: "%.1f", recipeData.recipe.fiber),
                    sugar: String(format: "%.1f", recipeData.recipe.sugars),
                    protein: String(format: "%.1f", recipeData.recipe.protein),
                    fat: String(format: "%.1f", recipeData.recipe.totalFat),
                    glycemicLoad: String(format: "%.0f", recipeData.recipe.glycemicLoad)
                )
            }
            .sheet(isPresented: $showingNoteDetail) {
                RecipeNoteDetailView(
                    title: recipeData.storyTitle ?? "balli'nin notu",
                    note: recipeData.storyDescription ?? ""
                )
            }
    }
}

// MARK: - Preview

#Preview("Tamarind-Peach Lassi") {
    NavigationStack {
        RecipeDetailView(
            recipeData: .preview()
        )
    }
}

#Preview("Without Story Card") {
    let context = Persistence.PersistenceController(inMemory: true).viewContext
    let recipe = Recipe(context: context)
    recipe.id = UUID()
    recipe.name = "Classic Hummus"
    recipe.servings = 6
    recipe.imageURL = nil
    recipe.dateCreated = Date()
    recipe.lastModified = Date()

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
    }
}

#Preview("Long Description") {
    let context = Persistence.PersistenceController(inMemory: true).viewContext
    let recipe = Recipe(context: context)
    recipe.id = UUID()
    recipe.name = "Homemade Sourdough Bread"
    recipe.servings = 1
    recipe.dateCreated = Date()
    recipe.lastModified = Date()

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
    }
}
