//
//  CameraSessionManager.swift
//  balli
//
//  Manages camera session configuration and lifecycle
//

import Foundation
@preconcurrency import AVFoundation
@preconcurrency import UIKit
import os.log

/// Manages camera session configuration, lifecycle, and device switching
@MainActor
public class CameraSessionManager {
    private let logger = os.Logger(subsystem: "com.balli.diabetes", category: "CameraSessionManager")
    private let capabilities = CameraCapabilities()
    private let cleanupCoordinator = CleanupCoordinator()
    
    // MARK: - Session Components
    private var captureSession: AVCaptureSession?
    private var photoOutput: AVCapturePhotoOutput?
    private var videoInput: AVCaptureDeviceInput?
    private var currentDevice: AVCaptureDevice?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    // MARK: - Session State
    private var currentZoom: CameraZoom = .oneX
    private var currentConfiguration: CameraConfiguration?
    private let sessionQueue = DispatchQueue(label: "com.balli.camera.session", qos: .userInitiated)
    private var isConfiguringSession = false
    
    public init() {}

    deinit {
        // Cleanup handled by explicit cleanup methods
    }
    
    // MARK: - Public Interface
    
    /// Get capture session for preview
    public func getCaptureSession() -> AVCaptureSession? {
        return captureSession
    }
    
    /// Get current camera configuration
    public func getCameraConfiguration() -> CameraConfiguration? {
        return currentConfiguration
    }
    
    /// Get current zoom level
    public func getCurrentZoom() -> CameraZoom {
        return currentZoom
    }
    
    /// Get current device
    public func getCurrentDevice() -> AVCaptureDevice? {
        return currentDevice
    }
    
    /// Get photo output for capture operations
    public func getPhotoOutput() -> AVCapturePhotoOutput? {
        return photoOutput
    }
    
    /// Prepare camera session with parallelized initialization
    public func prepareSession() async throws -> CameraConfiguration {
        // Discover cameras and get configuration
        let config = try capabilities.discoverCameras()
        currentConfiguration = config

        let description = capabilities.capabilityDescription()
        logger.info("Discovered cameras: \(description)")
        
        // Configure session
        try await configureSession(with: config)
        
        return config
    }
    
    /// Setup session monitoring with MainActor isolation
    public func setupSessionMonitoring(systemMonitor: CameraSystemMonitor) async {
        // Setup monitoring using the internal session and device references
        if let session = captureSession {
            await systemMonitor.setupInterruptionMonitoring(for: session)
        }
        if let device = currentDevice {
            await systemMonitor.setupSystemPressureMonitoring(for: device)
        }
    }
    
    /// Start camera session
    public func startSession() async throws {
        guard let session = captureSession else {
            throw CameraError.sessionConfigurationFailed
        }
        
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            sessionQueue.async {
                if !session.isRunning {
                    session.startRunning()
                }
                continuation.resume()
            }
        }
        
        logger.info("✅ Camera session started")
    }
    
    /// Stop camera session
    public func stopSession() async {
        guard let session = captureSession else { return }
        
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            sessionQueue.async {
                if session.isRunning {
                    session.stopRunning()
                }
                continuation.resume()
            }
        }
        
        logger.info("🛑 Camera session stopped")
    }
    
    /// Switch camera to different zoom level
    public func switchCamera(to zoomLevel: CameraZoom) async throws {
        guard let config = currentConfiguration else {
            throw CameraError.sessionConfigurationFailed
        }
        
        currentZoom = zoomLevel
        logger.info("Switching to zoom level: \(zoomLevel.rawValue)")
        
        // Get the device for the requested zoom level
        let targetDevice = try await getDeviceForZoom(zoomLevel, config: config)
        
        // Check if we need to switch devices or just adjust zoom
        if let currentDevice = currentDevice,
           currentDevice.uniqueID == targetDevice.uniqueID {
            // Same device, just adjust zoom factor
            try await applyZoomFactor(zoomLevel.zoomFactor, to: currentDevice)
        } else {
            // Different device, need to switch
            try await switchToDevice(targetDevice)
        }
        
        logger.info("✅ Switched to \(zoomLevel.rawValue)")
    }
    
    // MARK: - Private Configuration
    
    private func configureSession(with config: CameraConfiguration) async throws {
        guard !isConfiguringSession else { return }
        isConfiguringSession = true
        defer { isConfiguringSession = false }
        
        // Get the best device for scanning
        guard let device = capabilities.getBestCameraForScanning() else {
            throw CameraError.deviceNotAvailable
        }

        // Create session
        let session = AVCaptureSession()
        
        // Pre-create input and output objects outside of configuration block
        let input: AVCaptureDeviceInput
        do {
            input = try AVCaptureDeviceInput(device: device)
        } catch {
            throw CameraError.captureDeviceLocked
        }
        
        let output = AVCapturePhotoOutput()
        
        // Configure on session queue with minimal work inside configuration block
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            sessionQueue.async {
                session.beginConfiguration()
                defer { session.commitConfiguration() }
                
                // Set highest quality session preset for clear preview
                self.configureSessionPreset(session)
                
                // Add pre-created input
                if session.canAddInput(input) {
                    session.addInput(input)
                } else {
                    continuation.resume(throwing: CameraError.sessionConfigurationFailed)
                    return
                }
                
                // Add pre-created output
                if session.canAddOutput(output) {
                    session.addOutput(output)
                    self.configurePhotoOutput(output, device: device)
                } else {
                    continuation.resume(throwing: CameraError.sessionConfigurationFailed)
                    return
                }
                
                continuation.resume()
            }
        }
        
        // Store references
        self.captureSession = session
        self.currentDevice = device
        
        // Sync initial zoom level with actual device type
        self.currentZoom = determineInitialZoom(device: device, config: config)
        
        // Find and store input/output
        if let input = session.inputs.first as? AVCaptureDeviceInput {
            self.videoInput = input
        }
        if let output = session.outputs.first as? AVCapturePhotoOutput {
            self.photoOutput = output
            logger.info("📸 Photo output stored: \(output)")
        } else {
            logger.error("📸 No photo output found in session outputs!")
        }
        
        // Register session for cleanup
        _ = await cleanupCoordinator.registerSession(
            session,
            description: "Main capture session"
        ) { [session] in
            session.stopRunning()
        }
    }
    
    private nonisolated func configureSessionPreset(_ session: AVCaptureSession) {
        // Try presets in order of quality
        if session.canSetSessionPreset(.hd4K3840x2160) {
            session.sessionPreset = .hd4K3840x2160
            logger.info("Using 4K preset for maximum quality")
        } else if session.canSetSessionPreset(.hd1920x1080) {
            session.sessionPreset = .hd1920x1080
            logger.info("Using 1080p preset for high quality")
        } else if session.canSetSessionPreset(.high) {
            session.sessionPreset = .high
            logger.info("Using high preset")
        } else if session.canSetSessionPreset(.photo) {
            session.sessionPreset = .photo
            logger.info("Using photo preset")
        }
    }
    
    private nonisolated func configurePhotoOutput(_ output: AVCapturePhotoOutput, device: AVCaptureDevice) {
        // Configure output after adding to session
        if #available(iOS 16.0, *) {
            // Set max dimensions after output is connected
            let format = device.activeFormat
            let dimensions = format.supportedMaxPhotoDimensions.last ?? CMVideoDimensions(width: 4032, height: 3024)
            output.maxPhotoDimensions = dimensions
        } else {
            output.isHighResolutionCaptureEnabled = true
        }
    }
    
    private func determineInitialZoom(device: AVCaptureDevice, config: CameraConfiguration) -> CameraZoom {
        if device.deviceType == .builtInUltraWideCamera {
            return .halfX
        } else if device.deviceType == .builtInWideAngleCamera || 
                  device.deviceType == .builtInDualCamera ||
                  device.deviceType == .builtInDualWideCamera ||
                  device.deviceType == .builtInTripleCamera {
            // For multi-camera systems, they typically start at ultra-wide (0.5x) 
            // but we need to check what's actually available
            if config.hasUltraWide {
                return .halfX  // Start with ultra-wide if available
            } else {
                return .oneX   // Fallback to 1x if no ultra-wide
            }
        } else {
            return .oneX
        }
    }
    
    private func switchToDevice(_ device: AVCaptureDevice) async throws {
        guard let session = captureSession else { return }
        
        let currentInput = self.videoInput
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            sessionQueue.async {
                session.beginConfiguration()
                defer { session.commitConfiguration() }
                
                // Remove current input
                if let currentInput = currentInput {
                    session.removeInput(currentInput)
                }
                
                // Add new input
                do {
                    let newInput = try AVCaptureDeviceInput(device: device)
                    if session.canAddInput(newInput) {
                        session.addInput(newInput)
                        continuation.resume()
                    } else {
                        continuation.resume(throwing: CameraError.sessionConfigurationFailed)
                    }
                } catch {
                    continuation.resume(throwing: CameraError.captureDeviceLocked)
                }
            }
        }
        
        // Update stored references after successful switch
        if let newInput = session.inputs.first as? AVCaptureDeviceInput {
            self.videoInput = newInput
            self.currentDevice = device
        }
    }
    
    private func applyZoomFactor(_ factor: CGFloat, to device: AVCaptureDevice) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            sessionQueue.async {
                do {
                    try device.lockForConfiguration()
                    device.videoZoomFactor = factor
                    device.unlockForConfiguration()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: CameraError.captureDeviceLocked)
                }
            }
        }
    }
    
    private func getDeviceForZoom(_ zoom: CameraZoom, config: CameraConfiguration) async throws -> AVCaptureDevice {
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInTripleCamera, .builtInDualWideCamera, .builtInUltraWideCamera, .builtInWideAngleCamera, .builtInTelephotoCamera],
            mediaType: .video,
            position: .back
        )
        
        let device: AVCaptureDevice?
        
        switch zoom {
        case .halfX:
            // Prefer ultra-wide if available, otherwise use wide
            device = discoverySession.devices.first { $0.deviceType == .builtInUltraWideCamera } ??
                     discoverySession.devices.first { $0.deviceType == .builtInWideAngleCamera }
        case .oneX:
            // Use wide angle camera
            device = discoverySession.devices.first { $0.deviceType == .builtInWideAngleCamera }
        case .twoX, .threeX:
            // Prefer telephoto if available, otherwise use wide with digital zoom
            device = discoverySession.devices.first { $0.deviceType == .builtInTelephotoCamera } ??
                     discoverySession.devices.first { $0.deviceType == .builtInWideAngleCamera }
        }
        
        guard let targetDevice = device else {
            throw CameraError.deviceNotAvailable
        }
        
        return targetDevice
    }
}