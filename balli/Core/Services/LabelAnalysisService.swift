//
//  LabelAnalysisService.swift
//  balli
//
//  Real implementation for nutrition label analysis using Firebase Functions and Gemini AI
//

import Foundation
import UIKit
import os.log

/// Service for analyzing nutrition labels using Firebase Functions and Gemini AI
final class LabelAnalysisService: @unchecked Sendable {
    static let shared = LabelAnalysisService()

    private let logger = os.Logger(subsystem: "com.balli.diabetes", category: "LabelAnalysisService")
    private let session = URLSession.shared

    // Firebase Functions configuration
    private let functionsBaseURL = "https://us-central1-balli-project.cloudfunctions.net"
    private let extractionEndpoint = "/extractNutritionFromImage"

    private init() {}

    // MARK: - Public API

    /// Analyzes a nutrition label from an image using Firebase Functions
    /// - Parameters:
    ///   - image: The image containing the nutrition label
    ///   - language: Language for text recognition (default: Turkish)
    ///   - progressCallback: Optional callback for progress updates
    /// - Returns: Extracted nutrition information
    func analyzeLabel(
        image: UIImage,
        language: String = "tr",
        progressCallback: (@Sendable (String) -> Void)? = nil
    ) async throws -> NutritionExtractionResult {
        logger.info("🏷️ Starting nutrition label analysis")

        // Step 1: Preprocess and encode image
        await notifyProgress("Resmi hazırlıyor...", callback: progressCallback)
        let imageBase64 = try await preprocessAndEncodeImage(image)

        // Step 2: Send to Firebase Functions
        await notifyProgress("AI ile analiz ediyor...", callback: progressCallback)
        let result = try await callNutritionExtractionAPI(
            imageBase64: imageBase64,
            language: language
        )

        await notifyProgress("Sonuçları hazırlıyor...", callback: progressCallback)
        logger.info("✅ Nutrition label analysis completed successfully")

        return result
    }

    /// Legacy method for compatibility with old SimpleLabelNutrition
    /// - Parameter image: The image containing the nutrition label
    /// - Returns: Simplified nutrition information
    func analyzeLabel(image: UIImage) async throws -> SimpleLabelNutrition {
        let result = try await analyzeLabel(image: image, language: "tr")

        // Convert to legacy format
        return SimpleLabelNutrition(
            calories: result.nutrients.calories.value,
            servingSize: "\(Int(result.servingSize.value))\(result.servingSize.unit)",
            carbohydrates: result.nutrients.totalCarbohydrates.value,
            fiber: result.nutrients.dietaryFiber?.value ?? 0,
            sugar: result.nutrients.sugars?.value ?? 0,
            protein: result.nutrients.protein.value,
            fat: result.nutrients.totalFat.value
        )
    }

    /// Validates extracted nutrition data
    /// - Parameter result: The nutrition extraction result
    /// - Returns: Whether the data appears valid
    func validateNutritionData(_ result: NutritionExtractionResult) -> Bool {
        // Basic validation rules
        let calories = result.nutrients.calories.value
        let carbs = result.nutrients.totalCarbohydrates.value
        let protein = result.nutrients.protein.value
        let fat = result.nutrients.totalFat.value

        // Check for reasonable ranges
        guard calories >= 0 && calories <= 9000,  // Max ~9000 kcal per kg
              carbs >= 0 && carbs <= 100,         // Max 100g per 100g serving
              protein >= 0 && protein <= 100,     // Max 100g per 100g serving
              fat >= 0 && fat <= 100              // Max 100g per 100g serving
        else {
            logger.warning("Nutrition data validation failed: values out of reasonable range")
            return false
        }

        // Check confidence threshold
        guard result.metadata.confidence >= 30 else {
            logger.warning("Nutrition data validation failed: confidence too low (\(result.metadata.confidence)%)")
            return false
        }

        return true
    }

    // MARK: - Private Implementation

    /// Preprocesses image and converts to base64
    /// - Parameter image: The original image
    /// - Returns: Base64 encoded image string
    private func preprocessAndEncodeImage(_ image: UIImage) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            Task.detached {
                do {
                    // Optimize image for OCR: resize and adjust quality
                    let optimizedImage = try await MainActor.run {
                        try self.optimizeImageForOCR(image)
                    }

                    // Convert to JPEG with high quality for text recognition
                    guard let imageData = optimizedImage.jpegData(compressionQuality: 0.9) else {
                        throw LabelAnalysisError.imageProcessingFailed("Failed to convert image to JPEG")
                    }

                    // Encode to base64
                    let base64String = imageData.base64EncodedString()

                    await MainActor.run {
                        continuation.resume(returning: base64String)
                    }
                } catch {
                    await MainActor.run {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }

    /// Optimizes image for better OCR results
    /// - Parameter image: Original image
    /// - Returns: Optimized image
    private func optimizeImageForOCR(_ image: UIImage) throws -> UIImage {
        // Target size for optimal OCR (not too large, not too small)
        let targetMaxDimension: CGFloat = 1024
        let originalSize = image.size

        // Calculate resize ratio
        let ratio = min(
            targetMaxDimension / originalSize.width,
            targetMaxDimension / originalSize.height
        )

        // Only resize if image is too large
        guard ratio < 1.0 else {
            return image
        }

        let newSize = CGSize(
            width: originalSize.width * ratio,
            height: originalSize.height * ratio
        )

        // Create resized image
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        defer { UIGraphicsEndImageContext() }

        image.draw(in: CGRect(origin: .zero, size: newSize))

        guard let resizedImage = UIGraphicsGetImageFromCurrentImageContext() else {
            throw LabelAnalysisError.imageProcessingFailed("Failed to resize image")
        }

        return resizedImage
    }

    /// Calls the Firebase Functions nutrition extraction API
    /// - Parameters:
    ///   - imageBase64: Base64 encoded image
    ///   - language: Language for recognition
    /// - Returns: Nutrition extraction result
    private func callNutritionExtractionAPI(
        imageBase64: String,
        language: String
    ) async throws -> NutritionExtractionResult {
        // Construct request URL
        guard let url = URL(string: functionsBaseURL + extractionEndpoint) else {
            throw LabelAnalysisError.invalidURL("Invalid Firebase Functions URL")
        }

        // Prepare request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120 // 2 minutes timeout

        // Prepare request body
        let requestBody: [String: Any] = [
            "imageBase64": imageBase64,
            "language": language,
            "maxWidth": 1024,
            "userId": "ios-app" // Could be replaced with actual user ID
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            throw LabelAnalysisError.encodingFailed("Failed to encode request body")
        }

        // Execute request
        do {
            let (data, response) = try await session.data(for: request)

            // Check HTTP response
            guard let httpResponse = response as? HTTPURLResponse else {
                throw LabelAnalysisError.networkError("Invalid HTTP response")
            }

            guard httpResponse.statusCode == 200 else {
                let errorMessage = "HTTP \(httpResponse.statusCode)"

                // Log critical Firebase errors prominently for developer debugging
                switch httpResponse.statusCode {
                case 429:
                    logger.critical("🚨 LABEL ANALYSIS RATE LIMIT EXCEEDED - Check Firebase Console")
                    throw LabelAnalysisError.firebaseRateLimitExceeded(retryAfter: 60)
                case 503:
                    logger.critical("🚨 LABEL ANALYSIS QUOTA EXCEEDED - Check Gemini Vision API quota")
                    throw LabelAnalysisError.firebaseQuotaExceeded
                case 401, 403:
                    logger.error("🔒 Label Analysis Authentication Error - Check Firebase Auth")
                    throw LabelAnalysisError.serverError("\(errorMessage): Authentication Error")
                default:
                    if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let message = errorData["message"] as? String {
                        throw LabelAnalysisError.serverError("\(errorMessage): \(message)")
                    } else {
                        throw LabelAnalysisError.serverError(errorMessage)
                    }
                }
            }

            // Parse response
            let apiResponse = try JSONDecoder().decode(NutritionAPIResponse.self, from: data)

            guard apiResponse.success else {
                throw LabelAnalysisError.serverError(apiResponse.error ?? "Unknown server error")
            }

            guard let nutritionData = apiResponse.data else {
                throw LabelAnalysisError.noDataReceived("No nutrition data in response")
            }

            return nutritionData

        } catch let error as LabelAnalysisError {
            throw error
        } catch {
            logger.error("Network request failed: \(error.localizedDescription)")
            throw LabelAnalysisError.networkError("Network request failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - Progress Dispatch

private extension LabelAnalysisService {
    @MainActor
    func notifyProgress(_ message: String, callback: ((String) -> Void)?) {
        callback?(message)
    }
}

// MARK: - Supporting Types

/// API response structure for nutrition extraction
private struct NutritionAPIResponse: Codable {
    let success: Bool
    let data: NutritionExtractionResult?
    let error: String?
    let message: String?
    let timestamp: String?
    let metadata: APIMetadata?
}

private struct APIMetadata: Codable {
    let processingTime: String
    let timestamp: String
    let version: String
}

/// Errors that can occur during label analysis
enum LabelAnalysisError: LocalizedError {
    case imageProcessingFailed(String)
    case invalidURL(String)
    case encodingFailed(String)
    case networkError(String)
    case serverError(String)
    case noDataReceived(String)
    case validationFailed(String)

    // Firebase-specific errors for label analysis
    case networkTimeout
    case firebaseQuotaExceeded
    case firebaseRateLimitExceeded(retryAfter: Int)
    case geminiVisionError

    var errorDescription: String? {
        switch self {
        case .imageProcessingFailed(let message):
            return "Resim işleme hatası: \(message)\nImage processing error: \(message)"

        case .invalidURL(let message):
            return "Geçersiz URL: \(message)\nInvalid URL: \(message)"

        case .encodingFailed(let message):
            return "Kodlama hatası: \(message)\nEncoding error: \(message)"

        case .networkError(let message):
            return "İnternet bağlantısı sorunu: \(message)\nNetwork error: \(message)"

        case .networkTimeout:
            return "Etiket analizi zaman aşımına uğradı. Tekrar deneyin.\nLabel analysis timed out. Try again."

        case .firebaseQuotaExceeded:
            return "Etiket analiz servisi limiti aşıldı. Lütfen birkaç dakika bekleyin.\nLabel analysis quota exceeded. Wait a few minutes."

        case .firebaseRateLimitExceeded(let retryAfter):
            return "Çok fazla etiket analizi. \(retryAfter) saniye sonra tekrar deneyin.\nToo many analyses. Try again in \(retryAfter) seconds."

        case .geminiVisionError:
            return "Görüntü analizi yapılamadı. Lütfen fotoğrafı tekrar çekin.\nVision analysis failed. Please retake the photo."

        case .serverError(let message):
            return "Sunucu hatası: \(message)\nServer error: \(message)"

        case .noDataReceived(let message):
            return "Veri alınamadı: \(message)\nNo data received: \(message)"

        case .validationFailed(let message):
            return "Doğrulama hatası: \(message)\nValidation error: \(message)"
        }
    }

    var failureReason: String? {
        switch self {
        case .networkError, .networkTimeout:
            return "İnternet bağlantısı problemi"
        case .firebaseQuotaExceeded:
            return "Firebase quota exceeded (DEVELOPER: Check Gemini Vision API quota)"
        case .firebaseRateLimitExceeded:
            return "Firebase rate limit exceeded (DEVELOPER: Exponential backoff active)"
        case .geminiVisionError:
            return "Gemini Vision API error"
        case .serverError:
            return "Firebase Functions backend error (DEVELOPER: Check extractNutritionFromImage logs)"
        default:
            return nil
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .imageProcessingFailed:
            return "Fotoğrafı tekrar çekin ve tekrar deneyin."
        case .networkError, .networkTimeout:
            return "İnternet bağlantınızı kontrol edin ve tekrar deneyin."
        case .firebaseQuotaExceeded:
            return "DEVELOPER: Check Firebase Console for Gemini Vision API quota limits."
        case .firebaseRateLimitExceeded(let retryAfter):
            return "\(retryAfter) saniye bekleyip tekrar deneyin."
        case .geminiVisionError:
            return "Daha iyi aydınlatmalı ve net bir fotoğraf çekin."
        case .validationFailed:
            return "Etiketin tamamının görünür olduğundan emin olun."
        default:
            return "Tekrar deneyin veya destek ile iletişime geçin."
        }
    }

    /// Check if error is retryable
    var isRetryable: Bool {
        switch self {
        case .networkError, .networkTimeout:
            return true
        case .firebaseRateLimitExceeded:
            return true
        case .geminiVisionError:
            return false // User needs to retake photo
        default:
            return false
        }
    }

    /// Recommended retry delay
    var retryDelay: TimeInterval {
        switch self {
        case .firebaseRateLimitExceeded(let retryAfter):
            return TimeInterval(retryAfter)
        case .firebaseQuotaExceeded:
            return 300.0 // 5 minutes
        case .networkTimeout:
            return 5.0
        default:
            return 2.0
        }
    }
}
