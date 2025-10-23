//
//  ParsedMealData.swift
//  balli
//
//  Structured meal data extracted from voice transcription
//

import Foundation

/// Meal information extracted from voice transcription via Gemini
struct ParsedMealData: Sendable {
    let carbsGrams: Int?
    let timestamp: Date?
    let mealType: String?

    /// Turkish meal type mapping
    var localizedMealType: String? {
        guard let mealType = mealType?.lowercased() else { return nil }

        // Map Turkish meal types to standard values
        switch mealType {
        case "kahvaltı", "sabah", "breakfast":
            return "kahvaltı"
        case "öğle yemeği", "öğle", "lunch":
            return "öğle yemeği"
        case "akşam yemeği", "akşam", "dinner":
            return "akşam yemeği"
        case "ara öğün", "snack", "atıştırmalık":
            return "ara öğün"
        default:
            return mealType
        }
    }

    /// Check if we have minimum required data
    var isValid: Bool {
        guard let carbs = carbsGrams else { return false }
        return carbs > 0
    }
}

/// Response from Gemini API for meal parsing
struct GeminiMealResponse: Codable {
    let carbsGrams: Int?
    let timestamp: String?  // ISO 8601 format
    let mealType: String?
}
