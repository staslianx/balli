//
//  NutritionFormState.swift
//  balli
//
//  Form state for nutrition data editing
//

import Foundation

/// Represents the editable nutrition form data
struct NutritionFormState: Sendable {
    // MARK: - Product Information

    var productBrand: String
    var productName: String

    // MARK: - Serving Information

    var servingSize: String  // Base serving size from label
    var portionGrams: Double // User-selected portion

    // MARK: - Nutrition Values (per servingSize)

    var calories: String
    var carbohydrates: String
    var fiber: String
    var sugars: String
    var protein: String
    var fat: String
    var sodium: String

    // MARK: - Confidence Scores (0-100)

    var caloriesConfidence: Int
    var carbsConfidence: Int
    var fiberConfidence: Int
    var sugarsConfidence: Int
    var proteinConfidence: Int
    var fatConfidence: Int

    // MARK: - Initialization

    init() {
        // Empty form
        self.productBrand = ""
        self.productName = ""
        self.servingSize = ""
        self.portionGrams = 100.0
        self.calories = ""
        self.carbohydrates = ""
        self.fiber = ""
        self.sugars = ""
        self.protein = ""
        self.fat = ""
        self.sodium = ""
        self.caloriesConfidence = 0
        self.carbsConfidence = 0
        self.fiberConfidence = 0
        self.sugarsConfidence = 0
        self.proteinConfidence = 0
        self.fatConfidence = 0
    }

    init(from result: NutritionExtractionResult) {
        // Initialize from AI result
        self.productBrand = result.brandName ?? ""
        self.productName = result.productName ?? ""

        // Serving size
        let serving = result.servingSize
        self.servingSize = String(format: "%.0f", serving.value)
        self.portionGrams = serving.value

        // Nutrients - use "0" for missing optional nutrients instead of empty string
        let nutrients = result.nutrients
        self.calories = String(format: "%.0f", nutrients.calories.value)
        self.carbohydrates = String(format: "%.1f", nutrients.totalCarbohydrates.value)
        self.fiber = nutrients.dietaryFiber.map { String(format: "%.1f", $0.value) } ?? "0"
        self.sugars = nutrients.sugars.map { String(format: "%.1f", $0.value) } ?? "0"
        self.protein = String(format: "%.1f", nutrients.protein.value)
        self.fat = String(format: "%.1f", nutrients.totalFat.value)
        self.sodium = nutrients.sodium.map { String(format: "%.0f", $0.value) } ?? "0"

        // Confidence scores
        let confidence = Int(result.metadata.confidence)
        self.caloriesConfidence = confidence
        self.carbsConfidence = confidence
        self.fiberConfidence = confidence
        self.sugarsConfidence = confidence
        self.proteinConfidence = confidence
        self.fatConfidence = confidence
    }

    // MARK: - Computed Properties

    /// Calculate net carbs based on current form values
    func calculateNetCarbs() -> Double {
        let totalCarbs = carbohydrates.toDouble ?? 0
        let fiberValue = fiber.toDouble ?? 0
        let ratio = portionGrams / (servingSize.toDouble ?? 100.0)

        let adjustedCarbs = totalCarbs * ratio
        let adjustedFiber = fiberValue * ratio

        // Net carbs calculation: subtract fiber only if > 5g
        if adjustedFiber > 5 {
            return max(0, adjustedCarbs - adjustedFiber)
        } else {
            return adjustedCarbs
        }
    }

    /// Calculate overall confidence from current values
    func calculateOverallConfidence() -> Double {
        let confidences = [
            caloriesConfidence,
            carbsConfidence,
            proteinConfidence,
            fatConfidence
        ].filter { $0 > 0 }

        guard !confidences.isEmpty else { return 0 }

        let sum = confidences.reduce(0, +)
        return Double(sum) / Double(confidences.count)
    }

    /// Calculate impact score using Nestlé validated formula
    /// Handles missing/zero values gracefully by defaulting to 0.0
    func calculateImpactScore() -> Double {
        guard let baseServing = servingSize.toDouble, baseServing > 0 else {
            return 0.0
        }

        // Parse values with 0.0 fallback for missing data
        let baseCarbs = carbohydrates.toDouble ?? 0.0
        let baseFiber = fiber.toDouble ?? 0.0
        let baseSugars = sugars.toDouble ?? 0.0
        let baseProtein = protein.toDouble ?? 0.0
        let baseFat = fat.toDouble ?? 0.0

        // Use the validated Nestlé formula instead of old custom calculation
        let result = ImpactScoreCalculator.calculate(
            totalCarbs: baseCarbs,
            fiber: baseFiber,
            sugar: baseSugars,
            protein: baseProtein,
            fat: baseFat,
            servingSize: baseServing,
            portionGrams: portionGrams
        )

        return result.score
    }

    /// Get impact level based on current score using three-threshold evaluation
    var impactLevel: ImpactLevel {
        let score = calculateImpactScore()

        // Calculate scaled fat and protein for current portion
        guard let baseServing = servingSize.toDouble, baseServing > 0 else {
            return .low
        }

        let adjustmentRatio = portionGrams / baseServing
        let scaledFat = (fat.toDouble ?? 0.0) * adjustmentRatio
        let scaledProtein = (protein.toDouble ?? 0.0) * adjustmentRatio

        return ImpactLevel.from(
            score: score,
            fat: scaledFat,
            protein: scaledProtein
        )
    }
}
