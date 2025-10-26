//
//  CameraPreviewLayer.swift
//  balli
//
//  Camera preview layer for SwiftUI
//  UIViewRepresentable wrapper for AVCaptureVideoPreviewLayer
//
//  JUSTIFICATION FOR UIKIT USAGE:
//  iOS 26 does not provide a native SwiftUI component for live camera preview.
//  AVCaptureVideoPreviewLayer is Apple's official API for displaying camera feeds
//  and requires UIKit integration. This is NOT legacy code - it's the current
//  standard approach for camera preview in iOS.
//
//  Swift 6 strict concurrency compliant with @MainActor isolation
//

import SwiftUI
import AVFoundation
import OSLog

/// SwiftUI wrapper for AVCaptureVideoPreviewLayer
///
/// This UIViewRepresentable is **necessary** because iOS 26 SwiftUI has no native
/// camera preview component. AVCaptureVideoPreviewLayer is the Apple-provided API
/// for rendering live camera feeds and requires UIKit/CALayer integration.
///
/// Critical for food label scanning functionality - DO NOT remove.
struct CameraPreviewLayer: UIViewRepresentable {
    let cameraManager: CameraManager
    private let logger = AppLoggers.UI.camera
    
    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        context.coordinator.previewView = view
        return view
    }
    
    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        // Update the session when it changes
        if let session = cameraManager.captureSession {
            logger.debug("Setting session, isRunning: \(session.isRunning)")
            uiView.setSession(session, logger: logger)
        } else {
            logger.debug("No session available")
        }
    }
    
    @MainActor
    class CameraPreviewUIView: UIView {
        private var previewLayer: AVCaptureVideoPreviewLayer?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            backgroundColor = .black
        }
        
        required init?(coder: NSCoder) {
            super.init(coder: coder)
            backgroundColor = .black
        }
        
        override func layoutSubviews() {
            super.layoutSubviews()
            
            // Only update frame if we have valid bounds
            guard !bounds.isEmpty else { return }
            
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            previewLayer?.frame = bounds
            CATransaction.commit()
        }
        
        func setSession(_ session: AVCaptureSession?, logger: Logger) {
            logger.debug("setSession called, session: \(session != nil)")

            // Don't recreate if we already have the same session
            if let existingSession = previewLayer?.session, existingSession == session {
                logger.debug("Same session, skipping recreation")
                return
            }

            // Remove existing preview layer
            previewLayer?.removeFromSuperlayer()
            previewLayer = nil

            guard let session = session else {
                logger.debug("No session, returning")
                return
            }

            // Wait for valid bounds before creating preview layer
            Task { @MainActor [weak self] in
                guard let self = self else { return }

                let targetBounds: CGRect
                if self.bounds.isEmpty {
                    // Try to get bounds from window first, fallback to window scene screen
                    if let windowBounds = self.window?.bounds, !windowBounds.isEmpty {
                        targetBounds = windowBounds
                    } else if let screenBounds = self.window?.windowScene?.screen.bounds {
                        targetBounds = screenBounds
                    } else {
                        // Final fallback to reasonable default
                        targetBounds = CGRect(x: 0, y: 0, width: 393, height: 852)
                    }
                } else {
                    targetBounds = self.bounds
                }
                logger.debug("Creating preview layer with bounds: \(String(describing: targetBounds))")

                // Create new preview layer
                let newPreviewLayer = AVCaptureVideoPreviewLayer(session: session)
                newPreviewLayer.videoGravity = .resizeAspectFill
                newPreviewLayer.frame = targetBounds

                if let connection = newPreviewLayer.connection {
                    if #available(iOS 17.0, *) {
                        connection.videoRotationAngle = 90 // Portrait orientation
                    } else {
                        connection.videoOrientation = .portrait
                    }
                    logger.debug("Set video orientation")
                }

                // Add to view
                self.layer.addSublayer(newPreviewLayer)
                self.previewLayer = newPreviewLayer

                logger.debug("Preview layer added, frame: \(String(describing: newPreviewLayer.frame))")
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(cameraManager: cameraManager)
    }
    
    class Coordinator: NSObject {
        let cameraManager: CameraManager
        weak var previewView: CameraPreviewUIView?
        
        init(cameraManager: CameraManager) {
            self.cameraManager = cameraManager
        }
    }
}