//
//  CaptureImageProcessor.swift
//  balli
//
//  Handles image processing for captured photos
//  Extracted from CaptureFlowManager for single responsibility
//

import SwiftUI
@preconcurrency import UIKit
import os.log

/// Handles image processing operations for captured photos
@MainActor
final class CaptureImageProcessor {
    private let logger = os.Logger(subsystem: "com.balli.diabetes", category: "CaptureImageProcessor")
    private let imageProcessor = ImageProcessor()
    private let labelAnalysisService = LabelAnalysisService.shared
    private let securityManager = SecurityManager.shared
    private let configuration: CaptureConfiguration

    init(configuration: CaptureConfiguration) {
        self.configuration = configuration
    }

    // MARK: - Image Capture Processing

    func processImageCapture(
        _ image: UIImage,
        sessionId: UUID
    ) async throws -> (imageData: Data, thumbnailData: Data, thumbnail: UIImage) {
        // Generate thumbnail
        let thumbnail = await imageProcessor.generateThumbnail(from: image, cacheKey: sessionId.uuidString)

        // Save image data
        async let imageDataTask = imageProcessor.jpegData(
            from: image,
            compressionQuality: configuration.compressionQuality
        )
        async let thumbnailDataTask = imageProcessor.jpegData(
            from: thumbnail,
            compressionQuality: configuration.thumbnailCompressionQuality
        )

        guard let imageData = await imageDataTask,
              let thumbnailData = await thumbnailDataTask else {
            throw CaptureError.imageConversionFailed
        }

        return (imageData, thumbnailData, thumbnail)
    }

    // MARK: - AI Processing

    func processWithAI(
        originalImage: UIImage,
        sessionID: UUID,
        onProgress: @escaping @Sendable (String) -> Void
    ) async throws -> (optimizedImage: UIImage, nutritionResult: NutritionExtractionResult) {
        // Optimize image for AI
        let optimized = try await imageProcessor.optimizeForAI(image: originalImage)

        // Check rate limits
        guard await securityManager.canPerformAIScan() else {
            throw CaptureError.rateLimitExceeded
        }

        // Analyze the label using real AI processing via Firebase Functions
        let nutritionResult = try await labelAnalysisService.analyzeLabel(
            image: optimized,
            language: "tr"
        ) { progressMessage in
            onProgress(progressMessage)
        }

        // Validate the extracted data
        guard labelAnalysisService.validateNutritionData(nutritionResult) else {
            throw CaptureError.aiProcessingFailed("Extracted nutrition data failed validation")
        }

        // Record successful scan
        await securityManager.recordAIScan()

        return (optimized, nutritionResult)
    }

    func compressOptimizedImage(_ image: UIImage) async -> Data? {
        return await imageProcessor.compressForStorage(image: image)
    }

    // MARK: - Error Mapping

    func mapLabelAnalysisError(_ error: LabelAnalysisError) -> CaptureError {
        switch error {
        case .networkError, .networkTimeout:
            return .networkUnavailable
        case .serverError:
            return .aiProcessingFailed(error.localizedDescription)
        case .imageProcessingFailed:
            return .imageConversionFailed
        case .validationFailed, .noDataReceived:
            return .aiProcessingFailed(error.localizedDescription)
        case .invalidURL, .encodingFailed:
            return .processingFailed(error.localizedDescription)
        case .firebaseQuotaExceeded, .firebaseRateLimitExceeded:
            return .rateLimitExceeded
        case .geminiVisionError:
            return .aiProcessingFailed(error.localizedDescription)
        }
    }

    // MARK: - Utilities

    func getRemainingScans() async -> Int {
        return await securityManager.getRemainingScans()
    }
}
