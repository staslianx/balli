//
//  CameraActorCore.swift
//  balli
//
//  Main camera actor coordinator that manages all camera components
//

import Foundation
@preconcurrency import AVFoundation
@preconcurrency import UIKit
import os.log

/// Main camera coordinator that manages all camera operations through specialized components
@MainActor
public class CameraActorCore {
    private let logger = os.Logger(subsystem: "com.balli.diabetes", category: "CameraActorCore")

    // MARK: - Components (direct initialization, no isolation issues)
    private let stateManager = CameraStateManager()
    private let sessionManager = CameraSessionManager()
    private let captureHandler = CameraCaptureHandler()
    private let systemMonitor = CameraSystemMonitor()
    
    // MARK: - Performance Tracking
    private var sessionStartTime: Date?
    
    // MARK: - Initialization
    public init() {
        // Simple initialization since we're on MainActor - no isolation issues
    }
    
    deinit {
        // Cleanup handled by explicit cleanup method
    }
    
    // MARK: - Public Interface - State Management
    
    /// Get current camera state
    public func getState() async -> CameraState {
        await stateManager.getState()
    }
    
    /// Get current zoom level
    public func getCurrentZoom() -> CameraZoom {
        return sessionManager.getCurrentZoom()
    }
    
    /// Execute operation on capture session
    /// Direct access since we're on MainActor
    public func withCaptureSession<T>(_ operation: (AVCaptureSession?) -> T) -> T {
        return operation(sessionManager.getCaptureSession())
    }
    
    /// Get current camera configuration
    public func getCameraConfiguration() -> CameraConfiguration? {
        return sessionManager.getCameraConfiguration()
    }
    
    // MARK: - Public Interface - Observers
    
    /// Observe state changes
    public func observeState(_ observer: @escaping @Sendable (CameraState) -> Void) async -> UUID {
        return await stateManager.observeState(observer)
    }
    
    /// Remove state observer
    public func removeStateObserver(_ id: UUID) async {
        await stateManager.removeStateObserver(id)
    }
    
    /// Observe errors
    public func observeErrors(_ observer: @escaping @Sendable (CameraError) -> Void) async -> UUID {
        return await stateManager.observeErrors(observer)
    }
    
    /// Remove error observer
    public func removeErrorObserver(_ id: UUID) async {
        await stateManager.removeErrorObserver(id)
    }
    
    // MARK: - Public Interface - Session Management
    
    /// Prepare camera session with parallelized initialization
    public func prepareSession() async throws {
        let currentState = await stateManager.getState()
        guard currentState == .uninitialized || currentState == .failed else {
            logger.debug("Session already prepared, state: \(currentState.rawValue)")
            return
        }
        
        sessionStartTime = Date()
        
        do {
            try await stateManager.transition(to: .preparingSession)
            await stateManager.notifyStateObservers()
            
            // Parallelize independent operations
            async let monitoringTask: Void = systemMonitor.setupSystemMonitoring()
            async let stateTask: Void = stateManager.restoreState()
            async let sessionTask = sessionManager.prepareSession()
            
            // Wait for all parallel tasks
            _ = await monitoringTask
            _ = await stateTask
            _ = try await sessionTask
            
            // Setup monitoring for the session
            // Note: Session monitoring is set up through the session manager to avoid sending non-Sendable types
            await sessionManager.setupSessionMonitoring(systemMonitor: systemMonitor)
            
            // Track preparation time
            if let startTime = sessionStartTime {
                let preparationTime = Date().timeIntervalSince(startTime)
                captureHandler.updateSessionPreparationTime(preparationTime)
                logger.info("Camera prepared in \(preparationTime)s")
            }
            
            try await stateManager.transition(to: .ready)
            await stateManager.notifyStateObservers()
            
        } catch {
            try? await stateManager.transition(to: .failed, reason: error.localizedDescription)
            await stateManager.notifyStateObservers()
            await stateManager.notifyError(error as? CameraError ?? .sessionConfigurationFailed)
            throw error
        }
    }
    
    /// Start camera session
    public func startSession() async throws {
        let currentState = await stateManager.getState()
        
        switch currentState {
        case .ready, .interrupted:
            // Can start from these states
            break
        case .uninitialized, .failed:
            // Need to prepare first
            try await prepareSession()
        default:
            logger.warning("Cannot start session in state: \(currentState.rawValue)")
            return
        }

        // Check if session is ready using operation pattern
        let hasSession = withCaptureSession { session in
            session != nil
        }
        guard hasSession else {
            throw CameraError.sessionConfigurationFailed
        }
        
        let previewStartTime = Date()
        
        try await sessionManager.startSession()
        
        // Track preview start time
        let previewTime = Date().timeIntervalSince(previewStartTime)
        captureHandler.updatePreviewStartTime(previewTime)
        
        try await stateManager.transition(to: .ready)
        await stateManager.notifyStateObservers()
        
        logger.info("✅ Camera session running")
    }
    
    /// Stop camera session
    public func stopSession() async {
        await sessionManager.stopSession()
        
        let currentState = await stateManager.getState()
        if currentState == .ready {
            try? await stateManager.transition(to: .ready)
            await stateManager.notifyStateObservers()
        }
    }
    
    // MARK: - Public Interface - Camera Control
    
    /// Switch camera to different zoom level
    public func switchCamera(to zoomLevel: CameraZoom) async throws {
        let currentState = await stateManager.getState()
        guard currentState == .ready else {
            throw CameraError.invalidStateTransition(from: currentState, to: .ready)
        }
        
        try await sessionManager.switchCamera(to: zoomLevel)
        
        // Persist the new zoom level
        await stateManager.persistState(zoom: zoomLevel)
        
        // Update monitoring for new device if needed
        let device = sessionManager.getCurrentDevice()
        if let device = device {
            await systemMonitor.setupSystemPressureMonitoring(for: device)
        }
    }
    
    // MARK: - Public Interface - Photo Capture
    
    /// Capture a photo
    public func capturePhoto() async throws -> CaptureResult {
        guard let photoOutput = sessionManager.getPhotoOutput() else {
            throw CameraError.sessionConfigurationFailed
        }

        return try await captureHandler.capturePhoto(
            photoOutput: photoOutput,
            sessionManager: sessionManager,
            stateManager: stateManager
        )
    }
    
    // MARK: - Public Interface - Lifecycle Events
    
    /// Handle app entering background
    public func handleEnterBackground() async {
        await systemMonitor.handleEnterBackground()
        await stopSession()
    }
    
    /// Handle app entering foreground
    public func handleEnterForeground() async throws {
        let shouldRestart = try await systemMonitor.handleEnterForeground()
        if shouldRestart {
            try await startSession()
        }
    }
    
    // MARK: - Public Interface - Permission Management
    
    /// Request camera permission
    public func requestPermission() async throws -> Bool {
        return try await systemMonitor.requestPermission()
    }
    
    // MARK: - Public Interface - Diagnostics
    
    /// Get performance metrics
    public func getPerformanceMetrics() -> CameraPerformanceMetrics {
        return captureHandler.getPerformanceMetrics()
    }
    
    /// Get cleanup status
    public func getCleanupStatus() async -> CleanupStatus {
        return await systemMonitor.getCleanupStatus()
    }
    
    /// Run diagnostics
    public func runDiagnostics() async -> [String] {
        var diagnostics: [String] = []
        
        let state = await stateManager.getState()
        diagnostics.append("Current State: \(state.rawValue)")
        
        let zoom = sessionManager.getCurrentZoom()
        diagnostics.append("Current Zoom: \(zoom.rawValue)")

        let config = sessionManager.getCameraConfiguration()
        if let config = config {
            diagnostics.append("Has Ultra Wide: \(config.hasUltraWide)")
            diagnostics.append("Has Telephoto: \(config.hasTelephoto)")
        } else {
            diagnostics.append("Configuration: Not available")
        }
        
        // Get session diagnostics using operation pattern
        let sessionDiagnostics = withCaptureSession { session -> [String] in
            if let session = session {
                return [
                    "Session Running: \(session.isRunning)",
                    "Session Interrupted: \(session.isInterrupted)",
                    "Inputs Count: \(session.inputs.count)",
                    "Outputs Count: \(session.outputs.count)"
                ]
            } else {
                return ["Session: Not available"]
            }
        }
        diagnostics.append(contentsOf: sessionDiagnostics)

        let pendingCaptures = captureHandler.getPendingCaptureCount()
        diagnostics.append("Pending Captures: \(pendingCaptures)")

        let metrics = captureHandler.getPerformanceMetrics()
        diagnostics.append("Preparation Time: \(String(format: "%.2f", metrics.sessionPreparationTime))s")
        diagnostics.append("Capture Latency: \(String(format: "%.2f", metrics.captureLatency))s")
        diagnostics.append("Preview Start: \(String(format: "%.2f", metrics.previewStartTime))s")
        
        let cleanupStatus = await systemMonitor.getCleanupStatus()
        diagnostics.append("Active Cleanup Items: \(cleanupStatus.totalItems)")
        
        return diagnostics
    }
    
    /// Cleanup all resources
    public func cleanup() async {
        logger.info("Starting comprehensive camera cleanup")
        
        // Stop session first
        await stopSession()
        
        // Cleanup all components
        captureHandler.cleanup()
        await systemMonitor.cleanup()
        await stateManager.clearPersistedState()
        
        try? await stateManager.transition(to: .uninitialized)
        await stateManager.notifyStateObservers()
        
        logger.info("Camera cleanup complete")
    }
}
