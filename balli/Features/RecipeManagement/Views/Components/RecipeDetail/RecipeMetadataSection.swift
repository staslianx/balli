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
        VStack(alignment: .leading, spacing: 0) {
            // AI-generated: Show balli logo
            // Manual: Show user name in Galano Alt Semibold white
            if recipeSource == RecipeConstants.Source.ai {
                // AI-generated recipe - show balli logo (same size in both light and dark mode)
                Image("balli-text-logo-dark")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 40)
                    .offset(x:-9, y:4)
            } else if let author = author {
                // Manual recipe - show user name in Galano Alt Semibold white
                Text(author)
                    .font(.custom("GalanoGrotesqueAlt-SemiBold", size: 17))
                    .foregroundColor(.white)
            }

            // Recipe title - conditionally editable
            if isEditing {
                TextField("", text: $editedName, axis: .vertical)
                    .font(.custom("Playfair Display", size: 36))
                    .fontWeight(.bold)
                    .lineSpacing(0)
                    .foregroundColor(AppTheme.foregroundOnColor(for: colorScheme))
                    .textFieldStyle(.plain)
                    .shadow(color: Color.primary.opacity(0.2), radius: 4, x: 0, y: 2)
            } else {
                Text(recipeName)
                    .font(.custom("Playfair Display", size: 36))
                    .fontWeight(.bold)
                    .lineSpacing(0)
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
