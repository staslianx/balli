//
//  TranscriptionService.swift
//  balli
//
//  Service for handling speech-to-text transcription using Gemini 2.5 Flash
//  Processes audio recordings and extracts meal information
//

import Foundation
import AVFoundation
import os.log

// MARK: - Transcription Models

struct TranscriptionResult {
    let transcription: String
    let confidence: Double
    let language: String
    let mealInfo: MealInfo?
    let processingTime: TimeInterval
}

struct MealInfo {
    let hasMealContent: Bool
    let extractedItems: [ExtractedFoodItem]
}

struct ExtractedFoodItem {
    let name: String
    let quantity: String?
    let unit: String?
}

// MARK: - Transcription Error

enum TranscriptionError: LocalizedError {
    case audioDataMissing
    case networkError(String)
    case invalidResponse
    case transcriptionFailed(String)
    case audioTooShort
    case audioTooLong

    var errorDescription: String? {
        switch self {
        case .audioDataMissing:
            return "Ses verisi bulunamadı"
        case .networkError(let message):
            return "Ağ hatası: \(message)"
        case .invalidResponse:
            return "Geçersiz sunucu yanıtı"
        case .transcriptionFailed(let message):
            return "Çeviri başarısız: \(message)"
        case .audioTooShort:
            return "Ses kaydı çok kısa"
        case .audioTooLong:
            return "Ses kaydı çok uzun"
        }
    }
}

// MARK: - Transcription Service

actor TranscriptionService {
    private let logger = os.Logger(subsystem: "com.balli.diabetes", category: "TranscriptionService")
    private let baseURL: String
    private let maxAudioSize: Int = 10 * 1024 * 1024 // 10 MB max
    private let minAudioDuration: TimeInterval = 1.0
    private let maxAudioDuration: TimeInterval = 60.0

    init() {
        // Use the same base URL as GenkitService
        self.baseURL = NetworkConfiguration.shared.baseURL
    }

    // MARK: - Public Methods

    /// Transcribe audio data to text using Gemini 2.5 Flash
    func transcribeAudio(_ audioData: Data, context: String? = nil) async throws -> TranscriptionResult {
        let startTime = Date()

        // Validate audio data
        try validateAudioData(audioData)

        // Convert audio data to base64
        let audioBase64 = audioData.base64EncodedString()

        // Prepare request body
        let requestBody: [String: Any] = [
            "audioBase64": audioBase64,
            "mimeType": "audio/wav",
            "language": "tr",
            "context": context ?? "Kullanıcı yemek kaydı yapıyor"
        ]

        logger.info("📡 Sending audio for transcription (size: \(audioData.count) bytes)")

        do {
            // Prepare URL
            guard let url = URL(string: "\(baseURL)/transcribeAudio") else {
                throw TranscriptionError.invalidResponse
            }

            // Create request
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            // Encode request body
            let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
            request.httpBody = jsonData

            // Make the request
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  200...299 ~= httpResponse.statusCode else {
                throw TranscriptionError.networkError("Server error")
            }

            // Parse response
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let responseData = json["data"] as? [String: Any] else {
                throw TranscriptionError.invalidResponse
            }

            // Parse response
            let transcription = responseData["transcription"] as? String ?? ""
            let confidence = responseData["confidence"] as? Double ?? 0.0
            let language = responseData["language"] as? String ?? "tr"

            // Parse meal info if present
            let mealInfo: MealInfo? = parseMealInfo(from: responseData["mealInfo"] as? [String: Any])

            let processingTime = Date().timeIntervalSince(startTime)

            logger.info("✅ Transcription successful: \"\(transcription.prefix(50))...\" (confidence: \(confidence))")

            return TranscriptionResult(
                transcription: transcription,
                confidence: confidence,
                language: language,
                mealInfo: mealInfo,
                processingTime: processingTime
            )

        } catch {
            logger.error("❌ Transcription failed: \(error.localizedDescription)")

            if let transcriptionError = error as? TranscriptionError {
                throw transcriptionError
            } else {
                throw TranscriptionError.transcriptionFailed(error.localizedDescription)
            }
        }
    }

    /// Process audio file from URL
    func transcribeAudioFile(at url: URL, context: String? = nil) async throws -> TranscriptionResult {
        do {
            let audioData = try Data(contentsOf: url)
            return try await transcribeAudio(audioData, context: context)
        } catch {
            logger.error("❌ Failed to read audio file: \(error)")
            throw TranscriptionError.audioDataMissing
        }
    }

    // MARK: - Private Helpers

    private func validateAudioData(_ audioData: Data) throws {
        guard !audioData.isEmpty else {
            throw TranscriptionError.audioDataMissing
        }

        guard audioData.count <= maxAudioSize else {
            throw TranscriptionError.audioTooLong
        }

        // Basic WAV header validation (optional but recommended)
        // WAV files start with "RIFF"
        let headerData = audioData.prefix(4)
        if let headerString = String(data: headerData, encoding: .ascii),
           !headerString.hasPrefix("RIFF") && !headerString.hasPrefix("WAVE") {
            logger.warning("⚠️ Audio data may not be in WAV format")
        }
    }

    private func parseMealInfo(from dict: [String: Any]?) -> MealInfo? {
        guard let dict = dict else { return nil }

        let hasMealContent = dict["hasMealContent"] as? Bool ?? false
        let extractedItemsArray = dict["extractedItems"] as? [[String: Any]] ?? []

        let extractedItems = extractedItemsArray.compactMap { itemDict -> ExtractedFoodItem? in
            guard let name = itemDict["name"] as? String else { return nil }

            return ExtractedFoodItem(
                name: name,
                quantity: itemDict["quantity"] as? String,
                unit: itemDict["unit"] as? String
            )
        }

        return MealInfo(
            hasMealContent: hasMealContent,
            extractedItems: extractedItems
        )
    }

    // MARK: - Utility Methods

    /// Extract structured meal data from transcription
    func extractMealData(from transcription: String) async -> [ExtractedFoodItem] {
        // This is a simple extraction logic
        // In production, you might want to use more sophisticated NLP

        var items: [ExtractedFoodItem] = []

        // Common Turkish food quantity patterns
        let patterns = [
            // Number + unit + food (e.g., "2 dilim ekmek", "3 kaşık pilav")
            #"(\d+)\s*(dilim|kaşık|bardak|tabak|kase|adet|tane|porsiyon|gram|gr)\s+(\w+)"#,
            // Food + number + unit (e.g., "elma 2 adet")
            #"(\w+)\s+(\d+)\s*(dilim|kaşık|bardak|tabak|kase|adet|tane|porsiyon|gram|gr)"#,
            // Just food names (e.g., "çorba", "salata")
            #"(çorba|salata|pilav|makarna|et|tavuk|balık|ekmek|peynir|yoğurt|süt|meyve|sebze|\w+)"#
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let matches = regex.matches(
                    in: transcription,
                    range: NSRange(transcription.startIndex..., in: transcription)
                )

                for match in matches {
                    if match.numberOfRanges >= 4 {
                        // Pattern with quantity and unit
                        let quantityRange = Range(match.range(at: 1), in: transcription)
                        let unitRange = Range(match.range(at: 2), in: transcription)
                        let foodRange = Range(match.range(at: 3), in: transcription)

                        if let quantity = quantityRange.flatMap({ String(transcription[$0]) }),
                           let unit = unitRange.flatMap({ String(transcription[$0]) }),
                           let food = foodRange.flatMap({ String(transcription[$0]) }) {
                            items.append(ExtractedFoodItem(
                                name: food,
                                quantity: quantity,
                                unit: unit
                            ))
                        }
                    } else if match.numberOfRanges >= 2 {
                        // Pattern with just food name
                        let foodRange = Range(match.range(at: 1), in: transcription)
                        if let food = foodRange.flatMap({ String(transcription[$0]) }) {
                            items.append(ExtractedFoodItem(
                                name: food,
                                quantity: nil,
                                unit: nil
                            ))
                        }
                    }
                }
            }
        }

        return items
    }
}

// MARK: - Service Singleton

extension TranscriptionService {
    static let shared = TranscriptionService()
}