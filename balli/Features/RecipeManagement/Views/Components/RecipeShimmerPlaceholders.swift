//
//  RecipeShimmerPlaceholders.swift
//  balli
//
//  Shimmer placeholder components for recipe generation loading states
//  Shows animated placeholders while waiting for AI-generated content
//

import SwiftUI

// MARK: - Recipe Name Shimmer Placeholder

/// Shimmer placeholder for recipe name during generation
struct RecipeNameShimmerPlaceholder: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Text("Tarif ismi")
            .font(.system(size: 34, weight: .bold, design: .rounded))
            .foregroundColor(AppTheme.foregroundOnColor(for: colorScheme).opacity(0.3))
            .shadow(color: Color.primary.opacity(0.2), radius: 4, x: 0, y: 2)
            .shimmer(duration: 2.5, bounceBack: false)
    }
}

// MARK: - Ingredients Shimmer Placeholder

/// Shimmer placeholder for ingredients section during generation
struct IngredientsShimmerPlaceholder: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            Text("Malzemeler")
                .font(.custom("Playfair Display", size: 33.32))
                .fontWeight(.bold)
                .foregroundColor(.primary.opacity(0.3))

            // 3 ingredient placeholders
            ForEach(0..<3, id: \.self) { _ in
                HStack(spacing: 8) {
                    Text("•")
                        .font(.custom("Manrope-Medium", size: 20))
                        .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.7) : Color.black.opacity(0.7))

                    Text("Malzeme")
                        .font(.custom("Manrope-Medium", size: 20))
                        .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.7) : Color.black.opacity(0.7))
                        .shimmer(duration: 2.5, bounceBack: false)
                }
            }
        }
    }
}

// MARK: - Steps Shimmer Placeholder

/// Shimmer placeholder for steps section during generation
struct StepsShimmerPlaceholder: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            Text("Yapılışı")
                .font(.custom("Playfair Display", size: 33.32))
                .fontWeight(.bold)
                .foregroundColor(.primary.opacity(0.3))

            // 3 step placeholders
            ForEach(1...3, id: \.self) { index in
                HStack(spacing: 8) {
                    Text("\(index).")
                        .font(.custom("Manrope-Medium", size: 20))
                        .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.7) : Color.black.opacity(0.7))

                    Text("Adım")
                        .font(.custom("Manrope-Medium", size: 20))
                        .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.7) : Color.black.opacity(0.7))
                        .shimmer(duration: 2.5, bounceBack: false)
                }
            }
        }
    }
}

// MARK: - Previews

#Preview("Recipe Name Shimmer - Light") {
    RecipeNameShimmerPlaceholder()
        .padding()
        .preferredColorScheme(.light)
}

#Preview("Recipe Name Shimmer - Dark") {
    RecipeNameShimmerPlaceholder()
        .padding()
        .preferredColorScheme(.dark)
}

#Preview("Ingredients Shimmer - Light") {
    IngredientsShimmerPlaceholder()
        .padding()
        .preferredColorScheme(.light)
}

#Preview("Ingredients Shimmer - Dark") {
    IngredientsShimmerPlaceholder()
        .padding()
        .preferredColorScheme(.dark)
}

#Preview("Steps Shimmer - Light") {
    StepsShimmerPlaceholder()
        .padding()
        .preferredColorScheme(.light)
}

#Preview("Steps Shimmer - Dark") {
    StepsShimmerPlaceholder()
        .padding()
        .preferredColorScheme(.dark)
}

#Preview("Full Recipe Shimmer") {
    VStack(alignment: .leading, spacing: 32) {
        RecipeNameShimmerPlaceholder()

        IngredientsShimmerPlaceholder()

        StepsShimmerPlaceholder()
    }
    .padding()
    .background(Color(.secondarySystemBackground))
}
