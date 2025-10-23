//
//  CaptureFlowStateMachine.swift
//  balli
//
//  State machine for managing capture flow states
//

import Foundation
import os.log

// MARK: - Capture Flow State Machine

@MainActor
public final class CaptureFlowStateMachine: CaptureStateMachine, ObservableObject {
    private let logger = os.Logger(subsystem: "com.balli.diabetes", category: "CaptureFlowStateMachine")
    
    // MARK: - Published Properties
    @Published public private(set) var currentState: CaptureFlowState = .idle
    @Published public private(set) var processingProgress: Double = 0.0
    
    // MARK: - Private Properties
    private var stateTransitionHistory: [(from: CaptureFlowState, to: CaptureFlowState, timestamp: Date)] = []
    private let maxHistoryCount = 50
    
    // MARK: - State Transition Rules
    private let validTransitions: [CaptureFlowState: Set<CaptureFlowState>] = [
        .idle: [.capturing, .cancelled],
        .capturing: [.captured, .failed, .cancelled],
        .captured: [.optimizing, .failed, .cancelled],
        .optimizing: [.processingAI, .failed, .cancelled],
        .processingAI: [.waitingForNetwork, .completed, .failed, .cancelled],
        .waitingForNetwork: [.processingAI, .failed, .cancelled],
        .completed: [.idle],
        .failed: [.idle, .capturing], // Allow retry
        .cancelled: [.idle]
    ]
    
    // MARK: - Initialization
    
    public init() {
        logger.info("Initializing CaptureFlowStateMachine")
    }
    
    // MARK: - Public Methods
    
    public func transition(to newState: CaptureFlowState) async {
        guard canTransition(from: currentState, to: newState) else {
            logger.warning("Invalid state transition attempted: \(self.currentState.rawValue) -> \(newState.rawValue)")
            return
        }
        
        let previousState = currentState
        currentState = newState
        
        // Record transition
        recordTransition(from: previousState, to: newState)
        
        // Update progress based on state
        updateProgress(for: newState)
        
        // Handle state-specific actions
        await handleStateChange(newState)
        
        logger.info("State transition: \(previousState.rawValue) -> \(newState.rawValue)")
    }
    
    public func canTransition(from: CaptureFlowState, to: CaptureFlowState) -> Bool {
        guard let validStates = validTransitions[from] else {
            return false
        }
        return validStates.contains(to)
    }
    
    public func handleStateChange(_ state: CaptureFlowState) async {
        switch state {
        case .idle:
            processingProgress = 0.0
            
        case .capturing:
            processingProgress = 0.1
            
        case .captured:
            processingProgress = 0.3
            
        case .optimizing:
            processingProgress = 0.5
            
        case .processingAI:
            processingProgress = 0.7
            
        case .waitingForNetwork:
            processingProgress = 0.8
            
        case .completed:
            processingProgress = 1.0
            
        case .failed, .cancelled:
            // Keep current progress for debugging
            break
        }
    }
    
    // MARK: - Progress Management
    
    public func updateProgress(_ progress: Double) {
        processingProgress = min(max(progress, 0.0), 1.0)
    }
    
    public func getProgressForState(_ state: CaptureFlowState) -> Double {
        switch state {
        case .idle: return 0.0
        case .capturing: return 0.1
        case .captured: return 0.3
        case .optimizing: return 0.5
        case .processingAI: return 0.7
        case .waitingForNetwork: return 0.8
        case .completed: return 1.0
        case .failed, .cancelled: return processingProgress // Keep current
        }
    }
    
    // MARK: - State Query Methods
    
    public var isActive: Bool {
        switch currentState {
        case .idle, .completed, .failed, .cancelled:
            return false
        default:
            return true
        }
    }
    
    public var canRetry: Bool {
        return currentState == .failed
    }
    
    public var isProcessing: Bool {
        switch currentState {
        case .optimizing, .processingAI, .waitingForNetwork:
            return true
        default:
            return false
        }
    }
    
    // MARK: - History Management
    
    private func recordTransition(from: CaptureFlowState, to: CaptureFlowState) {
        stateTransitionHistory.append((from: from, to: to, timestamp: Date()))
        
        // Maintain max history
        if stateTransitionHistory.count > maxHistoryCount {
            stateTransitionHistory.removeFirst()
        }
    }
    
    public func getTransitionHistory() -> [(from: CaptureFlowState, to: CaptureFlowState, timestamp: Date)] {
        return stateTransitionHistory
    }
    
    public func reset() {
        currentState = .idle
        processingProgress = 0.0
        stateTransitionHistory.removeAll()
        logger.info("State machine reset")
    }
    
    // MARK: - Debug Methods
    
    public func debugPrintState() {
        logger.debug("""
            Current State: \(self.currentState.rawValue)
            Progress: \(self.processingProgress)
            Is Active: \(self.isActive)
            Can Retry: \(self.canRetry)
            History Count: \(self.stateTransitionHistory.count)
        """)
    }
    
    private func updateProgress(for state: CaptureFlowState) {
        processingProgress = getProgressForState(state)
    }
}