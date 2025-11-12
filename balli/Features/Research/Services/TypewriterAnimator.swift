//
//  TypewriterAnimator.swift
//  balli
//
//  Character-by-character typewriter effect with adaptive delays
//  Provides polished animation for streaming text display
//  Swift 6 strict concurrency compliant
//

import Foundation
import OSLog

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.balli",
    category: "TypewriterAnimator"
)

/// Actor that animates text character-by-character with adaptive delays
/// Provides cinematic typewriter effect for synthesis stage responses
actor TypewriterAnimator {
    // MARK: - Configuration

    /// Base delay between characters (milliseconds) - fast reading speed
    private let baseDelay: UInt64 = 8

    /// Delay for space characters (faster for natural flow)
    private let spaceDelay: UInt64 = 5

    /// Delay after punctuation (pause for emphasis)
    private let punctuationDelay: UInt64 = 50

    /// Punctuation characters that trigger longer pauses
    private let punctuationChars: Set<Character> = [".", "!", "?", ":", ";"]

    // MARK: - State Management

    /// Character queues per answer ID
    private var characterQueues: [String: [Character]] = [:]

    /// Active animation tasks per answer ID
    private var animationTasks: [String: Task<Void, Never>] = [:]

    /// Track if animation was cancelled (for instant flush)
    private var isCancelled: [String: Bool] = [:]

    /// Track total characters enqueued for verification
    private var totalEnqueued: [String: Int] = [:]

    /// Track total characters delivered for verification
    private var totalDelivered: [String: Int] = [:]

    // MARK: - Public API

    /// Enqueue text for character-by-character animation
    /// - Parameters:
    ///   - text: Text chunk to animate
    ///   - answerId: Answer identifier
    ///   - deliver: Callback to deliver displayed text progressively
    ///   - onComplete: Optional callback when animation completes naturally (queue empty for 200ms)
    func enqueueText(
        _ text: String,
        for answerId: String,
        deliver: @escaping @Sendable (String) async -> Void,
        onComplete: (@Sendable () async -> Void)? = nil
    ) async {
        logger.info("✍️ [TYPEWRITER] Enqueuing \(text.count) characters for animation | Content: '\(text.prefix(30))...'")

        // Initialize queue if needed
        if characterQueues[answerId] == nil {
            characterQueues[answerId] = []
            isCancelled[answerId] = false
            totalEnqueued[answerId] = 0
            totalDelivered[answerId] = 0
        }

        // Add characters to queue
        characterQueues[answerId]?.append(contentsOf: Array(text))

        // Track total enqueued characters
        totalEnqueued[answerId, default: 0] += text.count
        let currentTotal = totalEnqueued[answerId, default: 0]
        logger.debug("📊 [TYPEWRITER] Total enqueued: \(currentTotal) chars")

        // Start animation if not already running
        if animationTasks[answerId] == nil {
            await startAnimation(for: answerId, deliver: deliver, onComplete: onComplete)
        }
    }

    /// Flush all remaining characters instantly (on cancel or completion)
    /// - Parameters:
    ///   - answerId: Answer identifier
    ///   - deliver: Callback to deliver remaining text
    func flushRemaining(
        _ answerId: String,
        deliver: @escaping @Sendable (String) async -> Void
    ) async {
        logger.debug("⚡️ Flushing remaining characters for: \(answerId)")

        // Mark as cancelled (disables character delays)
        isCancelled[answerId] = true

        // Cancel existing animation task
        animationTasks[answerId]?.cancel()
        animationTasks[answerId] = nil

        // Deliver all remaining characters at once
        if let remaining = characterQueues[answerId], !remaining.isEmpty {
            let remainingText = String(remaining)
            await deliver(remainingText)
            logger.debug("⚡️ Flushed \(remaining.count) characters instantly")
        }

        // Cleanup
        characterQueues[answerId] = nil
        isCancelled[answerId] = nil
    }

    /// Cancel animation for an answer (usually on error or user cancellation)
    /// - Parameter answerId: Answer identifier
    func cancel(_ answerId: String) {
        logger.debug("❌ Cancelling animation for: \(answerId)")

        // Mark as cancelled
        isCancelled[answerId] = true

        // Cancel animation task
        animationTasks[answerId]?.cancel()
        animationTasks[answerId] = nil

        // Clear queue
        characterQueues[answerId] = nil
        isCancelled[answerId] = nil
    }

    // MARK: - Private Implementation

    /// Start character-by-character animation loop
    /// - Parameters:
    ///   - answerId: Answer identifier
    ///   - deliver: Callback to deliver displayed characters
    ///   - onComplete: Optional callback when animation completes naturally
    private func startAnimation(
        for answerId: String,
        deliver: @escaping @Sendable (String) async -> Void,
        onComplete: (@Sendable () async -> Void)? = nil
    ) async {
        logger.info("▶️ [TYPEWRITER] Starting character-by-character animation for: \(answerId)")

        let task = Task { @Sendable [weak self] in
            guard let self = self else { return }
            var displayedText = ""
            var isFirstCharacter = true

            while true {
                // Check if cancelled
                let cancelled = await self.isCancelled[answerId, default: false]
                if cancelled {
                    logger.debug("🛑 Animation cancelled for: \(answerId)")
                    break
                }

                // Get next character from queue
                let queue = await self.characterQueues[answerId]
                guard var queue = queue, !queue.isEmpty else {
                    // Queue empty - wait longer to ensure backend is truly done
                    // RACE CONDITION FIX: Extended wait prevents premature completion
                    // while backend is still streaming new content
                    try? await Task.sleep(for: .milliseconds(200))

                    // Double-check queue is still empty
                    let isEmpty = await self.characterQueues[answerId]?.isEmpty ?? true
                    if isEmpty {
                        // 🔍 CRITICAL FIX: Verify ALL enqueued chars were delivered before completion
                        let enqueued = await self.totalEnqueued[answerId, default: 0]
                        let delivered = await self.totalDelivered[answerId, default: 0]

                        logger.critical("🔍 [TYPEWRITER-COMPLETE] Queue empty check:")
                        logger.critical("🔍   Total enqueued: \(enqueued) chars")
                        logger.critical("🔍   Total delivered: \(delivered) chars")
                        logger.critical("🔍   Difference: \(enqueued - delivered) chars")

                        if delivered < enqueued {
                            logger.warning("⚠️ [TYPEWRITER] NOT all content delivered yet (\(delivered)/\(enqueued)) - waiting...")
                            // Wait a bit more for delivery to catch up
                            try? await Task.sleep(for: .milliseconds(100))
                            continue
                        }

                        logger.info("✅ [TYPEWRITER] Animation complete for: \(answerId) - All \(delivered) chars delivered")
                        await self.cleanupAnimation(for: answerId)

                        // Notify completion
                        if let onComplete = onComplete {
                            await onComplete()
                        }
                        break
                    }
                    continue
                }

                // Pop next character
                let character = queue.removeFirst()
                await self.updateQueue(answerId, queue: queue)

                // Calculate delay based on character type
                let delay = self.calculateDelay(for: character)

                // Apply delay BEFORE displaying character (creates smooth typewriter effect)
                // Skip delay for first character to show immediate response
                let stillActive = await self.isCancelled[answerId, default: false]
                if !stillActive && !isFirstCharacter {
                    try? await Task.sleep(for: .milliseconds(delay))
                }

                isFirstCharacter = false

                // Add to displayed text
                displayedText.append(character)

                // Track delivery
                await self.incrementDelivered(answerId)

                // Deliver updated text
                await deliver(displayedText)
            }
        }

        animationTasks[answerId] = task
    }

    /// Calculate delay based on character type (nonisolated for local access)
    /// - Parameter character: Character to display
    /// - Returns: Delay in milliseconds
    nonisolated private func calculateDelay(for character: Character) -> UInt64 {
        if punctuationChars.contains(character) {
            return punctuationDelay
        } else if character == " " {
            return spaceDelay
        } else {
            return baseDelay
        }
    }

    /// Update character queue
    /// - Parameters:
    ///   - answerId: Answer identifier
    ///   - queue: Updated queue
    private func updateQueue(_ answerId: String, queue: [Character]) {
        characterQueues[answerId] = queue
    }

    /// Cleanup animation state
    /// - Parameter answerId: Answer identifier
    private func cleanupAnimation(for answerId: String) {
        animationTasks[answerId] = nil
        characterQueues[answerId] = nil
        isCancelled[answerId] = nil
        totalEnqueued[answerId] = nil
        totalDelivered[answerId] = nil
    }

    /// Increment delivered character count
    /// - Parameter answerId: Answer identifier
    private func incrementDelivered(_ answerId: String) {
        totalDelivered[answerId, default: 0] += 1
    }
}
