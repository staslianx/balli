//
//  RecipeStoryCard.swift
//  balli
//
//  Glass morphism card for recipe story links
//  Displays thumbnail, headline, and navigation to related content
//

import SwiftUI

/// Story card with glass effect for related recipe content
struct RecipeStoryCard: View {
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    let description: String?
    let thumbnailURL: String?
    let isLoading: Bool
    let loadingStep: String?
    let loadingProgress: Double
    let onTap: () -> Void

    @State private var isPressed = false
    @State private var pulseOpacity: Double = 1.0

    init(
        title: String,
        description: String? = nil,
        thumbnailURL: String? = nil,
        isLoading: Bool = false,
        loadingStep: String? = nil,
        loadingProgress: Double = 0,
        onTap: @escaping () -> Void
    ) {
        self.title = title
        self.description = description
        self.thumbnailURL = thumbnailURL
        self.isLoading = isLoading
        self.loadingStep = loadingStep
        self.loadingProgress = loadingProgress
        self.onTap = onTap
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Thumbnail
                if let thumbnailURL = thumbnailURL {
                    AsyncImage(url: URL(string: thumbnailURL)) { phase in
                        switch phase {
                        case .empty:
                            placeholderThumbnail
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 50, height: 50)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        case .failure:
                            placeholderThumbnail
                        @unknown default:
                            placeholderThumbnail
                        }
                    }
                } else {
                    placeholderThumbnail
                }

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    // Use Galano font for "balli'nin tarif analizi", otherwise regular text
                    if title == "balli'nin tarif analizi" {
                        Text(title)
                            .font(.custom("GalanoGrotesqueAlt-SemiBold", size: 16))
                            .foregroundColor(.primary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    } else {
                        Text(title)
                            .font(.sfRounded(16, weight: .semiBold))
                            .foregroundColor(.primary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }

                    // Description or loading state
                    if isLoading, let step = loadingStep {
                        // Loading animation
                        VStack(alignment: .leading, spacing: 6) {
                            Text(step)
                                .font(.sfRounded(14, weight: .regular))
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                                .opacity(pulseOpacity)
                                .onAppear {
                                    withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                                        pulseOpacity = 0.5
                                    }
                                }

                            // Progress bar
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    // Background track
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color.secondary.opacity(0.2))
                                        .frame(height: 4)

                                    // Progress fill
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(ThemeColors.primaryPurple)
                                        .frame(width: geometry.size.width * (loadingProgress / 100.0), height: 4)
                                }
                            }
                            .frame(height: 4)
                        }
                    } else if let description = description {
                        Text(description)
                            .font(.sfRounded(14, weight: .regular))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .recipeGlass(tint: .warm, cornerRadius: 30)
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .shadow(
                color: Color.black.opacity(0.08),
                radius: 12,
                x: 0,
                y: 4
            )
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = false
                    }
                }
        )
    }

    private var placeholderThumbnail: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        ThemeColors.primaryPurple,
                        ThemeColors.lightPurple
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 50, height: 50)
            .overlay(
                Image(systemName: "long.text.page.and.pencil.fill")
                    .font(.system(size: 20))
                    .foregroundColor(AppTheme.foregroundOnColor(for: colorScheme).opacity(0.8))
            )
    }
}

// MARK: - Preview

#Preview("Recipe Story Card") {
    ZStack {
        // Purple background
        LinearGradient(
            colors: [
                ThemeColors.primaryPurple,
                ThemeColors.lightPurple
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        VStack(spacing: 24) {
            // With thumbnail
            RecipeStoryCard(
                title: "Pucker Up! Here's Seven Tantalizing Reasons to Embrace Tamarind",
                thumbnailURL: nil
            ) {
                print("Story tapped")
            }
            .padding(.horizontal)

            // Long title
            RecipeStoryCard(
                title: "The Ultimate Guide to Making Perfect Lassi Every Single Time: Expert Tips from Professional Chefs",
                thumbnailURL: nil
            ) {
                print("Story tapped")
            }
            .padding(.horizontal)

            // Short title
            RecipeStoryCard(
                title: "Summer Drink Ideas",
                thumbnailURL: nil
            ) {
                print("Story tapped")
            }
            .padding(.horizontal)

            Spacer()
        }
        .padding(.vertical, 40)
    }
}

#Preview("Different States") {
    ScrollView {
        VStack(spacing: 20) {
            Group {
                Text("With Placeholder Thumbnail")
                    .font(.headline)

                RecipeStoryCard(
                    title: "Amazing Recipe Story with Placeholder",
                    thumbnailURL: nil
                ) {
                    print("Tapped")
                }

                Text("Long Title Example")
                    .font(.headline)
                    .padding(.top)

                RecipeStoryCard(
                    title: "This is a Very Long Title That Will Definitely Span Multiple Lines and Test Our Line Limiting",
                    thumbnailURL: nil
                ) {
                    print("Tapped")
                }

                Text("Short Title Example")
                    .font(.headline)
                    .padding(.top)

                RecipeStoryCard(
                    title: "Quick Tips",
                    thumbnailURL: nil
                ) {
                    print("Tapped")
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
    }
    .background(
        LinearGradient(
            colors: [ThemeColors.primaryPurple.opacity(0.2), ThemeColors.lightPurple.opacity(0.3)],
            startPoint: .top,
            endPoint: .bottom
        )
    )
}
