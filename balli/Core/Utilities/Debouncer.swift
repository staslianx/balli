//
//  Debouncer.swift
//  balli
//
//  Reusable debouncing utility for rate-limiting operations
//  Swift 6 strict concurrency compliant
//

import Foundation
import OSLog

// MARK: - Main Actor Debouncer

/// A debouncer for operations that must run on the main actor
/// Use this for UI-related debouncing
@MainActor
final class Debouncer {
    private var task: Task<Void, Never>?
    private let logger = AppLoggers.Performance.main

    /// Debounces an async action
    /// - Parameters:
    ///   - interval: Delay in seconds before executing action
    ///   - action: Async action to execute
    func debounce(interval: TimeInterval, action: @escaping @MainActor () async -> Void) {
        // Cancel any existing pending task
        task?.cancel()

        // Create new debounced task
        task = Task { @MainActor in
            do {
                try await Task.sleep(for: .seconds(interval))

                // Only execute if not cancelled
                guard !Task.isCancelled else {
                    logger.debug("Debounced action cancelled")
                    return
                }

                await action()
            } catch {
                // Task was cancelled or sleep failed
                logger.debug("Debounce task interrupted: \(error.localizedDescription)")
            }
        }
    }

    /// Cancels any pending debounced action
    func cancel() {
        task?.cancel()
        task = nil
    }

    /// Check if there's a pending action
    var isPending: Bool {
        task != nil && !(task?.isCancelled ?? true)
    }

    deinit {
        task?.cancel()
    }
}

// MARK: - Actor-Isolated Debouncer

/// An actor-isolated debouncer for operations that need their own isolation domain
/// Use this for business logic that doesn't need main actor
actor ActorDebouncer {
    private var task: Task<Void, Never>?
    private let logger = AppLoggers.Performance.main

    /// Debounces an async action in an actor-isolated context
    /// - Parameters:
    ///   - interval: Delay in seconds before executing action
    ///   - action: Async action to execute
    func debounce(interval: TimeInterval, action: @escaping () async -> Void) {
        // Cancel any existing pending task
        task?.cancel()

        // Create new debounced task
        task = Task {
            do {
                try await Task.sleep(for: .seconds(interval))

                // Only execute if not cancelled
                guard !Task.isCancelled else {
                    logger.debug("Debounced action cancelled")
                    return
                }

                await action()
            } catch {
                // Task was cancelled or sleep failed
                logger.debug("Debounce task interrupted: \(error.localizedDescription)")
            }
        }
    }

    /// Cancels any pending debounced action
    func cancel() {
        task?.cancel()
        task = nil
    }

    /// Check if there's a pending action
    var isPending: Bool {
        task != nil && !(task?.isCancelled ?? true)
    }

    deinit {
        task?.cancel()
    }
}

// MARK: - Throttler

/// A throttler that ensures an action is executed at most once per interval
/// Unlike debouncing, throttling executes immediately and then blocks subsequent calls
@MainActor
final class Throttler {
    private var lastExecutionTime: Date?
    private let logger = AppLoggers.Performance.main

    /// Throttles an action to execute at most once per interval
    /// - Parameters:
    ///   - interval: Minimum time between executions
    ///   - action: Action to execute
    /// - Returns: True if action was executed, false if throttled
    @discardableResult
    func throttle(interval: TimeInterval, action: @MainActor () async -> Void) async -> Bool {
        let now = Date()

        if let lastTime = lastExecutionTime {
            let timeSinceLastExecution = now.timeIntervalSince(lastTime)
            if timeSinceLastExecution < interval {
                logger.debug("Action throttled - \(String(format: "%.1f", interval - timeSinceLastExecution))s remaining")
                return false
            }
        }

        lastExecutionTime = now
        await action()
        return true
    }

    /// Reset the throttler state
    func reset() {
        lastExecutionTime = nil
    }

    /// Check if the throttler would allow execution now
    func canExecute(interval: TimeInterval) -> Bool {
        guard let lastTime = lastExecutionTime else { return true }
        return Date().timeIntervalSince(lastTime) >= interval
    }
}

// MARK: - Actor-Isolated Throttler

/// An actor-isolated throttler for operations that need their own isolation domain
actor ActorThrottler {
    private var lastExecutionTime: Date?
    private let logger = AppLoggers.Performance.main

    /// Throttles an action to execute at most once per interval
    /// - Parameters:
    ///   - interval: Minimum time between executions
    ///   - action: Action to execute
    /// - Returns: True if action was executed, false if throttled
    @discardableResult
    func throttle(interval: TimeInterval, action: () async -> Void) async -> Bool {
        let now = Date()

        if let lastTime = lastExecutionTime {
            let timeSinceLastExecution = now.timeIntervalSince(lastTime)
            if timeSinceLastExecution < interval {
                logger.debug("Action throttled - \(String(format: "%.1f", interval - timeSinceLastExecution))s remaining")
                return false
            }
        }

        lastExecutionTime = now
        await action()
        return true
    }

    /// Reset the throttler state
    func reset() {
        lastExecutionTime = nil
    }

    /// Check if the throttler would allow execution now
    func canExecute(interval: TimeInterval) -> Bool {
        guard let lastTime = lastExecutionTime else { return true }
        return Date().timeIntervalSince(lastTime) >= interval
    }
}
