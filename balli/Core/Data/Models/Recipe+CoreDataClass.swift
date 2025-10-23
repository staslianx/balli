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
    
    // MARK: - Computed Properties
    
    /// Calculate net carbs (total carbs - fiber if fiber > 5g)
    var netCarbs: Double {
        if fiber > 5 {
            return max(0, totalCarbs - fiber)
        }
        return totalCarbs
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