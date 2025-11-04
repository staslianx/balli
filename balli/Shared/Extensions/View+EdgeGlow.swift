//
//  View+EdgeGlow.swift
//  balli
//
//  Reusable edge glow effect modifier
//  Edge glow effect for use across the app (voice control, chat assistant, dashboard, etc.)
//

import SwiftUI

// MARK: - Edge Glow Effect Modifier

/// View modifier that adds a glowing edge effect around the view
struct EdgeGlowEffect: ViewModifier {
    let isActive: Bool
    let color: Color
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .overlay {
                if isActive {
                    GeometryReader { geometry in
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(color, lineWidth: 4)
                            .shadow(color: color.opacity(0.8), radius: 20, x: 0, y: 0)
                            .shadow(color: color.opacity(0.6), radius: 40, x: 0, y: 0)
                            .shadow(color: color.opacity(0.4), radius: 60, x: 0, y: 0)
                            .shadow(color: color.opacity(0.2), radius: 80, x: 0, y: 0)
                            .allowsHitTesting(false)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                    }
                    .transition(.opacity)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7), value: isActive)
                }
            }
    }
}

// MARK: - View Extension

extension View {
    /// Add an edge glow effect to any view
    /// - Parameters:
    ///   - isActive: Whether the glow is visible
    ///   - color: Glow color (default: primary purple)
    ///   - cornerRadius: Corner radius for the glow rectangle (default: 24)
    /// - Returns: View with edge glow modifier applied
    ///
    /// **Usage:**
    /// ```swift
    /// MyView()
    ///     .edgeGlow(isActive: showGlow)
    ///
    /// MyView()
    ///     .edgeGlow(
    ///         isActive: isListening,
    ///         color: .purple,
    ///         cornerRadius: 32
    ///     )
    /// ```
    func edgeGlow(
        isActive: Bool,
        color: Color = AppTheme.primaryPurple,
        cornerRadius: CGFloat = 24
    ) -> some View {
        modifier(EdgeGlowEffect(
            isActive: isActive,
            color: color,
            cornerRadius: cornerRadius
        ))
    }
}
