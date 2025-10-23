//
//  CameraManager.swift
//  balli
//
//  SwiftUI-compatible camera manager
//

import SwiftUI
import Combine
@preconcurrency import AVFoundation
import os.log

/// Main camera manager for SwiftUI views
@MainActor
public class CameraManager: ObservableObject {
    private let logger = os.Logger(subsystem: "com.balli.diabetes", category: "CameraManager")
    
    // MARK: - Published Properties
    @Published public var state: CameraState = .uninitialized
    @Published public var isCapturing = false
    @Published public var lastCapturedImage: UIImage?
    @Published public var error: CameraError?
    @Published public var showingPermissionAlert = false
    @Published public var currentZoom: CameraZoom = .oneX
    @Published public var availableZoomLevels: [CameraZoom] = [.oneX]
    @Published public var isSessionRunning = false
    @Published public var captureSession: AVCaptureSession?
    
    // MARK: - Camera Components
    private let cameraActor = CameraActor()
    private var stateObserverID: UUID?
    private var errorObserverID: UUID?
    private var lifecycleObserver: Any?
    
    // MARK: - Performance Tracking
    @Published public var performanceMetrics: CameraPerformanceMetrics?
    @Published public var diagnosticMessages: [String] = []
    
    // MARK: - Initialization
    public init() {
        setupObservers()
        setupLifecycleObservation()
        
        // Check initial permission status
        checkPermissionStatus()
    }
    
    deinit {
        // Lifecycle observer cleanup handled by NotificationCenter
    }
    
    // MARK: - Setup
    
    private func setupObservers() {
        // State observation
        Task {
            stateObserverID = await cameraActor.observeState { @Sendable [weak self] newState in
                Task { @MainActor in
                    self?.handleStateChange(newState)
                }
            }
            
            // Error observation
            errorObserverID = await cameraActor.observeErrors { @Sendable [weak self] error in
                Task { @MainActor in
                    self?.handleError(error)
                }
            }
        }
    }
    
    private func setupLifecycleObservation() {
        // Scene phase changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleScenePhaseChange),
            name: UIScene.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleScenePhaseChange),
            name: UIScene.willEnterForegroundNotification,
            object: nil
        )
        
        // Permission changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePermissionChange),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    // MARK: - Public Methods
    
    /// Prepare camera for use
    public func prepare() async {
        logger.info("Preparing camera")
        
        do {
            // Request permission if needed
            let hasPermission = try await cameraActor.requestPermission()
            guard hasPermission else {
                showingPermissionAlert = true
                return
            }
            
            // Prepare session
            try await cameraActor.prepareSession()
            
            // Start session
            try await cameraActor.startSession()
            
            // Update available zoom levels
            await updateAvailableZoomLevels()

            // Sync current zoom with actual camera state
            let actualZoom = cameraActor.getCurrentZoom()
            self.currentZoom = actualZoom
            logger.info("✅ Camera initialized at zoom level: \(actualZoom.rawValue)")

            // Get capture session for preview using operation pattern
            self.captureSession = cameraActor.withCaptureSession { session in
                session
            }
            logger.info("Got capture session: \(self.captureSession != nil)")
            
            isSessionRunning = true
            
        } catch {
            logger.error("Failed to prepare camera: \(error)")
            self.error = error as? CameraError
        }
    }
    
    /// Stop camera session
    public func stop() async {
        logger.info("Stopping camera")
        await cameraActor.stopSession()
        isSessionRunning = false
    }
    
    /// Capture a photo
    public func capturePhoto() async {
        guard self.state.canCapture else {
            logger.warning("Cannot capture in state: \(self.state.rawValue)")
            return
        }
        
        do {
            isCapturing = true
            
            let result = try await cameraActor.capturePhoto()
            
            // Process captured image
            let processor = CaptureProcessor()
            let processedImage = await processor.processForScanning(result.image)
            
            lastCapturedImage = processedImage
            
            // Log performance
            logger.info("Photo captured: \(String(describing: result.image.size)), zoom: \(result.metadata.zoomFactor))")
            
        } catch {
            logger.error("Capture failed: \(error)")
            self.error = error as? CameraError
        }
        
        isCapturing = false
    }
    
    /// Switch camera zoom level
    public func switchZoom() async {
        let nextZoom = getNextAvailableZoom()
        await setZoom(nextZoom)
    }
    
    /// Set specific zoom level
    public func setZoom(_ zoomLevel: CameraZoom) async {
        guard availableZoomLevels.contains(zoomLevel) else { return }
        
        do {
            try await cameraActor.switchCamera(to: zoomLevel)
            currentZoom = zoomLevel
        } catch {
            logger.error("Failed to switch zoom: \(error)")
            self.error = error as? CameraError
        }
    }
    
    /// Run diagnostics
    public func runDiagnostics() async {
        let issues = await cameraActor.runDiagnostics()
        diagnosticMessages = issues
        
        // Get performance metrics
        performanceMetrics = cameraActor.getPerformanceMetrics()
        
        // Check cleanup status
        let cleanupStatus = await cameraActor.getCleanupStatus()
        if cleanupStatus.totalItems > 50 {
            diagnosticMessages.append("High resource count: \(cleanupStatus.totalItems)")
        }
    }
    
    /// Clear last captured image
    public func clearCapturedImage() {
        lastCapturedImage = nil
    }
    
    // MARK: - Permission Handling
    
    /// Check camera permission status
    public func checkPermissionStatus() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch status {
        case .authorized:
            showingPermissionAlert = false
            
        case .denied, .restricted:
            Task { @MainActor in
                handleStateChange(.permissionDenied)
            }
            
        case .notDetermined:
            // Will request when needed
            break
            
        @unknown default:
            break
        }
    }
    
    /// Open system settings
    public func openSettings() {
        guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else { return }
        
        if UIApplication.shared.canOpenURL(settingsUrl) {
            UIApplication.shared.open(settingsUrl)
        }
    }
    
    // MARK: - Private Methods
    
    private func handleStateChange(_ newState: CameraState) {
        state = newState
        
        // Update UI based on state
        switch newState {
        case .capturingPhoto, .processingCapture:
            isCapturing = true
            
        case .permissionDenied:
            self.showingPermissionAlert = true
            self.isSessionRunning = false
            
        case .failed:
            isSessionRunning = false
            
        case .ready:
            isCapturing = false
            error = nil
            
        default:
            isCapturing = false
        }
        
        logger.debug("Camera state changed: \(newState.rawValue)")
    }
    
    private func handleError(_ error: CameraError) {
        self.error = error
        
        // Show permission alert for permission errors
        if case .permissionDenied = error {
            showingPermissionAlert = true
        }
        
        logger.error("Camera error: \(error.localizedDescription)")
    }
    
    @objc private func handleScenePhaseChange(_ notification: Notification) {
        Task {
            switch notification.name {
            case UIScene.didEnterBackgroundNotification:
                await cameraActor.handleEnterBackground()
                isSessionRunning = false
                
            case UIScene.willEnterForegroundNotification:
                do {
                    try await cameraActor.handleEnterForeground()
                    if state == .ready {
                        isSessionRunning = true
                    }
                } catch {
                    logger.error("Failed to restore camera: \(error)")
                }
                
            default:
                break
            }
        }
    }
    
    @objc private func handlePermissionChange() {
        // Recheck permissions when app becomes active
        checkPermissionStatus()
    }
    
    private func updateAvailableZoomLevels() async {
        // Get the actual available zoom levels from the camera actor
        let configuration = cameraActor.getCameraConfiguration()
        if let config = configuration {
            availableZoomLevels = config.supportedZoomLevels
            logger.info("Updated available zoom levels: \(self.availableZoomLevels.map { $0.rawValue }.joined(separator: ", "))")
        } else {
            // Fallback to just 1x if we can't determine capabilities
            availableZoomLevels = [.oneX]
            logger.warning("Could not determine camera capabilities, defaulting to 1x only")
        }
    }
    
    private func getNextAvailableZoom() -> CameraZoom {
        guard let currentIndex = availableZoomLevels.firstIndex(of: currentZoom) else {
            return .oneX
        }
        
        let nextIndex = (currentIndex + 1) % availableZoomLevels.count
        return availableZoomLevels[nextIndex]
    }
    
}

// MARK: - Preview Support
extension CameraManager {
    /// Create a mock manager for SwiftUI previews
    static func preview(state: CameraState = .ready) -> CameraManager {
        let manager = CameraManager()
        manager.state = state
        // For preview, only show zoom levels that would be available on a dual-camera phone
        manager.availableZoomLevels = [.halfX, .oneX]
        return manager
    }
}

// MARK: - Camera Preview Layer
/// UIKit view for camera preview
public struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession?
    
    public func makeUIView(context: Context) -> UIView {
        let view = UIView()
        
        if let session = session {
            let previewLayer = AVCaptureVideoPreviewLayer(session: session)
            previewLayer.videoGravity = .resizeAspectFill
            previewLayer.frame = view.bounds
            view.layer.addSublayer(previewLayer)
            
            // Store reference for updates
            view.layer.setValue(previewLayer, forKey: "previewLayer")
        }
        
        return view
    }
    
    public func updateUIView(_ uiView: UIView, context: Context) {
        // Update preview layer frame
        if let previewLayer = uiView.layer.value(forKey: "previewLayer") as? AVCaptureVideoPreviewLayer {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            previewLayer.frame = uiView.bounds
            CATransaction.commit()
        }
    }
}