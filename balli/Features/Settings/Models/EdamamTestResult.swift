//
//  EdamamTestResult.swift
//  balli
//
//  Data models for EDAMAM API testing
//  Matches Firebase Function response structure
//

import Foundation

// MARK: - Main Test Result

struct EdamamTestResult: Codable, Sendable {
    let testId: String
    let recipeName: String
    let geminiNutrition: EdamamNutritionValues
    let edamamNutrition: EdamamNutritionValues
    let accuracyScores: AccuracyScores
    let overallAccuracy: Int
    let recognitionRate: Int
    let ingredients: [IngredientResult]
    let compatibility: CompatibilityInfo
    let processingTime: String
    let edamamResponse: EdamamFullResponse?

    // Display helpers
    var accuracyGrade: String {
        switch overallAccuracy {
        case 90...100: return "A"
        case 80..<90: return "B"
        case 70..<80: return "C"
        case 60..<70: return "D"
        default: return "F"
        }
    }

    var accuracyColor: String {
        switch overallAccuracy {
        case 90...100: return "green"
        case 80..<90: return "blue"
        case 70..<80: return "yellow"
        case 60..<70: return "orange"
        default: return "red"
        }
    }

    var recognitionStatus: String {
        switch recognitionRate {
        case 90...100: return "Excellent"
        case 80..<90: return "Good"
        case 70..<80: return "Fair"
        case 60..<70: return "Poor"
        default: return "Very Poor"
        }
    }
}

// MARK: - Nutrition Values

struct EdamamNutritionValues: Codable, Sendable {
    let calories: Double
    let carbohydrates: Double
    let protein: Double
    let fat: Double
    let fiber: Double
    let sugar: Double

    var formattedCalories: String {
        String(format: "%.0f", calories)
    }

    var formattedCarbs: String {
        String(format: "%.1f", carbohydrates)
    }

    var formattedProtein: String {
        String(format: "%.1f", protein)
    }

    var formattedFat: String {
        String(format: "%.1f", fat)
    }

    var formattedFiber: String {
        String(format: "%.1f", fiber)
    }

    var formattedSugar: String {
        String(format: "%.1f", sugar)
    }
}

// MARK: - Accuracy Scores

struct AccuracyScores: Codable, Sendable {
    let calories: Double
    let carbs: Double
    let protein: Double
    let fat: Double
    let fiber: Double
    let sugar: Double

    func getScore(for nutrient: String) -> Double {
        switch nutrient.lowercased() {
        case "calories": return calories
        case "carbs", "carbohydrates": return carbs
        case "protein": return protein
        case "fat": return fat
        case "fiber": return fiber
        case "sugar": return sugar
        default: return 0
        }
    }
}

// MARK: - Ingredient Result

struct IngredientResult: Codable, Identifiable, Sendable {
    var id: String { text }

    let text: String
    let recognized: Bool
    let confidence: Double
    let hasTurkishCharacters: Bool
    let hasFractionalMeasurement: Bool
    let hasTurkishMeasurement: Bool
    let parsedData: ParsedIngredientData?

    var statusIcon: String {
        recognized ? "checkmark.circle.fill" : "xmark.circle.fill"
    }

    var statusColor: String {
        recognized ? "green" : "red"
    }

    var badges: [String] {
        var result: [String] = []
        if hasTurkishCharacters { result.append("🇹🇷") }
        if hasFractionalMeasurement { result.append("½") }
        if hasTurkishMeasurement { result.append("📏") }
        return result
    }
}

struct ParsedIngredientData: Codable, Sendable {
    let quantity: Double?
    let measure: String?
    let food: String?
    let weight: Double?
    let foodMatch: String?
    let status: String?
}

// MARK: - Compatibility Info

struct CompatibilityInfo: Codable, Sendable {
    let totalIngredients: Int
    let turkishIngredientsCount: Int
    let fractionalMeasurementsCount: Int
    let turkishMeasurementsCount: Int
    let turkishRecognitionRate: Double

    var formattedRecognitionRate: String {
        String(format: "%.1f%%", turkishRecognitionRate)
    }

    var hasTurkishContent: Bool {
        turkishIngredientsCount > 0 ||
        turkishMeasurementsCount > 0
    }

    var hasFractionalMeasurements: Bool {
        fractionalMeasurementsCount > 0
    }
}

// MARK: - Full EDAMAM Response (for debugging)

struct EdamamFullResponse: Codable, Sendable {
    let uri: String?
    let calories: Double?
    let totalWeight: Double?
    let dietLabels: [String]?
    let healthLabels: [String]?
    let cautions: [String]?
}

// MARK: - API Response Wrapper

struct EdamamTestResponse: Codable {
    let success: Bool
    let data: EdamamTestResult?
    let error: String?
    let message: String?
    let metadata: ResponseMetadata?
}

struct ResponseMetadata: Codable {
    let timestamp: String
    let version: String
}

// MARK: - API Request

struct EdamamTestRequest: Codable {
    let userId: String
    let recipeName: String
    let mealType: String
    let styleType: String
    let recipeContent: String
    let geminiNutrition: RequestNutrition
}

struct RequestNutrition: Codable {
    let calories: String
    let carbohydrates: String
    let protein: String
    let fat: String
    let fiber: String
    let sugar: String
    let glycemicLoad: String
}
