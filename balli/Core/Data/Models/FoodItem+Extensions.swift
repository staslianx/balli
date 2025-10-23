//
//  FoodItem+Extensions.swift
//  balli
//
//  Created for Business Logic and Convenience Methods
//

import Foundation
import CoreData

// MARK: - FoodItem Missing Properties Extension

extension FoodItem {
    /// Computed property for totalCarbohydrates (legacy compatibility)
    public var totalCarbohydrates: Double {
        return totalCarbs
    }
    
    /// Computed property for createdAt (legacy compatibility)  
    public var createdAt: Date {
        return dateAdded
    }
}

// MARK: - Confidence Level Enum
public enum ConfidenceLevel: String, CaseIterable {
    case high = "high"
    case medium = "medium"
    case low = "low"
    
    var thresholdRange: ClosedRange<Double> {
        switch self {
        case .high: return 80...100
        case .medium: return 50...79.99
        case .low: return 0...49.99
        }
    }
    
    var displayColor: String {
        switch self {
        case .high: return "green"
        case .medium: return "yellow"
        case .low: return "red"
        }
    }
}

// MARK: - FoodItem Business Logic
extension FoodItem {
    
    /// Calculated net carbs (total - fiber - sugar alcohols)
    var netCarbs: Double {
        // Only subtract fiber if it's greater than 5g per serving
        let fiberDeduction = fiber > 5 ? fiber : 0
        return max(0, totalCarbs - fiberDeduction - sugarAlcohols)
    }
    
    /// Calculated impact score for blood glucose impact
    /// Updated formula based on evidence-based research:
    /// impactScore = (netCarbs × 1.0) + (sugars × 0.15) - (protein × 0.1) - (fat × 0.05)
    /// Result is always rounded up to whole numbers
    var impactScore: Double {
        let carbImpact = netCarbs * 1.0
        let sugarImpact = sugars * 0.15  // Research-based sugar weighting
        let proteinReduction = protein * 0.1
        let fatReduction = totalFat * 0.05

        let score = max(0, carbImpact + sugarImpact - proteinReduction - fatReduction)
        return ceil(score)  // Always round up to whole numbers
    }

    /// Impact level based on calculated impact score
    var impactLevel: ImpactLevel {
        return ImpactLevel.from(score: impactScore)
    }
    
    /// Localized name based on current locale
    var localizedName: String {
        let locale = Locale.current
        let languageCode = locale.language.languageCode?.identifier ?? "en"
        
        if languageCode == "tr", let turkish = nameTr, !turkish.isEmpty {
            return turkish
        } else if let english = nameEn, !english.isEmpty {
            return english
        }
        return name
    }
    
    /// Full display name including brand
    var displayName: String {
        if let brand = brand, !brand.isEmpty {
            return "\(localizedName) - \(brand)"
        }
        return localizedName
    }
    
    /// Confidence level as enum
    var confidenceLevel: ConfidenceLevel {
        switch overallConfidence {
        case 80...100: return .high
        case 50..<80: return .medium
        default: return .low
        }
    }
    
    /// Whether the item needs manual verification
    var needsVerification: Bool {
        return confidenceLevel == .low || !isVerified
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
    
    /// Calculate nutrition for a specific quantity
    func nutritionForQuantity(_ quantity: Double, unit: String? = nil) -> (carbs: Double, protein: Double, fat: Double, calories: Double, fiber: Double) {
        let multiplier = calculateMultiplier(for: quantity, unit: unit ?? servingUnit)
        
        return (
            carbs: totalCarbs * multiplier,
            protein: protein * multiplier,
            fat: totalFat * multiplier,
            calories: calories * multiplier,
            fiber: fiber * multiplier
        )
    }
    
    /// Calculate multiplier for portion conversion
    private func calculateMultiplier(for quantity: Double, unit: String) -> Double {
        // If using same unit as food item
        if unit == servingUnit {
            return quantity / servingSize
        }
        
        // Convert to grams if possible
        if (unit == "g" || unit == "gram" || unit == "grams") && gramWeight > 0 {
            return quantity / gramWeight
        }
        
        // Default to quantity as servings
        return quantity
    }
    
    /// Update usage tracking
    func recordUsage() {
        useCount += 1
        lastUsed = Date()
    }
    
    /// Toggle favorite status
    func toggleFavorite() {
        isFavorite.toggle()
        lastModified = Date()
    }
}

// MARK: - Search Helpers
extension FoodItem {
    
    /// Search request with multiple field matching
    @nonobjc public class func searchRequest(query: String) -> NSFetchRequest<FoodItem> {
        let request = fetchRequest()
        
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            request.fetchLimit = 50
            return request
        }
        
        // Create predicates for different search fields
        let predicates = [
            NSPredicate(format: "name CONTAINS[cd] %@", trimmedQuery),
            NSPredicate(format: "nameEn CONTAINS[cd] %@", trimmedQuery),
            NSPredicate(format: "nameTr CONTAINS[cd] %@", trimmedQuery),
            NSPredicate(format: "brand CONTAINS[cd] %@", trimmedQuery),
            NSPredicate(format: "category CONTAINS[cd] %@", trimmedQuery),
            NSPredicate(format: "barcode == %@", trimmedQuery),
            NSPredicate(format: "notes CONTAINS[cd] %@", trimmedQuery)
        ]
        
        request.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: predicates)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \FoodItem.useCount, ascending: false),
            NSSortDescriptor(keyPath: \FoodItem.lastUsed, ascending: false),
            NSSortDescriptor(keyPath: \FoodItem.name, ascending: true)
        ]
        request.fetchLimit = 50
        
        return request
    }
    
    /// Fetch frequently used items
    @nonobjc public class func frequentlyUsedRequest(limit: Int = 20) -> NSFetchRequest<FoodItem> {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "useCount > 0")
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \FoodItem.useCount, ascending: false),
            NSSortDescriptor(keyPath: \FoodItem.lastUsed, ascending: false)
        ]
        request.fetchLimit = limit
        return request
    }
    
    /// Fetch favorite items
    @nonobjc public class func favoritesRequest() -> NSFetchRequest<FoodItem> {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "isFavorite == true")
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \FoodItem.name, ascending: true)
        ]
        return request
    }
    
    /// Fetch recently added items
    @nonobjc public class func recentlyAddedRequest(days: Int = 7, limit: Int = 20) -> NSFetchRequest<FoodItem> {
        let request = fetchRequest()
        let date = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        request.predicate = NSPredicate(format: "dateAdded >= %@", date as NSDate)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \FoodItem.dateAdded, ascending: false)
        ]
        request.fetchLimit = limit
        return request
    }
    
    /// Fetch items by category
    @nonobjc public class func byCategoryRequest(category: String) -> NSFetchRequest<FoodItem> {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "category == %@", category)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \FoodItem.name, ascending: true)
        ]
        return request
    }
    
    /// Fetch items needing verification
    @nonobjc public class func needsVerificationRequest() -> NSFetchRequest<FoodItem> {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "isVerified == false OR carbsConfidence < 50")
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \FoodItem.carbsConfidence, ascending: true),
            NSSortDescriptor(keyPath: \FoodItem.dateAdded, ascending: false)
        ]
        return request
    }
}
