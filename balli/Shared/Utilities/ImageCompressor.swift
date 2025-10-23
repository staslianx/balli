//
//  ImageCompressor.swift
//  balli
//
//  Simplified image compression utility
//

import UIKit
import os.log

/// Configuration for image compression
public struct ImageCompressionConfig: Sendable {
    public let maxSizeBytes: Int
    public let initialQuality: CGFloat
    public let minQuality: CGFloat
    public let targetQuality: CGFloat
    
    public init(
        maxSizeBytes: Int = 1_048_576, // 1MB default
        initialQuality: CGFloat = 0.9,
        minQuality: CGFloat = 0.5,
        targetQuality: CGFloat = 0.8
    ) {
        self.maxSizeBytes = maxSizeBytes
        self.initialQuality = initialQuality
        self.minQuality = minQuality
        self.targetQuality = targetQuality
    }
    
    /// Configuration for AI model input
    public static let aiModel = ImageCompressionConfig(
        maxSizeBytes: 1_048_576, // 1MB
        initialQuality: 0.9,
        minQuality: 0.5,
        targetQuality: 0.8
    )
    
    /// Configuration for thumbnails
    public static let thumbnail = ImageCompressionConfig(
        maxSizeBytes: 102_400, // 100KB
        initialQuality: 0.7,
        minQuality: 0.3,
        targetQuality: 0.6
    )
    
    /// Configuration for high quality storage
    public static let highQuality = ImageCompressionConfig(
        maxSizeBytes: 5_242_880, // 5MB
        initialQuality: 0.95,
        minQuality: 0.8,
        targetQuality: 0.9
    )
}

/// Utility for compressing images efficiently
public struct ImageCompressor: Sendable {
    private let logger = os.Logger(subsystem: "com.balli.diabetes", category: "ImageCompressor")
    
    /// Compresses an image to meet size requirements
    public func compress(
        _ image: UIImage,
        config: ImageCompressionConfig = .aiModel
    ) -> Data? {
        // First, try with target quality
        if let data = image.jpegData(compressionQuality: config.targetQuality),
           data.count <= config.maxSizeBytes {
            logger.debug("Image compressed successfully at target quality: \(data.count) bytes")
            return data
        }
        
        // If still too large, calculate required scale factor
        guard let fullData = image.jpegData(compressionQuality: 1.0) else {
            logger.error("Failed to get image data")
            return nil
        }
        
        if fullData.count <= config.maxSizeBytes {
            // Image is already small enough at full quality
            return fullData
        }
        
        // Calculate scale factor needed
        let scaleFactor = sqrt(Double(config.maxSizeBytes) / Double(fullData.count))
        
        // Resize image
        if let resizedImage = resize(image, scaleFactor: scaleFactor) {
            // Return resized image with target quality
            let compressedData = resizedImage.jpegData(compressionQuality: config.targetQuality)
            logger.debug("Image resized and compressed: \(compressedData?.count ?? 0) bytes")
            return compressedData
        }
        
        // Fallback: try minimum quality without resizing
        return image.jpegData(compressionQuality: config.minQuality)
    }
    
    /// Resizes an image by a scale factor
    private func resize(_ image: UIImage, scaleFactor: CGFloat) -> UIImage? {
        guard scaleFactor > 0 && scaleFactor < 1 else {
            return image
        }
        
        let newSize = CGSize(
            width: image.size.width * scaleFactor,
            height: image.size.height * scaleFactor
        )
        
        // Use UIGraphicsImageRenderer for better performance
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { context in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
    
    /// Compresses an image for a specific use case
    public func compressForUseCase(
        _ image: UIImage,
        useCase: ImageUseCase
    ) -> Data? {
        switch useCase {
        case .aiAnalysis:
            return compress(image, config: .aiModel)
        case .thumbnail:
            return compress(image, config: .thumbnail)
        case .storage:
            return compress(image, config: .highQuality)
        case .preview:
            // For preview, just resize without heavy compression
            if let resized = resize(image, scaleFactor: 0.5) {
                return resized.jpegData(compressionQuality: 0.9)
            }
            return image.jpegData(compressionQuality: 0.9)
        }
    }
    
    /// Estimates the compression ratio needed for a target size
    public func estimateCompressionRatio(
        originalSize: Int,
        targetSize: Int
    ) -> CGFloat {
        guard originalSize > 0 && targetSize > 0 else { return 1.0 }
        return sqrt(CGFloat(targetSize) / CGFloat(originalSize))
    }
}

/// Use cases for image compression
public enum ImageUseCase {
    case aiAnalysis
    case thumbnail
    case storage
    case preview
}

/// Global image compressor instance
public let imageCompressor: ImageCompressor = ImageCompressor()