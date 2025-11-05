//
//  RecipeStoryCardSection.swift
//  balli
//
//  Story card component for nutrition analysis
//  Shows loading states and tappable card
//

import SwiftUI

/// Story card section wrapper for nutrition analysis
struct RecipeStoryCardSection: View {
    let hasStory: Bool
    let isCalculatingNutrition: Bool
    let currentLoadingStep: String?
    let nutritionCalculationProgress: Int
    let hasNutritionData: Bool
    let onTap: () -> Void

    private var nutritionButtonText: String {
        hasNutritionData ? "Besin değerlerini görüntüle" : "Besin değerlerini analiz et"
    }

    var body: some View {
        if hasStory {
            RecipeStoryCard(
                title: "balli'nin tarif analizi",
                description: nutritionButtonText,
                thumbnailURL: nil,
                isLoading: isCalculatingNutrition,
                loadingStep: currentLoadingStep,
                loadingProgress: Double(nutritionCalculationProgress),
                isComplete: hasNutritionData
            ) {
                onTap()
            }
        }
    }
}

// MARK: - Preview

#Preview("Default State - No Nutrition Data") {
    RecipeStoryCardSection(
        hasStory: true,
        isCalculatingNutrition: false,
        currentLoadingStep: nil,
        nutritionCalculationProgress: 0,
        hasNutritionData: false,
        onTap: {}
    )
    .padding()
}

#Preview("Default State - With Nutrition Data") {
    RecipeStoryCardSection(
        hasStory: true,
        isCalculatingNutrition: false,
        currentLoadingStep: nil,
        nutritionCalculationProgress: 0,
        hasNutritionData: true,
        onTap: {}
    )
    .padding()
}

#Preview("Loading - Step 1") {
    RecipeStoryCardSection(
        hasStory: true,
        isCalculatingNutrition: true,
        currentLoadingStep: "Tarife tekrar bakıyorum",
        nutritionCalculationProgress: 6,
        hasNutritionData: false,
        onTap: {}
    )
    .padding()
}

#Preview("Loading - Step 5") {
    RecipeStoryCardSection(
        hasStory: true,
        isCalculatingNutrition: true,
        currentLoadingStep: "Pişirme etkilerini belirliyorum",
        nutritionCalculationProgress: 48,
        hasNutritionData: false,
        onTap: {}
    )
    .padding()
}

#Preview("Loading - Final Step") {
    RecipeStoryCardSection(
        hasStory: true,
        isCalculatingNutrition: true,
        currentLoadingStep: "Sağlamasını yapıyorum",
        nutritionCalculationProgress: 100,
        hasNutritionData: false,
        onTap: {}
    )
    .padding()
}

#Preview("No Story Card") {
    RecipeStoryCardSection(
        hasStory: false,
        isCalculatingNutrition: false,
        currentLoadingStep: nil,
        nutritionCalculationProgress: 0,
        hasNutritionData: false,
        onTap: {}
    )
    .padding()
}
