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

        // Nutrients
        let nutrients = result.nutrients
        self.calories = String(format: "%.0f", nutrients.calories.value)
        self.carbohydrates = String(format: "%.1f", nutrients.totalCarbohydrates.value)
        self.fiber = nutrients.dietaryFiber.map { String(format: "%.1f", $0.value) } ?? ""
        self.sugars = nutrients.sugars.map { String(format: "%.1f", $0.value) } ?? ""
        self.protein = String(format: "%.1f", nutrients.protein.value)
        self.fat = String(format: "%.1f", nutrients.totalFat.value)
        self.sodium = nutrients.sodium.map { String(format: "%.0f", $0.value) } ?? ""

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
        let totalCarbs = Double(carbohydrates) ?? 0
        let fiberValue = Double(fiber) ?? 0
        let ratio = portionGrams / (Double(servingSize) ?? 100.0)

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

    /// Calculate impact score based on portion-adjusted values
    func calculateImpactScore() -> Double {
        guard let baseServing = Double(servingSize), baseServing > 0 else {
            return 0.0
        }

        let adjustmentRatio = portionGrams / baseServing

        // Get adjusted nutrition values
        let adjustedCarbs = (Double(carbohydrates) ?? 0) * adjustmentRatio
        let adjustedFiber = (Double(fiber) ?? 0) * adjustmentRatio
        let adjustedSugars = (Double(sugars) ?? 0) * adjustmentRatio
        let adjustedProtein = (Double(protein) ?? 0) * adjustmentRatio
        let adjustedFat = (Double(fat) ?? 0) * adjustmentRatio

        // Calculate net carbs
        let fiberDeduction = adjustedFiber > 5 ? adjustedFiber : 0
        let netCarbs = max(0, adjustedCarbs - fiberDeduction)

        // Calculate impact score
        let carbImpact = netCarbs * 1.0
        let sugarImpact = adjustedSugars * 0.15
        let proteinReduction = adjustedProtein * 0.1
        let fatReduction = adjustedFat * 0.05

        return max(0, carbImpact + sugarImpact - proteinReduction - fatReduction)
    }

    /// Get impact level based on current score
    var impactLevel: ImpactLevel {
        return ImpactLevel.from(score: calculateImpactScore())
    }
}
