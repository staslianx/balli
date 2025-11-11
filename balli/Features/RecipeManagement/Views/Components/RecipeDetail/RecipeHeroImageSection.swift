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
    @State private var showingShareSheet = false
    @State private var imageToShare: UIImage?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Black background
                Color.black
                    .ignoresSafeArea()

                // Image content - centered with proper constraints
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
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .scaleEffect(scale)
                .offset(offset)
                .gesture(
                    MagnificationGesture(minimumScaleDelta: 0)
                        .onChanged { value in
                            let delta = value / lastScale
                            lastScale = value
                            let newScale = scale * delta

                            // Allow temporary zoom beyond limits (rubber band effect)
                            scale = newScale
                        }
                        .onEnded { _ in
                            lastScale = 1.0

                            // Bounce back to limits with spring animation
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                // Clamp to 1.0 - 4.0 range
                                if scale < 1.0 {
                                    scale = 1.0
                                    offset = .zero
                                    lastOffset = .zero
                                } else if scale > 4.0 {
                                    scale = 4.0
                                }
                            }
                        }
                        .simultaneously(with: DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                // Only allow panning when zoomed in
                                guard scale > 1.0 else { return }

                                let newOffset = CGSize(
                                    width: lastOffset.width + value.translation.width,
                                    height: lastOffset.height + value.translation.height
                                )

                                // Apply offset without hard clamping (allows rubber band)
                                offset = newOffset
                            }
                            .onEnded { _ in
                                // Bounce back if dragged beyond bounds
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                    // Calculate proper bounds based on geometry (not deprecated UIScreen.main)
                                    let screenWidth = geometry.size.width
                                    let screenHeight = geometry.size.height
                                    let scaledWidth = screenWidth * scale
                                    let scaledHeight = screenHeight * scale
                                    let maxOffsetX = max(0, (scaledWidth - screenWidth) / 2)
                                    let maxOffsetY = max(0, (scaledHeight - screenHeight) / 2)

                                    // Clamp to bounds
                                    offset = CGSize(
                                        width: min(max(offset.width, -maxOffsetX), maxOffsetX),
                                        height: min(max(offset.height, -maxOffsetY), maxOffsetY)
                                    )
                                    lastOffset = offset
                                }
                            })
                )
                .onTapGesture(count: 2) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        if scale > 1.0 {
                            scale = 1.0
                            offset = .zero
                            lastOffset = .zero
                        } else {
                            scale = 2.0
                        }
                    }
                }

                // Overlay buttons (not in toolbar to avoid pushing content down)
                VStack {
                    HStack {
                        // Share button
                        Button(action: {
                            // Capture image before showing sheet
                            imageToShare = getShareableUIImage()
                            if imageToShare != nil {
                                showingShareSheet = true
                            }
                        }) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 22, weight: .medium))
                                .foregroundStyle(.white)
                                .padding(12)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        // Close button
                        Button(action: {
                            dismiss()
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 22, weight: .medium))
                                .foregroundStyle(.white)
                                .padding(12)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 60)  // Safe area top

                    Spacer()
                }
            }
        }
        .ignoresSafeArea()
        .sheet(isPresented: $showingShareSheet) {
            if let image = imageToShare {
                ActivityViewController(activityItems: [image])
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

    /// Get shareable UIImage for ActivityViewController
    private func getShareableUIImage() -> UIImage? {
        if let imageData = imageData, let uiImage = UIImage(data: imageData) {
            return uiImage
        }
        // Note: Remote imageURL sharing would require downloading the image first
        // For now, only support local imageData sharing
        return nil
    }
}

// MARK: - Activity View Controller (Share Sheet)

/// SwiftUI wrapper for UIActivityViewController
struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No updates needed
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
