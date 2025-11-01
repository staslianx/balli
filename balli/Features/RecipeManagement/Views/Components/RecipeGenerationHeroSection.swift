//
//  RecipeGenerationHeroSection.swift
//  balli
//
//  Hero section components for recipe generation view
//  Includes hero image, recipe metadata, and story card with fixed positioning
//

import SwiftUI

// MARK: - Hero Image Section

struct RecipeGenerationHeroImage: View {
    let recipeName: String
    let preparedImage: UIImage?
    let isGeneratingPhoto: Bool
    let recipeContent: String
    let geometry: GeometryProxy
    let onGeneratePhoto: () -> Void

    var body: some View {
        let imageHeight = max(UIScreen.main.bounds.height * 0.5, 350)

        ZStack(alignment: .top) {
            // Show generated image if available, otherwise show placeholder gradient
            if let image = preparedImage {
                // Display generated image
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geometry.size.width, height: imageHeight)
                    .clipped()

                // Dark gradient overlay for text readability
                RecipeImageGradient.textOverlay
                    .frame(width: geometry.size.width, height: imageHeight)
            } else {
                // Placeholder gradient (purple like recipe detail view)
                LinearGradient(
                    colors: [
                        ThemeColors.primaryPurple,
                        ThemeColors.lightPurple
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(width: geometry.size.width, height: imageHeight)

                // Dark gradient overlay
                RecipeImageGradient.textOverlay
                    .frame(width: geometry.size.width, height: imageHeight)
            }

            // Photo generation button or loading indicator
            if !recipeName.isEmpty {
                if isGeneratingPhoto {
                    // Show pulsing spatial.capture icon while generating
                    PulsingPhotoIcon()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if preparedImage == nil {
                    // Show photo generation button if no image yet
                    Button(action: onGeneratePhoto) {
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
        .frame(height: imageHeight)
    }
}

// MARK: - Recipe Metadata Section

struct RecipeGenerationMetadata: View {
    let recipeName: String
    let recipeContent: String
    let geometry: GeometryProxy

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 12) {
                // Logo - Shows balli logo if AI-generated recipe
                if !recipeContent.isEmpty {
                    Image("balli-text-logo-dark")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 40)
                }

                // Recipe title
                if !recipeName.isEmpty {
                    Text(recipeName)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                } else {
                    Text("Tarif ismi")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.3))
                        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.bottom, 24) // Minimum gap between name and story card
        }
        .frame(height: max(UIScreen.main.bounds.height * 0.5, 350) - 49) // Ends where story card begins
    }
}

// MARK: - Story Card Container

struct RecipeGenerationStoryCard: View {
    let storyCardTitle: String
    let isCalculatingNutrition: Bool
    let currentLoadingStep: String?
    let nutritionCalculationProgress: Int
    let geometry: GeometryProxy
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: max(UIScreen.main.bounds.height * 0.5, 350) - 49)

            RecipeStoryCard(
                title: storyCardTitle,
                description: "Besin değeri analizi",
                thumbnailURL: nil,
                isLoading: isCalculatingNutrition,
                loadingStep: currentLoadingStep,
                loadingProgress: Double(nutritionCalculationProgress)
            ) {
                onTap()
            }
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - Complete Hero Section

/// Complete hero section including image, metadata, and story card with proper layering
struct RecipeGenerationCompleteHero: View {
    let recipeName: String
    let preparedImage: UIImage?
    let isGeneratingPhoto: Bool
    let recipeContent: String
    let storyCardTitle: String
    let isCalculatingNutrition: Bool
    let currentLoadingStep: String?
    let nutritionCalculationProgress: Int
    let geometry: GeometryProxy
    let onGeneratePhoto: () -> Void
    let onStoryCardTap: () -> Void

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                // Hero image placeholder
                RecipeGenerationHeroImage(
                    recipeName: recipeName,
                    preparedImage: preparedImage,
                    isGeneratingPhoto: isGeneratingPhoto,
                    recipeContent: recipeContent,
                    geometry: geometry,
                    onGeneratePhoto: onGeneratePhoto
                )

                // Spacer to accommodate story card overlap
                // Story card is 82px tall + 16px padding = 98px
                // We want it half-over image, so subtract half its height
                Spacer()
                    .frame(height: 49)

                // Content placeholder (managed by parent)
                Color.clear
                    .frame(height: 0)
            }

            // Recipe metadata - positioned absolutely over hero image
            RecipeGenerationMetadata(
                recipeName: recipeName,
                recipeContent: recipeContent,
                geometry: geometry
            )

            // Story card - positioned absolutely at fixed offset
            RecipeGenerationStoryCard(
                storyCardTitle: storyCardTitle,
                isCalculatingNutrition: isCalculatingNutrition,
                currentLoadingStep: currentLoadingStep,
                nutritionCalculationProgress: nutritionCalculationProgress,
                geometry: geometry,
                onTap: onStoryCardTap
            )
        }
    }
}
