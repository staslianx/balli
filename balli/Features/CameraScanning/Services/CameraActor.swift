//
//  CameraActor.swift
//  balli
//
//  Main camera manager implementing thread-safe camera operations on MainActor
//

import Foundation
@preconcurrency import AVFoundation
@preconcurrency import UIKit
import os.log

/// Thread-safe camera management class running on MainActor for optimal Swift 6 concurrency
@MainActor
public class CameraActor {
    private let logger = os.Logger(subsystem: "com.balli.diabetes", category: "CameraActor")

    // MARK: - Components (directly integrated, no actor isolation issues)
    private let stateManager = CameraStateManager()
    private let sessionManager = CameraSessionManager()
    private let captureHandler = CameraCaptureHandler()
    private let systemMonitor = CameraSystemMonitor()
    
    // MARK: - Performance Tracking
    private var sessionStartTime: Date?
    
    // MARK: - Initialization
    public init() {
        logger.debug("CameraActor initialized with delegated core implementation")
    }
    
    deinit {
        logger.debug("CameraActor deinitializing")
    }
    
    // MARK: - Public Interface (Direct Implementation)
    
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
    
    // MARK: - Session Management (Direct Implementation)
    
    /// Prepare camera session with optimized parallel initialization
    public func prepareSession() async throws {
        let currentState = await stateManager.getState()
        guard currentState == .uninitialized || currentState == .failed else {
            logger.debug("Session already prepared, state: \(currentState.rawValue)")
            return
        }
        
        sessionStartTime = Date()
        
        do {
            // Pre-warm camera hardware before state transition
            let preWarmTask = Task.detached(priority: .userInitiated) {
                await AVCaptureDevice.requestAccess(for: .video)
            }
            
            try await stateManager.transition(to: .preparingSession)
            await stateManager.notifyStateObservers()
            
            // True parallel execution with TaskGroup for better performance
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask(priority: .userInitiated) {
                    await self.systemMonitor.setupSystemMonitoring()
                }
                group.addTask(priority: .userInitiated) {
                    await self.stateManager.restoreState()
                }
                group.addTask(priority: .userInitiated) {
                    _ = try await self.sessionManager.prepareSession()
                }
                
                // Wait for all tasks to complete
                try await group.waitForAll()
            }
            
            // Setup monitoring for the session
            await sessionManager.setupSessionMonitoring(systemMonitor: systemMonitor)

            // Ensure pre-warm task completed
            _ = await preWarmTask.value
            
            // Track preparation time
            if let startTime = sessionStartTime {
                let preparationTime = Date().timeIntervalSince(startTime)
                captureHandler.updateSessionPreparationTime(preparationTime)
                logger.info("Camera prepared in \(String(format: "%.2f", preparationTime))s")

                // Log performance warning if too slow
                if preparationTime > 1.0 {
                    logger.warning("Camera preparation took longer than expected: \(String(format: "%.2f", preparationTime))s")
                }
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
    
    // MARK: - Camera Control (Direct Implementation)
    
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
    
    // MARK: - Photo Capture (Direct Implementation)
    
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
    
    // MARK: - Lifecycle Events (Direct Implementation)
    
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
    
    // MARK: - Permission Management (Direct Implementation)
    
    /// Request camera permission
    public func requestPermission() async throws -> Bool {
        return try await systemMonitor.requestPermission()
    }
    
    // MARK: - Performance & Diagnostics (Direct Implementation)
    
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
        
        let cleanupStatus = await systemMonitor.getCleanupStatus()
        diagnostics.append("Active Cleanup Items: \(cleanupStatus.totalItems)")
        
        return diagnostics
    }
    
    // MARK: - Cleanup (Direct Implementation)
    
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