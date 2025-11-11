//
//  RecipeGlassStyle.swift
//  balli
//
//  iOS 26 Liquid Glass modifiers with warm golden tint for recipe views
//  Provides the warm, inviting aesthetic matching recipe photography
//

import SwiftUI

/// Warm color palette for recipe glass effects
enum RecipeGlassTint {
    case warm        // Golden/amber tint for general use
    case neutral     // Subtle warm white
    case transparent // Clear glass with minimal tint
    case purple      // balli's signature purple tint (0.18 opacity)

    var color: Color {
        switch self {
        case .warm:
            return ThemeColors.primaryPurple.opacity(0.20)
        case .neutral:
            return Color.white.opacity(0.15)
        case .transparent:
            return Color.white.opacity(0.05)
        case .purple:
            return AppTheme.primaryPurple.opacity(0.20)
        }
    }
}

/// Glass effect modifier with warm recipe aesthetic
struct RecipeGlassEffect: ViewModifier {
    let tint: RecipeGlassTint
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(tint.color)
            )
            .glassEffect(
                .regular.interactive(),
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
    }
}

/// Circular glass button for recipe navigation
struct RecipeCircularGlass: ViewModifier {
    let size: CGFloat
    let tint: RecipeGlassTint

    func body(content: Content) -> some View {
        content
            .frame(width: size, height: size)
            .background(
                Circle()
                    .fill(tint.color)
            )
            .glassEffect(.regular.interactive(), in: Circle())
            .overlay(
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.3),
                                Color.white.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            )
    }
}

// MARK: - View Extensions

extension View {
    /// Apply recipe-specific glass effect with warm tint
    /// Default corner radius: 28 for smooth, rounded cards
    func recipeGlass(
        tint: RecipeGlassTint = .warm,
        cornerRadius: CGFloat = 28
    ) -> some View {
        modifier(RecipeGlassEffect(tint: tint, cornerRadius: cornerRadius))
    }

    /// Apply circular glass button style for recipe nav
    func recipeCircularGlass(
        size: CGFloat = 44,
        tint: RecipeGlassTint = .warm
    ) -> some View {
        modifier(RecipeCircularGlass(size: size, tint: tint))
    }

    /// Apply balli's signature colored glass effect (purple tint)
    /// Default corner radius: 28 for smooth, rounded cards
    func balliColoredGlass(cornerRadius: CGFloat = 28) -> some View {
        modifier(RecipeGlassEffect(tint: .warm, cornerRadius: cornerRadius))
    }

    /// Apply circular glass button style for general app use (with purple tint)
    func balliCircularGlass(size: CGFloat = 32) -> some View {
        modifier(RecipeCircularGlass(size: size, tint: .warm))
    }

    /// Apply balli's signature purple-tinted glass effect with edge glow
    /// Uses AppTheme.primaryPurple.opacity(0.20) for tint for consistent branding
    /// Default corner radius: 28 for smooth, rounded appearance
    /// Includes subtle purple glow around edges for depth and shine
    func balliTintedGlass(cornerRadius: CGFloat = 28) -> some View {
        modifier(RecipeGlassEffect(tint: .purple, cornerRadius: cornerRadius))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                AppTheme.primaryPurple.opacity(0.4),
                                AppTheme.primaryPurple.opacity(0.2),
                                AppTheme.primaryPurple.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                    .blur(radius: 0.5)
            )
    }
}

// MARK: - Gradient Overlays for Text Readability

struct RecipeImageGradient {
    /// Dark gradient for text readability over recipe images
    static var textOverlay: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0.0),
                .init(color: .black.opacity(0.1), location: 0.2),
                .init(color: .black.opacity(0.25), location: 0.5),
                .init(color: .black.opacity(0.45), location: 0.85),
                .init(color: .black.opacity(0.6), location: 1.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Subtle warm glow for recipe cards
    static var warmGlow: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 1.0, green: 0.95, blue: 0.7, opacity: 0.2),
                Color(red: 1.0, green: 0.9, blue: 0.6, opacity: 0.3)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Preview

#Preview("Recipe Glass Styles") {
    ZStack {
        // Background image simulation
        Color.orange.opacity(0.3)
            .ignoresSafeArea()

        VStack(spacing: 24) {
            // Circular buttons
            HStack(spacing: 16) {
                Button(action: {}) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.primary)
                }
                .recipeCircularGlass(size: 44, tint: .warm)

                Button(action: {}) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.primary)
                }
                .recipeCircularGlass(size: 44, tint: .warm)
            }

            // Card with warm glass
            VStack(alignment: .leading, spacing: 8) {
                Text("balli'nin Notu")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)

                Text("Sample Recipe Card")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .recipeGlass(tint: .warm, cornerRadius: 20)

            // Action buttons with glass
            HStack(spacing: 12) {
                ForEach(["fork.knife", "bookmark", "square.and.arrow.up"], id: \.self) { icon in
                    VStack(spacing: 4) {
                        Image(systemName: icon)
                            .font(.system(size: 20))
                        Text("Action")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .recipeGlass(tint: .warm, cornerRadius: 12)
                }
            }

            Spacer()
        }
        .padding()
    }
}
