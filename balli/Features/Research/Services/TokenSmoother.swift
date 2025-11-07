//
//  TokenSmoother.swift
//  balli
//
//  Token buffering and smooth delivery for streaming AI responses
//  Ensures consistent 50ms display rate to eliminate choppy rendering
//  Swift 6 strict concurrency compliant
//

import Foundation
import OSLog

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.balli",
    category: "TokenSmoother"
)

/// Actor that buffers incoming tokens and delivers them at a steady 50ms rate
/// Eliminates choppy streaming caused by irregular token arrival patterns from AI APIs
/// Thread-safe with isolated state per answerId
actor TokenSmoother {
    // MARK: - State

    /// Token queues per answer ID
    private var tokenQueues: [String: [String]] = [:]

    /// Active delivery tasks per answer ID
    private var deliveryTasks: [String: Task<Void, Never>] = [:]

    /// Consistent delivery interval (50ms matches MarkdownText debounce)
    private let deliveryInterval: Duration = .milliseconds(50)

    // MARK: - Public API

    /// Enqueue a token for smooth delivery
    /// Starts delivery task if not already running for this answer
    /// - Parameters:
    ///   - token: The token to enqueue
    ///   - answerId: Answer identifier
    ///   - deliver: Callback to deliver token to UI (must be @Sendable)
    func enqueueToken(
        _ token: String,
        for answerId: String,
        deliver: @escaping @Sendable (String) async -> Void
    ) async {
        // Initialize queue if needed
        if tokenQueues[answerId] == nil {
            tokenQueues[answerId] = []
        }

        // Add token to queue
        tokenQueues[answerId]?.append(token)

        let queueDepth = self.tokenQueues[answerId]?.count ?? 0
        logger.info("📥 [SMOOTHER] Enqueued token (length: \(token.count) chars) | Queue depth: \(queueDepth) | Content: '\(token.prefix(30))...'")

        // Start delivery if not already running
        if deliveryTasks[answerId] == nil {
            await startDelivery(for: answerId, deliver: deliver)
        }
    }

    /// Flush all remaining tokens immediately without smoothing
    /// Used when streaming completes or user cancels
    /// - Parameters:
    ///   - answerId: Answer identifier
    ///   - deliver: Callback to deliver tokens to UI
    func flushRemaining(
        _ answerId: String,
        deliver: @escaping @Sendable (String) async -> Void
    ) async {
        // Cancel ongoing delivery
        deliveryTasks[answerId]?.cancel()
        deliveryTasks[answerId] = nil

        // Deliver all remaining tokens immediately
        if let remainingTokens = tokenQueues[answerId], !remainingTokens.isEmpty {
            logger.info("🚿 Flushing \(remainingTokens.count) remaining tokens for \(answerId)")

            for token in remainingTokens {
                await deliver(token)
            }

            tokenQueues[answerId] = []
        }
    }

    /// Cancel delivery for an answer
    /// Clears queue and stops delivery task
    /// - Parameter answerId: Answer identifier
    func cancel(_ answerId: String) {
        deliveryTasks[answerId]?.cancel()
        deliveryTasks[answerId] = nil
        tokenQueues[answerId] = []

        logger.info("❌ Cancelled token delivery for \(answerId)")
    }

    /// Check if tokens are queued for an answer
    /// - Parameter answerId: Answer identifier
    /// - Returns: True if tokens are queued or being delivered
    func hasQueuedTokens(_ answerId: String) -> Bool {
        return !(tokenQueues[answerId]?.isEmpty ?? true)
    }

    // MARK: - Private Helpers

    /// Start smooth token delivery at steady 50ms intervals
    /// Runs until queue is empty, then stops automatically
    /// - Parameters:
    ///   - answerId: Answer identifier
    ///   - deliver: Callback to deliver tokens to UI
    private func startDelivery(
        for answerId: String,
        deliver: @escaping @Sendable (String) async -> Void
    ) async {
        // Create delivery task
        let task = Task {
            logger.debug("🚀 Started smooth delivery for \(answerId)")

            while !Task.isCancelled {
                // Get next token from queue
                guard let token = dequeueToken(for: answerId) else {
                    // Queue empty - stop delivery
                    break
                }

                // Deliver token to UI
                logger.info("📤 [SMOOTHER] Delivering token (length: \(token.count) chars) after 50ms delay")
                await deliver(token)

                // Wait 50ms before next token (steady rate)
                try? await Task.sleep(for: deliveryInterval)
            }

            if Task.isCancelled {
                logger.debug("⏸️ Delivery cancelled for \(answerId)")
            } else {
                logger.debug("✅ Delivery completed for \(answerId)")
            }

            // Clean up
            await cleanup(answerId)
        }

        // Store task
        deliveryTasks[answerId] = task
    }

    /// Dequeue next token for delivery
    /// - Parameter answerId: Answer identifier
    /// - Returns: Next token, or nil if queue is empty
    private func dequeueToken(for answerId: String) -> String? {
        // Safely remove and return first token, or nil if empty
        guard var queue = tokenQueues[answerId], !queue.isEmpty else {
            return nil
        }

        // Remove first token from queue
        let token = queue.removeFirst()

        // Update dictionary with modified queue
        tokenQueues[answerId] = queue

        return token
    }

    /// Clean up completed delivery task
    /// - Parameter answerId: Answer identifier
    private func cleanup(_ answerId: String) {
        deliveryTasks[answerId] = nil

        // Only remove queue if it's empty
        if tokenQueues[answerId]?.isEmpty ?? true {
            tokenQueues[answerId] = nil
        }
    }
}
