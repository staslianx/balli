//
//  SmoothFadeInRenderer.swift
//  balli
//
//  Pi AI-style smooth character-by-character fade-in animation
//  iOS 18+ TextRenderer protocol implementation
//  Swift 6 strict concurrency compliant
//

import SwiftUI

/// Smooth fade-in text renderer for streaming AI responses
/// Implements per-character opacity animation with gentle easing for calm, Pi AI-style effect
@available(iOS 18, *)
struct SmoothFadeInRenderer: TextRenderer, Animatable {
    /// Current elapsed time in the animation
    var elapsedTime: TimeInterval

    /// Delay between each character's fade-in start (default: 50ms for calm pacing)
    var characterDelay: TimeInterval = 0.05

    /// Duration of each character's fade-in animation (default: 200ms for smooth effect)
    var fadeDuration: TimeInterval = 0.2

    /// Whether to add subtle vertical drop animation (default: true)
    var addVerticalDrop: Bool = true

    /// Amount of vertical drop in points (default: 3pt)
    var dropAmount: CGFloat = 3.0

    // MARK: - Animatable Conformance

    var animatableData: TimeInterval {
        get { elapsedTime }
        set { elapsedTime = newValue }
    }

    // MARK: - TextRenderer Conformance

    func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        var characterIndex = 0

        // Iterate through all lines, runs, and glyphs
        for line in layout {
            for run in line {
                for glyph in run {
                    // Calculate when this character should start fading in
                    let delay = Double(characterIndex) * characterDelay

                    // Calculate animation progress (0 to 1) for this character
                    let rawProgress = (elapsedTime - delay) / fadeDuration
                    let progress = max(0, min(1, rawProgress))

                    // Apply easeIn curve for gentle acceleration
                    let opacity = UnitCurve.easeIn.value(at: progress)

                    // Create a copy of the context for this glyph
                    var copy = context
                    copy.opacity = opacity

                    // Optional: Add subtle vertical drop for depth
                    if addVerticalDrop {
                        let yOffset = (1 - progress) * dropAmount
                        copy.translateBy(x: 0, y: yOffset)
                    }

                    // Render with subpixel quantization disabled for smooth movement
                    copy.draw(glyph, options: .disablesSubpixelQuantization)

                    characterIndex += 1
                }
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
@available(iOS 18, *)
#Preview("Smooth Fade-In Animation") {
    struct PreviewWrapper: View {
        @State private var animationProgress: TimeInterval = 0
        let sampleText = "This is a smooth, calm fade-in animation inspired by Pi AI. Each character appears gently with a subtle drop effect."

        var body: some View {
            VStack(spacing: 20) {
                Text(sampleText)
                    .font(.system(size: 18, weight: .medium, design: .default))
                    .foregroundStyle(.primary)
                    .textRenderer(SmoothFadeInRenderer(
                        elapsedTime: animationProgress,
                        characterDelay: 0.05,
                        fadeDuration: 0.2,
                        addVerticalDrop: true,
                        dropAmount: 3.0
                    ))
                    .padding()

                Button("Replay Animation") {
                    animationProgress = 0
                    withAnimation(.linear(duration: totalDuration)) {
                        animationProgress = totalDuration
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .onAppear {
                withAnimation(.linear(duration: totalDuration)) {
                    animationProgress = totalDuration
                }
            }
        }

        private var totalDuration: TimeInterval {
            let characterCount = sampleText.count
            return Double(characterCount) * 0.05 + 0.2
        }
    }

    return PreviewWrapper()
}

@available(iOS 18, *)
#Preview("Without Vertical Drop") {
    struct PreviewWrapper: View {
        @State private var animationProgress: TimeInterval = 0
        let sampleText = "Pi AI's calm streaming animation without the vertical drop effect."

        var body: some View {
            VStack(spacing: 20) {
                Text(sampleText)
                    .font(.system(size: 18, weight: .medium, design: .default))
                    .foregroundStyle(.primary)
                    .textRenderer(SmoothFadeInRenderer(
                        elapsedTime: animationProgress,
                        characterDelay: 0.05,
                        fadeDuration: 0.2,
                        addVerticalDrop: false
                    ))
                    .padding()

                Button("Replay Animation") {
                    animationProgress = 0
                    withAnimation(.linear(duration: totalDuration)) {
                        animationProgress = totalDuration
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .onAppear {
                withAnimation(.linear(duration: totalDuration)) {
                    animationProgress = totalDuration
                }
            }
        }

        private var totalDuration: TimeInterval {
            let characterCount = sampleText.count
            return Double(characterCount) * 0.05 + 0.2
        }
    }

    return PreviewWrapper()
}

@available(iOS 18, *)
#Preview("Fast Pacing (30ms delay)") {
    struct PreviewWrapper: View {
        @State private var animationProgress: TimeInterval = 0
        let sampleText = "Faster character appearance with 30ms delay between characters."

        var body: some View {
            VStack(spacing: 20) {
                Text(sampleText)
                    .font(.system(size: 18, weight: .medium, design: .default))
                    .foregroundStyle(.primary)
                    .textRenderer(SmoothFadeInRenderer(
                        elapsedTime: animationProgress,
                        characterDelay: 0.03,
                        fadeDuration: 0.15,
                        addVerticalDrop: true,
                        dropAmount: 2.0
                    ))
                    .padding()

                Button("Replay Animation") {
                    animationProgress = 0
                    withAnimation(.linear(duration: totalDuration)) {
                        animationProgress = totalDuration
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .onAppear {
                withAnimation(.linear(duration: totalDuration)) {
                    animationProgress = totalDuration
                }
            }
        }

        private var totalDuration: TimeInterval {
            let characterCount = sampleText.count
            return Double(characterCount) * 0.03 + 0.15
        }
    }

    return PreviewWrapper()
}
#endif
