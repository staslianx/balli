//
//  CameraSystemMonitor.swift
//  balli
//
//  Handles system monitoring and lifecycle events for camera operations
//

import Foundation
@preconcurrency import AVFoundation
@preconcurrency import UIKit
@preconcurrency import ObjectiveC
import os.log

/// Monitors system events, thermal state, and manages camera lifecycle events
public actor CameraSystemMonitor {
    private let logger = os.Logger(subsystem: "com.balli.diabetes", category: "CameraSystemMonitor")
    private let cleanupCoordinator = CleanupCoordinator()
    
    // MARK: - System Observers
    private var thermalStateObserver: NSObjectProtocol?
    private var systemPressureObserver: NSKeyValueObservation?
    private var interruptionObserver: NSObjectProtocol?
    private var runtimeErrorObserver: NSObjectProtocol?
    
    // MARK: - State
    private var wasBackgrounded = false
    
    public init() {}
    
    // MARK: - Public Interface
    
    /// Setup all system monitoring for the camera session
    public func setupSystemMonitoring() async {
        await setupThermalMonitoring()
        logger.info("System monitoring configured")
    }
    
    /// Setup system pressure monitoring for a specific device
    public func setupSystemPressureMonitoring(for device: AVCaptureDevice) async {
        // Clean up previous observer
        if let observer = systemPressureObserver {
            _ = await cleanupCoordinator.registerObserver(
                observer,
                description: "System pressure observer"
            ) { [observer] in
                observer.invalidate()
            }
        }
        
        // Setup new observer
        systemPressureObserver = device.observe(\.systemPressureState, options: .new) { [weak self] _, change in
            guard let pressureState = change.newValue else { return }
            
            Task {
                await self?.handleSystemPressure(pressureState)
            }
        }
        
        logger.info("System pressure monitoring configured for device: \(device.localizedName)")
    }
    
    /// Setup interruption monitoring for a capture session
    public func setupInterruptionMonitoring(for session: AVCaptureSession?) async {
        await setupSessionInterruptionMonitoring(session)
        await setupRuntimeErrorMonitoring(session)
        logger.info("Interruption monitoring configured")
    }
    
    /// Handle app entering background
    public func handleEnterBackground() async {
        wasBackgrounded = true
        logger.info("📱 Camera entering background")
        
        // System will automatically suspend camera when backgrounded
        // We just track the state for restoration
    }
    
    /// Handle app entering foreground
    public func handleEnterForeground() async throws -> Bool {
        if wasBackgrounded {
            logger.info("📱 Camera returning from background")
            wasBackgrounded = false
            return true // Indicates session should be restarted
        }
        return false
    }
    
    /// Request camera permission if needed
    public func requestPermission() async throws -> Bool {
        let currentStatus = AVCaptureDevice.authorizationStatus(for: .video)

        switch currentStatus {
        case .authorized:
            logger.info("Camera permission already granted")
            return true

        case .notDetermined:
            // Request permission from the user
            logger.info("Requesting camera permission from user")
            let granted = await AVCaptureDevice.requestAccess(for: .video)

            if !granted {
                logger.warning("Camera permission denied by user")
                throw CameraError.permissionDenied
            }

            // Small delay for system to settle after first-time grant
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1s
            logger.info("Camera permission granted")
            return true

        case .denied, .restricted:
            logger.warning("Camera permission denied or restricted")
            throw CameraError.permissionDenied

        @unknown default:
            logger.error("Unknown camera permission status")
            throw CameraError.permissionDenied
        }
    }
    
    /// Get cleanup status for diagnostics
    public func getCleanupStatus() async -> CleanupStatus {
        return await cleanupCoordinator.getStatus()
    }
    
    /// Clean up all system monitoring
    public func cleanup() async {
        logger.info("Cleaning up system monitoring")
        
        // Clean up thermal state observer
        if let observer = thermalStateObserver {
            NotificationCenter.default.removeObserver(observer)
            thermalStateObserver = nil
        }
        
        // Clean up system pressure observer
        systemPressureObserver?.invalidate()
        systemPressureObserver = nil
        
        // Clean up interruption observer
        if let observer = interruptionObserver {
            NotificationCenter.default.removeObserver(observer)
            interruptionObserver = nil
        }
        
        // Clean up runtime error observer
        if let observer = runtimeErrorObserver {
            NotificationCenter.default.removeObserver(observer)
            runtimeErrorObserver = nil
        }
        
        // Clean up coordinator resources
        await cleanupCoordinator.cleanupAll()
        
        logger.info("System monitoring cleanup complete")
    }
    
    // MARK: - Private Setup Methods
    
    private func setupThermalMonitoring() async {
        // Thermal state monitoring
        nonisolated(unsafe) let thermalObserver = self.thermalStateObserver
        _ = await cleanupCoordinator.registerObserver(
            ProcessInfo.thermalStateDidChangeNotification,
            description: "Thermal state observer"
        ) {
            if let observer = thermalObserver {
                NotificationCenter.default.removeObserver(observer)
            }
        }
        
        thermalStateObserver = NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task {
                await self?.handleThermalStateChange()
            }
        }
    }
    
    private func setupSessionInterruptionMonitoring(_ session: AVCaptureSession?) async {
        // Session interruption
        nonisolated(unsafe) let interruptObserver = self.interruptionObserver
        _ = await cleanupCoordinator.registerObserver(
            AVCaptureSession.interruptionEndedNotification,
            description: "Interruption observer"
        ) {
            if let observer = interruptObserver {
                NotificationCenter.default.removeObserver(observer)
            }
        }
        
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVCaptureSession.wasInterruptedNotification,
            object: session,
            queue: .main
        ) { [weak self] notification in
            // Extract needed data before entering async context
            let reasonValue = notification.userInfo?[AVCaptureSessionInterruptionReasonKey] as? Int
            
            Task { @MainActor in
                await self?.handleInterruption(reasonValue: reasonValue)
            }
        }
    }
    
    private func setupRuntimeErrorMonitoring(_ session: AVCaptureSession?) async {
        // Runtime error
        nonisolated(unsafe) let runtimeObserver = self.runtimeErrorObserver
        _ = await cleanupCoordinator.registerObserver(
            AVCaptureSession.runtimeErrorNotification,
            description: "Runtime error observer"
        ) {
            if let observer = runtimeObserver {
                NotificationCenter.default.removeObserver(observer)
            }
        }
        
        runtimeErrorObserver = NotificationCenter.default.addObserver(
            forName: AVCaptureSession.runtimeErrorNotification,
            object: session,
            queue: .main
        ) { [weak self] notification in
            // Extract error before entering async context
            let error = notification.userInfo?[AVCaptureSessionErrorKey] as? AVError
            
            Task {
                await self?.handleRuntimeError(error: error)
            }
        }
    }
    
    // MARK: - Event Handlers
    
    private func handleThermalStateChange() async {
        let thermalState = ProcessInfo.processInfo.thermalState
        logger.info("Thermal state changed: \(String(describing: thermalState))")
        
        // Notify parent about thermal state changes
        await notifyThermalStateChange(thermalState)
    }
    
    private func handleSystemPressure(_ pressure: AVCaptureDevice.SystemPressureState) async {
        logger.warning("System pressure: \(pressure.level.rawValue)")
        
        // Notify parent about system pressure changes
        await notifySystemPressureChange(pressure)
    }
    
    private func handleInterruption(reasonValue: Int?) async {
        let reason: AVCaptureSession.InterruptionReason?
        if let value = reasonValue {
            reason = AVCaptureSession.InterruptionReason(rawValue: value)
        } else {
            reason = nil
        }
        
        logger.warning("Camera session interrupted: \(reason?.rawValue ?? -1)")
        
        // Notify parent about interruption
        await notifyInterruption(reason)
    }
    
    private func handleRuntimeError(error: AVError?) async {
        if let error = error {
            logger.error("Camera runtime error: \(error.localizedDescription)")
            
            // Notify parent about runtime error
            await notifyRuntimeError(error)
        }
    }
    
    // MARK: - Notification Methods (to be implemented by parent)
    
    private func notifyThermalStateChange(_ state: ProcessInfo.ThermalState) async {
        // This would be implemented by the parent coordinator
        // For now, just log the event
        logger.info("Thermal state notification: \(state.rawValue)")
    }
    
    private func notifySystemPressureChange(_ pressure: AVCaptureDevice.SystemPressureState) async {
        // This would be implemented by the parent coordinator
        logger.info("System pressure notification: \(pressure.level.rawValue)")
    }
    
    private func notifyInterruption(_ reason: AVCaptureSession.InterruptionReason?) async {
        // This would be implemented by the parent coordinator
        logger.info("Interruption notification: \(reason?.rawValue ?? -1)")
    }
    
    private func notifyRuntimeError(_ error: AVError) async {
        // This would be implemented by the parent coordinator
        logger.error("Runtime error notification: \(error.localizedDescription)")
    }
}