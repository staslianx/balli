//
//  RecipePhotoGenerationService.swift
//  balli
//
//  Service responsible for AI-powered recipe photo generation using Firebase Functions and Imagen 4 Ultra
//  Swift 6 strict concurrency compliant with actor isolation
//

import Foundation

/// Response model for recipe photo generation API calls
public struct RecipePhotoGenerationResponse: Codable, Sendable {
    public let imageUrl: String
    public let prompt: String
    public let generationTime: String
    public let recipeName: String
}

/// Request model for recipe photo generation
public struct RecipePhotoRequest: Codable, Sendable {
    public let recipeName: String
    public let ingredients: [String]
    public let directions: [String]
    public let mealType: String
    public let styleType: String
    public let userId: String?

    public init(recipeName: String, ingredients: [String], directions: [String],
                mealType: String, styleType: String, userId: String? = nil) {
        self.recipeName = recipeName
        self.ingredients = ingredients
        self.directions = directions
        self.mealType = mealType
        self.styleType = styleType
        self.userId = userId
    }
}

/// Recipe photo generation service actor for thread-safe API operations
@globalActor
public actor RecipePhotoGenerationService {
    public static let shared = RecipePhotoGenerationService()

    private let genkitService: GenkitService

    private init() {
        self.genkitService = GenkitService()
    }

    // MARK: - Public Methods

    /// Generate a professional photo for a recipe using AI
    /// - Parameters:
    ///   - recipeName: The name of the recipe to photograph
    ///   - ingredients: List of ingredients in the recipe
    ///   - directions: Cooking instructions for reference
    ///   - mealType: Type of meal (e.g., "Kahvaltı", "Akşam Yemeği")
    ///   - styleType: Style subcategory for the meal type
    ///   - userId: Optional user ID for analytics
    /// - Returns: URL of the generated image
    /// - Throws: NetworkError if the request fails
    public func generateRecipePhoto(
        recipeName: String,
        ingredients: [String],
        directions: [String],
        mealType: String,
        styleType: String,
        userId: String? = nil
    ) async throws -> String {

        do {
            // Use GenkitService to generate the recipe image
            let imageUrl = try await genkitService.generateRecipePhoto(
                recipeName: recipeName,
                ingredients: ingredients,
                directions: directions,
                mealType: mealType,
                styleType: styleType
            )

            return imageUrl
        } catch {
            // Convert GenkitError to NetworkError for consistency
            if let genkitError = error as? GenkitError {
                switch genkitError {
                case .photoGenerationFailed:
                    throw NetworkError.serverError(statusCode: 500, message: genkitError.localizedDescription)
                case .httpError(let statusCode, let message):
                    throw NetworkError.serverError(statusCode: statusCode, message: message)
                default:
                    throw NetworkError.invalidResponseData
                }
            } else {
                throw NetworkError.invalidResponseData
            }
        }
    }

}

// MARK: - NetworkError Extensions

extension NetworkError {
    static var photoGenerationFailed: NetworkError {
        NetworkError.invalidRequest(reason: "Recipe photo generation request failed")
    }

    static var photoParsingFailed: NetworkError {
        NetworkError.invalidRequest(reason: "Failed to parse photo generation response")
    }
}