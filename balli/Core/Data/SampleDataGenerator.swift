//
//  SampleDataGenerator.swift
//  balli
//
//  Created for Generating Sample Data for Testing and Development
//

import Foundation
import CoreData
import OSLog

#if DEBUG

class SampleDataGenerator {
    
    // MARK: - Turkish Food Names
    private static let turkishFoods = [
        ("Ekmek", "Bread"),
        ("Beyaz Peynir", "White Cheese"),
        ("Yoğurt", "Yogurt"),
        ("Ayran", "Buttermilk"),
        ("Simit", "Turkish Bagel"),
        ("Bal", "Honey"),
        ("Reçel", "Jam"),
        ("Zeytin", "Olives"),
        ("Domates", "Tomato"),
        ("Salatalık", "Cucumber"),
        ("Çay", "Tea"),
        ("Türk Kahvesi", "Turkish Coffee"),
        ("Börek", "Pastry"),
        ("Pide", "Turkish Pizza"),
        ("Lahmacun", "Turkish Pizza with Meat"),
        ("Döner", "Doner Kebab"),
        ("Köfte", "Meatballs"),
        ("Pilav", "Rice"),
        ("Makarna", "Pasta"),
        ("Mercimek Çorbası", "Lentil Soup"),
        ("Baklava", "Baklava"),
        ("Sütlaç", "Rice Pudding"),
        ("Ayva Tatlısı", "Quince Dessert"),
        ("Lokum", "Turkish Delight"),
        ("Elma", "Apple"),
        ("Portakal", "Orange"),
        ("Muz", "Banana"),
        ("Karpuz", "Watermelon"),
        ("Kavun", "Melon"),
        ("Üzüm", "Grapes")
    ]
    
    // MARK: - Brand Names
    private static let brands = [
        "Ülker", "Eti", "Torku", "Pınar", "Sütaş",
        "İçim", "Danone", "Sek", "Dimes", "Cappy",
        "Coca-Cola", "Pepsi", "Fanta", "Sprite", nil
    ]
    
    // MARK: - Categories
    private static let categories = [
        "Kahvaltılık", "İçecek", "Meyve", "Sebze", "Tatlı",
        "Ana Yemek", "Çorba", "Atıştırmalık", "Fırın Ürünleri"
    ]
    
    // MARK: - Public Methods
    
    /// Generate sample food items
    static func generateFoodItems(in context: NSManagedObjectContext, count: Int = 50) throws {
        AppLoggers.Data.coredata.info("Generating \(count) sample food items...")
        
        for i in 0..<count {
            let food = FoodItem(context: context)
            
            // Basic info
            let foodIndex = i % turkishFoods.count
            let (turkishName, englishName) = turkishFoods[foodIndex]
            
            food.name = turkishName
            food.nameTr = turkishName
            food.nameEn = englishName
            food.brand = brands.randomElement() ?? nil
            food.category = categories.randomElement()
            
            // Barcode for some items
            if Bool.random() && food.brand != nil {
                food.barcode = generateBarcode()
            }
            
            // Serving info
            let servingInfo = generateServingInfo(for: foodIndex)
            food.servingSize = servingInfo.size
            food.servingUnit = servingInfo.unit
            food.servingsPerContainer = servingInfo.servingsPerContainer
            food.gramWeight = servingInfo.gramWeight
            
            // Nutrition
            let nutrition = generateNutrition(for: foodIndex)
            food.calories = nutrition.calories
            food.totalCarbs = nutrition.carbs
            food.fiber = nutrition.fiber
            food.sugars = nutrition.sugars
            food.addedSugars = nutrition.addedSugars
            food.sugarAlcohols = 0 // Most foods don't have this
            food.protein = nutrition.protein
            food.totalFat = nutrition.fat
            food.saturatedFat = nutrition.saturatedFat
            food.transFat = 0
            food.sodium = nutrition.sodium
            
            // Confidence scores
            food.carbsConfidence = Double.random(in: 50...100)
            food.overallConfidence = Double.random(in: 60...95)
            food.ocrConfidence = food.barcode != nil ? Double.random(in: 85...100) : 0
            
            // Metadata
            food.source = ["scanned", "manual", "database"].randomElement() ?? "manual"
            food.useCount = Int32.random(in: 0...100)
            food.isFavorite = food.useCount > 50
            food.isVerified = food.overallConfidence > 80

            // Dates
            let daysAgo = Int.random(in: 0...365)
            food.dateAdded = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
            food.lastModified = food.dateAdded
            
            if food.useCount > 0 {
                let lastUsedDaysAgo = Int.random(in: 0...30)
                food.lastUsed = Calendar.current.date(byAdding: .day, value: -lastUsedDaysAgo, to: Date())
            }
            
            // Add scan image for scanned items
            if food.source == "scanned" {
                try addScanImage(to: food, context: context)
            }
        }

        AppLoggers.Data.coredata.info("Generated \(count) food items")
    }
    
    /// Generate sample meal entries
    static func generateMealEntries(in context: NSManagedObjectContext, days: Int = 30) throws {
        AppLoggers.Data.coredata.info("Generating meal entries for \(days) days...")

        // Fetch all food items
        let foodRequest = FoodItem.fetchRequest()
        let foods = try context.fetch(foodRequest)

        guard !foods.isEmpty else {
            AppLoggers.Data.coredata.notice("No food items found. Generate food items first.")
            return
        }
        
        let calendar = Calendar.current
        var mealCount = 0
        
        for daysAgo in 0..<days {
            guard let date = calendar.date(byAdding: .day, value: -daysAgo, to: Date()) else {
                continue
            }

            // Generate 3-6 meals per day
            let mealsPerDay = Int.random(in: 3...6)
            
            for mealIndex in 0..<mealsPerDay {
                let meal = MealEntry(context: context)
                
                // Set meal time
                let mealType = determineMealType(for: mealIndex, total: mealsPerDay)
                meal.mealType = mealType.rawValue
                
                let hour = mealTimeHour(for: mealType)
                let minute = Int.random(in: 0...59)
                guard let timestamp = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: date),
                      let foodItem = foods.randomElement() else {
                    continue
                }
                meal.timestamp = timestamp

                // Select random food
                meal.foodItem = foodItem

                // Set portion
                let portionInfo = generatePortionInfo(for: foodItem)
                meal.quantity = portionInfo.quantity
                meal.unit = portionInfo.unit
                
                // Calculate nutrition
                meal.calculateNutrition()
                
                // Add glucose readings for some meals
                if Bool.random(probability: 0.6) {
                    try addGlucoseReadings(to: meal, context: context)
                }
                
                // Add insulin for some meals
                if meal.consumedCarbs > 15 && Bool.random(probability: 0.7) {
                    meal.insulinUnits = calculateInsulinDose(for: meal.consumedCarbs)
                }
                
                // Add notes occasionally
                if Bool.random(probability: 0.2) {
                    meal.notes = generateMealNote()
                }
                
                mealCount += 1
            }
        }

        AppLoggers.Data.coredata.info("Generated \(mealCount) meal entries")
    }
    
    /// Generate sample glucose readings
    static func generateGlucoseReadings(in context: NSManagedObjectContext, days: Int = 30) throws {
        AppLoggers.Data.coredata.info("Generating glucose readings for \(days) days...")
        
        let calendar = Calendar.current
        var readingCount = 0
        
        for daysAgo in 0..<days {
            guard let date = calendar.date(byAdding: .day, value: -daysAgo, to: Date()) else {
                continue
            }

            // Generate 4-8 readings per day
            let readingsPerDay = Int.random(in: 4...8)

            for readingIndex in 0..<readingsPerDay {
                let reading = GlucoseReading(context: context)

                // Set time
                let hour = (readingIndex * 24 / readingsPerDay) + Int.random(in: -1...1)
                let minute = Int.random(in: 0...59)
                guard let timestamp = calendar.date(bySettingHour: max(0, min(23, hour)),
                                                 minute: minute, second: 0, of: date) else {
                    continue
                }
                reading.timestamp = timestamp

                // Generate realistic glucose value based on time of day
                reading.value = generateGlucoseValue(hour: hour)

                // Set source
                let sources: [(GlucoseSource, Double)] = [
                    (.manual, 0.5),
                    (.healthKit, 0.3),
                    (.cgm, 0.2)
                ]
                reading.source = sources.randomElement(weights: sources.map { $0.1 })?.0.rawValue ?? "manual"
                
                // Set device name for CGM
                if reading.source == "cgm" {
                    reading.deviceName = "Dexcom G6"
                }
                
                // Set sync status for manual entries
                if reading.source == "manual" {
                    if Bool.random(probability: 0.8) {
                        reading.syncStatus = "synced"
                        reading.healthKitUUID = UUID().uuidString
                    } else {
                        reading.syncStatus = Bool.random() ? "pending" : "failed"
                    }
                }
                
                readingCount += 1
            }
        }

        AppLoggers.Data.coredata.info("Generated \(readingCount) glucose readings")
    }
    
    /// Clear all sample data
    static func clearAllData(in context: NSManagedObjectContext) throws {
        AppLoggers.Data.coredata.notice("Clearing all data...")

        let entities = ["FoodItem", "MealEntry", "GlucoseReading", "ScanImage", "NutritionVariant"]

        for entity in entities {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entity)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            try context.execute(deleteRequest)
        }

        try context.save()
        AppLoggers.Data.coredata.info("All data cleared")
    }
    
    // MARK: - Private Helper Methods
    
    private static func generateBarcode() -> String {
        let prefix = ["869", "890", "800"].randomElement() ?? "869"
        let middle = String(format: "%08d", Int.random(in: 0...99999999))
        let checksum = Int.random(in: 0...9)
        return "\(prefix)\(middle)\(checksum)"
    }
    
    private static func generateServingInfo(for foodIndex: Int) -> (size: Double, unit: String, servingsPerContainer: Double, gramWeight: Double) {
        switch foodIndex % turkishFoods.count {
        case 0...5: // Bread, cheese, etc.
            return (100, "g", 1, 100)
        case 6...10: // Liquids
            return (200, "ml", 1, 200)
        case 11...20: // Main dishes
            return (1, "porsiyon", 1, 250)
        case 21...25: // Desserts
            return (1, "adet", 1, 80)
        default: // Fruits
            return (1, "adet", 1, 150)
        }
    }
    
    private static func generateNutrition(for foodIndex: Int) -> (calories: Double, carbs: Double, fiber: Double, sugars: Double, addedSugars: Double, protein: Double, fat: Double, saturatedFat: Double, sodium: Double) {
        switch foodIndex % turkishFoods.count {
        case 0: // Bread
            return (250, 50, 3, 2, 0, 8, 1, 0.2, 450)
        case 1: // White cheese
            return (280, 2, 0, 1, 0, 18, 22, 14, 900)
        case 2: // Yogurt
            return (60, 5, 0, 4, 0, 4, 3, 2, 50)
        case 20: // Baklava
            return (400, 45, 2, 25, 20, 6, 22, 8, 300)
        case 24...29: // Fruits
            return (60, 15, 3, 12, 0, 1, 0.5, 0, 2)
        default:
            return (Double.random(in: 100...400),
                    Double.random(in: 10...60),
                    Double.random(in: 0...8),
                    Double.random(in: 0...20),
                    Double.random(in: 0...10),
                    Double.random(in: 2...30),
                    Double.random(in: 0...25),
                    Double.random(in: 0...10),
                    Double.random(in: 50...1000))
        }
    }
    
    private static func addScanImage(to foodItem: FoodItem, context: NSManagedObjectContext) throws {
        let scanImage = ScanImage(context: context)
        scanImage.foodItem = foodItem
        scanImage.imageType = "nutrition_label"
        scanImage.aiProcessed = true
        scanImage.processingTime = Double.random(in: 0.8...2.5)
        scanImage.aiModel = "balli-ai-v1"
        
        // Create dummy image data
        scanImage.imageData = Data(repeating: 0, count: 1000)
        scanImage.thumbnailData = Data(repeating: 0, count: 100)
        
        // Create AI response
        let aiResponse: [String: Any] = [
            "nutrition": [
                "calories": foodItem.calories,
                "carbs": foodItem.totalCarbs,
                "protein": foodItem.protein,
                "fat": foodItem.totalFat
            ],
            "confidence": [
                "overall": foodItem.overallConfidence,
                "carbs": foodItem.carbsConfidence,
                "ocr": foodItem.ocrConfidence
            ]
        ]
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: aiResponse, options: .prettyPrinted) {
            scanImage.aiResponse = String(data: jsonData, encoding: .utf8)
        }
    }
    
    private static func determineMealType(for index: Int, total: Int) -> MealType {
        if total <= 3 {
            return [.breakfast, .lunch, .dinner][index]
        } else {
            let mainMeals: [MealType] = [.breakfast, .lunch, .dinner]
            if index < 3 {
                return mainMeals[index]
            } else {
                return .snack
            }
        }
    }
    
    private static func mealTimeHour(for type: MealType) -> Int {
        switch type {
        case .breakfast:
            return Int.random(in: 7...9)
        case .lunch:
            return Int.random(in: 12...14)
        case .dinner:
            return Int.random(in: 18...20)
        case .snack:
            return Int.random(in: 10...22)
        }
    }
    
    private static func generatePortionInfo(for food: FoodItem) -> (quantity: Double, unit: String) {
        if food.servingUnit == "g" {
            return (Double.random(in: 50...200), "g")
        } else if food.servingUnit == "ml" {
            return (Double.random(in: 100...300), "ml")
        } else {
            return (Double([0.5, 1, 1.5, 2].randomElement() ?? 1.0), food.servingUnit)
        }
    }
    
    private static func addGlucoseReadings(to meal: MealEntry, context: NSManagedObjectContext) throws {
        // Before meal reading
        let beforeReading = GlucoseReading(context: context)
        beforeReading.timestamp = meal.timestamp.addingTimeInterval(-15 * 60) // 15 min before
        beforeReading.value = Double.random(in: 80...140)
        beforeReading.source = "manual"
        beforeReading.mealEntry = meal
        meal.glucoseBefore = beforeReading.value
        
        // After meal reading (1-2 hours later)
        let afterMinutes = Double.random(in: 60...120)
        let afterReading = GlucoseReading(context: context)
        afterReading.timestamp = meal.timestamp.addingTimeInterval(afterMinutes * 60)
        afterReading.value = beforeReading.value + Double.random(in: 20...80)
        afterReading.source = "manual"
        afterReading.mealEntry = meal
        meal.glucoseAfter = afterReading.value
    }
    
    private static func calculateInsulinDose(for carbs: Double) -> Double {
        let ratio = Double.random(in: 8...15) // 1 unit per 8-15g carbs
        return (carbs / ratio).rounded()
    }
    
    private static func generateGlucoseValue(hour: Int) -> Double {
        // Generate realistic glucose patterns
        switch hour {
        case 0...6: // Night/early morning
            return Double.random(in: 70...110)
        case 7...9: // Post-breakfast
            return Double.random(in: 100...180)
        case 10...11: // Mid-morning
            return Double.random(in: 80...140)
        case 12...14: // Post-lunch
            return Double.random(in: 110...190)
        case 15...17: // Afternoon
            return Double.random(in: 85...130)
        case 18...20: // Post-dinner
            return Double.random(in: 120...200)
        default: // Evening
            return Double.random(in: 90...150)
        }
    }
    
    private static func generateMealNote() -> String {
        let notes = [
            "Yemekten önce yürüyüş yaptım",
            "Ekstra porsiyon",
            "Karbonhidrat tahmini",
            "Evde pişirildi",
            "Restoranda yedim",
            "Glütensiz versiyon",
            "Az tuzlu",
            "Şekersiz",
            "Light ürün",
            "Organik"
        ]
        return notes.randomElement() ?? "Notlar"
    }
}

// MARK: - Helper Extensions

private extension Bool {
    static func random(probability: Double) -> Bool {
        return Double.random(in: 0...1) < probability
    }
}

private extension Array {
    func randomElement<T>(weights: [Double]) -> Element? where Element == (T, Double) {
        let totalWeight = weights.reduce(0, +)
        let randomValue = Double.random(in: 0..<totalWeight)
        
        var cumulativeWeight = 0.0
        for (index, weight) in weights.enumerated() {
            cumulativeWeight += weight
            if randomValue < cumulativeWeight {
                return self[index]
            }
        }
        
        return self.last
    }
}

#endif