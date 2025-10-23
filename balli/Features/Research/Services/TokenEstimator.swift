import Foundation

/// Utility for estimating token counts in conversation messages
enum TokenEstimator {
    /// Average characters per token for Turkish text
    /// Based on empirical analysis: Turkish text averages ~4 characters per token
    private static let charactersPerToken: Double = 4.0

    /// Safety threshold (tokens) before gracefully ending session
    /// Claude has 200K context window, we set threshold at 150K for safety
    static let safetyThreshold = 150_000

    /// Estimates total token count for a conversation history
    /// - Parameter messages: Array of conversation messages
    /// - Returns: Estimated token count
    static func estimateTokens(_ messages: [SessionMessageData]) -> Int {
        let totalCharacters = messages.reduce(0) { sum, message in
            sum + message.content.count
        }

        return Int(Double(totalCharacters) / charactersPerToken)
    }

    /// Estimates token count for a single message
    /// - Parameter message: The message to estimate
    /// - Returns: Estimated token count
    static func estimateTokens(for message: SessionMessageData) -> Int {
        return Int(Double(message.content.count) / charactersPerToken)
    }

    /// Estimates token count for text content
    /// - Parameter text: The text to estimate
    /// - Returns: Estimated token count
    static func estimateTokens(for text: String) -> Int {
        return Int(Double(text.count) / charactersPerToken)
    }

    /// Checks if a conversation is approaching the token limit
    /// - Parameter messages: Array of conversation messages
    /// - Returns: True if approaching limit (>80% of threshold)
    static func isApproachingLimit(_ messages: [SessionMessageData]) -> Bool {
        let tokenCount = estimateTokens(messages)
        let threshold = Int(Double(safetyThreshold) * 0.8)
        return tokenCount > threshold
    }

    /// Checks if a conversation has exceeded the safe token limit
    /// - Parameter messages: Array of conversation messages
    /// - Returns: True if limit exceeded
    static func hasExceededLimit(_ messages: [SessionMessageData]) -> Bool {
        let tokenCount = estimateTokens(messages)
        return tokenCount > safetyThreshold
    }

    /// Returns a formatted string showing token usage
    /// - Parameter messages: Array of conversation messages
    /// - Returns: Formatted string (e.g., "45,000 / 150,000 tokens")
    static func formatTokenUsage(_ messages: [SessionMessageData]) -> String {
        let current = estimateTokens(messages)
        let formatted = NumberFormatter.localizedString(from: NSNumber(value: current), number: .decimal)
        let threshold = NumberFormatter.localizedString(from: NSNumber(value: safetyThreshold), number: .decimal)
        return "\(formatted) / \(threshold) tokens"
    }

    /// Returns percentage of token limit used
    /// - Parameter messages: Array of conversation messages
    /// - Returns: Percentage (0.0 to 1.0+)
    static func percentageUsed(_ messages: [SessionMessageData]) -> Double {
        let current = Double(estimateTokens(messages))
        let limit = Double(safetyThreshold)
        return current / limit
    }
}
