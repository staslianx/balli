//
//  RecipeDetailView.swift
//  balli
//
//  iOS 26 recipe detail screen with hero image and glass UI
//  Matches Apple News+ recipe presentation style
//

import SwiftUI

/// Full-screen recipe detail with hero image and interactive elements
struct RecipeDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let recipeData: RecipeDetailData

    @State private var isSaved = false
    @State private var showingShareSheet = false
    @State private var showingNutritionalValues = false
    @State private var showingNoteDetail = false

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
            .presentationDetents([.fraction(0.5)])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Hero Image Section

    private var heroImageSection: some View {
        GeometryReader { geometry in
            let imageHeight = UIScreen.main.bounds.height * 0.5

            ZStack(alignment: .top) {
                if let imageData = recipeData.imageData,
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
                // Back button
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                }
                .recipeCircularGlass(size: 44, tint: .warm)

                Spacer()

                // More menu button
                Button(action: handleMoreMenu) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                }
                .recipeCircularGlass(size: 44, tint: .warm)
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

            // Recipe title
            Text(recipeData.recipeName)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
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
            // Use stored markdown content if available, otherwise build from arrays
            let markdownContent = recipeData.recipe.recipeContent ?? buildMarkdownContent()

            if !markdownContent.isEmpty {
                MarkdownText(
                    content: markdownContent,
                    fontSize: 20,  // Increased from 17 to 20
                    enableSelection: true,
                    sourceCount: 0,
                    sources: [],
                    headerFontSize: 20 * 2.0,  // Proportionally bigger headers (40pt)
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
        // TODO: Show action sheet with options
        print("More menu tapped")
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
