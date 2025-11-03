//
//  ImageAttachment.swift
//  balli
//
//  Model for image attachments in research messages
//  Swift 6 strict concurrency compliant
//

import SwiftUI
import UIKit

/// Represents an image attachment for research queries
struct ImageAttachment: Identifiable, Codable, Sendable, Equatable {
    /// Unique identifier
    let id: UUID

    /// Image data (JPEG compressed)
    let imageData: Data

    /// Thumbnail data for display (smaller, compressed)
    let thumbnailData: Data

    /// Original image size
    let originalSize: CGSize

    /// Creation timestamp
    let timestamp: Date

    /// Compression quality (0.0 to 1.0)
    let compressionQuality: Double

    init(
        id: UUID = UUID(),
        imageData: Data,
        thumbnailData: Data,
        originalSize: CGSize,
        timestamp: Date = Date(),
        compressionQuality: Double = 0.8
    ) {
        self.id = id
        self.imageData = imageData
        self.thumbnailData = thumbnailData
        self.originalSize = originalSize
        self.timestamp = timestamp
        self.compressionQuality = compressionQuality
    }

    /// Create attachment from UIImage with automatic compression
    static func create(from image: UIImage, compressionQuality: Double = 0.8) -> ImageAttachment? {
        // Compress full image
        guard let imageData = image.jpegData(compressionQuality: compressionQuality) else {
            return nil
        }

        // Create thumbnail (max 400x400 for sharper display on Retina)
        let thumbnailSize = CGSize(width: 400, height: 400)
        let thumbnail = image.preparingThumbnail(of: thumbnailSize)
        guard let thumbnailData = thumbnail?.jpegData(compressionQuality: 0.85) else {
            return nil
        }

        return ImageAttachment(
            imageData: imageData,
            thumbnailData: thumbnailData,
            originalSize: image.size,
            compressionQuality: compressionQuality
        )
    }

    /// Convert to UIImage for display
    var image: UIImage? {
        UIImage(data: imageData)
    }

    /// Convert to thumbnail UIImage for preview
    var thumbnail: UIImage? {
        UIImage(data: thumbnailData)
    }

    /// Get base64 encoded string for API transmission
    var base64String: String {
        imageData.base64EncodedString()
    }

    /// Estimated file size in bytes
    var estimatedSize: Int {
        imageData.count
    }

    /// Human-readable file size
    var fileSizeDescription: String {
        let bytes = Double(estimatedSize)
        if bytes < 1024 {
            return "\(Int(bytes)) B"
        } else if bytes < 1024 * 1024 {
            return String(format: "%.1f KB", bytes / 1024)
        } else {
            return String(format: "%.1f MB", bytes / (1024 * 1024))
        }
    }

    // MARK: - Equatable

    static func == (lhs: ImageAttachment, rhs: ImageAttachment) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Preview Helper

extension ImageAttachment {
    /// Create a preview attachment with a solid color
    static func preview(color: UIColor = .systemBlue) -> ImageAttachment {
        let size = CGSize(width: 400, height: 400)
        let renderer = UIGraphicsImageRenderer(size: size)

        let image = renderer.image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }

        return create(from: image) ?? ImageAttachment(
            imageData: Data(),
            thumbnailData: Data(),
            originalSize: size
        )
    }
}
