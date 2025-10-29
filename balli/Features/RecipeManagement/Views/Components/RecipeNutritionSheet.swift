//
//  RecipeNutritionSheet.swift
//  balli
//
//  Sheet wrapper for displaying recipe nutrition label
//

import SwiftUI

/// Sheet view displaying recipe nutrition using NutritionLabelView with portion slider
struct RecipeNutritionSheet: View {
    @Environment(\.dismiss) private var dismiss

    let recipeData: RecipeDetailData

    // State for nutrition label bindings
    @State private var productBrand: String = "balli"
    @State private var productName: String = ""
    @State private var calories: String = ""
    @State private var servingSize: String = "100"
    @State private var carbohydrates: String = ""
    @State private var fiber: String = ""
    @State private var sugars: String = ""
    @State private var protein: String = ""
    @State private var fat: String = ""
    @State private var glycemicLoad: String = ""
    @State private var portionGrams: Double = 100.0

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()

                VStack {
                    Spacer()

                    RecipeNutritionLabelView(
                        productBrand: $productBrand,
                        productName: $productName,
                        calories: $calories,
                        servingSize: $servingSize,
                        carbohydrates: $carbohydrates,
                        fiber: $fiber,
                        sugars: $sugars,
                        protein: $protein,
                        fat: $fat,
                        glycemicLoad: $glycemicLoad,
                        portionGrams: $portionGrams,
                        isEditing: false,
                        showIcon: true,
                        iconName: "fork.knife",
                        iconColor: AppTheme.primaryPurple,
                        showingValues: true,
                        valuesAnimationProgress: [:]
                    )

                    Spacer()
                }
            }
            .navigationTitle("Besin Değerleri")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kapat") {
                        dismiss()
                    }
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                }
            }
        }
        .onAppear {
            loadRecipeData()
        }
    }

    private func loadRecipeData() {
        productName = recipeData.recipeName
        calories = String(format: "%.0f", recipeData.recipe.calories)
        carbohydrates = String(format: "%.1f", recipeData.recipe.totalCarbs)
        fiber = String(format: "%.1f", recipeData.recipe.fiber)
        sugars = String(format: "%.1f", recipeData.recipe.sugars)
        protein = String(format: "%.1f", recipeData.recipe.protein)
        fat = String(format: "%.1f", recipeData.recipe.totalFat)
        glycemicLoad = String(format: "%.0f", recipeData.recipe.glycemicLoad)
    }
}

// MARK: - Preview

#Preview("Recipe Nutrition") {
    RecipeNutritionSheet(
        recipeData: RecipeDetailData.preview(
            recipeName: "Izgara Tavuk Salatası"
        )
    )
}
