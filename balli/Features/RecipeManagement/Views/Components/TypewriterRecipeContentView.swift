//
//  TypewriterRecipeContentView.swift
//  balli
//
//  Typewriter-style character-by-character recipe content display
//  Uses TypewriterAnimator for polished animation effect
//  Swift 6 strict concurrency compliant
//

import SwiftUI
import OSLog

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.balli",
    category: "TypewriterRecipeContentView"
)

/// View that displays recipe markdown content with typewriter animation
/// Wraps MarkdownText with character-by-character display logic
struct TypewriterRecipeContentView: View {
    let content: String
    let isStreaming: Bool
    let recipeId: String
    let onAnimationStateChange: ((Bool) -> Void)?  // Callback when animation starts/stops

    @State private var displayedContent = ""
    @State private var fullContentReceived = ""  // Track complete content separately from animation
    @State private var animator = TypewriterAnimator()
    @State private var isAnimationComplete = false  // Track animation completion

    var body: some View {
        Group {
            if !displayedContent.isEmpty {
                MarkdownText(
                    content: displayedContent,
                    fontSize: 20,
                    enableSelection: true,
                    sourceCount: 0,
                    sources: [],
                    headerFontSize: 20 * 2.0,
                    fontName: "Manrope",
                    skipFirstHeading: true  // Recipe name shown in hero section
                )
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                // Empty placeholder - show while waiting for animation to start
                Text("")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .onAppear {
            // View initialization - no logging needed
        }
        .task(id: content) {
            // STREAMING FIX: Replace .onChange with .task(id:) to prevent
            // "multiple updates per frame" warnings during fast token streaming.
            // .task automatically cancels and restarts when content changes,
            // coalescing rapid updates into single executions.

            guard content.count > fullContentReceived.count else { return }

            let newChars = String(content.dropFirst(fullContentReceived.count))
            fullContentReceived = content  // Update full content tracker

            // Mark animation as active when first characters arrive
            if fullContentReceived == newChars {  // First content
                isAnimationComplete = false
                onAnimationStateChange?(true)  // Animation started
            }

            let fullContentCount = fullContentReceived.count
            await animator.enqueueText(newChars, for: recipeId) { displayedText in
                // PERFORMANCE: Only update UI every 3 characters to reduce rendering overhead
                // This prevents stutter when markdown re-renders become expensive
                if displayedText.count % 3 == 0 || displayedText.count == fullContentCount {
                    await MainActor.run {
                        self.displayedContent = displayedText
                    }
                }
            } onComplete: {
                // Animation completed naturally - mark as complete and show final content
                await MainActor.run {
                    self.displayedContent = self.fullContentReceived  // Ensure all content is shown
                    self.isAnimationComplete = true
                    self.onAnimationStateChange?(false)
                }
            }
        }
        .onChange(of: isStreaming) { _, newValue in
            // When streaming completes, let animation finish naturally
            if !newValue {
                // Don't flush - let the typewriter animator finish at its own pace (8ms per char)
                // The animation will complete when the character queue is empty
                // This creates smooth, natural text appearance instead of instant dump
            }
        }
        .onAppear {
            // Reset animation state for new content
            isAnimationComplete = false
            displayedContent = ""
            fullContentReceived = ""
        }
        .onDisappear {
            // Cleanup on view disappear
            Task {
                await animator.cancel(recipeId)
            }
        }
    }
}

// MARK: - Previews

#Preview("Typewriter Recipe Animation") {
    struct RecipeTypewriterPreview: View {
        @State private var content = ""
        @State private var isStreaming = true

        let fullRecipe = """
        ## Tavuklu Sezar Salata

        **Hazırlık:** 15 dakika | **Pişirme:** 20 dakika | **Porsiyon:** 4

        ### Malzemeler

        - 500g tavuk göğsü
        - 1 adet marul
        - 50g parmesan peyniri
        - 100g kruton
        - 2 yemek kaşığı zeytinyağı

        ### Yapılışı

        1. Tavuk göğsünü küp küp doğrayın ve zeytinyağında soteleyin
        2. Marulu yıkayıp doğrayın
        3. Tüm malzemeleri karıştırın
        4. Parmesan rendesi ile servis yapın
        """

        var body: some View {
            VStack(spacing: 20) {
                Text("Recipe Typewriter Demo")
                    .font(.headline)

                ScrollView {
                    TypewriterRecipeContentView(
                        content: content,
                        isStreaming: isStreaming,
                        recipeId: "preview",
                        onAnimationStateChange: nil
                    )
                    .padding()
                }
                .frame(height: 500)
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
                for (_, char) in fullRecipe.enumerated() {
                    content.append(char)
                    // Simulate network delay
                    try? await Task.sleep(for: .milliseconds(50))
                }

                try? await Task.sleep(for: .milliseconds(200))
                isStreaming = false
            }
        }
    }

    return RecipeTypewriterPreview()
}
