//
//  RecipeHeroImageSection.swift
//  balli
//
//  Hero image component for RecipeDetailView
//  Handles image display, generation, and loading states
//

import SwiftUI
import OSLog

/// Hero image section with photo generation capability
struct RecipeHeroImageSection: View {
    let geometry: GeometryProxy
    let imageData: Data?
    let imageURL: String?
    let generatedImageData: Data?
    let isGeneratingPhoto: Bool
    let onGeneratePhoto: () async -> Void

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.balli", category: "RecipeHeroImageSection")

    var body: some View {
        let imageHeight = geometry.size.height * 0.5

        ZStack(alignment: .top) {
            // Show generated image if available, otherwise show existing or placeholder
            if let generatedData = generatedImageData,
               let uiImage = UIImage(data: generatedData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geometry.size.width, height: imageHeight)
                    .clipped()
            } else if let imageData = imageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geometry.size.width, height: imageHeight)
                    .clipped()
            } else if let imageURL = imageURL, let url = URL(string: imageURL) {
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

            // Photo generation button or loading indicator (only if no image exists)
            if imageData == nil && imageURL == nil && generatedImageData == nil {
                if isGeneratingPhoto {
                    // Show pulsing icon while generating
                    PulsingPhotoIcon()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Show photo generation button
                    Button(action: {
                        Task {
                            await onGeneratePhoto()
                        }
                    }) {
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

    @ViewBuilder
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
}

// MARK: - Preview

#Preview("With Image Data") {
    GeometryReader { geometry in
        RecipeHeroImageSection(
            geometry: geometry,
            imageData: nil,
            imageURL: "https://picsum.photos/400/300",
            generatedImageData: nil,
            isGeneratingPhoto: false,
            onGeneratePhoto: {}
        )
    }
}

#Preview("Placeholder - No Image") {
    GeometryReader { geometry in
        RecipeHeroImageSection(
            geometry: geometry,
            imageData: nil,
            imageURL: nil,
            generatedImageData: nil,
            isGeneratingPhoto: false,
            onGeneratePhoto: {}
        )
    }
}

#Preview("Generating Photo") {
    GeometryReader { geometry in
        RecipeHeroImageSection(
            geometry: geometry,
            imageData: nil,
            imageURL: nil,
            generatedImageData: nil,
            isGeneratingPhoto: true,
            onGeneratePhoto: {}
        )
    }
}
