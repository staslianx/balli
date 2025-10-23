//
//  FoodItem+CoreDataProperties.swift
//  balli
//
//  Created by Core Data Model Generator
//

import Foundation
import CoreData

extension FoodItem {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<FoodItem> {
        return NSFetchRequest<FoodItem>(entityName: "FoodItem")
    }
    
    // MARK: - Identifiers
    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var brand: String?
    @NSManaged public var barcode: String?
    @NSManaged public var category: String?
    
    // MARK: - Localization
    @NSManaged public var nameEn: String?
    @NSManaged public var nameTr: String?
    @NSManaged public var scannedText: String?
    @NSManaged public var detectedLanguage: String?
    
    // MARK: - Serving Information
    @NSManaged public var servingSize: Double
    @NSManaged public var servingUnit: String
    @NSManaged public var servingsPerContainer: Double
    @NSManaged public var gramWeight: Double
    
    // MARK: - Macronutrients (per serving)
    @NSManaged public var calories: Double
    @NSManaged public var totalCarbs: Double
    @NSManaged public var fiber: Double
    @NSManaged public var sugars: Double
    @NSManaged public var addedSugars: Double
    @NSManaged public var sugarAlcohols: Double
    @NSManaged public var protein: Double
    @NSManaged public var totalFat: Double
    @NSManaged public var saturatedFat: Double
    @NSManaged public var transFat: Double
    @NSManaged public var sodium: Double
    
    // MARK: - Confidence Scores (0-100)
    @NSManaged public var carbsConfidence: Double
    @NSManaged public var overallConfidence: Double
    @NSManaged public var ocrConfidence: Double
    
    // MARK: - Metadata
    @NSManaged public var source: String
    @NSManaged public var dateAdded: Date
    @NSManaged public var lastModified: Date
    @NSManaged public var lastUsed: Date?
    @NSManaged public var useCount: Int32
    @NSManaged public var isFavorite: Bool
    @NSManaged public var isVerified: Bool
    @NSManaged public var notes: String?
    
    // MARK: - Relationships
    @NSManaged public var mealEntries: Set<MealEntry>?
    @NSManaged public var scanImages: Set<ScanImage>?
    @NSManaged public var nutritionVariants: Set<NutritionVariant>?
}

// MARK: Generated accessors for mealEntries
extension FoodItem {
    
    @objc(addMealEntriesObject:)
    @NSManaged public func addToMealEntries(_ value: MealEntry)
    
    @objc(removeMealEntriesObject:)
    @NSManaged public func removeFromMealEntries(_ value: MealEntry)
    
    @objc(addMealEntries:)
    @NSManaged public func addToMealEntries(_ values: NSSet)
    
    @objc(removeMealEntries:)
    @NSManaged public func removeFromMealEntries(_ values: NSSet)
}

// MARK: Generated accessors for scanImages
extension FoodItem {
    
    @objc(addScanImagesObject:)
    @NSManaged public func addToScanImages(_ value: ScanImage)
    
    @objc(removeScanImagesObject:)
    @NSManaged public func removeFromScanImages(_ value: ScanImage)
    
    @objc(addScanImages:)
    @NSManaged public func addToScanImages(_ values: NSSet)
    
    @objc(removeScanImages:)
    @NSManaged public func removeFromScanImages(_ values: NSSet)
}

// MARK: Generated accessors for nutritionVariants
extension FoodItem {
    
    @objc(addNutritionVariantsObject:)
    @NSManaged public func addToNutritionVariants(_ value: NutritionVariant)
    
    @objc(removeNutritionVariantsObject:)
    @NSManaged public func removeFromNutritionVariants(_ value: NutritionVariant)
    
    @objc(addNutritionVariants:)
    @NSManaged public func addToNutritionVariants(_ values: NSSet)
    
    @objc(removeNutritionVariants:)
    @NSManaged public func removeFromNutritionVariants(_ values: NSSet)
}

extension FoodItem : Identifiable {
}