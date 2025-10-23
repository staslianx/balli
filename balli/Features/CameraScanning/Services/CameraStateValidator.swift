//
//  CameraStateValidator.swift
//  balli
//
//  Validates and manages camera state transitions
//

import Foundation
import os.log

/// Manages camera state transitions with validation and history tracking
public actor CameraStateValidator {
    private let logger = os.Logger(subsystem: "com.balli.diabetes", category: "CameraStateValidator")
    
    // MARK: - Properties
    private var currentState: CameraState = .uninitialized
    private var stateHistory: [StateTransition] = []
    private let maxHistorySize = 20
    private var stateTimeouts: [CameraState: Date] = [:]
    private let stateTimeout: TimeInterval = 30.0 // 30 seconds max for any state
    
    // MARK: - Valid Transitions
    private let validTransitions: [CameraState: Set<CameraState>] = [
        .uninitialized: [.preparingSession, .permissionDenied],
        .preparingSession: [.ready, .failed, .permissionDenied],
        .ready: [.capturingPhoto, .interrupted, .backgrounded, .failed, .thermallyThrottled],
        .capturingPhoto: [.processingCapture, .failed, .interrupted],
        .processingCapture: [.ready, .failed],
        .interrupted: [.ready, .failed, .backgrounded],
        .failed: [.uninitialized, .preparingSession],
        .backgrounded: [.uninitialized],
        .thermallyThrottled: [.ready, .failed],
        .permissionDenied: [.uninitialized]
    ]
    
    // MARK: - Public Interface
    
    /// Get current state
    public func getCurrentState() -> CameraState {
        currentState
    }
    
    /// Validate and perform state transition
    @discardableResult
    public func transition(to newState: CameraState, reason: String? = nil) throws -> StateTransition {
        // Check if transition is valid
        guard isValidTransition(from: currentState, to: newState) else {
            logger.error("Invalid state transition: \(self.currentState.rawValue) → \(newState.rawValue)")
            throw CameraError.invalidStateTransition(from: self.currentState, to: newState)
        }
        
        // Check for timeout
        if let timeoutDate = stateTimeouts[currentState],
           Date() > timeoutDate {
            logger.warning("State timeout detected for: \(self.currentState.rawValue)")
            // Force transition to failed state
            if currentState != .failed {
                _ = performTransition(to: .failed, reason: "State timeout")
            }
        }
        
        // Perform transition
        let transition = performTransition(to: newState, reason: reason)
        
        // Set timeout for new state if needed
        if newState.requiresTimeout {
            stateTimeouts[newState] = Date().addingTimeInterval(stateTimeout)
        } else {
            stateTimeouts.removeValue(forKey: newState)
        }
        
        return transition
    }
    
    /// Force a state transition (use with caution)
    public func forceTransition(to newState: CameraState, reason: String) -> StateTransition {
        logger.warning("Forcing state transition: \(self.currentState.rawValue) → \(newState.rawValue), reason: \(reason)")
        return performTransition(to: newState, reason: "FORCED: \(reason)")
    }
    
    /// Get state history
    public func getHistory() -> [StateTransition] {
        Array(stateHistory)
    }
    
    /// Get the last state transition
    public func getLastTransition() -> StateTransition? {
        stateHistory.last
    }
    
    /// Check if a transition is valid
    public func canTransition(to state: CameraState) -> Bool {
        isValidTransition(from: currentState, to: state)
    }
    
    /// Get valid next states from current state
    public func getValidNextStates() -> Set<CameraState> {
        validTransitions[currentState] ?? []
    }
    
    /// Check if current state has timed out
    public func hasTimedOut() -> Bool {
        if let timeoutDate = stateTimeouts[currentState] {
            return Date() > timeoutDate
        }
        return false
    }
    
    /// Clear timeout for current state
    public func clearTimeout() {
        stateTimeouts.removeValue(forKey: currentState)
    }
    
    /// Reset to initial state
    public func reset() {
        currentState = .uninitialized
        stateHistory.removeAll()
        stateTimeouts.removeAll()
        logger.info("State validator reset")
    }
    
    /// Get recovery state for current state
    public func getRecoveryState() -> CameraState {
        switch currentState {
        case .uninitialized, .permissionDenied:
            return .uninitialized
        case .preparingSession, .failed:
            return .uninitialized
        case .ready:
            return .ready
        case .capturingPhoto, .processingCapture:
            return .ready
        case .interrupted, .thermallyThrottled:
            return .ready
        case .backgrounded:
            return .uninitialized
        }
    }
    
    // MARK: - Private Methods
    
    private func isValidTransition(from: CameraState, to: CameraState) -> Bool {
        // Same state transitions are always valid (no-op)
        if from == to {
            return true
        }
        
        // Check valid transitions map
        guard let validStates = validTransitions[from] else {
            return false
        }
        
        return validStates.contains(to)
    }
    
    private func performTransition(to newState: CameraState, reason: String?) -> StateTransition {
        let transition = StateTransition(from: currentState, to: newState, reason: reason)
        
        // Update current state
        let oldState = currentState
        currentState = newState
        
        // Add to history
        stateHistory.append(transition)
        
        // Trim history if needed
        if stateHistory.count > maxHistorySize {
            stateHistory.removeFirst(stateHistory.count - maxHistorySize)
        }
        
        // Log transition
        logger.info("State transition: \(oldState.rawValue) → \(newState.rawValue)\(reason.map { ", reason: \($0)" } ?? "")")
        
        return transition
    }
    
    /// Analyze state history for patterns
    public func analyzeHistory() -> StateAnalysis {
        let recentHistory = stateHistory.suffix(10)
        
        // Count failures
        let failureCount = recentHistory.filter { $0.to == .failed }.count
        
        // Count interruptions
        let interruptionCount = recentHistory.filter { $0.to == .interrupted }.count
        
        // Calculate average time in states
        var stateDurations: [CameraState: TimeInterval] = [:]
        for i in 0..<recentHistory.count - 1 {
            let current = recentHistory[recentHistory.startIndex + i]
            let next = recentHistory[recentHistory.startIndex + i + 1]
            let duration = next.timestamp.timeIntervalSince(current.timestamp)
            
            stateDurations[current.to, default: 0] += duration
        }
        
        // Find stuck patterns (same transition repeated)
        var stuckPatterns: [(from: CameraState, to: CameraState, count: Int)] = []
        var lastTransition: (from: CameraState, to: CameraState)?
        var repeatCount = 0
        
        for transition in recentHistory {
            let current = (transition.from, transition.to)
            if let last = lastTransition, last == current {
                repeatCount += 1
            } else {
                if repeatCount > 2 {
                    if let last = lastTransition {
                        stuckPatterns.append((last.0, last.1, repeatCount))
                    }
                }
                lastTransition = current
                repeatCount = 1
            }
        }
        
        return StateAnalysis(
            failureCount: failureCount,
            interruptionCount: interruptionCount,
            averageStateDurations: stateDurations,
            stuckPatterns: stuckPatterns,
            isHealthy: failureCount < 3 && interruptionCount < 5 && stuckPatterns.isEmpty
        )
    }
}

// MARK: - State Analysis
public struct StateAnalysis: Sendable {
    let failureCount: Int
    let interruptionCount: Int
    let averageStateDurations: [CameraState: TimeInterval]
    let stuckPatterns: [(from: CameraState, to: CameraState, count: Int)]
    let isHealthy: Bool
}

// MARK: - State Extensions
extension CameraState {
    /// Whether this state requires timeout monitoring
    var requiresTimeout: Bool {
        switch self {
        case .preparingSession, .capturingPhoto, .processingCapture:
            return true
        default:
            return false
        }
    }
    
    /// Maximum allowed duration in this state
    var maxDuration: TimeInterval {
        switch self {
        case .preparingSession:
            return 10.0 // 10 seconds to prepare
        case .capturingPhoto:
            return 5.0 // 5 seconds to capture
        case .processingCapture:
            return 3.0 // 3 seconds to process
        default:
            return 30.0 // Default 30 seconds
        }
    }
}