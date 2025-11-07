//
//  ResearchConnectionRetrier.swift
//  balli
//
//  Network retry logic with exponential backoff for streaming AI research
//  Handles transient network failures gracefully with automatic reconnection
//  Swift 6 strict concurrency compliant
//

import Foundation
import OSLog

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.balli",
    category: "ResearchConnectionRetrier"
)

/// Actor that wraps network operations with retry logic and exponential backoff
/// Only retries on network-related errors (timeouts, connection lost)
/// Does NOT retry on client errors (4xx), server errors (5xx), or decoder errors
actor ResearchConnectionRetrier {
    // MARK: - Configuration

    /// Maximum number of retry attempts (total: 1 initial + 3 retries = 4 attempts)
    private let maxRetryAttempts: Int = 3

    /// Base delay for exponential backoff (doubles each retry: 1s → 2s → 4s)
    private let baseDelay: TimeInterval = 1.0

    // MARK: - Retry Logic

    /// Execute operation with automatic retry on network failures
    /// Uses exponential backoff: 1s → 2s → 4s
    /// - Parameters:
    ///   - operation: Async operation to execute (receives attempt number)
    ///   - onReconnecting: Called when starting a retry (receives attempt number)
    ///   - onReconnected: Called when retry succeeds after failure
    /// - Returns: Result of successful operation
    /// - Throws: Last error if all retries exhausted, or non-retryable error immediately
    func executeWithRetry<T>(
        operation: @Sendable @escaping (Int) async throws -> T,
        onReconnecting: (@Sendable (Int) async -> Void)? = nil,
        onReconnected: (@Sendable () async -> Void)? = nil
    ) async throws -> T {
        var attemptCount = 0
        var lastError: Error?
        var hadFailure = false

        while attemptCount <= maxRetryAttempts {
            do {
                logger.debug("🔄 Attempt \(attemptCount + 1)/\(self.maxRetryAttempts + 1)")

                // Execute operation
                let result = try await operation(attemptCount)

                // If we had failures but now succeeded, notify reconnection
                if hadFailure {
                    logger.info("✅ Reconnected successfully after \(attemptCount) retries")
                    await onReconnected?()
                }

                return result

            } catch let error {
                lastError = error
                attemptCount += 1

                // Check if error is retryable
                guard shouldRetry(error) else {
                    logger.warning("❌ Non-retryable error: \(error.localizedDescription)")
                    throw error
                }

                // Check if we've exhausted retries
                guard attemptCount <= maxRetryAttempts else {
                    logger.error("💥 All retry attempts exhausted after \(attemptCount) tries")
                    throw error
                }

                // Calculate delay with exponential backoff
                let delay = calculateBackoffDelay(attempt: attemptCount)
                logger.info("⏳ Network error - retrying in \(delay)s (attempt \(attemptCount)/\(self.maxRetryAttempts))")

                // Notify reconnection attempt
                hadFailure = true
                await onReconnecting?(attemptCount)

                // Wait before retry
                try await Task.sleep(for: .seconds(delay))
            }
        }

        // This should never happen (loop exits on success or throw), but satisfy compiler
        throw lastError ?? RetrierError.unknownFailure
    }

    // MARK: - Private Helpers

    /// Determine if error should trigger a retry
    /// Only network-related errors are retryable
    /// - Parameter error: Error to check
    /// - Returns: True if error is network-related and retryable
    private func shouldRetry(_ error: Error) -> Bool {
        // Check for URLError (network errors)
        if let urlError = error as? URLError {
            switch urlError.code {
            case .networkConnectionLost,
                 .notConnectedToInternet,
                 .timedOut,
                 .cannotConnectToHost,
                 .cannotFindHost,
                 .dnsLookupFailed,
                 .internationalRoamingOff,
                 .dataNotAllowed:
                return true
            default:
                return false
            }
        }

        // Don't retry on other error types (decoder errors, client errors, etc.)
        return false
    }

    /// Calculate exponential backoff delay
    /// Formula: baseDelay * (2 ^ (attempt - 1))
    /// Result: 1s → 2s → 4s
    /// - Parameter attempt: Current attempt number (1-based)
    /// - Returns: Delay in seconds
    private func calculateBackoffDelay(attempt: Int) -> TimeInterval {
        // Exponential backoff: 1s, 2s, 4s
        let multiplier = pow(2.0, Double(attempt - 1))
        return baseDelay * multiplier
    }
}

// MARK: - Error Types

enum RetrierError: LocalizedError {
    case unknownFailure

    var errorDescription: String? {
        switch self {
        case .unknownFailure:
            return "Connection failed for unknown reason"
        }
    }
}
