//
//  GeminiMealResponse.swift
//  balli
//
//  Response model for Gemini meal transcription
//  Matches the Cloud Function TranscribeMealOutput interface
//

import Foundation

// MARK: - Gemini Meal Response

/// Response from the transcribeMeal Cloud Function
/// Sendable for Swift 6 concurrency compliance
struct GeminiMealResponse: Codable, Sendable {
    let success: Bool
    let data: MealData?
    let error: String?
    let metadata: Metadata?

    struct MealData: Codable, Sendable {
        let transcription: String
        let foods: [FoodItem]
        let totalCarbs: Int
        let mealType: String
        let mealTime: String?
        let confidence: String

        enum CodingKeys: String, CodingKey {
            case transcription
            case foods
            case totalCarbs
            case mealType
            case mealTime
            case confidence
        }
    }

    struct FoodItem: Codable, Sendable, Identifiable {
        let id: UUID
        let name: String
        let amount: String?
        let carbs: Int?

        enum CodingKeys: String, CodingKey {
            case name
            case amount
            case carbs
        }

        init(name: String, amount: String?, carbs: Int?) {
            self.id = UUID()
            self.name = name
            self.amount = amount
            self.carbs = carbs
        }

        // Custom decoder to generate UUID on decoding
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.id = UUID()
            self.name = try container.decode(String.self, forKey: .name)
            self.amount = try container.decodeIfPresent(String.self, forKey: .amount)
            self.carbs = try container.decodeIfPresent(Int.self, forKey: .carbs)
        }
    }

    struct Metadata: Codable, Sendable {
        let processingTime: String
        let timestamp: String
        let version: String

        enum CodingKeys: String, CodingKey {
            case processingTime
            case timestamp
            case version
        }
    }
}

// MARK: - Confidence Level

enum MealConfidence: String, Codable, Sendable {
    case high
    case medium
    case low

    var displayText: String {
        switch self {
        case .high:
            return "Yüksek güven"
        case .medium:
            return "Orta güven"
        case .low:
            return "Düşük güven"
        }
    }

    var warningText: String? {
        switch self {
        case .high:
            return nil
        case .medium, .low:
            return "Bazı bilgiler tahmin edildi, lütfen kontrol edin"
        }
    }
}

// MARK: - Extensions

extension GeminiMealResponse.MealData {
    /// Get confidence as enum
    var confidenceLevel: MealConfidence {
        MealConfidence(rawValue: confidence) ?? .low
    }

    /// Check if this is simple format (total carbs only, no per-item carbs)
    var isSimpleFormat: Bool {
        foods.allSatisfy { $0.carbs == nil }
    }

    /// Check if this is detailed format (has per-item carbs)
    var isDetailedFormat: Bool {
        foods.contains { $0.carbs != nil }
    }

    /// Get sum of individual food carbs (for validation)
    var sumOfFoodCarbs: Int {
        foods.reduce(0) { $0 + ($1.carbs ?? 0) }
    }

    /// Validate that sum of food carbs matches total (for detailed format)
    var isCarbsSumValid: Bool {
        guard isDetailedFormat else { return true }
        let diff = abs(sumOfFoodCarbs - totalCarbs)
        return diff <= 5 // ±5g tolerance
    }
}

extension GeminiMealResponse.FoodItem {
    /// Display string for amount
    var displayAmount: String {
        amount ?? ""
    }

    /// Display string for carbs (empty if nil)
    var displayCarbs: String {
        guard let carbs = carbs else { return "" }
        return "\(carbs)g"
    }

    /// Full display string: "name (amount) - carbsg"
    var fullDisplay: String {
        var parts: [String] = [name]

        if let amt = amount, !amt.isEmpty {
            parts.append("(\(amt))")
        }

        if let c = carbs {
            parts.append("\(c)g")
        }

        return parts.joined(separator: " ")
    }
}
