//
//  AsyncTimerSequence.swift
//  balli
//
//  Modern async/await timer sequence for Swift 6
//  Replaces legacy Timer and DispatchQueue patterns
//

import Foundation

/// Async sequence that emits on a regular interval
/// Replacement for Timer.scheduledTimer for Swift 6 strict concurrency
///
/// Usage:
/// ```swift
/// for await tick in AsyncTimerSequence(interval: .seconds(1)) {
///     print("Tick: \(tick)")
/// }
/// ```
struct AsyncTimerSequence: AsyncSequence {
    typealias Element = Date

    let interval: Duration
    let tolerance: Duration?

    /// Create a timer sequence
    /// - Parameters:
    ///   - interval: Time between emissions
    ///   - tolerance: Acceptable timing variance for battery optimization (default: 10% of interval)
    init(interval: Duration, tolerance: Duration? = nil) {
        self.interval = interval
        self.tolerance = tolerance ?? Duration.milliseconds(Int(interval.components.seconds * 100))
    }

    func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(interval: interval, tolerance: tolerance)
    }

    struct AsyncIterator: AsyncIteratorProtocol {
        let interval: Duration
        let tolerance: Duration?

        func next() async -> Date? {
            try? await Task.sleep(for: interval, tolerance: tolerance)
            return Date()
        }
    }
}
