import Foundation
import OSLog

/// Configuration for retry behavior with exponential backoff
public struct RetryConfiguration: Sendable {
    let maxAttempts: Int
    let initialDelay: TimeInterval
    let backoffMultiplier: Double
    let maxDelay: TimeInterval
    let shouldRetry: @Sendable (Error) -> Bool

    public init(
        maxAttempts: Int = 3,
        initialDelay: TimeInterval = 1.0,
        backoffMultiplier: Double = 2.0,
        maxDelay: TimeInterval = 30.0,
        shouldRetry: @escaping @Sendable (Error) -> Bool = NetworkRetryHandler.defaultShouldRetry
    ) {
        self.maxAttempts = maxAttempts
        self.initialDelay = initialDelay
        self.backoffMultiplier = backoffMultiplier
        self.maxDelay = maxDelay
        self.shouldRetry = shouldRetry
    }

    /// Standard configuration for network operations
    public static let network = RetryConfiguration(
        maxAttempts: 3,
        initialDelay: 1.0,
        backoffMultiplier: 2.0,
        maxDelay: 30.0
    )

    /// Configuration for critical operations requiring more attempts
    public static let critical = RetryConfiguration(
        maxAttempts: 5,
        initialDelay: 2.0,
        backoffMultiplier: 2.0,
        maxDelay: 60.0
    )

    /// Configuration for fast-failing operations
    public static let quick = RetryConfiguration(
        maxAttempts: 2,
        initialDelay: 0.5,
        backoffMultiplier: 2.0,
        maxDelay: 10.0
    )
}

/// Errors specific to retry operations
public enum RetryError: LocalizedError, Sendable {
    case maxAttemptsExceeded(attempts: Int, lastError: Error?)
    case operationCancelled

    public var errorDescription: String? {
        switch self {
        case .maxAttemptsExceeded(let attempts, let lastError):
            if let lastError = lastError {
                return "Operation failed after \(attempts) attempts. Last error: \(lastError.localizedDescription)"
            } else {
                return "Operation failed after \(attempts) attempts"
            }
        case .operationCancelled:
            return "Operation was cancelled"
        }
    }
}

/// Network retry handler with exponential backoff
public enum NetworkRetryHandler {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.balli",
        category: "NetworkRetryHandler"
    )

    // MARK: - Main Retry Function

    /// Executes an async operation with exponential backoff retry logic
    /// - Parameters:
    ///   - configuration: Retry configuration parameters
    ///   - operation: The async operation to retry
    /// - Returns: Result of the operation if successful
    /// - Throws: RetryError.maxAttemptsExceeded if all attempts fail, or the underlying error if not retryable
    public static func retryWithBackoff<T>(
        configuration: RetryConfiguration = .network,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        var currentDelay = configuration.initialDelay
        var lastError: Error?

        for attempt in 1...configuration.maxAttempts {
            // Check if task is cancelled
            if Task.isCancelled {
                logger.warning("Retry operation cancelled at attempt \(attempt)")
                throw RetryError.operationCancelled
            }

            do {
                let result = try await operation()

                if attempt > 1 {
                    logger.info("Operation succeeded on attempt \(attempt)")
                }

                return result
            } catch {
                lastError = error

                // Check if we should retry this error
                if !configuration.shouldRetry(error) {
                    logger.warning("Error is not retryable: \(error.localizedDescription)")
                    throw error
                }

                // Don't wait after the last attempt
                if attempt < configuration.maxAttempts {
                    logger.warning("Attempt \(attempt)/\(configuration.maxAttempts) failed: \(error.localizedDescription). Retrying in \(String(format: "%.1f", currentDelay))s")

                    try await Task.sleep(nanoseconds: UInt64(currentDelay * 1_000_000_000))

                    // Calculate next delay with cap
                    currentDelay = min(currentDelay * configuration.backoffMultiplier, configuration.maxDelay)
                } else {
                    logger.error("All \(configuration.maxAttempts) attempts failed. Last error: \(error.localizedDescription)")
                }
            }
        }

        throw RetryError.maxAttemptsExceeded(attempts: configuration.maxAttempts, lastError: lastError)
    }

    // MARK: - Simple Retry

    /// Executes an async operation with simple retry logic (fixed delay)
    /// - Parameters:
    ///   - times: Number of attempts
    ///   - delay: Fixed delay between attempts
    ///   - operation: The async operation to retry
    /// - Returns: Result of the operation if successful
    public static func retry<T>(
        times: Int = 3,
        delay: TimeInterval = 2.0,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        var lastError: Error?

        for attempt in 1...times {
            if Task.isCancelled {
                throw RetryError.operationCancelled
            }

            do {
                return try await operation()
            } catch {
                lastError = error

                if attempt < times {
                    logger.warning("Attempt \(attempt)/\(times) failed, retrying...")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }

        throw RetryError.maxAttemptsExceeded(attempts: times, lastError: lastError)
    }

    // MARK: - Error Classification

    /// Default retry logic: determines if an error is worth retrying
    public static func defaultShouldRetry(_ error: Error) -> Bool {
        // URLError cases
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut,
                 .cannotConnectToHost,
                 .networkConnectionLost,
                 .notConnectedToInternet,
                 .dnsLookupFailed,
                 .cannotFindHost,
                 .dataNotAllowed,
                 .internationalRoamingOff:
                return true
            case .badServerResponse,
                 .cannotDecodeContentData,
                 .cannotDecodeRawData:
                return true
            default:
                return false
            }
        }

        // NSError cases
        if let nsError = error as NSError? {
            // Network errors
            if nsError.domain == NSURLErrorDomain {
                return true
            }

            // Temporary file system errors
            if nsError.domain == NSCocoaErrorDomain {
                switch nsError.code {
                case NSFileReadNoSuchFileError,
                     NSFileReadUnknownError,
                     NSFileWriteNoPermissionError:
                    return false
                case NSFileReadCorruptFileError,
                     NSFileWriteUnknownError:
                    return true
                default:
                    return false
                }
            }
        }

        return false
    }

    /// Checks if an error indicates a rate limit
    public static func isRateLimitError(_ error: Error) -> Bool {
        if error is URLError {
            // Some APIs return 429 as bad URL
            return false
        }

        if let nsError = error as NSError? {
            // Check for HTTP 429 status code
            if nsError.domain == NSURLErrorDomain,
               let response = nsError.userInfo[NSURLErrorFailingURLErrorKey] as? String,
               response.contains("429") {
                return true
            }
        }

        return false
    }

    /// Extracts retry-after duration from error if available
    public static func retryAfter(from error: Error) -> TimeInterval? {
        if let nsError = error as NSError?,
           let retryAfter = nsError.userInfo["Retry-After"] as? String,
           let seconds = TimeInterval(retryAfter) {
            return seconds
        }
        return nil
    }
}

// MARK: - Fallback Utilities

/// Utility for implementing fallback strategies when operations fail
public enum FallbackUtility {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.balli",
        category: "FallbackUtility"
    )

    /// Tries primary operation, falls back to secondary if it fails
    public static func withFallback<T>(
        primary: @escaping @Sendable () async throws -> T,
        fallback: @escaping @Sendable () async throws -> T,
        logContext: String = "Operation"
    ) async throws -> T {
        do {
            return try await primary()
        } catch {
            logger.warning("\(logContext) failed with error: \(error.localizedDescription). Attempting fallback...")
            return try await fallback()
        }
    }

    /// Tries primary operation, returns cached value on failure
    public static func withCacheFallback<T>(
        primary: @escaping @Sendable () async throws -> T,
        cache: @escaping @Sendable () async -> T?,
        updateCache: @escaping @Sendable (T) async -> Void,
        logContext: String = "Operation"
    ) async throws -> T {
        do {
            let result = try await primary()
            await updateCache(result)
            return result
        } catch {
            logger.warning("\(logContext) failed, attempting cache fallback")

            if let cached = await cache() {
                logger.info("Using cached data for \(logContext)")
                return cached
            }

            logger.error("No cache available for \(logContext)")
            throw error
        }
    }

    /// Executes multiple operations in parallel, returns partial results
    public static func allowPartialFailure<T: Sendable>(
        operations: [@Sendable () async throws -> T],
        logContext: String = "Parallel operations"
    ) async -> [Result<T, Error>] where T: Sendable {
        await withTaskGroup(of: Result<T, Error>.self) { group in
            for operation in operations {
                group.addTask {
                    do {
                        let result = try await operation()
                        return .success(result)
                    } catch {
                        logger.warning("\(logContext): One operation failed: \(error.localizedDescription)")
                        return .failure(error)
                    }
                }
            }

            var results: [Result<T, Error>] = []
            for await result in group {
                results.append(result)
            }

            let successCount = results.filter { if case .success = $0 { return true }; return false }.count
            logger.info("\(logContext): \(successCount)/\(operations.count) operations succeeded")

            return results
        }
    }
}

// MARK: - Constants

private enum RetryConstants {
    static let maxAttempts = 3
    static let initialDelaySeconds: TimeInterval = 1.0
    static let backoffMultiplier: Double = 2.0
    static let maxDelaySeconds: TimeInterval = 30.0
}
