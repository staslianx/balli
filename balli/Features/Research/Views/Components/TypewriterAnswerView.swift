//
//  TypewriterAnswerView.swift
//  balli
//
//  Typewriter-style character-by-character answer display
//  Uses TypewriterAnimator for polished animation effect
//  Swift 6 strict concurrency compliant
//

import SwiftUI
import OSLog

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.balli",
    category: "TypewriterAnswerView"
)

/// View that displays answer content with typewriter animation
/// Wraps StreamingAnswerView with character-by-character display logic
struct TypewriterAnswerView: View {
    let content: String
    let isStreaming: Bool
    let sourceCount: Int
    let sources: [ResearchSource]
    let fontSize: CGFloat
    let answerId: String
    let onAnimationStateChange: ((Bool) -> Void)?  // Callback when animation starts/stops

    @State private var displayedContent = ""
    @State private var fullContentReceived = ""  // Track complete content separately from animation
    @State private var animator = TypewriterAnimator()
    @State private var isAnimationComplete = false  // Track animation completion
    @State private var lastAnswerId = ""  // Track which answer we're displaying

    var body: some View {
        StreamingAnswerView(
            content: displayedContent,
            isStreaming: isStreaming || !isAnimationComplete,  // Keep streaming until both backend AND animation complete
            sourceCount: sourceCount,
            sources: sources,
            fontSize: fontSize
        )
        .onChange(of: answerId) { _, newAnswerId in
            // LIFECYCLE FIX: Reset animation state only when answerId changes (new answer)
            // This prevents content from disappearing on tab switch or lock/unlock
            if newAnswerId != lastAnswerId {
                logger.debug("🔄 [TYPEWRITER] New answer detected, resetting state")
                isAnimationComplete = false
                displayedContent = ""
                fullContentReceived = ""
                lastAnswerId = newAnswerId
            }
        }
        .task(id: content) {
            // STREAMING FIX: Replace .onChange with .task(id:) to prevent
            // "multiple updates per frame" warnings during fast token streaming.
            // .task automatically cancels and restarts when content changes,
            // coalescing rapid updates into single executions.

            guard content.count > fullContentReceived.count else { return }

            let newChars = String(content.dropFirst(fullContentReceived.count))

            logger.debug("📝 [TYPEWRITER] New chars: '\(newChars.prefix(30))...' (total: \(content.count))")

            // Mark animation as active when first characters arrive
            if fullContentReceived.isEmpty {  // First content - check against empty, not equality
                isAnimationComplete = false
                onAnimationStateChange?(true)  // Animation started
            }

            // P0 FIX: Update fullContentReceived ONLY after animation starts
            // This prevents race condition where view re-renders and guard check fails
            // because fullContentReceived was updated before animation could start
            await animator.enqueueText(newChars, for: answerId) { displayedText in
                await MainActor.run {
                    self.displayedContent = displayedText
                }
            } onComplete: {
                // Animation completed naturally - mark as complete
                await MainActor.run {
                    self.isAnimationComplete = true
                    self.onAnimationStateChange?(false)
                    logger.debug("✅ [TYPEWRITER] Animation naturally completed")
                }
            }

            // ✅ CRITICAL FIX: Update tracker AFTER enqueuing text for animation
            // This ensures guard check passes on next render if animation is still running
            fullContentReceived = content
        }
        .onChange(of: isStreaming) { _, newValue in
            // When streaming completes, let animation finish naturally
            if !newValue {
                logger.debug("🏁 [TYPEWRITER] Backend streaming complete, animation will continue naturally")
                // Don't flush - let the typewriter animator finish at its own pace (30ms per char)
                // The animation will complete when the character queue is empty
                // This creates smooth, natural text appearance instead of instant dump
            }
        }
        .onAppear {
            // LIFECYCLE FIX: On view appear, restore content if it's already complete
            // This handles tab switching and lock/unlock scenarios
            if answerId != lastAnswerId {
                // New answer - reset state
                logger.debug("🔄 [TYPEWRITER] New answer on appear, resetting state")
                isAnimationComplete = false
                displayedContent = ""
                fullContentReceived = ""
                lastAnswerId = answerId
            } else if !content.isEmpty && displayedContent.isEmpty {
                // Same answer, but content was cleared (view recreation) - restore it
                logger.debug("🔄 [TYPEWRITER] Restoring content after view recreation: \(content.count) chars")
                displayedContent = content
                fullContentReceived = content
                isAnimationComplete = true  // Content is complete, no need to animate
            }
        }
        .onDisappear {
            // Cleanup on view disappear
            Task {
                await animator.cancel(answerId)
            }
        }
    }
}

// MARK: - Previews

#Preview("Typewriter Animation") {
    struct TypewriterPreview: View {
        @State private var content = ""
        @State private var isStreaming = true

        let fullText = """
        **Type 2 diabetes** is a chronic condition that affects how your body processes _blood sugar_ (glucose).

        ## Key Management Strategies

        1. **Physical Activity**: Regular exercise helps control weight and blood sugar levels
        2. **Healthy Diet**: Focus on whole grains, fruits, vegetables, and lean proteins
        3. **Blood Sugar Monitoring**: Check levels regularly as recommended

        Research shows that lifestyle modifications can significantly improve outcomes.
        """

        var body: some View {
            VStack(spacing: 20) {
                Text("Typewriter Animation Demo")
                    .font(.headline)

                ScrollView {
                    TypewriterAnswerView(
                        content: content,
                        isStreaming: isStreaming,
                        sourceCount: 0,
                        sources: [],
                        fontSize: 17,
                        answerId: "preview",
                        onAnimationStateChange: nil
                    )
                    .padding()
                }
                .frame(height: 400)
                .background(Color.gray.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                HStack {
                    Text("Length: \(content.count)")
                        .font(.caption)
                    Spacer()
                    Text(isStreaming ? "Streaming..." : "Complete")
                        .font(.caption)
                        .foregroundStyle(isStreaming ? .blue : .green)
                }

                Button(isStreaming ? "Streaming..." : "Start Animation") {
                    startAnimation()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isStreaming)
            }
            .padding()
        }

        private func startAnimation() {
            content = ""
            isStreaming = true

            Task {
                // Simulate token-by-token arrival
                for (_, char) in fullText.enumerated() {
                    content.append(char)
                    // Simulate network delay
                    try? await Task.sleep(for: .milliseconds(50))
                }

                try? await Task.sleep(for: .milliseconds(200))
                isStreaming = false
            }
        }
    }

    return TypewriterPreview()
}

#Preview("Fast Typewriter") {
    struct FastTypewriterPreview: View {
        @State private var content = ""
        @State private var isStreaming = true

        let fastText = "This is a fast streaming test. Notice the typewriter effect smooths out the display!"

        var body: some View {
            VStack(spacing: 20) {
                Text("Fast Typewriter Test")
                    .font(.headline)

                TypewriterAnswerView(
                    content: content,
                    isStreaming: isStreaming,
                    sourceCount: 0,
                    sources: [],
                    fontSize: 17,
                    answerId: "fast-preview",
                    onAnimationStateChange: nil
                )
                .padding()
                .frame(height: 200)
                .background(Color.gray.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                Button("Start Fast Animation") {
                    startFastAnimation()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isStreaming)
            }
            .padding()
        }

        private func startFastAnimation() {
            content = ""
            isStreaming = true

            Task {
                // Very fast token arrival
                for (_, char) in fastText.enumerated() {
                    content.append(char)
                    try? await Task.sleep(for: .milliseconds(10))
                }

                isStreaming = false
            }
        }
    }

    return FastTypewriterPreview()
}
