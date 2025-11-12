//
//  RecipeContentSection.swift
//  balli
//
//  Recipe content component displaying ingredients and instructions
//  Supports both read and edit modes with markdown rendering
//

import SwiftUI
import OSLog

/// Recipe content section with ingredients and instructions
struct RecipeContentSection: View {
    let recipe: Recipe
    let isEditing: Bool
    @Binding var editedIngredients: [String]
    @Binding var editedInstructions: [String]

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.balli", category: "RecipeContentSection")

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isEditing {
                // Edit mode: Show editable text fields
                editableRecipeContent
            } else {
                // Read mode: Show markdown
                let markdownContent = recipe.recipeContent ?? buildMarkdownContent()

                if !markdownContent.isEmpty {
                    MarkdownText(
                        content: markdownContent,
                        fontSize: 20,
                        enableSelection: true,
                        sourceCount: 0,
                        sources: [],
                        headerFontSize: 20 * 2.0,
                        fontName: "Manrope",
                        headerFontName: "PlayfairDisplay",
                        skipFirstHeading: true  // Recipe name shown in hero section
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

    // MARK: - Editable Content

    @ViewBuilder
    private var editableRecipeContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Editable Ingredients Section
            VStack(alignment: .leading, spacing: 12) {
                Text("Malzemeler")
                    .font(.custom("Playfair Display", size: 33))
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .padding(.bottom, 0)

                ForEach(Array(editedIngredients.enumerated()), id: \.offset) { index, ingredient in
                    HStack(alignment: .top, spacing: 6) {
                        Text("•")
                            .font(.custom("Manrope", size: 20).weight(.heavy))
                            .foregroundStyle(AppTheme.primaryPurple)
                            .frame(width: 14, alignment: .trailing)
                            .offset(x: -20)

                        TextField("", text: $editedIngredients[index], axis: .vertical)
                            .font(.custom("Manrope-Medium", size: 20))
                            .foregroundColor(.primary)
                            .textFieldStyle(.plain)
                            .lineLimit(nil)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.leading, 20)
                }
            }
            .padding(.vertical, 2)
            .padding(.bottom, 24)

            // Editable Instructions Section
            VStack(alignment: .leading, spacing: 12) {
                Text("Yapılışı")
                    .font(.custom("Playfair Display", size: 33))
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .padding(.bottom, 0)

                ForEach(Array(editedInstructions.enumerated()), id: \.offset) { index, instruction in
                    HStack(alignment: .top, spacing: 6) {
                        Text("\(index + 1).")
                            .font(.custom("Manrope", size: 20).weight(.bold))
                            .foregroundStyle(AppTheme.primaryPurple)
                            .frame(width: 24, alignment: .trailing)
                            .offset(x: -30)

                        TextField("", text: $editedInstructions[index], axis: .vertical)
                            .font(.custom("Manrope-Medium", size: 20))
                            .foregroundColor(.primary)
                            .textFieldStyle(.plain)
                            .lineLimit(nil)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.leading, 30)
                }
            }
            .padding(.vertical, 2)
        }
    }

    // MARK: - Helper Functions

    private func buildMarkdownContent() -> String {
        var markdown = ""

        // Add ingredients section
        let ingredients = recipe.ingredientsArray
        if !ingredients.isEmpty {
            markdown += "## Malzemeler\n\n"
            for ingredient in ingredients {
                markdown += "- \(ingredient)\n"
            }
            markdown += "\n"
        }

        // Add instructions section
        let instructions = recipe.instructionsArray
        if !instructions.isEmpty {
            markdown += "## Yapılışı\n\n"
            for (index, instruction) in instructions.enumerated() {
                markdown += "\(index + 1). \(instruction)\n"
            }
        }

        return markdown
    }
}

// MARK: - Preview

#Preview("Read Mode - Full Recipe") {
    let controller = Persistence.PersistenceController(inMemory: true)
    let context = controller.viewContext
    let recipe = Recipe(context: context)

    recipe.id = UUID()
    recipe.name = "Classic Hummus"
    recipe.servings = 6
    recipe.dateCreated = Date()
    recipe.lastModified = Date()
    recipe.source = "manual"
    recipe.isVerified = false
    recipe.isFavorite = false
    recipe.timesCooked = 0
    recipe.userRating = 0
    recipe.calories = 0
    recipe.totalCarbs = 0
    recipe.fiber = 0
    recipe.sugars = 0
    recipe.protein = 0
    recipe.totalFat = 0
    recipe.glycemicLoad = 0
    recipe.prepTime = 10
    recipe.cookTime = 0
    recipe.ingredients = [
        "1 can chickpeas",
        "1/4 cup tahini",
        "2 tbsp lemon juice",
        "2 cloves garlic",
        "2 tbsp olive oil",
        "Salt to taste"
    ] as NSArray
    recipe.instructions = [
        "Drain chickpeas",
        "Blend all ingredients",
        "Adjust seasoning",
        "Serve with olive oil drizzle"
    ] as NSArray

    return ScrollView {
        RecipeContentSection(
            recipe: recipe,
            isEditing: false,
            editedIngredients: .constant([]),
            editedInstructions: .constant([])
        )
        .padding()
    }
}

#Preview("Edit Mode") {
    let controller = Persistence.PersistenceController(inMemory: true)
    let context = controller.viewContext
    let recipe = Recipe(context: context)

    recipe.id = UUID()
    recipe.name = "Classic Hummus"
    recipe.servings = 6
    recipe.dateCreated = Date()
    recipe.lastModified = Date()
    recipe.source = "manual"
    recipe.isVerified = false
    recipe.isFavorite = false
    recipe.timesCooked = 0
    recipe.userRating = 0
    recipe.calories = 0
    recipe.totalCarbs = 0
    recipe.fiber = 0
    recipe.sugars = 0
    recipe.protein = 0
    recipe.totalFat = 0
    recipe.glycemicLoad = 0
    recipe.prepTime = 10
    recipe.cookTime = 0

    return ScrollView {
        RecipeContentSection(
            recipe: recipe,
            isEditing: true,
            editedIngredients: .constant([
                "1 can chickpeas",
                "1/4 cup tahini",
                "2 tbsp lemon juice"
            ]),
            editedInstructions: .constant([
                "Drain chickpeas",
                "Blend all ingredients"
            ])
        )
        .padding()
    }
}

#Preview("Empty Content") {
    let controller = Persistence.PersistenceController(inMemory: true)
    let context = controller.viewContext
    let recipe = Recipe(context: context)

    recipe.id = UUID()
    recipe.name = "Empty Recipe"
    recipe.servings = 1
    recipe.dateCreated = Date()
    recipe.lastModified = Date()
    recipe.source = "manual"
    recipe.isVerified = false
    recipe.isFavorite = false
    recipe.timesCooked = 0
    recipe.userRating = 0
    recipe.calories = 0
    recipe.totalCarbs = 0
    recipe.fiber = 0
    recipe.sugars = 0
    recipe.protein = 0
    recipe.totalFat = 0
    recipe.glycemicLoad = 0
    recipe.prepTime = 0
    recipe.cookTime = 0

    return ScrollView {
        RecipeContentSection(
            recipe: recipe,
            isEditing: false,
            editedIngredients: .constant([]),
            editedInstructions: .constant([])
        )
        .padding()
    }
}
