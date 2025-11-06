//
//  DemoDataService.swift
//  balli
//
//  Service for managing demo/preview data
//  Swift 6 strict concurrency compliant
//

import Foundation
import CoreData

@MainActor
struct DemoDataService {

    /// Add demo food products to the given context
    static func addDemoProducts(to context: NSManagedObjectContext) {
        // Check if demo products already exist
        let fetchRequest = FoodItem.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "source == %@", "ai_scanned")

        guard (try? context.fetch(fetchRequest))?.isEmpty ?? true else {
            return // Products already exist
        }

        let demoProducts = [
            (
                name: "Whole Wheat Bread",
                brand: "Deli's Best",
                carbs: 42.0,
                protein: 4.0,
                totalFat: 2.0,
                fiber: 3.0,
                sugars: 3.0,
                servingSize: 50.0,
                servingUnit: "gr",
                calories: 200.0
            ),
            (
                name: "Greek Yogurt",
                brand: "Fage",
                carbs: 6.5,
                protein: 10.0,
                totalFat: 3.0,
                fiber: 0.0,
                sugars: 4.0,
                servingSize: 150.0,
                servingUnit: "gr",
                calories: 100.0
            ),
            (
                name: "Granola Cereal",
                brand: "Nature Valley",
                carbs: 35.0,
                protein: 6.0,
                totalFat: 8.0,
                fiber: 2.0,
                sugars: 12.0,
                servingSize: 40.0,
                servingUnit: "gr",
                calories: 180.0
            ),
            (
                name: "Almond Butter",
                brand: "Justin's",
                carbs: 4.0,
                protein: 7.0,
                totalFat: 9.0,
                fiber: 2.5,
                sugars: 1.0,
                servingSize: 32.0,
                servingUnit: "gr",
                calories: 190.0
            )
        ]

        for product in demoProducts {
            let foodItem = FoodItem(context: context)
            foodItem.id = UUID()
            foodItem.name = product.name
            foodItem.brand = product.brand
            foodItem.totalCarbs = product.carbs
            foodItem.protein = product.protein
            foodItem.totalFat = product.totalFat
            foodItem.fiber = product.fiber
            foodItem.sugars = product.sugars
            // Calculate calories from macros to ensure validation passes
            let carbCals = product.carbs * 4
            let proteinCals = product.protein * 4
            let fatCals = product.totalFat * 9
            let calculatedCalories = carbCals + proteinCals + fatCals
            foodItem.calories = calculatedCalories
            foodItem.servingSize = product.servingSize
            foodItem.servingUnit = product.servingUnit
            foodItem.source = "ai_scanned"
            foodItem.dateAdded = Date()
            foodItem.lastModified = Date()
            foodItem.lastUsed = Date()
            foodItem.isFavorite = false
            foodItem.overallConfidence = 85.0
            foodItem.carbsConfidence = 90.0
            foodItem.ocrConfidence = 80.0
            foodItem.isVerified = true
            foodItem.gramWeight = product.servingSize
        }

        do {
            try context.save()
        } catch {
        }
    }
}
