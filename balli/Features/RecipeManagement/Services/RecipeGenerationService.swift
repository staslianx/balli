//
//  RecipeGenerationService.swift
//  balli
//
//  Service for AI-powered recipe generation using Firebase Functions and Gemini 2.5 Flash
//  Swift 6 strict concurrency compliant with actor isolation
//

import Foundation
import Network

/// Response model for recipe generation API calls
public struct RecipeGenerationResponse: Codable, Sendable {
    public let recipeName: String
    public let prepTime: String
    public let cookTime: String
    public let waitingTime: String?  // Optional waiting time (e.g., marinating, rising, resting)
    public let ingredients: [String]  // Legacy: kept for backward compatibility
    public let directions: [String]  // Legacy: kept for backward compatibility
    public let notes: String?  // DEPRECATED: AI notes no longer generated, field kept for backward compatibility
    public let recipeContent: String?  // NEW: Markdown content (ingredients + directions)
    public let calories: String
    public let carbohydrates: String
    public let fiber: String
    public let protein: String
    public let fat: String
    public let sugar: String
    public let glycemicLoad: String
    public let extractedIngredients: [String]?  // NEW: Main ingredients extracted by Cloud Functions for memory system
}

/// Simple recent recipe for diversity tracking
public struct SimpleRecentRecipe: Codable, Sendable {
    public let title: String
    public let mainIngredient: String
    public let cookingMethod: String

    public init(title: String, mainIngredient: String, cookingMethod: String) {
        self.title = title
        self.mainIngredient = mainIngredient
        self.cookingMethod = cookingMethod
    }
}

/// Diversity constraints for recipe generation to avoid repetition
public struct DiversityConstraints: Codable, Sendable {
    public let avoidCuisines: [String]?
    public let avoidProteins: [String]?
    public let avoidMethods: [String]?
    public let suggestCuisines: [String]?
    public let suggestProteins: [String]?

    public init(
        avoidCuisines: [String]? = nil,
        avoidProteins: [String]? = nil,
        avoidMethods: [String]? = nil,
        suggestCuisines: [String]? = nil,
        suggestProteins: [String]? = nil
    ) {
        self.avoidCuisines = avoidCuisines
        self.avoidProteins = avoidProteins
        self.avoidMethods = avoidMethods
        self.suggestCuisines = suggestCuisines
        self.suggestProteins = suggestProteins
    }
}

/// Request model for spontaneous recipe generation
public struct SpontaneousRecipeRequest: Codable, Sendable {
    public let mealType: String
    public let styleType: String
    public let userId: String?
    public let streamingEnabled: Bool
    public let recentRecipes: [SimpleRecentRecipe]
    public let diversityConstraints: DiversityConstraints?
    public let userContext: String?

    public init(
        mealType: String,
        styleType: String,
        userId: String? = nil,
        streamingEnabled: Bool = false,
        recentRecipes: [SimpleRecentRecipe] = [],
        diversityConstraints: DiversityConstraints? = nil,
        userContext: String? = nil
    ) {
        self.mealType = mealType
        self.styleType = styleType
        self.userId = userId
        self.streamingEnabled = streamingEnabled
        self.recentRecipes = recentRecipes
        self.diversityConstraints = diversityConstraints
        self.userContext = userContext
    }
}

/// Recipe generation service actor for thread-safe API operations
@globalActor
public actor RecipeGenerationService: RecipeGenerationServiceProtocol {
    public static let shared = RecipeGenerationService()

    private let session: URLSession
    private let configuration: NetworkConfiguration

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60.0
        config.timeoutIntervalForResource = 300.0
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData

        self.session = URLSession(configuration: config)
        self.configuration = NetworkConfiguration.shared
    }

    // MARK: - Public Methods

    /// Generate a spontaneous recipe based on meal type and style
    /// - Parameters:
    ///   - mealType: The type of meal (e.g., "Kahvaltı", "Akşam Yemeği")
    ///   - styleType: The style subcategory for the meal type
    ///   - userId: Optional user ID for personalization
    ///   - recentRecipes: Recent recipes for diversity (empty array = no diversity constraints)
    ///   - diversityConstraints: Constraints for avoiding overused ingredients/proteins
    ///   - userContext: Optional user context or notes for recipe generation
    /// - Returns: Generated recipe with all fields populated
    /// - Throws: NetworkError if the request fails
    public func generateSpontaneousRecipe(
        mealType: String,
        styleType: String,
        userId: String? = nil,
        recentRecipes: [SimpleRecentRecipe] = [],
        diversityConstraints: DiversityConstraints? = nil,
        userContext: String? = nil
    ) async throws -> RecipeGenerationResponse {


        let request = SpontaneousRecipeRequest(
            mealType: mealType,
            styleType: styleType,
            userId: userId,
            streamingEnabled: false, // Non-streaming for complete response
            recentRecipes: recentRecipes,
            diversityConstraints: diversityConstraints,
            userContext: userContext
        )

        let url = try buildGenerateURL()

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = 60.0

        // Encode request body
        let requestData = try JSONEncoder().encode(request)
        urlRequest.httpBody = requestData


        // Execute request
        let (data, response) = try await session.data(for: urlRequest)


        // Validate response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponseData
        }


        guard httpResponse.statusCode == 200 else {
            // Try to extract error message from response body
            if String(data: data, encoding: .utf8) != nil {
                // Error string available for debugging
            }
            throw NetworkError.serverError(
                statusCode: httpResponse.statusCode,
                message: "Recipe generation failed with status \(httpResponse.statusCode)"
            )
        }

        // Parse response
        do {
            // Log raw response for debugging
            if String(data: data, encoding: .utf8) != nil {
                // Response string available for debugging
            }

            let responseContainer = try JSONDecoder().decode(ResponseContainer.self, from: data)
            return responseContainer.data
        } catch {
            if error is DecodingError {
                // Decoding error available for debugging
            }
            throw NetworkError.decodingError(underlying: error)
        }
    }

    /// Generate recipe with ingredient suggestions based on meal type and style
    /// - Parameters:
    ///   - mealType: The type of meal (e.g., "Kahvaltı", "Akşam Yemeği")
    ///   - styleType: The style subcategory for the meal type
    ///   - ingredients: Available ingredients to use in the recipe
    ///   - userId: Optional user ID for personalization
    ///   - userContext: Optional user context or notes for recipe generation
    /// - Returns: Generated recipe incorporating the provided ingredients
    /// - Throws: NetworkError if the request fails
    public func generateRecipeFromIngredients(
        mealType: String,
        styleType: String,
        ingredients: [String],
        userId: String? = nil,
        userContext: String? = nil
    ) async throws -> RecipeGenerationResponse {

        let request = IngredientsRecipeRequest(
            mealType: mealType,
            styleType: styleType,
            ingredients: ingredients,
            userId: userId,
            streamingEnabled: false,
            userContext: userContext
        )

        let url = try buildIngredientsURL()
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = 60.0

        // Encode request body
        let requestData = try JSONEncoder().encode(request)
        urlRequest.httpBody = requestData

        // Execute request
        let (data, response) = try await session.data(for: urlRequest)

        // Validate response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponseData
        }

        guard httpResponse.statusCode == 200 else {
            throw NetworkError.serverError(
                statusCode: httpResponse.statusCode,
                message: "Recipe generation from ingredients failed with status \(httpResponse.statusCode)"
            )
        }

        // Parse response
        do {
            let responseContainer = try JSONDecoder().decode(ResponseContainer.self, from: data)
            return responseContainer.data
        } catch {
            throw NetworkError.decodingError(underlying: error)
        }
    }

    // MARK: - Private Methods

    private func buildGenerateURL() throws -> URL {
        guard let url = URL(string: "\(configuration.baseURL)/generateSpontaneousRecipe") else {
            throw NetworkError.invalidRequest(reason: "Invalid spontaneous recipe generation URL")
        }
        return url
    }

    private func buildIngredientsURL() throws -> URL {
        guard let url = URL(string: "\(configuration.baseURL)/generateRecipeFromIngredients") else {
            throw NetworkError.invalidRequest(reason: "Invalid ingredients recipe generation URL")
        }
        return url
    }
}

// MARK: - Supporting Types

/// Request model for ingredients-based recipe generation
private struct IngredientsRecipeRequest: Codable, Sendable {
    let mealType: String
    let styleType: String
    let ingredients: [String]
    let userId: String?
    let streamingEnabled: Bool
    let userContext: String?
}

/// Response container matching Firebase Functions response format
private struct ResponseContainer: Codable {
    let success: Bool
    let data: RecipeGenerationResponse
}

// MARK: - NetworkError Extensions

extension NetworkError {
    static var recipeGenerationFailed: NetworkError {
        NetworkError.invalidRequest(reason: "Recipe generation request failed")
    }

    static var recipeParsingFailed: NetworkError {
        NetworkError.invalidRequest(reason: "Failed to parse recipe response")
    }
}