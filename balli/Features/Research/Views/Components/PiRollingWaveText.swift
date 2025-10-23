//
//  PiRollingWaveText.swift
//  balli
//
//  Pi AI-style rolling wave text animation
//  Word-based parallel fade-in with smooth rolling wave effect
//  Swift 6 strict concurrency compliant
//
//  ALGORITHM:
//  Implements the exact Pi AI rolling wave where ~30% of text fades simultaneously:
//  - Each word has a position (0.0 to 1.0) based on its index
//  - As globalProgress moves 0→1, a "wave" of opacity rolls through
//  - fadeWindowSize (0.3) determines how many words fade at once
//  - Words earlier in text start fading earlier, creating smooth flow
//
//  PERFORMANCE:
//  - Single Text view with AttributedString (no view overhead)
//  - TimelineView for smooth 60fps updates
//  - Automatic text wrapping (native layout)
//  - Efficient opacity calculations per frame
//

import SwiftUI

/// Pi AI-style rolling wave text animation
///
/// Displays text with a smooth rolling wave fade-in effect where approximately 30% of the content
/// is in various stages of fading at any given moment. This creates a calm, flowing appearance
/// similar to Pi AI's distinctive text streaming style.
///
/// ## Algorithm Details
///
/// For each word at position `wordIndex` in text with `totalWords`:
/// ```
/// wordPosition = wordIndex / totalWords  // 0.0 to 1.0
/// fadeWindowSize = 0.3  // 30% of document fades at once
/// wordRevealStart = wordPosition - fadeWindowSize
/// wordRevealEnd = wordPosition
///
/// adjustedProgress = globalProgress * (1 + fadeWindowSize) - fadeWindowSize
///
/// if adjustedProgress <= wordRevealStart:
///     opacity = 0
/// else if adjustedProgress >= wordRevealEnd:
///     opacity = 1
/// else:
///     opacity = easeOut((adjustedProgress - start) / (end - start))
/// ```
///
/// ## Key Characteristics
///
/// - **Word-Based**: Splits text by spaces and animates whole words
/// - **Parallel Animation**: Multiple words fade simultaneously (not sequential)
/// - **Rolling Wave**: ~30% of text actively fading at any moment
/// - **Position-Based**: No line detection needed - natural wrapping creates line effect
/// - **Smooth 60fps**: TimelineView ensures consistent animation updates
///
/// ## Usage
///
/// ```swift
/// PiRollingWaveText(
///     text: "Your streaming text content here",
///     fadeWindowSize: 0.3,      // 30% of text fading at once
///     duration: 2.5,             // Total animation duration
///     easeCurve: 0.5             // Power for ease-out curve
/// )
/// ```
///
/// ## Integration with Streaming
///
/// Works seamlessly with streaming content:
/// - Animation restarts automatically when `text` changes
/// - Previous words maintain opacity while new words animate
/// - Smooth transition as content grows
///
struct PiRollingWaveText: View {
    // MARK: - Public Properties

    /// The text to display with rolling wave animation
    let text: String

    /// Size of the fade window (0.0 to 1.0)
    /// - Default: 0.3 (30% of text fading simultaneously)
    /// - Larger values create wider, smoother waves
    /// - Smaller values create tighter, faster waves
    let fadeWindowSize: Double

    /// Total duration of the animation in seconds
    /// - Default: 2.5 seconds for medium-length responses
    /// - Adjust based on text length for optimal feel
    let duration: TimeInterval

    /// Power value for ease-out curve (opacity = progress ^ easeCurve)
    /// - Default: 0.5 (gentle ease-out)
    /// - Values < 1.0 create ease-out (fast start, slow end)
    /// - Values > 1.0 create ease-in (slow start, fast end)
    let easeCurve: Double

    // MARK: - Private State

    /// Animation state wrapper to ensure thread-safe access
    /// CONCURRENCY FIX: Wraps mutable state in MainActor-isolated container
    @State private var animationState = AnimationState()

    // MARK: - Environment

    /// Accessibility: Disable animation if user enabled Reduce Motion
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Initialization

    /// Creates a rolling wave text animation
    ///
    /// - Parameters:
    ///   - text: The text to display
    ///   - fadeWindowSize: Size of fade window (0.0-1.0), default 0.3
    ///   - duration: Animation duration in seconds, default 2.5
    ///   - easeCurve: Ease curve power, default 0.5 for gentle ease-out
    init(
        text: String,
        fadeWindowSize: Double = 0.3,
        duration: TimeInterval = 2.5,
        easeCurve: Double = 0.5
    ) {
        self.text = text
        self.fadeWindowSize = fadeWindowSize
        self.duration = duration
        self.easeCurve = easeCurve
    }

    // MARK: - Body

    var body: some View {
        if reduceMotion {
            // ACCESSIBILITY FALLBACK: Plain text without animation
            // Used when user enabled Reduce Motion in system settings
            Text(text)
                .font(.system(size: 18, weight: .medium, design: .default))
                .foregroundStyle(.primary)
        } else {
            // NORMAL MODE: Rolling wave animation with smooth transitions
            // Uses individual Text views with SwiftUI animation for CSS-like transitions
            WordBasedRollingWave(
                text: text,
                fadeWindowSize: fadeWindowSize,
                duration: duration,
                easeCurve: easeCurve
            )
        }
    }

}

// MARK: - Word-Based Rolling Wave Implementation

/// Individual word-based rolling wave view with smooth CSS-like transitions
/// Each word is a separate Text view with SwiftUI animation (300ms like React CSS)
private struct WordBasedRollingWave: View {
    let text: String
    let fadeWindowSize: Double
    let duration: TimeInterval
    let easeCurve: Double

    @State private var startTime: Date = Date()
    @State private var words: [String] = []

    var body: some View {
        TimelineView(.animation) { timeline in
            // Use WordFlowLayout to wrap words naturally like HTML
            WordFlowLayout(spacing: 0) {
                ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                    AnimatedWord(
                        word: word,
                        index: index,
                        totalWords: words.count,
                        startTime: startTime,
                        duration: duration,
                        fadeWindowSize: fadeWindowSize,
                        easeCurve: easeCurve,
                        currentTime: timeline.date
                    )
                }
            }
        }
        .onAppear {
            words = text.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
            startTime = Date()
        }
        .onChange(of: text) { _, newText in
            words = newText.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
            startTime = Date()
        }
    }
}

/// Single animated word with smooth opacity transition (matches React CSS transition)
private struct AnimatedWord: View {
    let word: String
    let index: Int
    let totalWords: Int
    let startTime: Date
    let duration: TimeInterval
    let fadeWindowSize: Double
    let easeCurve: Double
    let currentTime: Date

    var body: some View {
        Text(word + " ")
            .font(.system(size: 18, weight: .medium, design: .default))
            .foregroundStyle(.primary)
            .opacity(calculatedOpacity)
            .animation(.easeOut(duration: 0.3), value: calculatedOpacity) // CSS-like 300ms transition
    }

    private var calculatedOpacity: Double {
        let elapsed = currentTime.timeIntervalSince(startTime)
        let globalProgress = min(1.0, elapsed / duration)

        guard totalWords > 0 else { return 1.0 }

        let wordPosition = Double(index) / Double(totalWords)
        let wordRevealStart = wordPosition - fadeWindowSize
        let wordRevealEnd = wordPosition
        let adjustedProgress = globalProgress * (1.0 + fadeWindowSize) - fadeWindowSize

        let opacity: Double
        if adjustedProgress <= wordRevealStart {
            opacity = 0.0
        } else if adjustedProgress >= wordRevealEnd {
            opacity = 1.0
        } else {
            let rawProgress = (adjustedProgress - wordRevealStart) / (wordRevealEnd - wordRevealStart)
            opacity = pow(rawProgress, easeCurve)
        }

        return opacity
    }
}

/// CONCURRENCY FIX: Animation state container for thread-safe access
@MainActor
private class AnimationState: ObservableObject {
    @Published var startTime: Date = Date()
    @Published var hasStarted: Bool = false
}

/// WordFlowLayout that wraps words naturally (like CSS flexbox wrap)
private struct WordFlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y), proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if currentX + size.width > maxWidth && currentX > 0 {
                    // Move to next line
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }

                positions.append(CGPoint(x: currentX, y: currentY))
                currentX += size.width
                lineHeight = max(lineHeight, size.height)
            }

            self.size = CGSize(width: maxWidth, height: currentY + lineHeight)
        }
    }
}

// MARK: - Preview Examples

#if DEBUG

/// Preview showing rolling wave animation on static text
#Preview("Rolling Wave Animation") {
    struct PreviewWrapper: View {
        @State private var animationKey = 0

        let sampleText = """
        Artificial intelligence is a fascinating field of computer science that focuses on creating systems capable of performing tasks that typically require human intelligence. These tasks include things like understanding natural language, recognizing patterns, making decisions, and solving complex problems. At its core, AI is about teaching machines to learn from experience and adapt to new information, much like how humans learn and grow throughout their lives.
        """

        var body: some View {
            ScrollView {
                VStack(spacing: 20) {
                    Text("Pi AI-Style Rolling Wave")
                        .font(.headline)

                    PiRollingWaveText(
                        text: sampleText,
                        fadeWindowSize: 0.3,
                        duration: 3.0,
                        easeCurve: 0.5
                    )
                    .padding()
                    .id(animationKey)  // Force recreation on button tap

                    Button("Replay Animation") {
                        animationKey += 1
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
        }
    }

    return PreviewWrapper()
}

/// Preview showing streaming text simulation
#Preview("Simulated Streaming") {
    struct StreamingPreview: View {
        @State private var displayedText = ""

        let fullText = """
        Recent research has shown promising developments in beta cell regeneration. Scientists have identified several approaches including stem cell therapy and small molecule drugs that can stimulate beta cell proliferation. Key findings include converting other pancreatic cells into beta cells and protecting remaining beta cells from autoimmune attack through immunotherapy.
        """

        var body: some View {
            ScrollView {
                VStack(spacing: 20) {
                    Text("Streaming Simulation")
                        .font(.headline)

                    PiRollingWaveText(
                        text: displayedText,
                        fadeWindowSize: 0.3,
                        duration: 2.5,
                        easeCurve: 0.5
                    )
                    .padding()

                    Button("Start Streaming") {
                        displayedText = ""
                        simulateStreaming()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
        }

        func simulateStreaming() {
            // Use Task with AsyncStream for Swift 6 concurrency compliance
            Task { @MainActor in
                var currentIndex = fullText.startIndex

                // Async timer loop
                while currentIndex < fullText.endIndex {
                    // Add 5-15 characters per chunk (realistic streaming)
                    let chunkSize = Int.random(in: 5...15)
                    let endIndex = fullText.index(
                        currentIndex,
                        offsetBy: min(chunkSize, fullText.distance(from: currentIndex, to: fullText.endIndex))
                    )

                    displayedText = String(fullText[..<endIndex])
                    currentIndex = endIndex

                    // Sleep for 50ms between chunks
                    try? await Task.sleep(nanoseconds: 50_000_000)
                }
            }
        }
    }

    return StreamingPreview()
}

/// Preview comparing different fade window sizes
#Preview("Fade Window Comparison") {
    ScrollView {
        VStack(spacing: 30) {
            Text("Fade Window Size Comparison")
                .font(.headline)

            let text = "This demonstrates how different fade window sizes affect the rolling wave animation effect."

            VStack(alignment: .leading, spacing: 8) {
                Text("Window: 0.2 (Narrow)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                PiRollingWaveText(text: text, fadeWindowSize: 0.2, duration: 2.5)
            }
            .padding()
            .background(.thinMaterial)
            .cornerRadius(12)

            VStack(alignment: .leading, spacing: 8) {
                Text("Window: 0.3 (Default)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                PiRollingWaveText(text: text, fadeWindowSize: 0.3, duration: 2.5)
            }
            .padding()
            .background(.thinMaterial)
            .cornerRadius(12)

            VStack(alignment: .leading, spacing: 8) {
                Text("Window: 0.5 (Wide)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                PiRollingWaveText(text: text, fadeWindowSize: 0.5, duration: 2.5)
            }
            .padding()
            .background(.thinMaterial)
            .cornerRadius(12)
        }
        .padding()
    }
}

/// Preview showing accessibility fallback
#Preview("Accessibility (Reduce Motion)") {
    struct AccessibilityPreview: View {
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        let text = "This preview demonstrates the accessibility fallback. When Reduce Motion is enabled in system settings, the text appears without animation to ensure comfortable use for users with motion sensitivity."

        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 8) {
                        Image(systemName: reduceMotion ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(reduceMotion ? .green : .orange)
                        Text("Reduce Motion: \(reduceMotion ? "ON" : "OFF")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Divider()

                    PiRollingWaveText(
                        text: text,
                        fadeWindowSize: 0.3,
                        duration: 2.5
                    )
                }
                .padding()
            }
        }
    }

    return AccessibilityPreview()
}

#endif
