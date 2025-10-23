//
//  CameraCaptureHandler.swift
//  balli
//
//  Handles photo capture operations and delegate management
//

import Foundation
@preconcurrency import AVFoundation
@preconcurrency import UIKit
import os.log

/// Handles photo capture operations, delegate management, and capture result processing
@MainActor
public class CameraCaptureHandler {
    private let logger = os.Logger(subsystem: "com.balli.diabetes", category: "CameraCaptureHandler")
    
    // MARK: - Capture Management
    private var pendingCaptures: [(id: UUID, continuation: CheckedContinuation<CaptureResult, Error>)] = []
    private var activeDelegates: [UUID: PhotoCaptureDelegate] = [:]
    private let sessionQueue = DispatchQueue(label: "com.balli.camera.capture", qos: .userInitiated)
    
    // MARK: - Performance Tracking
    private var lastCaptureTime: Date?
    private var performanceMetrics = CameraPerformanceMetrics(
        sessionPreparationTime: 0,
        captureLatency: 0,
        previewStartTime: 0,
        memoryUsage: 0,
        cpuUsage: 0
    )
    
    public init() {}
    
    // MARK: - Public Interface
    
    /// Get performance metrics
    public func getPerformanceMetrics() -> CameraPerformanceMetrics {
        return performanceMetrics
    }
    
    /// Get last capture time
    public func getLastCaptureTime() -> Date? {
        return lastCaptureTime
    }
    
    /// Get pending capture count for diagnostics
    public func getPendingCaptureCount() -> Int {
        return pendingCaptures.count
    }
    
    /// Capture a photo with the given session manager and state manager
    public func capturePhoto(
        photoOutput: AVCapturePhotoOutput,
        sessionManager: CameraSessionManager,
        stateManager: CameraStateManager
    ) async throws -> CaptureResult {
        let currentState = await stateManager.getState()
        guard currentState == .ready else {
            throw CameraError.invalidStateTransition(from: currentState, to: .capturingPhoto)
        }
        
        try await stateManager.transition(to: .capturingPhoto)
        await stateManager.notifyStateObservers()
        
        let captureStartTime = Date()
        
        do {
            let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CaptureResult, Error>) in
                let continuationID = UUID()
                logger.info("📸 Creating continuation with ID: \(continuationID)")
                
                // Store continuation immediately for tracking
                self.pendingCaptures.append((id: continuationID, continuation: continuation))
                logger.info("📸 Stored continuation, pending captures count: \(self.pendingCaptures.count)")
                
                // Configure settings
                let settings = AVCapturePhotoSettings()
                settings.flashMode = .auto
                
                // Use high quality when available
                if #available(iOS 16.0, *) {
                    // Already set maxPhotoDimensions during configuration
                } else {
                    settings.isHighResolutionPhotoEnabled = photoOutput.isHighResolutionCaptureEnabled
                }
                
                // Create delegate and store it to prevent deallocation
                let delegate = PhotoCaptureDelegate(delegateID: continuationID) { [weak self] result in
                    Task {
                        await self?.handleCaptureResult(result, continuationID: continuationID)
                    }
                }
                
                // Store delegate to keep it alive
                self.activeDelegates[continuationID] = delegate
                logger.info("📸 Stored delegate, active delegates count: \(self.activeDelegates.count)")
                
                // Capture on session queue
                sessionQueue.async { [weak self] in
                    guard let self = self else { return }
                    
                    // Log session status (session details are managed by sessionManager)
                    
                    self.logger.info("📸 Calling photoOutput.capturePhoto with delegate ID: \(continuationID)")
                    photoOutput.capturePhoto(with: settings, delegate: delegate)
                    self.logger.info("📸 photoOutput.capturePhoto called successfully")
                }
            }
            
            // Track capture latency
            let captureLatency = Date().timeIntervalSince(captureStartTime)
            performanceMetrics = CameraPerformanceMetrics(
                sessionPreparationTime: performanceMetrics.sessionPreparationTime,
                captureLatency: captureLatency,
                previewStartTime: performanceMetrics.previewStartTime,
                memoryUsage: performanceMetrics.memoryUsage,
                cpuUsage: performanceMetrics.cpuUsage
            )
            
            lastCaptureTime = Date()
            
            try await stateManager.transition(to: .processingCapture)
            await stateManager.notifyStateObservers()
            
            try await stateManager.transition(to: .ready)
            await stateManager.notifyStateObservers()
            
            return result
            
        } catch {
            // Ensure we return to ready state on error
            try? await stateManager.transition(to: .ready)
            await stateManager.notifyStateObservers()
            throw error
        }
    }
    
    /// Update session preparation time in performance metrics
    public func updateSessionPreparationTime(_ time: TimeInterval) {
        performanceMetrics = CameraPerformanceMetrics(
            sessionPreparationTime: time,
            captureLatency: performanceMetrics.captureLatency,
            previewStartTime: performanceMetrics.previewStartTime,
            memoryUsage: performanceMetrics.memoryUsage,
            cpuUsage: performanceMetrics.cpuUsage
        )
    }
    
    /// Update preview start time in performance metrics
    public func updatePreviewStartTime(_ time: TimeInterval) {
        performanceMetrics = CameraPerformanceMetrics(
            sessionPreparationTime: performanceMetrics.sessionPreparationTime,
            captureLatency: performanceMetrics.captureLatency,
            previewStartTime: time,
            memoryUsage: performanceMetrics.memoryUsage,
            cpuUsage: performanceMetrics.cpuUsage
        )
    }
    
    /// Clean up all pending captures and delegates
    public func cleanup() {
        logger.info("Cleaning up capture handler - \(self.pendingCaptures.count) pending, \(self.activeDelegates.count) delegates")
        
        // Cancel all pending captures
        for (_, continuation) in pendingCaptures {
            continuation.resume(throwing: CameraError.sessionConfigurationFailed)
        }
        pendingCaptures.removeAll()
        
        // Clear all active delegates
        activeDelegates.removeAll()
        
        logger.info("Capture handler cleanup complete")
    }
    
    // MARK: - Private Capture Handling
    
    private func handleCaptureResult(_ result: Result<CaptureResult, Error>, continuationID: UUID) {
        logger.info("📸 handleCaptureResult called for ID: \(continuationID)")
        logger.info("📸 Pending captures before lookup: \(self.pendingCaptures.count)")
        
        // Remove delegate now that capture is complete
        activeDelegates.removeValue(forKey: continuationID)
        logger.info("📸 Removed delegate, remaining: \(self.activeDelegates.count)")
        
        // Find and remove pending capture
        if let index = pendingCaptures.firstIndex(where: { $0.id == continuationID }) {
            logger.info("📸 Found continuation at index: \(index)")
            let (_, continuation) = pendingCaptures.remove(at: index)
            
            switch result {
            case .success(let captureResult):
                continuation.resume(returning: captureResult)
                
            case .failure(let error):
                continuation.resume(throwing: error)
            }
        } else {
            logger.error("Could not find continuation for capture ID: \(continuationID)")
        }
    }
}