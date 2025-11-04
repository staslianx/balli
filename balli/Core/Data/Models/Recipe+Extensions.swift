//
//  Recipe+Extensions.swift
//  balli
//
//  Extensions for Recipe to support Firestore sync
//  Swift 6 strict concurrency compliant
//

import Foundation
import CoreData
import UIKit

extension Recipe {

    // MARK: - Firestore Sync Helpers

    /// Mark this recipe as pending sync
    func markAsPendingSync() {
        self.lastModified = Date()
        if self.source.isEmpty {
            self.source = "manual"
        }
    }

    /// Check if this entry needs to be synced
    var needsSync: Bool {
        // For now, we'll sync all entries
        // In the future, we could add sync status tracking
        return true
    }

    /// Device identifier for multi-device sync conflict resolution
    var deviceIdentifier: String {
        UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
    }

    // MARK: - Computed Properties

    /// Display-friendly meal type name
    var displayMealType: String {
        guard let mealType = mealType else { return "Genel" }

        switch mealType.lowercased() {
        case "kahvaltı", "breakfast":
            return "Kahvaltı"
        case "öğle yemeği", "lunch":
            return "Öğle Yemeği"
        case "akşam yemeği", "dinner":
            return "Akşam Yemeği"
        case "ara öğün", "snack":
            return "Ara Öğün"
        default:
            return mealType.capitalized
        }
    }

    /// Display-friendly style type
    var displayStyleType: String {
        guard let styleType = styleType else { return "Genel" }
        return styleType.capitalized
    }

    /// Total time (prep + cook)
    var totalTime: Int {
        return Int(prepTime) + Int(cookTime)
    }

    /// Whether recipe has photo
    var hasPhoto: Bool {
        return imageData != nil || (imageURL != nil && !imageURL!.isEmpty)
    }

    /// Net carbs per serving (total carbs - fiber)
    var netCarbsPerServing: Double {
        return max(0, carbsPerServing - fiberPerServing)
    }

    // MARK: - Portion Definition System (Critical for Diabetes Management)

    /// Whether portion has been defined by user
    /// `true` if portionSize > 0, meaning user has explicitly set what "1 portion" means
    var isPortionDefined: Bool {
        return portionSize > 0
    }

    /// Number of portions the total recipe makes
    /// Calculated as: totalRecipeWeight / portionSize
    /// Returns nil if portion not defined or totalWeight is 0
    var portionCount: Double? {
        guard isPortionDefined, totalRecipeWeight > 0 else { return nil }
        return totalRecipeWeight / portionSize
    }

    /// Total nutrition for entire recipe
    /// This represents the TOTAL values before portioning
    var totalNutrition: NutritionValues {
        return NutritionValues(
            calories: caloriesPerServing,
            carbohydrates: carbsPerServing,
            fiber: fiberPerServing,
            sugar: sugarsPerServing,
            protein: proteinPerServing,
            fat: fatPerServing,
            glycemicLoad: glycemicLoadPerServing
        )
    }

    /// Nutrition per 100g (calculated from total)
    /// Used for nutrition facts display and comparisons
    var per100gNutrition: NutritionValues {
        guard totalRecipeWeight > 0 else {
            return NutritionValues()  // Return zeros if no weight
        }
        let ratio = 100.0 / totalRecipeWeight
        return totalNutrition * ratio
    }

    /// Nutrition for one user-defined portion
    /// Returns nil if portion not defined
    /// Calculated as: totalNutrition × (portionSize / totalRecipeWeight)
    var portionNutrition: NutritionValues? {
        guard isPortionDefined, totalRecipeWeight > 0 else { return nil }
        let ratio = portionSize / totalRecipeWeight
        return totalNutrition * ratio
    }

    /// Calculate nutrition for a specific portion size
    /// - Parameter portionSize: Portion size in grams
    /// - Returns: Nutrition values for that portion size
    func calculatePortionNutrition(for portionSize: Double) -> NutritionValues {
        guard totalRecipeWeight > 0 else {
            return NutritionValues()
        }
        let ratio = portionSize / totalRecipeWeight
        return totalNutrition * ratio
    }

    /// Update portion size and recalculate nutrition
    /// - Parameter newSize: New portion size in grams
    /// - Note: This method updates the portion but does NOT save to Core Data
    ///         Call `try? context.save()` after calling this method
    func updatePortionSize(_ newSize: Double) {
        self.portionSize = newSize
        self.markAsPendingSync()
    }

    /// Validate nutrition calculations for consistency
    /// - Returns: Array of validation error messages (empty if valid)
    ///
    /// # Validation Rules
    /// 1. Portion size must be >= 50g (minimum realistic portion)
    /// 2. Portion size must not exceed total recipe weight
    /// 3. Reconstructed total from portions should match actual total (within tolerance)
    func validateNutrition() -> [String] {
        var errors: [String] = []

        // Validate portion size bounds
        if isPortionDefined {
            if portionSize < 50 {
                errors.append("Portion size too small: \(Int(portionSize))g (minimum 50g)")
            }
            if portionSize > totalRecipeWeight {
                errors.append("Portion size (\(Int(portionSize))g) exceeds total recipe weight (\(Int(totalRecipeWeight))g)")
            }

            // Validate reconstruction: portionNutrition × portionCount ≈ totalNutrition
            if let portionNutrition = portionNutrition,
               let portionCount = portionCount {
                let reconstructedTotal = portionNutrition * portionCount

                // Check calories (±1.0 kcal tolerance for rounding)
                let caloriesDiff = abs(reconstructedTotal.calories - totalNutrition.calories)
                if caloriesDiff > 1.0 {
                    errors.append("Calorie calculation mismatch: \(caloriesDiff) kcal difference")
                }

                // Check protein (±0.1g tolerance)
                let proteinDiff = abs(reconstructedTotal.protein - totalNutrition.protein)
                if proteinDiff > 0.1 {
                    errors.append("Protein calculation mismatch: \(proteinDiff)g difference")
                }

                // Check carbs (±0.1g tolerance)
                let carbsDiff = abs(reconstructedTotal.carbohydrates - totalNutrition.carbohydrates)
                if carbsDiff > 0.1 {
                    errors.append("Carbohydrate calculation mismatch: \(carbsDiff)g difference")
                }

                // Check fat (±0.1g tolerance)
                let fatDiff = abs(reconstructedTotal.fat - totalNutrition.fat)
                if fatDiff > 0.1 {
                    errors.append("Fat calculation mismatch: \(fatDiff)g difference")
                }

                // Check glycemic load (±1.0 tolerance)
                let glDiff = abs(reconstructedTotal.glycemicLoad - totalNutrition.glycemicLoad)
                if glDiff > 1.0 {
                    errors.append("Glycemic load calculation mismatch: \(glDiff) difference")
                }
            }
        }

        // Validate total weight is reasonable
        if totalRecipeWeight > 0 && totalRecipeWeight < 10 {
            errors.append("Total recipe weight unreasonably small: \(Int(totalRecipeWeight))g")
        }

        return errors
    }
}
