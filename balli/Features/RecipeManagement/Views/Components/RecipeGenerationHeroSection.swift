//
//  RecipeGenerationHeroSection.swift
//  balli
//
//  Hero section components for recipe generation view
//  Includes hero image, recipe metadata, and story card with fixed positioning
//

import SwiftUI

// MARK: - Typewriter Text Component

/// Simple typewriter effect for recipe name
struct TypewriterText: View {
    let content: String
    let font: Font
    let fontWeight: Font.Weight
    let foregroundColor: Color

    @State private var displayedText = ""
    @State private var animator = TypewriterAnimator()

    var body: some View {
        Text(displayedText)
            .font(font)
            .fontWeight(fontWeight)
            .foregroundColor(foregroundColor)
            .onAppear {
                // Start animation when view appears
                Task {
                    await animator.enqueueText(content, for: "recipe-name") { displayedContent in
                        await MainActor.run {
                            self.displayedText = displayedContent
                        }
                    } onComplete: {
                        // Animation complete
                    }
                }
            }
            .onChange(of: content) { oldValue, newValue in
                // Reset and animate new content
                if oldValue != newValue {
                    displayedText = ""
                    Task {
                        await animator.cancel("recipe-name")
                        await animator.enqueueText(newValue, for: "recipe-name") { displayedContent in
                            await MainActor.run {
                                self.displayedText = displayedContent
                            }
                        } onComplete: {
                            // Animation complete
                        }
                    }
                }
            }
    }
}

// MARK: - Hero Image Section

struct RecipeGenerationHeroImage: View {
    let recipeName: String
    let preparedImage: UIImage?
    let isGeneratingPhoto: Bool
    let recipeContent: String
    let geometry: GeometryProxy
    let onGeneratePhoto: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        // Calculate 50% of true screen height including safe area
        let safeAreaTop = geometry.safeAreaInsets.top
        let screenHeight = geometry.size.height + safeAreaTop
        let imageHeight = max(screenHeight * 0.5, 350)

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
                        Image(systemName: "spatial.capture")
                            .font(.system(size: 64, weight: .light))
                            .foregroundStyle(AppTheme.foregroundOnColor(for: colorScheme).opacity(0.8))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(height: imageHeight)
    }
}

// MARK: - Time Pill Component

struct RecipeTimePill: View {
    let icon: String
    let time: Int
    let label: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
            Text("\(time) dk")
                .font(.system(size: 16, weight: .semibold))
                .fixedSize()
        }
        .foregroundColor(AppTheme.foregroundOnColor(for: colorScheme))
    }
}

// MARK: - Recipe Metadata Section

struct RecipeGenerationMetadata: View {
    let recipeName: String
    let recipeContent: String
    let geometry: GeometryProxy
    @Binding var editableRecipeName: String
    let isManualRecipe: Bool
    let prepTime: Int?
    let cookTime: Int?
    @Environment(\.colorScheme) private var colorScheme
    @FocusState.Binding var isNameFieldFocused: Bool

    var body: some View{
        // Calculate consistent hero image height (50% of screen including safe area)
        let safeAreaTop = geometry.safeAreaInsets.top
        let screenHeight = geometry.size.height + safeAreaTop
        let heroImageHeight = max(screenHeight * 0.5, 350)

        VStack(spacing: 0) {
            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 8) {
                // Logo - Shows balli logo if AI-generated recipe (same size in both light and dark mode)
                if !recipeContent.isEmpty {
                    Image("balli-text-logo-dark")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 40)
                        .offset(x: -9, y: 4)
                }

                // Recipe title - editable for manual recipes, display-only for AI-generated
                if isManualRecipe {
                    TextField("Tarif ismi (zorunlu)", text: $editableRecipeName)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.foregroundOnColor(for: colorScheme))
                        .focused($isNameFieldFocused)
                        .shadow(color: Color.primary.opacity(0.2), radius: 4, x: 0, y: 2)
                        .submitLabel(.done)
                } else if !recipeName.isEmpty {
                    TypewriterText(
                        content: recipeName,
                        font: .custom("Playfair Display", size: 34),
                        fontWeight: .bold,
                        foregroundColor: AppTheme.foregroundOnColor(for: colorScheme)
                    )
                    .shadow(color: Color.primary.opacity(0.2), radius: 4, x: 0, y: 2)
                } else {
                    Text("Tarif ismi")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.foregroundOnColor(for: colorScheme).opacity(0.3))
                        .shadow(color: Color.primary.opacity(0.2), radius: 4, x: 0, y: 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.bottom, 12) // Minimum gap between name and story card
        }
        .frame(height: heroImageHeight - 49) // Ends where story card begins
    }
}

// MARK: - Story Card Container

struct RecipeGenerationStoryCard: View {
    let storyCardTitle: String
    let isCalculatingNutrition: Bool
    let currentLoadingStep: String?
    let nutritionCalculationProgress: Int
    let hasNutritionData: Bool
    let geometry: GeometryProxy
    let onTap: () -> Void

    private var nutritionButtonText: String {
        hasNutritionData ? "Besin değerlerini görüntüle" : "Besin değerlerini analiz et"
    }

    var body: some View {
        // Calculate consistent hero image height (50% of screen including safe area)
        let safeAreaTop = geometry.safeAreaInsets.top
        let screenHeight = geometry.size.height + safeAreaTop
        let heroImageHeight = max(screenHeight * 0.5, 350)

        VStack(spacing: 0) {
            Spacer()
                .frame(height: heroImageHeight - 49)

            RecipeStoryCard(
                title: storyCardTitle,
                description: nutritionButtonText,
                thumbnailURL: nil,
                isLoading: isCalculatingNutrition,
                loadingStep: currentLoadingStep,
                loadingProgress: Double(nutritionCalculationProgress),
                isComplete: hasNutritionData
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
    let hasNutritionData: Bool
    let geometry: GeometryProxy
    @Binding var editableRecipeName: String
    let isManualRecipe: Bool
    let prepTime: Int?
    let cookTime: Int?
    @FocusState.Binding var isNameFieldFocused: Bool
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
                geometry: geometry,
                editableRecipeName: $editableRecipeName,
                isManualRecipe: isManualRecipe,
                prepTime: prepTime,
                cookTime: cookTime,
                isNameFieldFocused: $isNameFieldFocused
            )

            // Story card - positioned absolutely at fixed offset
            RecipeGenerationStoryCard(
                storyCardTitle: storyCardTitle,
                isCalculatingNutrition: isCalculatingNutrition,
                currentLoadingStep: currentLoadingStep,
                nutritionCalculationProgress: nutritionCalculationProgress,
                hasNutritionData: hasNutritionData,
                geometry: geometry,
                onTap: onStoryCardTap
            )
        }
    }
}
