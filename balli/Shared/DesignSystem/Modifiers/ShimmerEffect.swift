//
//  ShimmerEffect.swift
//  balli
//
//  Shimmer animation modifier with text masking support
//

import SwiftUI

/// Shimmer effect modifier that creates an animated gradient sweep
/// The shimmer is masked by the view content (text, shapes, etc.)
/// Swift 6 compliant with @MainActor and Task-based initialization
@MainActor
struct ShimmerEffect: ViewModifier {
    @State private var phase: CGFloat = 0

    let duration: Double
    let bounceBack: Bool

    init(duration: Double = 2.0, bounceBack: Bool = false) {
        self.duration = duration
        self.bounceBack = bounceBack
    }

    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { geometry in
                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(0), location: 0.0),
                            .init(color: .white.opacity(0), location: 0.2),
                            .init(color: .white.opacity(0.3), location: 0.35),
                            .init(color: .white.opacity(0.8), location: 0.45),
                            .init(color: .white.opacity(1.0), location: 0.5),
                            .init(color: .white.opacity(0.8), location: 0.55),
                            .init(color: .white.opacity(0.3), location: 0.65),
                            .init(color: .white.opacity(0), location: 0.8),
                            .init(color: .white.opacity(0), location: 1.0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .scaleEffect(x: 4, anchor: .leading)
                    .offset(x: phase * geometry.size.width * 3 - geometry.size.width * 1.5)
                    .blendMode(.overlay)
                    .mask {
                        content
                    }
                }
            }
            .task {
                try? await Task.sleep(for: .milliseconds(100))
                withAnimation(
                    .linear(duration: duration)
                    .repeatForever(autoreverses: bounceBack)
                ) {
                    phase = 1.0
                }
            }
    }
}

/// Conditional shimmer modifier that only applies shimmer when active
/// Maintains proper text alignment without causing layout shifts
@MainActor
struct ConditionalShimmer: ViewModifier {
    let isActive: Bool
    let duration: Double
    let bounceBack: Bool

    func body(content: Content) -> some View {
        if isActive {
            content.modifier(ShimmerEffect(duration: duration, bounceBack: bounceBack))
        } else {
            content
        }
    }
}

extension View {
    /// Applies a shimmer effect to the view
    /// - Parameters:
    ///   - duration: Animation duration in seconds (default: 2.0)
    ///   - bounceBack: Whether the shimmer should reverse direction (default: false)
    /// - Returns: View with shimmer effect applied
    func shimmer(duration: Double = 2.0, bounceBack: Bool = false) -> some View {
        modifier(ShimmerEffect(duration: duration, bounceBack: bounceBack))
    }
}

// MARK: - Previews
#Preview("Shimmer Variations") {
    ZStack {
        Color(.systemGray6)
            .ignoresSafeArea()

        ScrollView {
            VStack(spacing: 50) {
                // As used in AnalysisNutritionLabelView
                VStack(spacing: 16) {
                    Text("As Used in Analysis View")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("İnceliyorum")
                        .font(.system(size: 28, weight: .medium, design: .rounded))
                        .foregroundColor(.primary.opacity(0.7))
                        .shimmer(duration: 2.5, bounceBack: false)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding()
                }

                // Longer text
                VStack(spacing: 16) {
                    Text("Longer Text Example")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("Sadeleştiriyorum")
                        .font(.system(size: 28, weight: .medium, design: .rounded))
                        .foregroundColor(.primary.opacity(0.7))
                        .shimmer(duration: 2.5)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding()
                }

                // Even longer
                VStack(spacing: 16) {
                    Text("Very Long Text")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("Etiketini oluşturuyorum")
                        .font(.system(size: 28, weight: .medium, design: .rounded))
                        .foregroundColor(.primary.opacity(0.7))
                        .shimmer(duration: 2.5)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding()
                }

                // Last example
                VStack(spacing: 16) {
                    Text("Final Stage Example")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("Son bi bakıyorum...")
                        .font(.system(size: 28, weight: .medium, design: .rounded))
                        .foregroundColor(.primary.opacity(0.7))
                        .shimmer(duration: 2.5)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding()
                }

                // Dark text for comparison
                VStack(spacing: 16) {
                    Text("Dark Text (Comparison)")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("Sağlamasını yapıyorum")
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .foregroundColor(.black)
                        .shimmer(duration: 2.5)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(12)
                }
            }
            .padding()
        }
    }
}
