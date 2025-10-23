//
//  StreamBuffer.swift
//  balli
//
//  Token batching system for smooth streaming
//  Batches tokens into 50ms windows to prevent choppy updates
//  Swift 6 strict concurrency compliant
//

import Foundation
import SwiftUI
import OSLog

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.anaxoniclabs.balli", category: "StreamBuffer")

/// Buffers streaming tokens and flushes them in batches for smooth UI updates
/// Prevents choppy updates by batching tokens into time windows
@MainActor
@Observable
class StreamBuffer {
    /// Current displayed content (publicly observable)
    var displayContent: String = ""

    /// Internal buffer for accumulating tokens before flush
    private var buffer: String = ""

    /// Task handle for scheduled flush
    private var flushTask: Task<Void, Never>?

    /// Flush interval in milliseconds (default: 50ms for smooth updates)
    private let flushIntervalMs: Int

    /// Total tokens received (for debugging)
    private(set) var tokenCount: Int = 0

    /// Whether streaming is active
    private(set) var isStreaming: Bool = false

    init(flushIntervalMs: Int = 50) {
        self.flushIntervalMs = flushIntervalMs
    }

    /// Append a token to the buffer and schedule flush
    /// Tokens accumulate until flush timer expires or flush() is called manually
    func append(_ token: String) {
        guard !token.isEmpty else { return }

        buffer += token
        tokenCount += 1
        isStreaming = true

        // Schedule flush after interval
        scheduleFlush()
    }

    /// Schedule a flush after the configured interval
    /// Cancels any pending flush and reschedules
    private func scheduleFlush() {
        // Cancel any existing flush task
        flushTask?.cancel()

        // Schedule new flush
        flushTask = Task { @MainActor in
            do {
                try await Task.sleep(for: .milliseconds(flushIntervalMs))

                // Only flush if task wasn't cancelled
                if !Task.isCancelled {
                    flush()
                }
            } catch {
                // Task was cancelled, do nothing
            }
        }
    }

    /// Immediately flush buffered content to display
    /// Call this when streaming completes or you need immediate update
    func flush() {
        guard !buffer.isEmpty else { return }

        logger.debug("Flushing \(self.buffer.count) characters to display")

        // Move buffer content to display
        displayContent += buffer
        buffer = ""
    }

    /// Complete streaming and flush any remaining content
    func complete() {
        // Cancel any pending flush
        flushTask?.cancel()
        flushTask = nil

        // Flush remaining buffer
        flush()

        isStreaming = false

        logger.info("Stream completed. Total tokens: \(self.tokenCount), Final length: \(self.displayContent.count)")
    }

    /// Reset the buffer to initial state
    /// Use this when starting a new streaming session
    func reset() {
        flushTask?.cancel()
        flushTask = nil

        buffer = ""
        displayContent = ""
        tokenCount = 0
        isStreaming = false

        logger.debug("Buffer reset")
    }

    /// Get current buffer size (for debugging)
    var bufferSize: Int {
        buffer.count
    }

    // Note: deinit cannot access @MainActor properties
    // The Task will be cancelled automatically when the object is deallocated
}

// MARK: - Observable Array Extension for Multiple Streams

/// Extension to manage multiple stream buffers efficiently
@MainActor
extension StreamBuffer {
    /// Create a new buffer with custom flush interval
    static func custom(flushIntervalMs: Int) -> StreamBuffer {
        StreamBuffer(flushIntervalMs: flushIntervalMs)
    }

    /// Create buffer optimized for very fast streaming (30ms flush)
    static func fast() -> StreamBuffer {
        StreamBuffer(flushIntervalMs: 30)
    }

    /// Create buffer optimized for slow/deliberate streaming (100ms flush)
    static func slow() -> StreamBuffer {
        StreamBuffer(flushIntervalMs: 100)
    }
}

// MARK: - Previews

#Preview("Stream Buffer Simulation") {
    struct StreamBufferPreview: View {
        @State private var buffer = StreamBuffer()
        @State private var isSimulating = false

        let sampleText = """
        **Type 2 diabetes** is a chronic condition affecting how your body processes blood sugar (glucose).

        Key management strategies:
        - Regular physical activity
        - Healthy diet rich in fiber
        - Blood sugar monitoring
        - Medication as prescribed

        Learn more at [Mayo Clinic](https://mayoclinic.org)
        """

        var body: some View {
            VStack(spacing: 20) {
                Text("Stream Buffer Demo")
                    .font(.headline)

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Buffered Content:")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(buffer.displayContent)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        HStack {
                            Text("Tokens: \(buffer.tokenCount)")
                                .font(.caption)
                            Spacer()
                            Text("Buffer: \(buffer.bufferSize) chars")
                                .font(.caption)
                            Spacer()
                            Text("Display: \(buffer.displayContent.count) chars")
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                    }
                }
                .frame(height: 400)

                VStack(spacing: 12) {
                    Button(isSimulating ? "Streaming..." : "Start Streaming") {
                        simulateStreaming()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isSimulating)

                    Button("Reset") {
                        buffer.reset()
                    }
                    .buttonStyle(.bordered)
                    .disabled(isSimulating)
                }
            }
            .padding()
        }

        private func simulateStreaming() {
            guard !isSimulating else { return }

            buffer.reset()
            isSimulating = true

            Task {
                // Simulate token-by-token streaming
                for (_, char) in sampleText.enumerated() {
                    buffer.append(String(char))

                    // Simulate realistic token arrival timing
                    let delay = Int.random(in: 20...80)
                    try? await Task.sleep(for: .milliseconds(delay))
                }

                // Complete the stream
                buffer.complete()
                isSimulating = false
            }
        }
    }

    return StreamBufferPreview()
}

#Preview("Fast vs Slow Comparison") {
    struct ComparisonPreview: View {
        @State private var fastBuffer = StreamBuffer.fast()  // 30ms
        @State private var slowBuffer = StreamBuffer.slow()  // 100ms
        @State private var isSimulating = false

        let sampleText = "The quick brown fox jumps over the lazy dog. " +
                        "This is a comparison between fast (30ms) and slow (100ms) flush intervals."

        var body: some View {
            VStack(spacing: 20) {
                Text("Fast vs Slow Buffer Comparison")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Fast (30ms flush):")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(fastBuffer.displayContent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(minHeight: 60)
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Slow (100ms flush):")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(slowBuffer.displayContent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(minHeight: 60)
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button(isSimulating ? "Streaming..." : "Start Comparison") {
                    simulateComparison()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSimulating)
            }
            .padding()
        }

        private func simulateComparison() {
            guard !isSimulating else { return }

            fastBuffer.reset()
            slowBuffer.reset()
            isSimulating = true

            Task {
                for (_, char) in sampleText.enumerated() {
                    let token = String(char)
                    fastBuffer.append(token)
                    slowBuffer.append(token)

                    try? await Task.sleep(for: .milliseconds(30))
                }

                fastBuffer.complete()
                slowBuffer.complete()
                isSimulating = false
            }
        }
    }

    return ComparisonPreview()
}
