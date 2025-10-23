//
//  MealEntry+Extensions.swift
//  balli
//
//  Created for Business Logic and Convenience Methods
//

import Foundation
import CoreData

// MARK: - Meal Type Enum
public enum MealType: String, CaseIterable {
    case breakfast = "breakfast"
    case lunch = "lunch"
    case dinner = "dinner"
    case snack = "snack"
    
    var displayName: String {
        switch self {
        case .breakfast: return NSLocalizedString("meal.breakfast", comment: "Breakfast")
        case .lunch: return NSLocalizedString("meal.lunch", comment: "Lunch")
        case .dinner: return NSLocalizedString("meal.dinner", comment: "Dinner")
        case .snack: return NSLocalizedString("meal.snack", comment: "Snack")
        }
    }
    
    var icon: String {
        switch self {
        case .breakfast: return "sun.and.horizon"
        case .lunch: return "sun.max"
        case .dinner: return "moon"
        case .snack: return "leaf"
        }
    }
    
    var typicalTimeRange: ClosedRange<Int> {
        switch self {
        case .breakfast: return 6...10
        case .lunch: return 11...14
        case .dinner: return 17...21
        case .snack: return 0...23
        }
    }
}

// MARK: - MealEntry Business Logic
extension MealEntry {
    
    /// Meal type as enum
    var mealTypeEnum: MealType? {
        return MealType(rawValue: mealType)
    }
    
    /// Calculate nutrition based on portion
    func calculateNutrition() {
        guard let food = foodItem else { return }
        
        let portionMultiplier = calculatePortionMultiplier()
        
        consumedCarbs = food.totalCarbs * portionMultiplier
        consumedProtein = food.protein * portionMultiplier
        consumedFat = food.totalFat * portionMultiplier
        consumedCalories = food.calories * portionMultiplier
        consumedFiber = food.fiber * portionMultiplier
    }
    
    /// Calculate portion multiplier based on quantity and unit
    private func calculatePortionMultiplier() -> Double {
        guard let food = foodItem else { return 1.0 }
        
        // If using same unit as food item
        if unit == food.servingUnit {
            return quantity / food.servingSize
        }
        
        // Convert grams to servings
        if (unit == "g" || unit == "gram" || unit == "grams") && food.gramWeight > 0 {
            portionGrams = quantity
            return quantity / food.gramWeight
        }
        
        // Convert other units if we have gram weight
        if food.gramWeight > 0 {
            switch unit {
            case "oz", "ounce", "ounces":
                portionGrams = quantity * 28.35
                return portionGrams / food.gramWeight
            case "cup", "cups":
                // Approximate conversion - should be customized per food type
                portionGrams = quantity * 240
                return portionGrams / food.gramWeight
            case "tbsp", "tablespoon", "tablespoons":
                portionGrams = quantity * 15
                return portionGrams / food.gramWeight
            case "tsp", "teaspoon", "teaspoons":
                portionGrams = quantity * 5
                return portionGrams / food.gramWeight
            default:
                break
            }
        }
        
        // Default to quantity as number of servings
        return quantity
    }
    
    /// Net carbs consumed
    var consumedNetCarbs: Double {
        guard let food = foodItem else { return consumedCarbs }
        let portionMultiplier = calculatePortionMultiplier()
        
        // Apply same logic as FoodItem netCarbs calculation
        let fiberDeduction = food.fiber > 5 ? consumedFiber : 0
        let sugarAlcohols = food.sugarAlcohols * portionMultiplier
        
        return max(0, consumedCarbs - fiberDeduction - sugarAlcohols)
    }
    
    /// Blood glucose impact score
    /// Updated formula based on evidence-based research:
    /// impactScore = (netCarbs × 1.0) + (sugars × 0.15) - (protein × 0.1) - (fat × 0.05)
    /// Result is always rounded up to whole numbers
    var glucoseImpactScore: Double {
        guard let food = foodItem else { return 0 }
        let portionMultiplier = calculatePortionMultiplier()

        let carbImpact = consumedNetCarbs * 1.0
        let sugarImpact = (food.sugars * portionMultiplier) * 0.15  // Reduced from 0.25 to 0.15 based on research
        let proteinReduction = consumedProtein * 0.1
        let fatReduction = consumedFat * 0.05

        let score = max(0, carbImpact + sugarImpact - proteinReduction - fatReduction)
        return ceil(score)  // Always round up to whole numbers
    }
    
    /// Time since meal for glucose correlation
    var hoursSinceMeal: Double {
        return Date().timeIntervalSince(timestamp) / 3600
    }
    
    /// Whether meal is recent enough for glucose correlation
    var isRecentForGlucoseCorrelation: Bool {
        return hoursSinceMeal <= 6
    }
    
    /// Formatted timestamp
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
    
    /// Short time description (e.g., "2 hours ago")
    var timeAgoDescription: String {
        let hours = hoursSinceMeal
        
        if hours < 1 {
            let minutes = Int(hours * 60)
            return minutes == 1 ? "1 minute ago" : "\(minutes) minutes ago"
        } else if hours < 24 {
            let hoursInt = Int(hours)
            return hoursInt == 1 ? "1 hour ago" : "\(hoursInt) hours ago"
        } else {
            let days = Int(hours / 24)
            return days == 1 ? "1 day ago" : "\(days) days ago"
        }
    }
    
    /// Description of portion
    var portionDescription: String {
        if quantity == 1 {
            return "1 \(unit)"
        } else if quantity.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(quantity)) \(unit)"
        } else {
            return String(format: "%.1f %@", quantity, unit)
        }
    }
    
    /// Summary of consumed nutrition
    var nutritionSummary: String {
        let netCarbs = consumedNetCarbs
        return String(format: "%.1fg net carbs, %.1fg protein, %.1fg fat, %.0f cal",
                      netCarbs, consumedProtein, consumedFat, consumedCalories)
    }
}

// MARK: - Fetch Requests
extension MealEntry {
    
    /// Fetch meals for a specific date
    @nonobjc public class func mealsForDate(_ date: Date) -> NSFetchRequest<MealEntry> {
        let request = fetchRequest()

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            // Fallback: use 24 hours from start of day
            let endOfDay = startOfDay.addingTimeInterval(86400)
            request.predicate = NSPredicate(format: "timestamp >= %@ AND timestamp < %@",
                                            startOfDay as NSDate, endOfDay as NSDate)
            request.sortDescriptors = [
                NSSortDescriptor(keyPath: \MealEntry.timestamp, ascending: true)
            ]
            return request
        }

        request.predicate = NSPredicate(format: "timestamp >= %@ AND timestamp < %@",
                                        startOfDay as NSDate, endOfDay as NSDate)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \MealEntry.timestamp, ascending: true)
        ]

        return request
    }
    
    /// Fetch meals for a date range
    @nonobjc public class func mealsInRange(from startDate: Date, to endDate: Date) -> NSFetchRequest<MealEntry> {
        let request = fetchRequest()
        
        request.predicate = NSPredicate(format: "timestamp >= %@ AND timestamp <= %@",
                                        startDate as NSDate, endDate as NSDate)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \MealEntry.timestamp, ascending: false)
        ]
        
        return request
    }
    
    /// Fetch recent meals
    @nonobjc public class func recentMeals(limit: Int = 10) -> NSFetchRequest<MealEntry> {
        let request = fetchRequest()
        
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \MealEntry.timestamp, ascending: false)
        ]
        request.fetchLimit = limit
        
        return request
    }
    
    /// Fetch meals by type
    @nonobjc public class func mealsByType(_ type: MealType) -> NSFetchRequest<MealEntry> {
        let request = fetchRequest()
        
        request.predicate = NSPredicate(format: "mealType == %@", type.rawValue)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \MealEntry.timestamp, ascending: false)
        ]
        
        return request
    }
    
    /// Fetch meals with glucose readings
    @nonobjc public class func mealsWithGlucoseReadings() -> NSFetchRequest<MealEntry> {
        let request = fetchRequest()
        
        request.predicate = NSPredicate(format: "glucoseReadings.@count > 0")
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \MealEntry.timestamp, ascending: false)
        ]
        request.relationshipKeyPathsForPrefetching = ["glucoseReadings"]
        
        return request
    }
}