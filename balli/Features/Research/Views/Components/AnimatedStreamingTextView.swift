//
//  AnimatedStreamingTextView.swift
//  balli
//
//  Character-by-character animation wrapper for smooth streaming UX
//  Converts chunky Gemini tokens into smooth character-level display
//  Swift 6 strict concurrency compliant
//

import SwiftUI

/// Animates text character-by-character for smooth streaming appearance
/// Wraps StreamingAnswerView to provide ChatGPT-like streaming UX
@MainActor
struct AnimatedStreamingTextView: View {
    /// The source content that arrives in chunks from backend
    let sourceContent: String

    /// Whether streaming is currently active
    let isStreaming: Bool

    /// Additional props to pass through to StreamingAnswerView
    let sourceCount: Int
    let sources: [ResearchSource]
    let fontSize: CGFloat

    /// The animated content being displayed character-by-character
    @State private var displayedContent: String = ""

    /// Animation task reference for cancellation
    @State private var animationTask: Task<Void, Never>?

    var body: some View {
        StreamingAnswerView(
            content: displayedContent,
            isStreaming: isStreaming,
            sourceCount: sourceCount,
            sources: sources,
            fontSize: fontSize
        )
        .onAppear {
            // Animate initial content if it exists when view appears
            // This handles both Tier 1 (small chunks) and Tier 2 (large first chunk)
            if displayedContent.isEmpty && !sourceContent.isEmpty {
                animateNewContent(from: "", to: sourceContent)
            }
        }
        .onChange(of: sourceContent) { _, newValue in
            // When new content arrives, animate from current displayed position
            // Use displayedContent (what user sees) not oldValue (previous sourceContent)
            // This prevents jumps when chunks arrive faster than animation
            animateNewContent(from: displayedContent, to: newValue)
        }
        .onDisappear {
            // Cancel animation when view disappears
            animationTask?.cancel()
        }
    }

    /// Animates new characters that were added to sourceContent
    private func animateNewContent(from oldContent: String, to newContent: String) {
        // Cancel any existing animation (new animation will continue from current position)
        animationTask?.cancel()

        // If content shrunk (shouldn't happen in streaming), just update immediately
        guard newContent.count >= oldContent.count else {
            displayedContent = newContent
            return
        }

        // If content didn't change, do nothing
        guard newContent != oldContent else { return }

        // Extract the new characters that need to be animated
        let startIndex = oldContent.count
        let newCharacters = String(newContent.dropFirst(startIndex))

        // Start animation task
        animationTask = Task { @MainActor in
            // Display characters one by one with small delays
            for char in newCharacters {
                // Check if task was cancelled
                guard !Task.isCancelled else {
                    // If cancelled, just stop - don't dump remaining content
                    // The next animation will continue from wherever we stopped
                    return
                }

                displayedContent.append(char)

                // Delay between characters (6ms = 167 chars/second, smooth ChatGPT-like speed)
                // Adjust this value to control animation speed:
                // - 3ms = very fast (333 chars/sec)
                // - 5ms = fast (200 chars/sec)
                // - 6ms = smooth (167 chars/sec) ← CURRENT
                // - 8ms = relaxed (125 chars/sec)
                // - 10ms = slow (100 chars/sec)
                try? await Task.sleep(for: .milliseconds(6))
            }
        }
    }
}

// MARK: - Previews

#Preview("Animated Streaming") {
    struct AnimatedPreview: View {
        @State private var sourceContent = ""
        @State private var isStreaming = true

        let chunks = [
            "Ketoasidoz, ",
            "vücudun yeterli insülin üretemediği veya kullanamadığı durumlarda ortaya",
            " çıkan ciddi bir komplikasyon canım. ",
            "İnsülin olmadan hücreler glukozu enerji için kullanamaz ve vücut enerji kaynağı olarak yağları yakmaya başlar."
        ]

        var body: some View {
            VStack(spacing: 20) {
                Text("Animated Streaming Demo")
                    .font(.headline)

                ScrollView {
                    AnimatedStreamingTextView(
                        sourceContent: sourceContent,
                        isStreaming: isStreaming,
                        sourceCount: 0,
                        sources: [],
                        fontSize: 17
                    )
                    .padding()
                }
                .frame(height: 300)
                .background(Color.gray.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                HStack {
                    Text("Source: \(sourceContent.count)")
                        .font(.caption)
                    Spacer()
                    Text(isStreaming ? "Streaming..." : "Complete")
                        .font(.caption)
                        .foregroundStyle(isStreaming ? .blue : .green)
                }

                Button(isStreaming ? "Streaming..." : "Start Streaming") {
                    startStreaming()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isStreaming)
            }
            .padding()
        }

        private func startStreaming() {
            sourceContent = ""
            isStreaming = true

            Task {
                // Simulate chunky Gemini streaming (like real backend)
                for chunk in chunks {
                    sourceContent += chunk

                    // Simulate network delay between chunks (300-700ms)
                    try? await Task.sleep(for: .milliseconds(Int.random(in: 300...700)))
                }

                try? await Task.sleep(for: .milliseconds(500))
                isStreaming = false
            }
        }
    }

    return AnimatedPreview()
}
