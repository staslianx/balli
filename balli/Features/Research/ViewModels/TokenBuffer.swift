import Foundation

/// An actor that buffers streaming tokens per answerId and delivers them in debounced batches.
public actor TokenBuffer {
    private var buffers: [String: String] = [:]
    private var pendingTasks: [String: Task<Void, Never>] = [:]

    /// Appends a token to the buffer for the specified answerId and schedules a debounced delivery.
    /// - Parameters:
    ///   - token: The token string to append.
    ///   - answerId: The identifier for the answer whose tokens are buffered.
    ///   - deliver: The closure called with the concatenated tokens after debounce.
    public func appendToken(_ token: String, for answerId: String, deliver: @escaping @Sendable (String) -> Void) async {
        buffers[answerId, default: ""] += token

        // Cancel existing task if any
        pendingTasks[answerId]?.cancel()

        // Schedule new debounce task
        let task = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(70))
            guard let self = self else { return }
            await self.deliverBufferedTokens(for: answerId, deliver: deliver)
        }
        pendingTasks[answerId] = task
    }

    /// Immediately flushes any buffered tokens for the specified answerId and delivers them.
    /// - Parameters:
    ///   - answerId: The identifier for the answer whose buffered tokens will be flushed.
    ///   - deliver: The closure called once with the concatenated tokens.
    public func flushRemaining(_ answerId: String, deliver: @escaping @Sendable (String) -> Void) async {
        // Cancel any pending task
        pendingTasks[answerId]?.cancel()
        pendingTasks.removeValue(forKey: answerId)

        await deliverBufferedTokens(for: answerId, deliver: deliver)
    }

    /// Cancels any pending delivery task and clears the buffer for the specified answerId.
    /// - Parameter answerId: The identifier for the answer to cancel buffering and delivery.
    public func cancel(_ answerId: String) async {
        pendingTasks[answerId]?.cancel()
        pendingTasks.removeValue(forKey: answerId)
        buffers.removeValue(forKey: answerId)
    }

    // MARK: - Private

    /// Drains the buffered tokens for an answerId and calls deliver if non-empty.
    private func deliverBufferedTokens(for answerId: String, deliver: @Sendable @escaping (String) -> Void) async {
        let batched = buffers[answerId] ?? ""
        buffers.removeValue(forKey: answerId)
        pendingTasks.removeValue(forKey: answerId)

        guard !batched.isEmpty else { return }

        Task.detached(priority: .utility) {
            deliver(batched)
        }
    }
}
