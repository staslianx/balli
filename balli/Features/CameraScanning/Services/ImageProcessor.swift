//
//  ImageProcessor.swift
//  balli
//
//  Image processing utilities for camera capture flow
//

import UIKit
@preconcurrency import CoreImage
@preconcurrency import Vision
import os.log

/// Actor for thread-safe image processing operations
public actor ImageProcessor {
    private let logger = os.Logger(subsystem: "com.balli.diabetes", category: "ImageProcessor")
    
    // Core Image context for efficient processing
    private let ciContext = CIContext(options: [
        .useSoftwareRenderer: false,
        .highQualityDownsample: true
    ])

    // Cache for processed images (actor-isolated, thread-safe)
    private var thumbnailCache: [String: UIImage] = [:]
    private let maxCacheSize = 20
    
    // MARK: - Public Methods
    
    /// Generate thumbnail from captured image
    public func generateThumbnail(
        from image: UIImage,
        cacheKey: String? = nil,
        maxSize: CGSize = CGSize(width: 200, height: 200)
    ) async -> UIImage {
        let startTime = Date()

        // Check cache first
        let resolvedKey = makeCacheKey(for: image, providedKey: cacheKey)
        if let cached = thumbnailCache[resolvedKey] {
            return cached
        }
        
        // Use Task.detached for CPU-intensive image processing off the actor
        let thumbnail = await Task.detached(priority: .userInitiated) {
            // Calculate target size maintaining aspect ratio
            let scale = min(maxSize.width / image.size.width, maxSize.height / image.size.height)
            let targetSize = CGSize(
                width: image.size.width * scale,
                height: image.size.height * scale
            )

            // Create thumbnail
            UIGraphicsBeginImageContextWithOptions(targetSize, false, 0.0)
            image.draw(in: CGRect(origin: .zero, size: targetSize))
            let thumbnail = UIGraphicsGetImageFromCurrentImageContext() ?? image
            UIGraphicsEndImageContext()

            return thumbnail
        }.value
        
        // Cache thumbnail
        cacheThumbnail(thumbnail, for: resolvedKey)

        let duration = Date().timeIntervalSince(startTime)
        logger.debug("Thumbnail generated in \(duration)s")

        return thumbnail
    }
    
    /// Optimize image for AI processing
    public func optimizeForAI(image: UIImage) async throws -> UIImage {
        let startTime = Date()
        
        // Capture context before entering closure
        let context = self.ciContext
        let loggerCapture = self.logger
        
        // Use Task.detached for CPU-intensive Core Image processing
        return try await Task.detached(priority: .userInitiated) {
            // Convert to CIImage for processing
            guard let ciImage = CIImage(image: image) else {
                throw CaptureError.imageConversionFailed
            }

            // Apply filters for better text recognition
            let enhanced = ciImage
                .applyingFilter("CIColorControls", parameters: [
                    "inputContrast": 1.1,
                    "inputBrightness": 0.05,
                    "inputSaturation": 0.8
                ])
                .applyingFilter("CISharpenLuminance", parameters: [
                    "inputSharpness": 0.4
                ])

            // Render optimized image
            guard let cgImage = context.createCGImage(enhanced, from: enhanced.extent) else {
                throw CaptureError.optimizationFailed
            }

            let optimized = UIImage(cgImage: cgImage)

            let duration = Date().timeIntervalSince(startTime)
            loggerCapture.info("Image optimized in \(duration)s")

            return optimized
        }.value
    }
    
    /// Crop image to nutrition label area
    public func cropToLabel(image: UIImage, boundingBox: CGRect) async -> UIImage? {
        // Use Task.detached for image cropping operation
        await Task.detached(priority: .userInitiated) {
            // Convert normalized coordinates to image coordinates
            let imageRect = CGRect(
                x: boundingBox.origin.x * image.size.width,
                y: boundingBox.origin.y * image.size.height,
                width: boundingBox.width * image.size.width,
                height: boundingBox.height * image.size.height
            )

            // Perform crop
            guard let cgImage = image.cgImage,
                  let croppedCGImage = cgImage.cropping(to: imageRect) else {
                return nil
            }

            return UIImage(cgImage: croppedCGImage)
        }.value
    }
    
    /// Detect text regions in image using Vision
    public func detectTextRegions(in image: UIImage) async throws -> [VNTextObservation] {
        try await withCheckedThrowingContinuation { continuation in
            guard let cgImage = image.cgImage else {
                continuation.resume(throwing: CaptureError.imageConversionFailed)
                return
            }
            
            let request = VNDetectTextRectanglesRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                let observations = request.results as? [VNTextObservation] ?? []
                continuation.resume(returning: observations)
            }
            
            request.reportCharacterBoxes = false
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            Task {
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Compress image for storage
    public func compressForStorage(image: UIImage, maxSizeKB: Int = 1024) async -> Data? {
        // Use Task.detached for compression algorithm
        await Task.detached(priority: .utility) {
            var compression: CGFloat = 1.0
            var imageData = image.jpegData(compressionQuality: compression)

            // Reduce compression until size requirement is met
            while let data = imageData,
                  data.count > maxSizeKB * 1024,
                  compression > 0.1 {
                compression -= 0.1
                imageData = image.jpegData(compressionQuality: compression)
            }

            return imageData
        }.value
    }
    
    /// Auto-rotate image based on EXIF orientation
    public func autoRotate(image: UIImage) async -> UIImage {
        // Use Task.detached for image rotation
        await Task.detached(priority: .userInitiated) {
            // Already correctly oriented
            if image.imageOrientation == .up {
                return image
            }

            // Redraw in correct orientation
            UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
            image.draw(in: CGRect(origin: .zero, size: image.size))
            let rotated = UIGraphicsGetImageFromCurrentImageContext() ?? image
            UIGraphicsEndImageContext()

            return rotated
        }.value
    }
    
    // MARK: - Private Methods
    
    private func cacheThumbnail(_ thumbnail: UIImage, for key: String) {
        // Maintain cache size limit
        if thumbnailCache.count >= maxCacheSize {
            // Remove oldest entries (simple FIFO for now)
            let toRemove = thumbnailCache.count - maxCacheSize + 1
            for _ in 0..<toRemove {
                if let firstKey = thumbnailCache.keys.first {
                    thumbnailCache.removeValue(forKey: firstKey)
                }
            }
        }

        thumbnailCache[key] = thumbnail
    }

    /// Clear all caches
    public func clearCaches() async {
        thumbnailCache.removeAll()
        logger.info("Image processor caches cleared")
    }

    public func jpegData(from image: UIImage, compressionQuality: CGFloat) async -> Data? {
        // Use Task.detached for JPEG encoding
        await Task.detached(priority: .utility) {
            return image.jpegData(compressionQuality: compressionQuality)
        }.value
    }

    private func makeCacheKey(for image: UIImage, providedKey: String?) -> String {
        if let providedKey, !providedKey.isEmpty {
            return providedKey
        }

        let identifier = ObjectIdentifier(image).hashValue
        let width = Int(image.size.width.rounded())
        let height = Int(image.size.height.rounded())
        return "\(identifier)_\(width)x\(height)_\(image.scale)"
    }
}
