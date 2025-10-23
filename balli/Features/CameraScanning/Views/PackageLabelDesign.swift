//
//  PackageLabelDesign.swift
//  balli
//
//  Package food label styling - separate from recipe card for independent sizing
//

import SwiftUI

// MARK: - Package Label Design
public struct PackageLabelDesign: ViewModifier {
    public let outerCornerRadius: CGFloat

    public init(outerCornerRadius: CGFloat = RecipeConstants.UI.cardOuterCornerRadius) {
        self.outerCornerRadius = outerCornerRadius
    }

    public func body(content: Content) -> some View {
        content
            .padding(.horizontal, ResponsiveDesign.Spacing.large)
            .padding(.vertical, ResponsiveDesign.Spacing.xLarge)
            .frame(width: ResponsiveDesign.Components.foodLabelWidth)
            .background(
                RoundedRectangle(cornerRadius: outerCornerRadius)
                    .fill(Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: outerCornerRadius)
                    .stroke(Color.gray.opacity(0.3), lineWidth: RecipeConstants.UI.borderStrokeWidth)
            )
            .shadow(
                color: .black.opacity(0.1),
                radius: ResponsiveDesign.height(8),
                x: 0,
                y: ResponsiveDesign.height(4)
            )
    }
}

// MARK: - View Extensions
extension View {
    /// Apply package label design
    public func packageLabelStyle() -> some View {
        self.modifier(PackageLabelDesign())
    }
}