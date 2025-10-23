//
//  RecipeStyleGuide.swift
//  balli
//
//  Font styles for recipe cards
//

import SwiftUI

// MARK: - Recipe Style Guide
public struct RecipeStyleGuide {
    // Helper functions for font switching with appropriate size adjustments
    public static func titleFont(_ baseSize: CGFloat, useHandwritten: Bool) -> Font {
        if useHandwritten {
            // Use maximum bold weight (700) for all text
            return .caveat(baseSize * RecipeConstants.UI.handwrittenTitleMultiplier, weight: RecipeConstants.UI.caveatMaxWeight)
        } else {
            return .system(size: baseSize, weight: .semibold, design: .rounded)
        }
    }

    public static func bodyFont(_ baseSize: CGFloat, useHandwritten: Bool) -> Font {
        if useHandwritten {
            // Use maximum bold weight (700) for all text
            return .caveat(baseSize * RecipeConstants.UI.handwrittenBodyMultiplier, weight: RecipeConstants.UI.caveatMaxWeight)
        } else {
            return .system(size: baseSize, weight: .regular, design: .rounded)
        }
    }

    public static func labelFont(_ baseSize: CGFloat, useHandwritten: Bool) -> Font {
        if useHandwritten {
            // Use maximum bold weight (700) for all text
            return .caveat(baseSize * RecipeConstants.UI.handwrittenLabelMultiplier, weight: RecipeConstants.UI.caveatMaxWeight)
        } else {
            return .system(size: baseSize, weight: .medium, design: .rounded)
        }
    }

    // Adaptive text color for paper - white text in dark mode, black in light mode
    public static func paperTextColor(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? .white : .black
    }
}
