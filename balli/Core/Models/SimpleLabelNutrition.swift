//
//  SimpleLabelNutrition.swift
//  balli
//
//  Simple nutrition model for label scanning - only essential values
//

import Foundation

// MARK: - Simple Label Nutrition Model
public struct SimpleLabelNutrition: Codable, Sendable {
    public let calories: Double?          // kcal
    public let servingSize: String?       // e.g., "100g", "1 porsiyon (50g)"
    public let carbohydrates: Double?     // Karbonhidrat (g)
    public let fiber: Double?             // Lif (g) - subset of carbs
    public let sugar: Double?             // Şeker (g) - subset of carbs
    public let protein: Double?           // Protein (g)
    public let fat: Double?               // Yağ (g)
    
    public init(
        calories: Double? = nil,
        servingSize: String? = nil,
        carbohydrates: Double? = nil,
        fiber: Double? = nil,
        sugar: Double? = nil,
        protein: Double? = nil,
        fat: Double? = nil
    ) {
        self.calories = calories
        self.servingSize = servingSize
        self.carbohydrates = carbohydrates
        self.fiber = fiber
        self.sugar = sugar
        self.protein = protein
        self.fat = fat
    }
    
    // MARK: - Computed Properties
    
    /// Check if we have at least some nutrition data
    public var hasData: Bool {
        return calories != nil || 
               carbohydrates != nil || 
               protein != nil || 
               fat != nil
    }
    
    /// Format for display
    public var formattedCalories: String {
        guard let calories = calories else { return "--" }
        return "\(Int(calories))"
    }
    
    public var formattedCarbs: String {
        guard let carbs = carbohydrates else { return "--" }
        return String(format: "%.1f", carbs)
    }
    
    public var formattedProtein: String {
        guard let protein = protein else { return "--" }
        return String(format: "%.1f", protein)
    }
    
    public var formattedFat: String {
        guard let fat = fat else { return "--" }
        return String(format: "%.1f", fat)
    }
    
    public var formattedFiber: String {
        guard let fiber = fiber else { return "--" }
        return String(format: "%.1f", fiber)
    }
    
    public var formattedSugar: String {
        guard let sugar = sugar else { return "--" }
        return String(format: "%.1f", sugar)
    }
}

// MARK: - JSON Example for AI Response
/*
Expected JSON format from AI service:
{
    "calories": 250,
    "servingSize": "100g",
    "carbohydrates": 30.5,
    "fiber": 2.3,
    "sugar": 8.7,
    "protein": 12.4,
    "fat": 10.2
}
*/