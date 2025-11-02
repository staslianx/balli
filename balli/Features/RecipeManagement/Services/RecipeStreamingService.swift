//
//  RecipeStreamingService.swift
//  balli
//
//  HTTP/SSE streaming client for recipe generation
//  Swift 6 strict concurrency compliant
//

import Foundation
import OSLog

/// SSE streaming service for recipe generation
@MainActor
class RecipeStreamingService {

    // MARK: - Logger

    private let logger = AppLoggers.Recipe.generation

    // Cloud Function URLs
    private let generateFromIngredientsURL = "https://us-central1-balli-project.cloudfunctions.net/generateRecipeFromIngredients"
    private let generateSpontaneousURL = "https://us-central1-balli-project.cloudfunctions.net/generateSpontaneousRecipe"

    /// Generate recipe with streaming from ingredients
    func generateWithIngredients(
        ingredients: [String],
        mealType: String,
        styleType: String,
        userId: String,
        onConnected: @escaping @Sendable () -> Void,
        onChunk: @escaping @Sendable (String, String, Int) -> Void,  // (chunkText, fullContent, tokenCount)
        onComplete: @escaping @Sendable (RecipeGenerationResponse) -> Void,
        onError: @escaping @Sendable (Error) -> Void
    ) async {
        let requestBody: [String: Any] = [
            "ingredients": ingredients,
            "mealType": mealType,
            "styleType": styleType,
            "userId": userId
        ]

        await performStreaming(
            url: generateFromIngredientsURL,
            requestBody: requestBody,
            onConnected: onConnected,
            onChunk: onChunk,
            onComplete: onComplete,
            onError: onError
        )
    }

    /// Generate spontaneous recipe with streaming
    func generateSpontaneous(
        mealType: String,
        styleType: String,
        userId: String,
        recentRecipes: [SimpleRecentRecipe] = [],
        diversityConstraints: DiversityConstraints? = nil,
        onConnected: @escaping @Sendable () -> Void,
        onChunk: @escaping @Sendable (String, String, Int) -> Void,  // (chunkText, fullContent, tokenCount)
        onComplete: @escaping @Sendable (RecipeGenerationResponse) -> Void,
        onError: @escaping @Sendable (Error) -> Void
    ) async {
        // Convert recent recipes to dictionary format
        let recentRecipesData = recentRecipes.map { recipe in
            [
                "title": recipe.title,
                "mainIngredient": recipe.mainIngredient,
                "cookingMethod": recipe.cookingMethod
            ]
        }

        var requestBody: [String: Any] = [
            "mealType": mealType,
            "styleType": styleType,
            "userId": userId,
            "recentRecipes": recentRecipesData
        ]

        // Add diversity constraints if provided
        if let constraints = diversityConstraints {
            var constraintsDict: [String: Any] = [:]
            if let avoidProteins = constraints.avoidProteins {
                constraintsDict["avoidProteins"] = avoidProteins
            }
            if let suggestProteins = constraints.suggestProteins {
                constraintsDict["suggestProteins"] = suggestProteins
            }
            if let avoidCuisines = constraints.avoidCuisines {
                constraintsDict["avoidCuisines"] = avoidCuisines
            }
            if let suggestCuisines = constraints.suggestCuisines {
                constraintsDict["suggestCuisines"] = suggestCuisines
            }
            if let avoidMethods = constraints.avoidMethods {
                constraintsDict["avoidMethods"] = avoidMethods
            }
            if !constraintsDict.isEmpty {
                requestBody["diversityConstraints"] = constraintsDict
            }
        }

        await performStreaming(
            url: generateSpontaneousURL,
            requestBody: requestBody,
            onConnected: onConnected,
            onChunk: onChunk,
            onComplete: onComplete,
            onError: onError
        )
    }

    // MARK: - Private Methods

    private func performStreaming(
        url: String,
        requestBody: [String: Any],
        onConnected: @escaping @Sendable () -> Void,
        onChunk: @escaping @Sendable (String, String, Int) -> Void,
        onComplete: @escaping @Sendable (RecipeGenerationResponse) -> Void,
        onError: @escaping @Sendable (Error) -> Void
    ) async {
        guard let requestURL = URL(string: url) else {
            logger.error("Invalid function URL: \(url, privacy: .public)")
            onError(RecipeStreamingError.invalidURL)
            return
        }

        // Create request
        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 180  // 3 minutes timeout

        // Convert body to JSON
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            logger.error("Failed to serialize request body")
            onError(RecipeStreamingError.invalidRequest)
            return
        }
        request.httpBody = jsonData

        // Capture for concurrency safety
        let immutableRequest = request

        do {
            // Create URL session for streaming
            let (asyncBytes, response) = try await URLSession.shared.bytes(for: immutableRequest)

            // Check HTTP status
            guard let httpResponse = response as? HTTPURLResponse else {
                logger.error("Invalid HTTP response")
                onError(RecipeStreamingError.invalidResponse)
                return
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                logger.error("HTTP error: \(httpResponse.statusCode)")
                onError(RecipeStreamingError.httpError(statusCode: httpResponse.statusCode))
                return
            }

            logger.info("🔌 [STREAMING] Connected to recipe generation stream")

            // Process SSE events
            var eventType = ""
            var eventData = ""

            for try await line in asyncBytes.lines {
                if line.hasPrefix("event:") {
                    eventType = String(line.dropFirst(6).trimmingCharacters(in: .whitespaces))
                } else if line.hasPrefix("data:") {
                    eventData = String(line.dropFirst(5).trimmingCharacters(in: .whitespaces))

                    // Parse event data
                    if let jsonData = eventData.data(using: .utf8),
                       let event = try? JSONDecoder().decode(RecipeSSEEvent.self, from: jsonData) {

                        await handleSSEEvent(
                            event: event,
                            eventType: eventType,
                            onConnected: onConnected,
                            onChunk: onChunk,
                            onComplete: onComplete,
                            onError: onError
                        )
                    }

                    // Reset for next event
                    eventType = ""
                    eventData = ""
                }
            }

        } catch {
            logger.error("❌ [STREAMING] Connection error: \(error.localizedDescription)")
            onError(error)
        }
    }

    private func handleSSEEvent(
        event: RecipeSSEEvent,
        eventType: String,
        onConnected: @Sendable () -> Void,
        onChunk: @Sendable (String, String, Int) -> Void,
        onComplete: @Sendable (RecipeGenerationResponse) -> Void,
        onError: @Sendable (Error) -> Void
    ) async {
        switch event.type {
        case "connected":
            logger.info("✅ [STREAMING] Connected to recipe generation")
            onConnected()

        case "chunk":
            if let chunkData = event.data as? [String: Any],
               let chunkText = chunkData["content"] as? String,
               let fullContent = chunkData["fullContent"] as? String,
               let tokenCount = chunkData["tokenCount"] as? Int {

                onChunk(chunkText, fullContent, tokenCount)
            }

        case "completed":
            logger.info("🎉 [STREAMING] Recipe generation completed")

            // Parse recipe response from event.data
            do {
                // Extract values from the dictionary and construct the response manually
                // This avoids serialization issues with nested Any types
                // Try both "recipeName" and "name" for backward compatibility
                guard let recipeName = (event.data["recipeName"] as? String) ?? (event.data["name"] as? String) else {
                    throw RecipeStreamingError.serverError(message: "Missing recipeName or name in response")
                }

                // Helper to safely extract string or convert number to string, default to empty
                let getString = { (key: String) -> String in
                    if let str = event.data[key] as? String {
                        return str
                    } else if let num = event.data[key] as? NSNumber {
                        return num.stringValue
                    }
                    return ""
                }

                // Helper to safely extract string array
                let getStringArray = { (key: String) -> [String] in
                    if let array = event.data[key] as? [Any] {
                        return array.compactMap { $0 as? String }
                    }
                    return []
                }

                let response = RecipeGenerationResponse(
                    recipeName: recipeName,
                    prepTime: getString("prepTime"),
                    cookTime: getString("cookTime"),
                    ingredients: getStringArray("ingredients"),
                    directions: getStringArray("directions"),
                    notes: getString("notes"),
                    recipeContent: event.data["recipeContent"] as? String,
                    calories: getString("calories"),
                    carbohydrates: getString("carbohydrates"),
                    fiber: getString("fiber"),
                    protein: getString("protein"),
                    fat: getString("fat"),
                    sugar: getString("sugar"),
                    glycemicLoad: getString("glycemicLoad"),
                    extractedIngredients: getStringArray("extractedIngredients")
                )

                logger.info("✅ [STREAMING] Successfully parsed recipe: \(response.recipeName)")
                logger.debug("✅ [STREAMING] Nutrition values - Calories: \(response.calories), Carbs: \(response.carbohydrates), Protein: \(response.protein), Fat: \(response.fat)")
                onComplete(response)
            } catch {
                logger.error("❌ [STREAMING] Failed to parse recipe response: \(error.localizedDescription)")
                logger.error("❌ [STREAMING] Event data keys: \(event.data.keys.joined(separator: ", "))")
                onError(RecipeStreamingError.decodingError(error))
            }

        case "error":
            logger.error("❌ [STREAMING] Recipe generation error")
            if let errorData = event.data as? [String: Any],
               let errorMessage = errorData["message"] as? String {
                onError(RecipeStreamingError.serverError(message: errorMessage))
            } else {
                onError(RecipeStreamingError.unknownError)
            }

        default:
            logger.warning("⚠️ [STREAMING] Unknown event type: \(event.type)")
        }
    }
}

// MARK: - Recipe SSE Event Models

private struct RecipeSSEEvent: Codable {
    let type: String
    let data: [String: Any]
    let timestamp: String

    enum CodingKeys: String, CodingKey {
        case type, data, timestamp
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        timestamp = try container.decode(String.self, forKey: .timestamp)

        // Decode data as flexible dictionary
        let dataContainer = try container.decode([String: AnyCodable].self, forKey: .data)
        data = dataContainer.mapValues { $0.value }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(timestamp, forKey: .timestamp)

        // Encode data as flexible dictionary
        let dataContainer = data.mapValues { AnyCodable(value: $0) }
        try container.encode(dataContainer, forKey: .data)
    }
}

// Helper for decoding Any values
private struct AnyCodable: Codable {
    let value: Any

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported type")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let bool as Bool:
            try container.encode(bool)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable(value: $0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable(value: $0) })
        default:
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: [], debugDescription: "Unsupported type"))
        }
    }

    init(value: Any) {
        self.value = value
    }
}

// MARK: - Error Types

enum RecipeStreamingError: LocalizedError {
    case invalidURL
    case invalidRequest
    case invalidResponse
    case httpError(statusCode: Int)
    case decodingError(Error)
    case serverError(message: String)
    case unknownError

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid streaming URL"
        case .invalidRequest:
            return "Invalid request data"
        case .invalidResponse:
            return "Invalid server response"
        case .httpError(let statusCode):
            return "Server error: \(statusCode)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .serverError(let message):
            return "Server error: \(message)"
        case .unknownError:
            return "Unknown error occurred"
        }
    }
}
