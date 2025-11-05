//
//  GeminiTranscriptionService.swift
//  balli
//
//  Service for transcribing meal audio using Gemini 2.5 Flash via Cloud Functions
//

import Foundation
import UIKit
import os.log

// MARK: - Transcription Errors

enum GeminiTranscriptionError: LocalizedError {
    case invalidURL
    case encodingFailed(String)
    case networkError(String)
    case serverError(String)
    case rateLimitExceeded(retryAfter: Int)
    case audioTooLarge
    case decodingFailed(String)
    case noData

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return NSLocalizedString("error.transcription.invalidURL", comment: "Invalid URL error")
        case .encodingFailed(let message):
            return String(format: NSLocalizedString("error.transcription.encodingFailed", comment: "Encoding failed"), message)
        case .networkError(let message):
            return String(format: NSLocalizedString("error.transcription.networkError", comment: "Network error"), message)
        case .serverError(let message):
            return String(format: NSLocalizedString("error.transcription.serverError", comment: "Server error"), message)
        case .rateLimitExceeded(let retryAfter):
            return String(format: NSLocalizedString("error.transcription.rateLimitExceeded", comment: "Rate limit"), retryAfter)
        case .audioTooLarge:
            return NSLocalizedString("error.transcription.audioTooLarge", comment: "Audio too large")
        case .decodingFailed(let message):
            return String(format: NSLocalizedString("error.transcription.decodingFailed", comment: "Decoding failed"), message)
        case .noData:
            return NSLocalizedString("error.transcription.noData", comment: "No data")
        }
    }
}

// MARK: - Transcription Service

/// Actor-isolated service for calling the transcribeMeal Cloud Function
/// Provides async/await interface for Gemini-powered meal transcription
actor GeminiTranscriptionService {

    private let logger = Logger(subsystem: "com.balli.diabetes", category: "GeminiTranscription")
    private let session = URLSession.shared

    // Firebase Functions configuration
    private let functionsBaseURL = "https://us-central1-balli-project.cloudfunctions.net"
    private let transcriptionEndpoint = "/transcribeMeal"

    // Singleton instance
    static let shared = GeminiTranscriptionService()

    private init() {}

    // MARK: - Public API

    /// Transcribes meal audio using Gemini 2.5 Flash with offline support
    /// - Parameters:
    ///   - audioData: Audio file data (m4a format)
    ///   - userId: User ID for authentication
    ///   - progressCallback: Optional callback for progress updates
    ///   - allowOfflineQueue: If true, failed transcriptions will be queued for retry (default: true)
    /// - Returns: Transcribed meal data
    func transcribeMeal(
        audioData: Data,
        userId: String,
        progressCallback: (@Sendable (String) -> Void)? = nil,
        allowOfflineQueue: Bool = true
    ) async throws -> GeminiMealResponse {
        logger.info("🎤 Starting meal transcription for user: \(userId)")

        // Save audio file locally first (for offline queue if needed)
        let audioURL = try await saveAudioLocally(audioData: audioData, userId: userId)

        // Validate audio size (20MB limit as per spec)
        let audioSizeMB = Double(audioData.count) / (1024 * 1024)
        logger.info("📊 Audio size: \(String(format: "%.2f", audioSizeMB))MB")

        guard audioSizeMB <= 20 else {
            logger.error("❌ Audio too large: \(String(format: "%.2f", audioSizeMB))MB")
            throw GeminiTranscriptionError.audioTooLarge
        }

        // Step 1: Encode audio to base64
        await notifyProgress("Sesi hazırlıyor...", callback: progressCallback)
        let audioBase64 = audioData.base64EncodedString()

        // Step 2: Call Cloud Function with retry logic
        await notifyProgress("AI ile analiz ediyor...", callback: progressCallback)

        do {
            // Use existing NetworkRetryHandler with exponential backoff
            let response = try await NetworkRetryHandler.retryWithBackoff(
                configuration: .network
            ) {
                try await self.callTranscriptionAPI(
                    audioBase64: audioBase64,
                    userId: userId
                )
            }

            await notifyProgress("Sonuçları hazırlıyor...", callback: progressCallback)
            logger.info("✅ Meal transcription completed successfully")

            // Clean up local audio file after successful transcription
            try? FileManager.default.removeItem(at: audioURL)

            return response

        } catch {
            // Only queue if offline queueing is enabled (prevents infinite loop)
            if allowOfflineQueue {
                // Check if it's a network error that should be queued
                let isNetworkError: Bool = {
                    if case .networkError = error as? GeminiTranscriptionError {
                        return true
                    }
                    return NetworkRetryHandler.defaultShouldRetry(error)
                }()

                if isNetworkError {
                    logger.warning("⚠️ Network error, queueing audio for offline processing")
                    await notifyProgress("Kaydedildi, ağ bağlantısı geldiğinde gönderilecek", callback: progressCallback)

                    // Queue the operation for retry when network returns
                    try await queueOfflineTranscription(audioURL: audioURL, userId: userId)

                    // Return a placeholder error that UI can handle gracefully
                    throw GeminiTranscriptionError.networkError("Ses kaydedildi, internet bağlantısı geldiğinde otomatik gönderilecek")
                }
            }

            // Clean up on other errors
            try? FileManager.default.removeItem(at: audioURL)
            throw error
        }
    }

    // MARK: - Private Implementation

    /// Calls the Firebase Functions transcribeMeal API
    /// - Parameters:
    ///   - audioBase64: Base64 encoded audio data
    ///   - userId: User ID for authentication
    /// - Returns: Transcription response
    private func callTranscriptionAPI(
        audioBase64: String,
        userId: String
    ) async throws -> GeminiMealResponse {
        // Construct request URL
        guard let url = URL(string: self.functionsBaseURL + self.transcriptionEndpoint) else {
            logger.error("❌ Invalid URL: \(self.functionsBaseURL + self.transcriptionEndpoint)")
            throw GeminiTranscriptionError.invalidURL
        }

        // Prepare request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60 // 60 seconds timeout (as configured in Cloud Function)

        // Prepare request body (matching TranscribeMealInput from Cloud Function)
        let requestBody: [String: Any] = [
            "audioData": audioBase64,
            "mimeType": "audio/m4a", // iOS default format
            "userId": userId,
            "currentTime": ISO8601DateFormatter().string(from: Date())
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            logger.error("❌ Failed to encode request body: \(error.localizedDescription)")
            throw GeminiTranscriptionError.encodingFailed(error.localizedDescription)
        }

        logger.info("🔄 Sending transcription request to Cloud Function...")

        // Show network activity indicator
        await MainActor.run {
            UIApplication.shared.isNetworkActivityIndicatorVisible = true
        }

        // Ensure indicator is hidden when function exits (success or error)
        defer {
            Task { @MainActor in
                UIApplication.shared.isNetworkActivityIndicatorVisible = false
            }
        }

        // Execute request
        do {
            let (data, response) = try await session.data(for: request)

            // Check HTTP response
            guard let httpResponse = response as? HTTPURLResponse else {
                logger.error("❌ Invalid HTTP response")
                throw GeminiTranscriptionError.networkError("Invalid HTTP response")
            }

            logger.info("📡 Received HTTP \(httpResponse.statusCode)")

            // Handle HTTP errors
            guard httpResponse.statusCode == 200 else {
                let errorMessage = "HTTP \(httpResponse.statusCode)"

                switch httpResponse.statusCode {
                case 429:
                    logger.critical("🚨 RATE LIMIT EXCEEDED - Too many transcription requests")
                    throw GeminiTranscriptionError.rateLimitExceeded(retryAfter: 60)
                case 503:
                    logger.critical("🚨 SERVICE UNAVAILABLE - Check Gemini API quota")
                    throw GeminiTranscriptionError.serverError("Service temporarily unavailable")
                case 400:
                    // Try to extract error message from response
                    if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let message = errorData["error"] as? String {
                        logger.error("❌ Bad request: \(message)")
                        throw GeminiTranscriptionError.serverError(message)
                    }
                    throw GeminiTranscriptionError.serverError("Invalid request")
                case 401, 403:
                    logger.error("🔒 Authentication Error")
                    throw GeminiTranscriptionError.serverError("Authentication failed")
                default:
                    if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let message = errorData["error"] as? String {
                        logger.error("❌ Server error: \(message)")
                        throw GeminiTranscriptionError.serverError(message)
                    } else {
                        logger.error("❌ Server error: \(errorMessage)")
                        throw GeminiTranscriptionError.serverError(errorMessage)
                    }
                }
            }

            // Parse response
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase

            let geminiResponse: GeminiMealResponse

            do {
                geminiResponse = try decoder.decode(GeminiMealResponse.self, from: data)
            } catch {
                logger.error("❌ Failed to decode response: \(error.localizedDescription)")

                // Log the raw response for debugging
                if let rawString = String(data: data, encoding: .utf8) {
                    logger.debug("Raw response: \(rawString)")
                }

                throw GeminiTranscriptionError.decodingFailed(error.localizedDescription)
            }

            // Check if transcription was successful
            guard geminiResponse.success else {
                let errorMsg = geminiResponse.error ?? "Unknown error"
                logger.error("❌ Transcription failed: \(errorMsg)")
                throw GeminiTranscriptionError.serverError(errorMsg)
            }

            guard let mealData = geminiResponse.data else {
                logger.error("❌ No meal data in successful response")
                throw GeminiTranscriptionError.noData
            }

            logger.info("✅ Successfully transcribed: \(mealData.foods.count) foods, \(mealData.totalCarbs)g carbs")
            logger.info("📊 Confidence: \(mealData.confidence)")

            return geminiResponse

        } catch let error as GeminiTranscriptionError {
            // Re-throw our custom errors
            throw error
        } catch {
            // Wrap other errors
            logger.error("❌ Unexpected error: \(error.localizedDescription)")
            throw GeminiTranscriptionError.networkError(error.localizedDescription)
        }
    }

    /// Notifies progress callback on main actor
    private func notifyProgress(_ message: String, callback: (@Sendable (String) -> Void)?) async {
        guard let callback = callback else { return }

        await MainActor.run {
            callback(message)
        }
    }

    // MARK: - Offline Support

    /// Save audio file to persistent storage for offline queue
    private func saveAudioLocally(audioData: Data, userId: String) async throws -> URL {
        guard let documentsPath = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw GeminiTranscriptionError.encodingFailed("Documents directory unavailable")
        }

        // Create audio storage directory
        let audioDirectory = documentsPath.appendingPathComponent("OfflineAudio")
        try? FileManager.default.createDirectory(
            at: audioDirectory,
            withIntermediateDirectories: true
        )

        // Save with unique filename
        let filename = "meal_\(UUID().uuidString).m4a"
        let fileURL = audioDirectory.appendingPathComponent(filename)

        try audioData.write(to: fileURL)
        logger.info("💾 Saved audio locally: \(filename)")

        return fileURL
    }

    /// Queue audio transcription for later processing when network returns
    private func queueOfflineTranscription(audioURL: URL, userId: String) async throws {
        // Create queue data structure
        struct AudioTranscriptionQueueData: Codable {
            let audioPath: String
            let userId: String
            let timestamp: Date
        }

        let queueData = AudioTranscriptionQueueData(
            audioPath: audioURL.path,
            userId: userId,
            timestamp: Date()
        )

        try await OfflineQueue.shared.enqueue(
            type: .audioTranscription,
            data: queueData
        )

        logger.info("📥 Queued audio transcription for offline processing")
    }

    // MARK: - File Cleanup

    /// Clean up old audio files from offline storage
    /// Call this on app launch to prevent storage leaks from crashed/killed transcriptions
    /// - Parameter olderThan: Delete files older than this many days (default: 7)
    func cleanupOldAudioFiles(olderThan days: Int = 7) async throws {
        guard let documentsPath = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            logger.warning("⚠️ Documents directory unavailable for cleanup")
            return
        }

        let audioDirectory = documentsPath.appendingPathComponent("OfflineAudio")

        // Check if directory exists
        guard FileManager.default.fileExists(atPath: audioDirectory.path) else {
            logger.info("ℹ️ No OfflineAudio directory found - nothing to clean up")
            return
        }

        // Get all files in directory
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: audioDirectory,
            includingPropertiesForKeys: [.creationDateKey],
            options: []
        ) else {
            logger.warning("⚠️ Failed to enumerate audio files for cleanup")
            return
        }

        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        var deletedCount = 0
        var totalSize: Int64 = 0

        for fileURL in files {
            // Get file creation date
            guard let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
                  let creationDate = attributes[.creationDate] as? Date else {
                continue
            }

            // Delete if older than cutoff
            if creationDate < cutoffDate {
                if let size = attributes[.size] as? Int64 {
                    totalSize += size
                }

                do {
                    try FileManager.default.removeItem(at: fileURL)
                    deletedCount += 1
                    logger.info("🗑️ Cleaned up old audio: \(fileURL.lastPathComponent)")
                } catch {
                    logger.error("❌ Failed to delete \(fileURL.lastPathComponent): \(error.localizedDescription)")
                }
            }
        }

        if deletedCount > 0 {
            let sizeMB = Double(totalSize) / 1_048_576
            logger.info("✅ Cleanup complete: deleted \(deletedCount) files, freed \(String(format: "%.2f", sizeMB)) MB")
        } else {
            logger.info("ℹ️ No old files to clean up")
        }
    }
}
