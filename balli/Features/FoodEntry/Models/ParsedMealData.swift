//
//  ParsedMealData.swift
//  balli
//
//  Structured meal data extracted from voice transcription
//

import Foundation

/// Meal information extracted from voice transcription via Gemini
/// Supports both legacy (simple carbs only) and new (foods array) formats
struct ParsedMealData: Sendable {
    // Legacy fields (backward compatibility with Apple Speech Recognition)
    let carbsGrams: Int?
    let timestamp: Date?
    let mealType: String?

    // New Gemini fields
    let transcription: String?
    let foods: [ParsedFoodItem]?
    let confidence: String?

    // MARK: - Initializers

    /// Legacy initializer for Apple Speech Recognition
    init(carbsGrams: Int?, timestamp: Date?, mealType: String?) {
        self.carbsGrams = carbsGrams
        self.timestamp = timestamp
        self.mealType = mealType
        self.transcription = nil
        self.foods = nil
        self.confidence = nil
    }

    /// Gemini initializer with full meal data
    init(
        transcription: String,
        foods: [ParsedFoodItem],
        totalCarbs: Int,
        mealType: String,
        mealTime: String?,
        confidence: String
    ) {
        self.transcription = transcription
        self.foods = foods
        self.carbsGrams = totalCarbs
        self.mealType = mealType
        self.confidence = confidence

        // Parse mealTime if provided
        if let timeString = mealTime {
            self.timestamp = Self.parseTime(timeString)
        } else {
            self.timestamp = Date()
        }
    }

    /// Convenience initializer from GeminiMealResponse
    init(from response: GeminiMealResponse.MealData) {
        // Parse mealTime if provided
        let parsedTimestamp: Date
        if let timeString = response.mealTime {
            parsedTimestamp = Self.parseTime(timeString) ?? Date()
        } else {
            parsedTimestamp = Date()
        }

        // Convert GeminiMealResponse.FoodItem array to our ParsedFoodItem array
        let convertedFoods: [ParsedFoodItem] = response.foods.map { geminiFood in
            ParsedFoodItem(
                name: geminiFood.name,
                amount: geminiFood.amount,
                carbs: geminiFood.carbs
            )
        }

        // Set properties directly
        self.transcription = response.transcription
        self.foods = convertedFoods
        self.carbsGrams = response.totalCarbs
        self.mealType = response.mealType
        self.confidence = response.confidence
        self.timestamp = parsedTimestamp
    }

    // MARK: - Computed Properties

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
            return "atıştırmalık"
        default:
            return mealType
        }
    }

    /// Check if we have minimum required data
    var isValid: Bool {
        guard let carbs = carbsGrams else { return false }
        return carbs > 0
    }

    /// Check if this is Gemini format (has foods array)
    var isGeminiFormat: Bool {
        foods != nil && !foods!.isEmpty
    }

    /// Check if this is simple format (legacy or Gemini with total carbs only)
    var isSimpleFormat: Bool {
        if let foods = foods {
            return foods.allSatisfy { $0.carbs == nil }
        }
        return true // Legacy format is simple
    }

    /// Check if this is detailed format (has per-item carbs)
    var isDetailedFormat: Bool {
        guard let foods = foods else { return false }
        return foods.contains { $0.carbs != nil }
    }

    // MARK: - Helper Methods

    /// Parse time string in HH:MM format to Date (today with that time)
    private static func parseTime(_ timeString: String) -> Date? {
        let components = timeString.split(separator: ":").map { String($0) }
        guard components.count == 2,
              let hour = Int(components[0]),
              let minute = Int(components[1]) else {
            return nil
        }

        let calendar = Calendar.current
        var dateComponents = calendar.dateComponents([.year, .month, .day], from: Date())
        dateComponents.hour = hour
        dateComponents.minute = minute

        return calendar.date(from: dateComponents)
    }
}

// MARK: - ParsedFoodItem

/// Individual food item in a meal (parsed from voice transcription)
struct ParsedFoodItem: Sendable, Identifiable {
    let id: UUID
    let name: String
    let amount: String?
    let carbs: Int?

    init(name: String, amount: String?, carbs: Int?) {
        self.id = UUID()
        self.name = name
        self.amount = amount
        self.carbs = carbs
    }
}
