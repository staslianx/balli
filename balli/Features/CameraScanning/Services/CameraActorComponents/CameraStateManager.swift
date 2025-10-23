//
//  CameraStateManager.swift
//  balli
//
//  Manages camera state transitions and persistence
//

import Foundation
@preconcurrency import AVFoundation
import os.log

/// Manages camera state transitions, validation, and persistence
public actor CameraStateManager {
    private let logger = os.Logger(subsystem: "com.balli.diabetes", category: "CameraStateManager")
    private let stateValidator = CameraStateValidator()
    
    // MARK: - State Management
    private var stateObservers: [UUID: @Sendable (CameraState) -> Void] = [:]
    private var errorObservers: [UUID: @Sendable (CameraError) -> Void] = [:]
    
    // MARK: - Persistence
    private let stateKey = "com.balli.camera.state"
    
    public init() {}
    
    // MARK: - Public Interface
    
    /// Get current camera state
    public func getState() async -> CameraState {
        await stateValidator.getCurrentState()
    }
    
    /// Transition to a new state
    public func transition(to state: CameraState, reason: String? = nil) async throws {
        _ = try await stateValidator.transition(to: state, reason: reason)
    }
    
    /// Observe state changes
    public func observeState(_ observer: @escaping @Sendable (CameraState) -> Void) async -> UUID {
        let id = UUID()
        stateObservers[id] = observer
        let currentState = await stateValidator.getCurrentState()
        observer(currentState)
        return id
    }
    
    /// Remove state observer
    public func removeStateObserver(_ id: UUID) async {
        stateObservers.removeValue(forKey: id)
    }
    
    /// Observe errors
    public func observeErrors(_ observer: @escaping @Sendable (CameraError) -> Void) async -> UUID {
        let id = UUID()
        errorObservers[id] = observer
        return id
    }
    
    /// Remove error observer
    public func removeErrorObserver(_ id: UUID) async {
        errorObservers.removeValue(forKey: id)
    }
    
    /// Notify state observers of state changes
    public func notifyStateObservers() async {
        let currentState = await stateValidator.getCurrentState()
        logger.debug("Notifying \(self.stateObservers.count) state observers of state: \(currentState.rawValue)")
        
        for observer in self.stateObservers.values {
            observer(currentState)
        }
    }
    
    /// Notify error observers of errors
    public func notifyError(_ error: CameraError) async {
        logger.warning("Notifying \(self.errorObservers.count) error observers of error: \(error.localizedDescription)")
        
        for observer in self.errorObservers.values {
            observer(error)
        }
    }
    
    // MARK: - State Persistence
    
    /// Restore saved camera state
    public func restoreState() async {
        guard let data = UserDefaults.standard.object(forKey: stateKey) as? Data,
              let savedState = try? JSONDecoder().decode(CameraPersistentState.self, from: data) else {
            logger.debug("No saved state found, using defaults")
            return
        }
        
        logger.info("Restored camera state: zoom=\(savedState.lastZoomLevel.rawValue)")
        // State restoration is handled by the main actor coordinator
    }
    
    /// Persist current camera state
    public func persistState(zoom: CameraZoom) async {
        let state = CameraPersistentState(
            lastZoomLevel: zoom,
            timestamp: Date()
        )
        
        do {
            let data = try JSONEncoder().encode(state)
            UserDefaults.standard.set(data, forKey: stateKey)
            logger.debug("Persisted camera state: zoom=\(zoom.rawValue)")
        } catch {
            logger.error("Failed to persist camera state: \(error.localizedDescription)")
        }
    }
    
    /// Clear persisted state
    public func clearPersistedState() {
        UserDefaults.standard.removeObject(forKey: stateKey)
        logger.debug("Cleared persisted camera state")
    }
}

// MARK: - Persistent State Model

private struct CameraPersistentState: Codable {
    let lastZoomLevel: CameraZoom
    let timestamp: Date
}