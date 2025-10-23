//
//  GenkitServiceStub.swift
//  balli
//
//  Minimal stub for GenkitService after ChatAssistant deletion
//  Only supports recipe photo generation (used by RecipePhotoGenerationService)
//  ChatAssistant chat features removed - this stub keeps recipe photos working
//

import Foundation

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

    // MARK: - Recipe Photo Generation (ONLY remaining feature)

    func generateRecipePhoto(
        recipeName: String,
        ingredients: [String],
        directions: [String],
        mealType: String,
        styleType: String
    ) async throws -> String {
        // Call Firebase Function for recipe photo generation
        let url = URL(string: "https://us-central1-balli-project.cloudfunctions.net/generateRecipePhoto")!

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

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GenkitError.httpError(0, "Invalid response")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw GenkitError.httpError(httpResponse.statusCode, errorMessage)
        }

        // Parse response
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let imageUrl = json["imageUrl"] as? String else {
            throw GenkitError.photoGenerationFailed("Failed to parse image URL from response")
        }

        return imageUrl
    }
}
