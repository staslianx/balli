//
//  ThemeModifiers.swift
//  balli
//
//  View modifiers for consistent styling
//  Extracted from AppTheme.swift
//

import SwiftUI

// MARK: - Card Style Modifier

struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(AppTheme.cardBackground)
            .cornerRadius(AppTheme.CornerRadius.card)
            .shadow(color: AppTheme.cardShadow, radius: 4, x: 0, y: 2)
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }
}
