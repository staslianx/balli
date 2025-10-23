//
//  NutritionVariant+Extensions.swift
//  balli
//
//  Created for Business Logic and Convenience Methods
//

import Foundation
import CoreData

// MARK: - NutritionVariant Business Logic
extension NutritionVariant {
    
    /// Calculated net carbs
    var netCarbs: Double {
        // Apply same logic as parent food item
        let fiberDeduction = fiber > 5 ? fiber : 0
        return max(0, totalCarbs - fiberDeduction)
    }
    
    /// Display name with parent food context
    var displayName: String {
        guard let parent = parentFood else { return name }
        return "\(parent.localizedName) - \(name)"
    }
    
    /// Formatted serving description
    var servingDescription: String {
        if servingSize == 1 {
            return "1 \(servingUnit)"
        } else if servingSize.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(servingSize)) \(servingUnit)"
        } else {
            return String(format: "%.1f %@", servingSize, servingUnit)
        }
    }
    
    /// Difference from parent nutrition
    func nutritionDifference(from parent: FoodItem) -> NutritionDifference {
        return NutritionDifference(
            calories: calories - parent.calories,
            totalCarbs: totalCarbs - parent.totalCarbs,
            fiber: fiber - parent.fiber,
            sugars: sugars - parent.sugars,
            protein: protein - parent.protein,
            totalFat: totalFat - parent.totalFat
        )
    }
    
    /// Whether this variant is healthier than parent
    var isHealthierThanParent: Bool {
        guard let parent = parentFood else { return false }
        
        let diff = nutritionDifference(from: parent)
        
        // Consider healthier if:
        // - Lower calories
        // - Lower carbs or sugars
        // - Higher fiber or protein
        let calorieImprovement = diff.calories < 0
        let carbImprovement = diff.totalCarbs < 0 || diff.sugars < -2
        let nutritionImprovement = diff.fiber > 1 || diff.protein > 2
        
        return calorieImprovement || carbImprovement || nutritionImprovement
    }
    
    /// Percentage difference from parent
    func percentageDifference(from parent: FoodItem) -> (calories: Double, carbs: Double, protein: Double, fat: Double) {
        let caloriesDiff = parent.calories > 0 ? ((calories - parent.calories) / parent.calories) * 100 : 0
        let carbsDiff = parent.totalCarbs > 0 ? ((totalCarbs - parent.totalCarbs) / parent.totalCarbs) * 100 : 0
        let proteinDiff = parent.protein > 0 ? ((protein - parent.protein) / parent.protein) * 100 : 0
        let fatDiff = parent.totalFat > 0 ? ((totalFat - parent.totalFat) / parent.totalFat) * 100 : 0
        
        return (caloriesDiff, carbsDiff, proteinDiff, fatDiff)
    }
    
    /// Summary of differences from parent
    var differenceSummary: String? {
        guard let parent = parentFood else { return nil }
        
        let diff = nutritionDifference(from: parent)
        var summaryParts: [String] = []
        
        // Add significant differences
        if abs(diff.calories) >= 10 {
            let change = diff.calories > 0 ? "+" : ""
            summaryParts.append("\(change)\(Int(diff.calories)) cal")
        }
        
        if abs(diff.totalCarbs) >= 1 {
            let change = diff.totalCarbs > 0 ? "+" : ""
            summaryParts.append(String(format: "%@%.1fg carbs", change, diff.totalCarbs))
        }
        
        if abs(diff.sugars) >= 1 {
            let change = diff.sugars > 0 ? "+" : ""
            summaryParts.append(String(format: "%@%.1fg sugar", change, diff.sugars))
        }
        
        if abs(diff.protein) >= 1 {
            let change = diff.protein > 0 ? "+" : ""
            summaryParts.append(String(format: "%@%.1fg protein", change, diff.protein))
        }
        
        return summaryParts.isEmpty ? nil : summaryParts.joined(separator: ", ")
    }
}

// MARK: - Supporting Types
struct NutritionDifference {
    let calories: Double
    let totalCarbs: Double
    let fiber: Double
    let sugars: Double
    let protein: Double
    let totalFat: Double
}

// MARK: - Fetch Requests
extension NutritionVariant {
    
    /// Fetch variants for a specific food item
    @nonobjc public class func variantsForFood(_ food: FoodItem) -> NSFetchRequest<NutritionVariant> {
        let request = fetchRequest()
        
        request.predicate = NSPredicate(format: "parentFood == %@", food)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \NutritionVariant.name, ascending: true)
        ]
        
        return request
    }
    
    /// Fetch healthier variants
    @nonobjc public class func healthierVariants() -> NSFetchRequest<NutritionVariant> {
        let request = fetchRequest()
        
        // This is a simplified query - actual healthiness would need to be computed
        request.predicate = NSPredicate(format: "name CONTAINS[cd] %@ OR name CONTAINS[cd] %@ OR name CONTAINS[cd] %@",
                                        "Light", "Sugar-Free", "Low")
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \NutritionVariant.calories, ascending: true)
        ]
        
        return request
    }
}