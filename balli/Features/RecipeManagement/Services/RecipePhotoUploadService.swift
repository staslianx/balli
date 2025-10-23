//
//  RecipePhotoUploadService.swift
//  balli
//
//  Handles background upload of recipe photos to Firebase Storage
//  Uploads base64 images and returns HTTP URLs for long-term storage
//  Swift 6 strict concurrency compliant
//

import Foundation
import FirebaseStorage
import OSLog

/// Handles background upload of recipe photos to Firebase Storage
actor RecipePhotoUploadService {
    static let shared = RecipePhotoUploadService()

    private let storage = Storage.storage()
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.balli",
        category: "RecipePhotoUpload"
    )

    private init() {}

    /// Upload base64 image to Firebase Storage and return HTTP URL
    /// - Parameters:
    ///   - base64String: Base64 data URL or raw base64 string
    ///   - recipeName: Name of the recipe for filename
    ///   - userId: User ID for organizing storage
    /// - Returns: HTTPS download URL from Firebase Storage
    func uploadBase64Image(
        base64String: String,
        recipeName: String,
        userId: String
    ) async throws -> String {
        logger.info("📤 Starting background upload for recipe: \(recipeName)")

        // Extract image data from base64
        guard let imageData = extractBase64Data(from: base64String) else {
            logger.error("❌ Invalid base64 data format")
            throw RecipePhotoError.invalidBase64Data
        }

        logger.debug("✅ Extracted \(imageData.count) bytes from base64")

        // Generate unique filename
        let timestamp = Date().timeIntervalSince1970
        let sanitizedName = recipeName
            .replacingOccurrences(of: " ", with: "_")
            .lowercased()
        let filename = "\(userId)/\(sanitizedName)_\(Int(timestamp)).jpg"

        // Create storage reference
        let storageRef = storage.reference().child("recipe_photos/\(filename)")

        // Upload with metadata
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        metadata.customMetadata = [
            "recipeName": recipeName,
            "userId": userId,
            "uploadedAt": ISO8601DateFormatter().string(from: Date())
        ]

        logger.info("📁 Uploading to path: recipe_photos/\(filename)")

        // Perform upload and get download URL
        // Note: Firebase Storage SDK types are not Sendable-compliant yet
        // We isolate the storage operations to prevent data races
        return try await withCheckedThrowingContinuation { continuation in
            Task {
                do {
                    // Upload data
                    _ = try await storageRef.putDataAsync(imageData, metadata: metadata)
                    logger.info("✅ Upload complete, fetching download URL...")

                    // Get download URL
                    let downloadURL = try await storageRef.downloadURL()
                    logger.info("✅ Background upload complete: \(downloadURL.absoluteString)")
                    continuation.resume(returning: downloadURL.absoluteString)
                } catch {
                    logger.error("❌ Upload failed: \(error.localizedDescription)")
                    continuation.resume(throwing: RecipePhotoError.uploadFailed(underlying: error))
                }
            }
        }
    }

    private func extractBase64Data(from dataURL: String) -> Data? {
        // Handle "data:image/jpeg;base64,..." format
        if dataURL.hasPrefix("data:") {
            guard let commaIndex = dataURL.firstIndex(of: ",") else {
                logger.warning("⚠️ Invalid data URL format: missing comma")
                return nil
            }
            let base64String = String(dataURL[dataURL.index(after: commaIndex)...])
            return Data(base64Encoded: base64String)
        }

        // Handle raw base64 string
        return Data(base64Encoded: dataURL)
    }
}

enum RecipePhotoError: LocalizedError {
    case invalidBase64Data
    case uploadFailed(underlying: Error)
    case downloadURLFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .invalidBase64Data:
            return "Invalid base64 image data format"
        case .uploadFailed(let error):
            return "Failed to upload image: \(error.localizedDescription)"
        case .downloadURLFailed(let error):
            return "Failed to get download URL: \(error.localizedDescription)"
        }
    }
}
