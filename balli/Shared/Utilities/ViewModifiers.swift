//
//  ViewModifiers.swift
//  balli
//
//  Custom view modifiers for consistent styling and behavior
//

import SwiftUI

// MARK: - Preference Keys

/// Preference key for tracking scroll offset in ScrollViews
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Card Style Modifier
struct CardStyleModifier: ViewModifier {
    let cornerRadius: CGFloat
    let shadowRadius: CGFloat
    let shadowColor: Color
    
    init(
        cornerRadius: CGFloat = ResponsiveDesign.CornerRadius.large,
        shadowRadius: CGFloat = ResponsiveDesign.height(8),
        shadowColor: Color = .black.opacity(0.1)
    ) {
        self.cornerRadius = cornerRadius
        self.shadowRadius = shadowRadius
        self.shadowColor = shadowColor
    }
    
    func body(content: Content) -> some View {
        content
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: shadowRadius / 2)
    }
}

// MARK: - Loading Overlay Modifier
struct LoadingOverlay: ViewModifier {
    let isLoading: Bool
    let message: String?
    
    func body(content: Content) -> some View {
        ZStack {
            content
                .disabled(isLoading)
                .blur(radius: isLoading ? 3 : 0)
            
            if isLoading {
                VStack(spacing: ResponsiveDesign.Spacing.medium) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.primaryPurple))
                        .scaleEffect(1.5)
                    
                    if let message = message {
                        Text(message)
                            .font(.system(size: 17, weight: .regular, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(ResponsiveDesign.Spacing.large)
                .background(Color(.systemBackground).opacity(0.95))
                .clipShape(RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.medium, style: .continuous))
                .shadow(radius: ResponsiveDesign.height(10))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isLoading)
    }
}

// MARK: - Error Alert Modifier
struct ErrorAlert: ViewModifier {
    @Binding var error: Error?
    let onDismiss: (() -> Void)?
    
    func body(content: Content) -> some View {
        content
            .alert("Hata", isPresented: .constant(error != nil), presenting: error) { _ in
                Button("Tamam") {
                    error = nil
                    onDismiss?()
                }
            } message: { error in
                Text(error.localizedDescription)
            }
    }
}

// MARK: - Keyboard Adaptive Modifier
struct KeyboardAdaptive: ViewModifier {
    @State private var keyboardHeight: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .padding(.bottom, keyboardHeight)
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
                if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                    withAnimation(.easeOut(duration: 0.25)) {
                        keyboardHeight = keyboardFrame.height
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                withAnimation(.easeOut(duration: 0.25)) {
                    keyboardHeight = 0
                }
            }
    }
}

// MARK: - Redacted Modifier
struct RedactedShimmer: ViewModifier {
    let isRedacted: Bool
    
    func body(content: Content) -> some View {
        if isRedacted {
            content
                .redacted(reason: .placeholder)
        } else {
            content
        }
    }
}

// MARK: - Accessibility Modifier
struct AccessibilityEnhanced: ViewModifier {
    let label: String
    let hint: String?
    let traits: AccessibilityTraits
    
    init(
        label: String,
        hint: String? = nil,
        traits: AccessibilityTraits = .isButton
    ) {
        self.label = label
        self.hint = hint
        self.traits = traits
    }
    
    func body(content: Content) -> some View {
        content
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityAddTraits(traits)
    }
}

// MARK: - View Extensions
extension View {
    func cardStyle(
        cornerRadius: CGFloat = ResponsiveDesign.CornerRadius.large,
        shadowRadius: CGFloat = ResponsiveDesign.height(8),
        shadowColor: Color = .black.opacity(0.1)
    ) -> some View {
        modifier(CardStyleModifier(cornerRadius: cornerRadius, shadowRadius: shadowRadius, shadowColor: shadowColor))
    }
    
    func loadingOverlay(isLoading: Bool, message: String? = nil) -> some View {
        modifier(LoadingOverlay(isLoading: isLoading, message: message))
    }
    
    func errorAlert(error: Binding<Error?>, onDismiss: (() -> Void)? = nil) -> some View {
        modifier(ErrorAlert(error: error, onDismiss: onDismiss))
    }

    func keyboardAdaptive() -> some View {
        modifier(KeyboardAdaptive())
    }
    
    func redactedShimmer(when isRedacted: Bool) -> some View {
        modifier(RedactedShimmer(isRedacted: isRedacted))
    }
    
    func accessibilityEnhanced(
        label: String,
        hint: String? = nil,
        traits: AccessibilityTraits = .isButton
    ) -> some View {
        modifier(AccessibilityEnhanced(label: label, hint: hint, traits: traits))
    }
}

// MARK: - Conditional Modifier
extension View {
    @ViewBuilder
    func `if`<Transform: View>(_ condition: Bool, transform: (Self) -> Transform) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
    
    @ViewBuilder
    func ifLet<Value, Transform: View>(_ value: Value?, transform: (Self, Value) -> Transform) -> some View {
        if let value = value {
            transform(self, value)
        } else {
            self
        }
    }
}

// MARK: - Text Shimmer Effect (ChatGPT-style)

/// A shimmer effect that only affects text characters, similar to ChatGPT's loading animation
/// Uses a subtle gradient that gently highlights text as it passes through
struct TextShimmerEffect: ViewModifier {
    @State private var phase: CGFloat = -200
    let duration: Double

    init(duration: Double = 2.0) {
        self.duration = duration
    }

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: .white.opacity(0.15), location: 0.4),
                        .init(color: .white.opacity(0.25), location: 0.5),
                        .init(color: .white.opacity(0.15), location: 0.6),
                        .init(color: .clear, location: 1.0)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 200) // Narrower wave for smoother effect
                .offset(x: phase)
                .mask(content) // Critical: mask ensures shimmer only shows on text
            )
            .onAppear {
                withAnimation(
                    .linear(duration: duration)
                    .repeatForever(autoreverses: false)
                ) {
                    phase = 400 // Move gradient across the view
                }
            }
    }
}

// MARK: - Diagonal Shimmer Effect for Badges

/// A diagonal shimmer effect with gradient, perfect for research tier badges
/// Creates a diagonal sweep that makes text sparkle with activity
struct DiagonalShimmerEffect: ViewModifier {
    let duration: Double
    let colors: [Color]

    // Use @State with a timer to ensure animation starts immediately
    @State private var isAnimating = true

    init(duration: Double = 1.5, colors: [Color]? = nil) {
        self.duration = duration
        self.colors = colors ?? [
            .white.opacity(0.0),
            .white.opacity(0.4),
            .white.opacity(0.8),
            .white.opacity(0.4),
            .white.opacity(0.0)
        ]
    }

    func body(content: Content) -> some View {
        TimelineView(.animation(minimumInterval: 0.016)) { timeline in
            let phase = (timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: duration)) / duration

            content
                .overlay(
                    LinearGradient(
                        gradient: Gradient(colors: colors),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .rotationEffect(.degrees(45))
                    .scaleEffect(3)
                    .offset(x: -200 + (phase * 400))
                    .mask(
                        content
                    )
                )
        }
    }
}

extension View {
    /// Applies a ChatGPT-style shimmer effect that only affects text characters
    /// - Parameter duration: The duration of one shimmer cycle (default: 2.0 seconds)
    func textShimmer(duration: Double = 2.0) -> some View {
        modifier(TextShimmerEffect(duration: duration))
    }

    /// Applies a diagonal shimmer effect perfect for badges
    /// - Parameters:
    ///   - duration: The duration of one shimmer cycle (default: 1.5 seconds)
    ///   - colors: Custom gradient colors (default: white with varying opacity)
    func diagonalShimmer(duration: Double = 1.5, colors: [Color]? = nil) -> some View {
        modifier(DiagonalShimmerEffect(duration: duration, colors: colors))
    }
}

// MARK: - Device Specific Modifiers
extension View {
    @ViewBuilder
    func onPhone<Content: View>(@ViewBuilder content: (Self) -> Content) -> some View {
        if UIDevice.current.userInterfaceIdiom == .phone {
            content(self)
        } else {
            self
        }
    }

    @ViewBuilder
    func onPad<Content: View>(@ViewBuilder content: (Self) -> Content) -> some View {
        if UIDevice.current.userInterfaceIdiom == .pad {
            content(self)
        } else {
            self
        }
    }
}