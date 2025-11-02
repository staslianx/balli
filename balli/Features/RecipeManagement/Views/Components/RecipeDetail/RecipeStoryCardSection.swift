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
    let onTap: () -> Void

    var body: some View {
        if hasStory {
            RecipeStoryCard(
                title: "balli'nin tarif analizi",
                description: "Besin değerlerini analiz et",
                thumbnailURL: nil,
                isLoading: isCalculatingNutrition,
                loadingStep: currentLoadingStep,
                loadingProgress: Double(nutritionCalculationProgress)
            ) {
                onTap()
            }
        }
    }
}

// MARK: - Preview

#Preview("Default State") {
    RecipeStoryCardSection(
        hasStory: true,
        isCalculatingNutrition: false,
        currentLoadingStep: nil,
        nutritionCalculationProgress: 0,
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
        onTap: {}
    )
    .padding()
}
