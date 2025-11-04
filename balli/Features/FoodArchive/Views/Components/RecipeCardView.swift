//
//  RecipeCardView.swift
//  balli
//
//  Recipe/food item card component for Ardiye view
//  Swift 6 strict concurrency compliant
//

import SwiftUI

struct RecipeCardView: View {
    let item: ArdiyeItem
    let onRecipeTap: (Recipe) -> Void
    let onFoodItemTap: (FoodItem) -> Void

    var body: some View {
        Group {
            if item.isRecipe, let recipe = item.recipe {
                // Recipe - Open as full screen modal
                Button(action: {
                    onRecipeTap(recipe)
                }) {
                    cardContent
                }
                .buttonStyle(CardButtonStyle())
            } else if let foodItem = item.foodItem {
                // Scanned packaged food product - Open product detail view
                Button(action: {
                    onFoodItemTap(foodItem)
                }) {
                    cardContent
                }
                .buttonStyle(CardButtonStyle())
            } else {
                // Fallback for items without proper entity reference
                cardContent
            }
        }
    }

    @ViewBuilder
    private var cardContent: some View {
        HStack(spacing: 0) {
            // Left side - Text content
            VStack(alignment: .leading, spacing: 8) {
                // Recipe name
                Text(item.name)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundColor(.primary)

                Spacer()

                // Serving size
                Text("\(Int(item.servingSize)) \(item.servingUnit)")
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(.primary.opacity(0.7))

                // Carb amount
                Text(String(format: "%.1f gr Karb.", item.totalCarbs))
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.primary)
            }
            .padding(.vertical, 16)
            .padding(.leading, 16)
            .frame(maxWidth: .infinity, alignment: .leading)

            // Right side - Photo (if recipe exists)
            if let recipe = item.recipe {
                ZStack(alignment: .bottomTrailing) {
                    recipePhoto(for: recipe)

                    // Yellow star on bottom right if favorited
                    if recipe.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.system(size: ResponsiveDesign.Font.scaledSize(20), weight: .semibold))
                            .foregroundColor(Color(red: 1, green: 0.85, blue: 0, opacity: 1))
                            .padding(.bottom, 16)
                            .padding(.trailing, 16)
                    }
                }
            }
        }
        .frame(height: 140)
        .background(.clear)
        .glassEffect(
            .regular.interactive(),
            in: RoundedRectangle(cornerRadius: 32, style: .continuous)
        )
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: ResponsiveDesign.height(8), x: 0, y: ResponsiveDesign.height(4))
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func recipePhoto(for recipe: Recipe) -> some View {
        if let imageData = recipe.imageData, let uiImage = UIImage(data: imageData) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 140, height: 140)
                .clipShape(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                )
        } else {
            // Placeholder for recipes without photos
            ZStack {
                Color.secondary.opacity(0.1)
                Image(systemName: "photo")
                    .font(.system(size: 32))
                    .foregroundStyle(.secondary.opacity(0.3))
            }
            .frame(width: 140, height: 140)
            .clipShape(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
            )
        }
    }
}
