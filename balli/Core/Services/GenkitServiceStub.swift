//
//  GenkitServiceStub.swift
//  balli
//
//  Minimal stub for GenkitService after ChatAssistant deletion
//  Only supports recipe photo generation (used by RecipePhotoGenerationService)
//  ChatAssistant chat features removed - this stub keeps recipe photos working
//

import Foundation
import OSLog

// MARK: - Genkit Error

enum GenkitError: Error, LocalizedError {
    case photoGenerationFailed(String)
    case httpError(Int, String)
    case chatFeaturesRemoved

    var errorDescription: String? {
        switch self {
        case .photoGenerationFailed(let message):
            return "Photo generation failed: \(message)"
        case .httpError(let code, let message):
            return "HTTP error \(code): \(message)"
        case .chatFeaturesRemoved:
            return "Chat features have been removed. Only recipe photo generation is supported."
        }
    }
}

// MARK: - Genkit Service Protocol

protocol GenkitServiceProtocol: Sendable {
    func generateRecipePhoto(
        recipeName: String,
        ingredients: [String],
        directions: [String],
        mealType: String,
        styleType: String
    ) async throws -> String
}

// MARK: - Genkit Service Stub

actor GenkitService: GenkitServiceProtocol {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.balli", category: "GenkitService")

    // MARK: - Recipe Photo Generation (ONLY remaining feature)

    func generateRecipePhoto(
        recipeName: String,
        ingredients: [String],
        directions: [String],
        mealType: String,
        styleType: String
    ) async throws -> String {
        logger.info("🌐 [GENKIT] generateRecipePhoto() called")
        logger.debug("📋 [GENKIT] Request params:")
        logger.debug("  - recipeName: '\(recipeName)'")
        logger.debug("  - ingredients: \(ingredients.count) items")
        logger.debug("  - directions: \(directions.count) items")
        logger.debug("  - mealType: '\(mealType)'")
        logger.debug("  - styleType: '\(styleType)'")

        // Call Firebase Function for recipe photo generation
        let url = URL(string: "https://us-central1-balli-project.cloudfunctions.net/generateRecipePhoto")!
        logger.info("🔗 [GENKIT] Firebase Function URL: \(url.absoluteString)")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "recipeName": recipeName,
            "ingredients": ingredients,
            "directions": directions,
            "mealType": mealType,
            "styleType": styleType
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        logger.debug("📤 [GENKIT] Request body serialized - \(request.httpBody?.count ?? 0) bytes")

        logger.info("🚀 [GENKIT] Sending HTTP POST request to Firebase Function...")
        let (data, response) = try await URLSession.shared.data(for: request)

        logger.info("✅ [GENKIT] Received HTTP response")
        logger.debug("📥 [GENKIT] Response data size: \(data.count) bytes")

        guard let httpResponse = response as? HTTPURLResponse else {
            logger.error("❌ [GENKIT] Invalid HTTP response type")
            throw GenkitError.httpError(0, "Invalid response")
        }

        logger.info("📊 [GENKIT] HTTP Status Code: \(httpResponse.statusCode)")

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            logger.error("❌ [GENKIT] HTTP error \(httpResponse.statusCode): \(errorMessage)")
            throw GenkitError.httpError(httpResponse.statusCode, errorMessage)
        }

        // Parse response
        logger.info("🔍 [GENKIT] Parsing JSON response...")
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            logger.error("❌ [GENKIT] Failed to parse response as JSON dictionary")
            throw GenkitError.photoGenerationFailed("Failed to parse response as JSON")
        }

        logger.debug("📋 [GENKIT] JSON keys: \(json.keys.joined(separator: ", "))")

        // Check if response has nested 'data' object (Firebase Function wrapper)
        var imageUrl: String?

        if let dataObject = json["data"] as? [String: Any] {
            logger.info("🔍 [GENKIT] Response has nested 'data' object")
            logger.debug("📋 [GENKIT] Data object keys: \(dataObject.keys.joined(separator: ", "))")
            imageUrl = dataObject["imageUrl"] as? String
        } else {
            // Try top-level imageUrl
            imageUrl = json["imageUrl"] as? String
        }

        guard let finalImageUrl = imageUrl else {
            logger.error("❌ [GENKIT] 'imageUrl' field missing or not a string")
            logger.debug("📋 [GENKIT] Top-level keys: \(json.keys.joined(separator: ", "))")
            if let dataObj = json["data"] as? [String: Any] {
                logger.debug("📋 [GENKIT] Data object keys: \(dataObj.keys.joined(separator: ", "))")
            }
            throw GenkitError.photoGenerationFailed("Failed to parse image URL from response")
        }

        logger.info("✅ [GENKIT] Successfully extracted imageUrl")
        logger.debug("🔍 [GENKIT] imageUrl prefix: \(finalImageUrl.prefix(60))...")
        logger.debug("🔍 [GENKIT] imageUrl length: \(finalImageUrl.count) characters")

        return finalImageUrl
    }
}
