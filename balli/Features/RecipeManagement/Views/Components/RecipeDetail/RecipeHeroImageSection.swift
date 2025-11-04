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
    @Environment(\.colorScheme) private var colorScheme

    @State private var showingImagePreview = false

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.balli", category: "RecipeHeroImageSection")

    var body: some View {
        // Calculate 50% of true screen height including safe area
        let safeAreaTop = geometry.safeAreaInsets.top
        let screenHeight = geometry.size.height + safeAreaTop
        let imageHeight = screenHeight * 0.5

        ZStack(alignment: .top) {
            // Show generated image if available, otherwise show existing or placeholder
            if let generatedData = generatedImageData,
               let uiImage = UIImage(data: generatedData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geometry.size.width, height: imageHeight)
                    .clipped()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        showingImagePreview = true
                    }
            } else if let imageData = imageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geometry.size.width, height: imageHeight)
                    .clipped()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        showingImagePreview = true
                    }
            } else if let imageURL = imageURL, let url = URL(string: imageURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geometry.size.width, height: imageHeight)
                            .clipped()
                            .contentShape(Rectangle())
                            .onTapGesture {
                                showingImagePreview = true
                            }
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
                .allowsHitTesting(false)

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
        .fullScreenCover(isPresented: $showingImagePreview) {
            RecipeImagePreview(
                imageData: generatedImageData ?? imageData,
                imageURL: imageURL
            )
        }
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

// MARK: - Full Screen Image Preview

/// Full-screen recipe image preview with dismiss gesture
struct RecipeImagePreview: View {
    @Environment(\.dismiss) private var dismiss
    let imageData: Data?
    let imageURL: String?

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var imageSize: CGSize = .zero

    var body: some View {
        NavigationStack {
            ZStack {
                // Black background
                Color.black
                    .ignoresSafeArea()

                // Image content
                GeometryReader { geometry in
                Group {
                    if let imageData = imageData,
                       let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } else if let imageURL = imageURL,
                              let url = URL(string: imageURL) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                            case .failure:
                                placeholderView
                            case .empty:
                                ProgressView()
                                    .tint(.white)
                            @unknown default:
                                placeholderView
                            }
                        }
                    } else {
                        placeholderView
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .background(
                    GeometryReader { imageGeometry in
                        Color.clear.onAppear {
                            imageSize = imageGeometry.size
                        }
                    }
                )
                .scaleEffect(scale)
                .offset(offset)
                .gesture(
                    MagnificationGesture(minimumScaleDelta: 0)
                        .onChanged { value in
                            let delta = value / lastScale
                            lastScale = value
                            let newScale = scale * delta
                            scale = min(max(newScale, 1.0), 4.0)
                        }
                        .onEnded { _ in
                            lastScale = 1.0
                            if scale <= 1.0 {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    scale = 1.0
                                    offset = .zero
                                    lastOffset = .zero
                                }
                            }
                        }
                        .simultaneously(with: scale > 1.0 ? DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let newOffset = CGSize(
                                    width: lastOffset.width + value.translation.width,
                                    height: lastOffset.height + value.translation.height
                                )

                                // Calculate maximum allowed offset based on zoom level
                                let scaledWidth = geometry.size.width * scale
                                let scaledHeight = geometry.size.height * scale
                                let maxOffsetX = max(0, (scaledWidth - geometry.size.width) / 2)
                                let maxOffsetY = max(0, (scaledHeight - geometry.size.height) / 2)

                                // Clamp offset to prevent showing black background
                                offset = CGSize(
                                    width: min(max(newOffset.width, -maxOffsetX), maxOffsetX),
                                    height: min(max(newOffset.height, -maxOffsetY), maxOffsetY)
                                )
                            }
                            .onEnded { _ in
                                lastOffset = offset
                            } : nil)
                )
                .onTapGesture(count: 2) {
                    withAnimation(.spring(response: 0.3)) {
                        if scale > 1.0 {
                            scale = 1.0
                            offset = .zero
                            lastOffset = .zero
                        } else {
                            scale = 2.0
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(.white)
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        }
    }

    private var placeholderView: some View {
        VStack {
            Image(systemName: "photo")
                .font(.system(size: 64))
                .foregroundStyle(.white.opacity(0.5))
            Text("Fotoğraf yüklenemedi")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
                .padding(.top, 8)
        }
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
