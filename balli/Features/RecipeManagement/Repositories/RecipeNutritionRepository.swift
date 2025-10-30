//
//  RecipeNutritionRepository.swift
//  balli
//
//  On-demand nutrition calculation using Gemini 2.5 Pro
//  Swift 6 strict concurrency compliant
//

import Foundation
import OSLog

/// Thread-safe repository for on-demand recipe nutrition calculation
/// Uses Gemini 2.5 Pro at temperature 0.7 for accurate nutrition analysis
actor RecipeNutritionRepository {
    // MARK: - Properties

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.balli.app",
        category: "RecipeNutrition"
    )

    // Cloud Function URL for nutrition calculation
    private let nutritionCalculatorURL = "https://us-central1-balli-project.cloudfunctions.net/calculateRecipeNutrition"

    // MARK: - Public Methods

    /// Calculate nutrition for a recipe on-demand using Gemini 2.5 Pro
    /// - Parameters:
    ///   - recipeName: Name of the recipe
    ///   - recipeContent: Full markdown content (ingredients + directions)
    ///   - servings: Number of servings the recipe makes
    /// - Returns: Nutrition data including calories, macros, and glycemic load
    /// - Throws: RecipeNutritionError if calculation fails
    func calculateNutrition(
        recipeName: String,
        recipeContent: String,
        servings: Int
    ) async throws -> RecipeNutritionData {
        logger.info("🍽️ [NUTRITION-CALC] Requesting calculation for: \(recipeName, privacy: .public)")
        logger.info("🍽️ [NUTRITION-CALC] Servings: \(servings)")

        guard let url = URL(string: nutritionCalculatorURL) else {
            logger.error("❌ [NUTRITION-CALC] Invalid URL: \(self.nutritionCalculatorURL)")
            throw RecipeNutritionError.invalidURL
        }

        // Prepare request body
        let requestBody: [String: Any] = [
            "recipeName": recipeName,
            "recipeContent": recipeContent,
            "servings": servings
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            logger.error("❌ [NUTRITION-CALC] Failed to serialize request body")
            throw RecipeNutritionError.requestSerializationFailed
        }

        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        request.timeoutInterval = 120  // 120 seconds to accommodate Cloud Function's 90s timeout

        do {
            // Make request
            let (data, response) = try await URLSession.shared.data(for: request)

            // Check response status
            guard let httpResponse = response as? HTTPURLResponse else {
                logger.error("❌ [NUTRITION-CALC] Invalid response type")
                throw RecipeNutritionError.invalidResponse
            }

            logger.info("🍽️ [NUTRITION-CALC] Response status: \(httpResponse.statusCode)")

            guard httpResponse.statusCode == 200 else {
                logger.error("❌ [NUTRITION-CALC] HTTP error: \(httpResponse.statusCode)")

                // Try to parse error message
                if let errorResponse = try? JSONDecoder().decode(RecipeNutritionErrorResponse.self, from: data) {
                    logger.error("❌ [NUTRITION-CALC] Error: \(errorResponse.error)")
                    throw RecipeNutritionError.serverError(errorResponse.error)
                }

                throw RecipeNutritionError.httpError(httpResponse.statusCode)
            }

            // Parse response
            let apiResponse = try JSONDecoder().decode(RecipeNutritionAPIResponse.self, from: data)

            guard apiResponse.success else {
                logger.error("❌ [NUTRITION-CALC] API returned success=false")
                throw RecipeNutritionError.calculationFailed
            }

            logger.info("✅ [NUTRITION-CALC] Calculation complete:")
            logger.info("   Calories: \(apiResponse.data.calories) kcal/100g")
            logger.info("   Carbs: \(apiResponse.data.carbohydrates)g, Protein: \(apiResponse.data.protein)g, Fat: \(apiResponse.data.fat)g")
            logger.info("   Glycemic Load: \(apiResponse.data.glycemicLoad)")

            return apiResponse.data

        } catch let error as RecipeNutritionError {
            throw error
        } catch {
            logger.error("❌ [NUTRITION-CALC] Network error: \(error.localizedDescription)")
            throw RecipeNutritionError.networkError(error.localizedDescription)
        }
    }
}

// MARK: - Data Models

/// Per-portion nutrition values from API
struct PerPortionNutrition: Codable, Sendable {
    let weight: Double
    let calories: Double
    let carbohydrates: Double
    let fiber: Double
    let sugar: Double
    let protein: Double
    let fat: Double
    let glycemicLoad: Double
}

/// Digestion timing insights from API (insulin-glucose curve mismatch)
public struct DigestionTiming: Codable, Sendable {
    public let hasMismatch: Bool
    public let mismatchHours: Double
    public let severity: String  // "low", "medium", "high"
    public let glucosePeakTime: Double  // Hours after meal
    public let timingInsight: String  // Markdown formatted insight
}

/// Nutrition data returned from the Cloud Function
struct RecipeNutritionData: Codable, Sendable {
    // Per-100g values
    let calories: Double
    let carbohydrates: Double
    let fiber: Double
    let sugar: Double
    let protein: Double
    let fat: Double
    let glycemicLoad: Double  // This is per-portion GL

    // Per-portion values (direct from API)
    let perPortion: PerPortionNutrition?
    let nutritionCalculation: NutritionCalculationDetails?

    // Digestion timing insights (insulin-glucose curve analysis)
    let digestionTiming: DigestionTiming?

    /// Per-serving nutrition values (use API values if available, otherwise calculate)
    var caloriesPerServing: Double {
        perPortion?.calories ?? (calories * multiplier)
    }

    var carbohydratesPerServing: Double {
        perPortion?.carbohydrates ?? (carbohydrates * multiplier)
    }

    var fiberPerServing: Double {
        perPortion?.fiber ?? (fiber * multiplier)
    }

    var sugarPerServing: Double {
        perPortion?.sugar ?? (sugar * multiplier)
    }

    var proteinPerServing: Double {
        perPortion?.protein ?? (protein * multiplier)
    }

    var fatPerServing: Double {
        perPortion?.fat ?? (fat * multiplier)
    }

    /// Glycemic Load is already per-portion from API (NOT per-100g)
    var glycemicLoadPerServing: Double {
        perPortion?.glycemicLoad ?? glycemicLoad
    }

    var totalRecipeWeight: Double {
        perPortion?.weight ?? nutritionCalculation?.totalRecipeWeight ?? 0
    }

    /// Calculate per-serving values (fallback when perPortion is not available)
    /// Multiplier = (totalRecipeWeight / 100) to convert from per-100g to per-serving
    private var multiplier: Double {
        guard let weight = nutritionCalculation?.totalRecipeWeight, weight > 0 else {
            return 1.0
        }
        return weight / 100.0
    }

    /// Convert to string values for RecipeFormState compatibility (per-100g values)
    func toFormState() -> (
        calories: String,
        carbohydrates: String,
        fiber: String,
        sugar: String,
        protein: String,
        fat: String,
        glycemicLoad: String
    ) {
        return (
            calories: String(format: "%.0f", calories),
            carbohydrates: String(format: "%.1f", carbohydrates),
            fiber: String(format: "%.1f", fiber),
            sugar: String(format: "%.1f", sugar),
            protein: String(format: "%.1f", protein),
            fat: String(format: "%.1f", fat),
            glycemicLoad: String(format: "%.0f", glycemicLoad)
        )
    }

    /// Convert per-serving values to strings for display
    func toFormStatePerServing() -> (
        calories: String,
        carbohydrates: String,
        fiber: String,
        sugar: String,
        protein: String,
        fat: String,
        glycemicLoad: String,
        totalRecipeWeight: String
    ) {
        return (
            calories: String(format: "%.0f", caloriesPerServing),
            carbohydrates: String(format: "%.1f", carbohydratesPerServing),
            fiber: String(format: "%.1f", fiberPerServing),
            sugar: String(format: "%.1f", sugarPerServing),
            protein: String(format: "%.1f", proteinPerServing),
            fat: String(format: "%.1f", fatPerServing),
            glycemicLoad: String(format: "%.0f", glycemicLoadPerServing),
            totalRecipeWeight: String(format: "%.0f", totalRecipeWeight)
        )
    }
}

struct NutritionCalculationDetails: Codable, Sendable {
    let totalRecipeWeight: Double
    let totalRecipeCalories: Double
    let calculationNotes: String
}

struct RecipeNutritionAPIResponse: Codable {
    let success: Bool
    let data: RecipeNutritionData
}

struct RecipeNutritionErrorResponse: Codable {
    let success: Bool
    let error: String
}

// MARK: - Errors

enum RecipeNutritionError: LocalizedError {
    case invalidURL
    case requestSerializationFailed
    case invalidResponse
    case httpError(Int)
    case serverError(String)
    case calculationFailed
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid nutrition calculation URL"
        case .requestSerializationFailed:
            return "Failed to prepare nutrition calculation request"
        case .invalidResponse:
            return "Invalid response from nutrition calculation service"
        case .httpError(let code):
            return "Nutrition calculation failed with HTTP error \(code)"
        case .serverError(let message):
            return "Nutrition calculation error: \(message)"
        case .calculationFailed:
            return "Nutrition calculation failed"
        case .networkError(let message):
            return "Network error during nutrition calculation: \(message)"
        }
    }
}
