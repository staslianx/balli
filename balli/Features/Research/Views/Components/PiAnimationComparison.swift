//
//  PiAnimationComparison.swift
//  balli
//
//  Comparison of different Pi AI animation approaches
//  Shows three different methods side-by-side for user testing
//

import SwiftUI

/// Comparison view showing different Pi AI animation approaches
struct PiAnimationComparison: View {
    var body: some View {
        TabView {
            // APPROACH 1: Instant full text with rolling wave (True Pi AI)
            Approach1_InstantWithWave()
                .tabItem {
                    Label("Instant + Wave", systemImage: "1.circle.fill")
                }

            // APPROACH 2: Plain streaming (no animation)
            Approach2_PlainStreaming()
                .tabItem {
                    Label("Plain Stream", systemImage: "2.circle.fill")
                }

            // APPROACH 3: Stream plain, then wave on complete
            Approach3_StreamThenWave()
                .tabItem {
                    Label("Stream → Wave", systemImage: "3.circle.fill")
                }
        }
    }
}

// MARK: - Approach 1: Instant Full Text + Rolling Wave

/// TRUE Pi AI behavior: Instant full text (opacity 0) then rolling wave reveal
private struct Approach1_InstantWithWave: View {
    @State private var animationKey = 0

    let sampleText = """
    Artificial intelligence is a fascinating field of computer science that focuses on creating systems capable of performing tasks that typically require human intelligence. These tasks include things like understanding natural language, recognizing patterns, making decisions, and solving complex problems. At its core, AI is about teaching machines to learn from experience and adapt to new information, much like how humans learn and grow throughout their lives.
    """

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("APPROACH 1: INSTANT + WAVE")
                        .font(.headline)
                        .foregroundStyle(.blue)

                    Text("How it works:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("• Full text appears instantly (but invisible)\n• Rolling wave reveals it over 3 seconds\n• Exactly like Pi AI / React example\n• No streaming simulation")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.thinMaterial)
                .cornerRadius(12)

                Divider()

                // The actual animation
                PiRollingWaveText(
                    text: sampleText,
                    fadeWindowSize: 0.3,
                    duration: 3.0,
                    easeCurve: 0.5
                )
                .padding()
                .id(animationKey)

                Button("Replay Animation") {
                    animationKey += 1
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
    }
}

// MARK: - Approach 2: Plain Streaming (No Animation)

/// Plain streaming: Text appears as it arrives, no fade-in animation
private struct Approach2_PlainStreaming: View {
    @State private var displayedText = ""
    @State private var isStreaming = false

    let fullText = """
    Artificial intelligence is a fascinating field of computer science that focuses on creating systems capable of performing tasks that typically require human intelligence. These tasks include things like understanding natural language, recognizing patterns, making decisions, and solving complex problems. At its core, AI is about teaching machines to learn from experience and adapt to new information, much like how humans learn and grow throughout their lives.
    """

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("APPROACH 2: PLAIN STREAMING")
                        .font(.headline)
                        .foregroundStyle(.green)

                    Text("How it works:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("• Text appears as it arrives from backend\n• No fade-in animation\n• Fast and responsive\n• Simple and clean")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.thinMaterial)
                .cornerRadius(12)

                Divider()

                // Plain text streaming
                HStack(alignment: .top, spacing: 0) {
                    Text(displayedText)
                        .font(.system(size: 18, weight: .medium, design: .default))
                        .foregroundStyle(.primary)

                    if isStreaming {
                        Text("▊")
                            .font(.system(size: 18, weight: .medium, design: .default))
                            .foregroundStyle(.primary.opacity(0.6))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()

                Button(isStreaming ? "Streaming..." : "Start Streaming") {
                    displayedText = ""
                    simulateStreaming()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isStreaming)
            }
            .padding()
        }
    }

    func simulateStreaming() {
        // Use Task for Swift 6 concurrency compliance
        Task { @MainActor in
            isStreaming = true
            var currentIndex = fullText.startIndex

            while currentIndex < fullText.endIndex {
                // Add 3-8 characters per chunk
                let chunkSize = Int.random(in: 3...8)
                let endIndex = fullText.index(
                    currentIndex,
                    offsetBy: min(chunkSize, fullText.distance(from: currentIndex, to: fullText.endIndex))
                )

                displayedText = String(fullText[..<endIndex])
                currentIndex = endIndex

                // Sleep for 30ms between chunks
                try? await Task.sleep(nanoseconds: 30_000_000)
            }

            isStreaming = false
        }
    }
}

// MARK: - Approach 3: Stream Plain, Then Wave on Complete

/// Hybrid: Stream plain text, then apply rolling wave when complete
private struct Approach3_StreamThenWave: View {
    @State private var displayedText = ""
    @State private var isStreaming = false
    @State private var showWithAnimation = false

    let fullText = """
    Artificial intelligence is a fascinating field of computer science that focuses on creating systems capable of performing tasks that typically require human intelligence. These tasks include things like understanding natural language, recognizing patterns, making decisions, and solving complex problems. At its core, AI is about teaching machines to learn from experience and adapt to new information, much like how humans learn and grow throughout their lives.
    """

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("APPROACH 3: STREAM → WAVE")
                        .font(.headline)
                        .foregroundStyle(.orange)

                    Text("How it works:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("• Text streams in normally (fast)\n• When complete, fade out plain text\n• Fade in with rolling wave animation\n• Best of both worlds?")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.thinMaterial)
                .cornerRadius(12)

                Divider()

                // Show either plain streaming or animated version
                if showWithAnimation {
                    PiRollingWaveText(
                        text: displayedText,
                        fadeWindowSize: 0.3,
                        duration: 3.0,
                        easeCurve: 0.5
                    )
                    .padding()
                    .transition(.opacity)
                } else {
                    HStack(alignment: .top, spacing: 0) {
                        Text(displayedText)
                            .font(.system(size: 18, weight: .medium, design: .default))
                            .foregroundStyle(.primary)

                        if isStreaming {
                            Text("▊")
                                .font(.system(size: 18, weight: .medium, design: .default))
                                .foregroundStyle(.primary.opacity(0.6))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .transition(.opacity)
                }

                Button(isStreaming ? "Streaming..." : "Start Streaming") {
                    displayedText = ""
                    showWithAnimation = false
                    simulateStreaming()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isStreaming)
            }
            .padding()
        }
    }

    func simulateStreaming() {
        // Use Task for Swift 6 concurrency compliance
        Task { @MainActor in
            isStreaming = true
            var currentIndex = fullText.startIndex

            while currentIndex < fullText.endIndex {
                // Add 3-8 characters per chunk
                let chunkSize = Int.random(in: 3...8)
                let endIndex = fullText.index(
                    currentIndex,
                    offsetBy: min(chunkSize, fullText.distance(from: currentIndex, to: fullText.endIndex))
                )

                displayedText = String(fullText[..<endIndex])
                currentIndex = endIndex

                // Sleep for 30ms between chunks
                try? await Task.sleep(nanoseconds: 30_000_000)
            }

            isStreaming = false

            // When streaming completes, trigger animation
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms delay
            withAnimation(.easeInOut(duration: 0.3)) {
                showWithAnimation = true
            }
        }
    }
}

// MARK: - Previews

#Preview("Animation Comparison") {
    PiAnimationComparison()
}

#Preview("Approach 1: Instant + Wave") {
    Approach1_InstantWithWave()
}

#Preview("Approach 2: Plain Streaming") {
    Approach2_PlainStreaming()
}

#Preview("Approach 3: Stream → Wave") {
    Approach3_StreamThenWave()
}
