//
//  Recipe+CoreDataClass.swift
//  balli
//
//  Generated Core Data class for Recipe entity
//

import Foundation
import CoreData

@objc(Recipe)
public class Recipe: NSManagedObject, @unchecked Sendable {

    // MARK: - Lifecycle

    public override func awakeFromInsert() {
        super.awakeFromInsert()
        setPrimitiveValue(UUID(), forKey: "id")
        setPrimitiveValue(Date(), forKey: "dateCreated")
        setPrimitiveValue(Date(), forKey: "lastModified")
        setPrimitiveValue("manual", forKey: "source")
        setPrimitiveValue(false, forKey: "isVerified")
        setPrimitiveValue(false, forKey: "isFavorite")
        setPrimitiveValue(Int32(0), forKey: "timesCooked")
        setPrimitiveValue(Int16(1), forKey: "userRating")  // Set to 1 to satisfy Core Data validation
    }
    
    // MARK: - Computed Properties
    
    /// Calculate net carbs (total carbs - fiber if fiber > 5g)
    var netCarbs: Double {
        if fiber > 5 {
            return max(0, totalCarbs - fiber)
        }
        return totalCarbs
    }

    // MARK: - Insulin-Glucose Curve Properties

    /// Nutrition data package for per-serving values
    private var nutritionPerServing: InsulinCurveCalculator.RecipeNutrition {
        InsulinCurveCalculator.RecipeNutrition(
            carbohydrates: carbsPerServing,
            fat: fatPerServing,
            protein: proteinPerServing,
            sugar: sugarsPerServing,
            fiber: fiberPerServing,
            glycemicLoad: glycemicLoadPerServing
        )
    }

    /// Calculate when glucose levels will peak after consuming this recipe (per serving)
    /// Based on carbohydrate composition, fat, protein, and fiber content
    var glucosePeakTimeMinutes: Int {
        InsulinCurveCalculator.shared.calculateGlucosePeakTime(nutrition: nutritionPerServing)
    }

    /// Calculate how long glucose levels will remain elevated (per serving)
    var glucoseDurationMinutes: Int {
        InsulinCurveCalculator.shared.calculateGlucoseDuration(
            nutrition: nutritionPerServing,
            peakTime: glucosePeakTimeMinutes
        )
    }

    /// Calculate absolute time mismatch between insulin peak (NovoRapid: 75min) and glucose peak
    /// Large mismatches (>60min) indicate potential for late hyperglycemia or early hypoglycemia
    var insulinMismatchMinutes: Int {
        InsulinCurveCalculator.shared.calculateMismatch(glucosePeakTime: glucosePeakTimeMinutes)
    }

    /// Determine warning level for insulin-glucose curve mismatch
    /// Considers mismatch time, fat content, and glycemic load to assess risk
    var curveWarningLevel: CurveWarningLevel {
        let warning = InsulinCurveCalculator.shared.determineWarning(nutrition: nutritionPerServing)
        return warning.level
    }

    /// Check if curve warning should be shown to user
    /// Only show if there's a meaningful mismatch (level != .none)
    var shouldShowCurveWarning: Bool {
        curveWarningLevel != .none
    }

    /// Get complete glucose absorption curve for charting
    var glucoseCurve: [GlucoseCurvePoint] {
        InsulinCurveCalculator.shared.generateGlucoseCurve(nutrition: nutritionPerServing)
    }

    /// Get warning message with mismatch and nutrition context
    var curveWarningMessage: String {
        curveWarningLevel.getMessage(
            mismatchMinutes: insulinMismatchMinutes,
            fatGrams: fatPerServing,
            proteinGrams: proteinPerServing
        )
    }

    /// Get actionable recommendations based on curve mismatch
    var curveWarningRecommendations: [String] {
        curveWarningLevel.getRecommendations(
            mismatchMinutes: insulinMismatchMinutes,
            fatGrams: fatPerServing
        )
    }
    
    /// Get ingredients as array
    var ingredientsArray: [String] {
        guard let ingredients = ingredients as? [String] else {
            return []
        }
        return ingredients
    }
    
    /// Get instructions as array
    var instructionsArray: [String] {
        guard let instructions = instructions as? [String] else {
            return []
        }
        return instructions
    }
    
    /// Recipe source display name
    var sourceDisplayName: String {
        switch source {
        case "ai":
            return "AI Tarifi"
        case "manual":
            return "Kendi Tarifim"
        default:
            return "Bilinmeyen"
        }
    }
    
    /// Check if this is an AI-generated recipe
    var isAIGenerated: Bool {
        return source == "ai"
    }
    
    /// Check if this is a manual recipe
    var isManualRecipe: Bool {
        return source == "manual"
    }
    
    // MARK: - Helper Methods
    
    /// Mark recipe as cooked
    func markAsCooked() {
        timesCooked += 1
        lastModified = Date()
    }
    
    /// Toggle favorite status
    func toggleFavorite() {
        isFavorite.toggle()
        lastModified = Date()
    }
    
    /// Update recipe rating
    func updateRating(_ rating: Int16) {
        guard rating >= 1 && rating <= 5 else { return }
        userRating = rating
        lastModified = Date()
    }
}