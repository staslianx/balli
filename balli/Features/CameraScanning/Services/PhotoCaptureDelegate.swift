//
//  PhotoCaptureDelegate.swift
//  balli
//
//  Handles photo capture callbacks from AVFoundation
//

import Foundation
import AVFoundation
import UIKit
import os.log

/// Delegate for handling photo capture results
final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    private let logger = os.Logger(subsystem: "com.balli.diabetes", category: "PhotoCapture")
    private let completion: @Sendable (Result<CaptureResult, Error>) -> Void
    private let delegateID: UUID
    private var captureStartTime: Date?
    
    init(
        delegateID: UUID,
        completion: @escaping @Sendable (Result<CaptureResult, Error>) -> Void
    ) {
        self.delegateID = delegateID
        self.completion = completion
        super.init()
    }
    
    // MARK: - AVCapturePhotoCaptureDelegate
    
    func photoOutput(_ output: AVCapturePhotoOutput, willBeginCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
        captureStartTime = Date()
        logger.info("📸 PhotoCaptureDelegate: willBeginCaptureFor called - ID: \(self.delegateID)")
        logger.debug("Photo capture beginning: \(resolvedSettings.uniqueID)")
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, willCapturePhotoFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
        // This is when the actual photo is taken (shutter sound)
        logger.info("📸 PhotoCaptureDelegate: willCapturePhotoFor called - ID: \(self.delegateID)")
        logger.debug("Photo capturing: \(resolvedSettings.uniqueID)")
    }
    
    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        logger.info("📸 PhotoCaptureDelegate: didFinishProcessingPhoto called for ID: \(self.delegateID)")
        let captureTime = Date().timeIntervalSince(captureStartTime ?? Date())
        logger.debug("Photo processing finished in \(captureTime)s")
        
        // Handle error
        if let error = error {
            logger.error("Photo capture failed: \(error)")
            completion(.failure(CameraError.failedToCapture(description: error.localizedDescription)))
            return
        }
        
        // Extract image data
        guard let imageData = photo.fileDataRepresentation() else {
            logger.error("Failed to get image data representation")
            completion(.failure(CameraError.failedToCapture(description: "No image data")))
            return
        }
        
        // Create UIImage
        guard let image = UIImage(data: imageData) else {
            logger.error("Failed to create UIImage from data")
            completion(.failure(CameraError.failedToCapture(description: "Invalid image data")))
            return
        }
        
        // Extract metadata
        let metadata = extractMetadata(from: photo)
        
        // Create capture result
        let result = CaptureResult(
            image: image,
            metadata: metadata,
            timestamp: Date()
        )
        
        logger.info("Photo captured successfully: \(String(describing: image.size)), \(imageData.count) bytes")
        completion(.success(result))
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        // Final callback - capture session is complete
        if let error = error {
            logger.error("Capture session failed: \(String(describing: error))")
            // Only call completion if we haven't already
            if captureStartTime != nil {
                completion(.failure(CameraError.failedToCapture(description: error.localizedDescription)))
            }
        }
        
        logger.debug("Capture session finished: \(resolvedSettings.uniqueID)")
    }
    
    // MARK: - Private Methods
    
    private func extractMetadata(from photo: AVCapturePhoto) -> CaptureMetadata {
        // Extract device type from metadata if available
        let deviceType: AVCaptureDevice.DeviceType = .builtInWideAngleCamera // Default
        
        // Get zoom factor
        let zoomFactor = photo.metadata[kCGImagePropertyExifDigitalZoomRatio as String] as? CGFloat ?? 1.0
        
        // Get exposure and ISO
        var exposureDuration: CMTime?
        var iso: Float?
        
        if let exifData = photo.metadata[kCGImagePropertyExifDictionary as String] as? [String: Any] {
            if let exposureTime = exifData[kCGImagePropertyExifExposureTime as String] as? Double {
                exposureDuration = CMTime(seconds: exposureTime, preferredTimescale: 1000)
            }
            
            if let isoValue = exifData[kCGImagePropertyExifISOSpeedRatings as String] as? [Float],
               let firstISO = isoValue.first {
                iso = firstISO
            }
        }
        
        // Get flash mode
        let flashMode: AVCaptureDevice.FlashMode = photo.metadata[kCGImagePropertyExifFlash as String] as? Int == 1 ? .on : .off
        
        return CaptureMetadata(
            deviceType: deviceType,
            zoomFactor: zoomFactor,
            exposureDuration: exposureDuration,
            iso: iso,
            flashMode: flashMode
        )
    }
}

// MARK: - Capture Processor
/// Helper class for processing captured images
final class CaptureProcessor {
    private let logger = os.Logger(subsystem: "com.balli.diabetes", category: "CaptureProcessor")
    
    /// Process and optimize image for nutrition label scanning
    func processForScanning(_ image: UIImage) async -> UIImage {
        logger.debug("Processing image for scanning: \(String(describing: image.size))")
        
        // For now, return the original image
        // In the future, we can add:
        // - Auto-rotation correction
        // - Contrast enhancement
        // - Resolution optimization
        // - Cropping to label area
        
        return image
    }
    
    /// Validate if image is suitable for scanning
    func validateForScanning(_ image: UIImage) -> (isValid: Bool, reason: String?) {
        // Check minimum resolution
        let minDimension: CGFloat = 800
        if image.size.width < minDimension || image.size.height < minDimension {
            return (false, "Görüntü çözünürlüğü çok düşük")
        }
        
        // Check if image is too blurry (simplified check)
        // In production, we'd use vision framework for blur detection
        
        return (true, nil)
    }
    
    /// Extract region of interest for nutrition label
    func extractLabelRegion(from image: UIImage) async -> UIImage? {
        // Future implementation: Use Vision framework to detect text regions
        // For now, return the original image
        return image
    }
}