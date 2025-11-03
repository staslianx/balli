//
//  RecipeMetadataSection.swift
//  balli
//
//  Recipe metadata component displaying logo, author, and title
//  Supports inline editing mode
//

import SwiftUI

/// Recipe metadata section with logo, author, and title
struct RecipeMetadataSection: View {
    let recipeSource: String
    let author: String?
    let recipeName: String
    let isEditing: Bool
    @Binding var editedName: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Balli logo for AI-generated recipes
            if recipeSource == RecipeConstants.Source.ai {
                Image("balli-text-logo-dark")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 40)
            }

            // Author
            if let author = author {
                Text(author)
                    .font(.sfRounded(17, weight: .regular))
                    .foregroundColor(AppTheme.foregroundOnColor(for: colorScheme).opacity(0.95))
            }

            // Recipe title - conditionally editable
            if isEditing {
                TextField("", text: $editedName, axis: .vertical)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.foregroundOnColor(for: colorScheme))
                    .textFieldStyle(.plain)
                    .shadow(color: Color.primary.opacity(0.2), radius: 4, x: 0, y: 2)
            } else {
                Text(recipeName)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.foregroundOnColor(for: colorScheme))
                    .shadow(color: Color.primary.opacity(0.2), radius: 4, x: 0, y: 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Preview

#Preview("AI Recipe with Author") {
    ZStack {
        Color.black
        RecipeMetadataSection(
            recipeSource: RecipeConstants.Source.ai,
            author: "Chef Maria",
            recipeName: "Tamarind-Peach Summer Lassi",
            isEditing: false,
            editedName: .constant("")
        )
        .padding()
    }
}

#Preview("Manual Recipe") {
    ZStack {
        Color.black
        RecipeMetadataSection(
            recipeSource: "manual",
            author: "John Smith",
            recipeName: "Classic Hummus",
            isEditing: false,
            editedName: .constant("")
        )
        .padding()
    }
}

#Preview("Edit Mode") {
    ZStack {
        Color.black
        RecipeMetadataSection(
            recipeSource: RecipeConstants.Source.ai,
            author: "Chef Maria",
            recipeName: "Original Title",
            isEditing: true,
            editedName: .constant("Editing this title...")
        )
        .padding()
    }
}

#Preview("Long Title") {
    ZStack {
        Color.black
        RecipeMetadataSection(
            recipeSource: RecipeConstants.Source.ai,
            author: "Chef Maria Gonzalez",
            recipeName: "Authentic Mediterranean Slow-Roasted Lamb Shoulder with Rosemary, Garlic, and Lemon",
            isEditing: false,
            editedName: .constant("")
        )
        .padding()
    }
}
