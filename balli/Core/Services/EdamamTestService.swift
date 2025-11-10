//
//  EdamamTestService.swift
//  balli
//
//  Service for testing EDAMAM API integration via Firebase Functions
//  Swift 6 strict concurrency compliant
//

import Foundation
import OSLog

@MainActor
final class EdamamTestService: ObservableObject {
    // MARK: - Published State
    @Published var isLoading = false
    @Published var lastResult: EdamamTestResult?
    @Published var errorMessage: String?

    // MARK: - Properties
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.balli", category: "EdamamTestService")
    private let firebaseProjectId = "balli-project"

    // Firebase Functions endpoint
    private var functionURL: URL {
        URL(string: "https://us-central1-\(firebaseProjectId).cloudfunctions.net/testEdamamNutrition")!
    }

    // MARK: - Test Recipe with EDAMAM

    /// Test a recipe with EDAMAM API
    /// - Parameters:
    ///   - userId: User ID
    ///   - recipeName: Recipe name
    ///   - meal Type: Meal type (e.g., "Kahvaltı")
    ///   - styleType: Style type (e.g., "Geleneksel")
    ///   - recipeContent: Markdown recipe content from Gemini
    ///   - geminiNutrition: Nutrition values from Gemini
    /// - Returns: Test result with EDAMAM comparison
    func testRecipe(
        userId: String,
        recipeName: String,
        mealType: String,
        styleType: String,
        recipeContent: String,
        geminiNutrition: RequestNutrition
    ) async throws -> EdamamTestResult {
        logger.info("🧪 [EDAMAM-TEST] ═══════════════════════════════════════")
        logger.info("🧪 [EDAMAM-TEST] Starting test for recipe: '\(recipeName)'")
        logger.info("🧪 [EDAMAM-TEST] Meal Type: \(mealType), Style: \(styleType)")
        logger.info("🧪 [EDAMAM-TEST] User ID: \(userId)")

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        // Prepare request
        let request = EdamamTestRequest(
            userId: userId,
            recipeName: recipeName,
            mealType: mealType,
            styleType: styleType,
            recipeContent: recipeContent,
            geminiNutrition: geminiNutrition
        )

        logger.info("   Calories: \(geminiNutrition.calories)")
        logger.info("   Carbs: \(geminiNutrition.carbohydrates)g")
        logger.info("   Protein: \(geminiNutrition.protein)g")
        logger.info("   Fat: \(geminiNutrition.fat)g")
        logger.info("   Fiber: \(geminiNutrition.fiber)g")
        logger.info("   Sugar: \(geminiNutrition.sugar)g")

        logger.info("📤 [EDAMAM-TEST] Preparing request to Firebase Function")
        logger.info("📤 [EDAMAM-TEST] URL: \(self.functionURL.absoluteString)")

        // Create URL request
        var urlRequest = URLRequest(url: functionURL)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = 120 // 2 minute timeout

        // Encode request body
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted

        do {
            urlRequest.httpBody = try encoder.encode(request)
            logger.info("📤 [EDAMAM-TEST] Request body size: \(urlRequest.httpBody?.count ?? 0) bytes")

            // Log first 500 characters of recipe content for debugging
            let previewLength = min(recipeContent.count, 500)
            _ = String(recipeContent.prefix(previewLength))
        } catch {
            logger.error("❌ [EDAMAM-TEST] Failed to encode request: \(error.localizedDescription)")
            throw EdamamTestError.decodingError("Failed to encode request: \(error.localizedDescription)")
        }

        logger.info("🌐 [EDAMAM-TEST] Sending POST request...")

        // Send request
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: urlRequest)
            logger.info("📥 [EDAMAM-TEST] Response received, size: \(data.count) bytes")
        } catch {
            logger.error("❌ [EDAMAM-TEST] Network error: \(error.localizedDescription)")
            if let urlError = error as? URLError {
                logger.error("❌ [EDAMAM-TEST] URLError code: \(urlError.code.rawValue)")
                logger.error("❌ [EDAMAM-TEST] URLError description: \(urlError.localizedDescription)")
            }
            throw error
        }

        // Check HTTP response
        guard let httpResponse = response as? HTTPURLResponse else {
            logger.error("❌ [EDAMAM-TEST] Invalid response type")
            throw EdamamTestError.invalidResponse
        }

        logger.info("📥 [EDAMAM-TEST] HTTP Status Code: \(httpResponse.statusCode)")
        logger.debug("📥 [EDAMAM-TEST] Response headers: \(httpResponse.allHeaderFields)")

        guard httpResponse.statusCode == 200 else {
            logger.error("❌ [EDAMAM-TEST] Non-200 status code: \(httpResponse.statusCode)")

            // Log response body for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                logger.error("❌ [EDAMAM-TEST] Error response body: \(responseString)")
            }

            // Try to parse error response
            if let errorResponse = try? JSONDecoder().decode(EdamamTestResponse.self, from: data),
               let errorMsg = errorResponse.error {
                logger.error("❌ [EDAMAM-TEST] API error message: \(errorMsg)")
                if let message = errorResponse.message {
                    logger.error("❌ [EDAMAM-TEST] Additional message: \(message)")
                }
                throw EdamamTestError.apiError(errorMsg)
            }

            throw EdamamTestError.httpError(httpResponse.statusCode)
        }

        // Decode response
        let decoder = JSONDecoder()
        let testResponse: EdamamTestResponse

        do {
            testResponse = try decoder.decode(EdamamTestResponse.self, from: data)
        } catch {
            logger.error("❌ [EDAMAM-TEST] Decoding error: \(error.localizedDescription)")
            if let decodingError = error as? DecodingError {
                logger.error("❌ [EDAMAM-TEST] Decoding error details: \(decodingError)")
            }
            if let responseString = String(data: data, encoding: .utf8) {
                logger.error("❌ [EDAMAM-TEST] Response that failed to decode: \(responseString)")
            }
            throw EdamamTestError.decodingError(error.localizedDescription)
        }

        guard testResponse.success, let result = testResponse.data else {
            let errorMsg = testResponse.error ?? "Unknown error"
            logger.error("❌ [EDAMAM-TEST] Test failed: \(errorMsg)")
            if let message = testResponse.message {
                logger.error("❌ [EDAMAM-TEST] Additional message: \(message)")
            }
            throw EdamamTestError.testFailed(errorMsg)
        }

        logger.info("   Calories: \(result.geminiNutrition.formattedCalories) kcal")
        logger.info("   Carbs: \(result.geminiNutrition.formattedCarbs)g")
        logger.info("   Protein: \(result.geminiNutrition.formattedProtein)g")
        logger.info("   Fat: \(result.geminiNutrition.formattedFat)g")
        logger.info("   Calories: \(result.edamamNutrition.formattedCalories) kcal")
        logger.info("   Carbs: \(result.edamamNutrition.formattedCarbs)g")
        logger.info("   Protein: \(result.edamamNutrition.formattedProtein)g")
        logger.info("   Fat: \(result.edamamNutrition.formattedFat)g")
        logger.info("   Calories: \(String(format: "%.1f", result.accuracyScores.calories))%")
        logger.info("   Carbs: \(String(format: "%.1f", result.accuracyScores.carbs))%")
        logger.info("   Protein: \(String(format: "%.1f", result.accuracyScores.protein))%")
        logger.info("   Fat: \(String(format: "%.1f", result.accuracyScores.fat))%")
        logger.info("   Recognized: \(result.ingredients.filter { $0.recognized }.count)")
        logger.info("   Turkish characters: \(result.compatibility.turkishIngredientsCount)")
        logger.info("   Fractional measurements: \(result.compatibility.fractionalMeasurementsCount)")
        logger.info("   Turkish measurements: \(result.compatibility.turkishMeasurementsCount)")

        // Store result
        lastResult = result
        return result
    }

    // MARK: - Helper: Convert ViewModel nutrition to Request format

    func convertToRequestNutrition(
        calories: String,
        carbs: String,
        protein: String,
        fat: String,
        fiber: String,
        sugar: String,
        glycemicLoad: String
    ) -> RequestNutrition {
        RequestNutrition(
            calories: calories,
            carbohydrates: carbs,
            protein: protein,
            fat: fat,
            fiber: fiber,
            sugar: sugar,
            glycemicLoad: glycemicLoad
        )
    }
}

// MARK: - Error Types

enum EdamamTestError: LocalizedError {
    case invalidResponse
    case httpError(Int)
    case apiError(String)
    case testFailed(String)
    case decodingError(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .apiError(let message):
            return "API error: \(message)"
        case .testFailed(let message):
            return "Test failed: \(message)"
        case .decodingError(let message):
            return "Decoding error: \(message)"
        }
    }
}
