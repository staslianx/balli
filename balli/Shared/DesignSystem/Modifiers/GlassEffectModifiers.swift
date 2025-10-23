//
//  GlassEffectModifiers.swift
//  balli
//
//  iOS 26 Liquid Glass effect modifier helpers for consistent glass design
//

import SwiftUI

/// Glass effect style options for iOS 26 native Liquid Glass effects
enum LiquidGlassStyle {
    case thin
    case regular
    case thick

    /// Returns the appropriate iOS 26 material style
    var material: Material {
        switch self {
        case .thin: return .thin
        case .regular: return .regular
        case .thick: return .thick
        }
    }
}

/// Glass effect modifier using iOS 26 native Liquid Glass
struct NativeLiquidGlassButton: ViewModifier {
    let style: LiquidGlassStyle
    let tint: Color

    func body(content: Content) -> some View {
        content
            .background(tint)
            .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

/// Glass effect modifier for text fields using iOS 26 native
struct NativeLiquidGlassTextField: ViewModifier {
    let style: LiquidGlassStyle

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

/// Circular glass button for toolbars with purple tint
struct ToolbarCircularGlass: ViewModifier {
    let size: CGFloat
    let tint: Color

    func body(content: Content) -> some View {
        content
            .frame(width: size, height: size)
            .background(
                Circle()
                    .fill(tint)
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

/// Interactive response modifier for glass elements
struct InteractiveGlassResponse: ViewModifier {
    @State private var isPressed = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .opacity(isPressed ? 0.85 : 1.0)
            .onLongPressGesture(
                minimumDuration: 0.1,
                perform: {},
                onPressingChanged: { pressing in
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isPressed = pressing
                    }
                }
            )
    }
}

/// Convenience extension for applying native glass effects
extension View {
    /// Apply native iOS 26 Liquid Glass button style
    func liquidGlassButton(style: LiquidGlassStyle = .thin, tint: Color = .blue) -> some View {
        modifier(NativeLiquidGlassButton(style: style, tint: tint))
    }

    /// Apply native iOS 26 Liquid Glass text field style
    func liquidGlassTextField(style: LiquidGlassStyle = .thin) -> some View {
        modifier(NativeLiquidGlassTextField(style: style))
    }

    /// Apply circular glass button style for toolbars with purple tint
    func toolbarCircularGlass(size: CGFloat = 44, tint: Color = ThemeColors.primaryPurple.opacity(0.15)) -> some View {
        modifier(ToolbarCircularGlass(size: size, tint: tint))
    }

    /// Apply interactive glass response effect
    func interactiveGlassResponse() -> some View {
        modifier(InteractiveGlassResponse())
    }
}

#Preview {
    VStack(spacing: 20) {
        // Glass button preview
        Button(action: {}) {
            Label("Glass Button", systemImage: "star.fill")
                .padding()
        }
        .liquidGlassButton(style: .thin, tint: .blue)

        // Different glass button styles
        HStack(spacing: 10) {
            Button(action: {}) {
                Text("Thin").font(.caption)
                    .padding()
            }
            .liquidGlassButton(style: .thin, tint: .blue)

            Button(action: {}) {
                Text("Regular").font(.caption)
                    .padding()
            }
            .liquidGlassButton(style: .regular, tint: .purple)

            Button(action: {}) {
                Text("Thick").font(.caption)
                    .padding()
            }
            .liquidGlassButton(style: .thick, tint: .green)
        }

        Spacer()
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(.systemBackground))
}
