//
//  ValidationUtilities.swift
//  balli
//
//  Created for Core Data Validation and Business Rules
//

import Foundation
import CoreData

// MARK: - Validation Errors
public enum ValidationError: LocalizedError {
    case invalidCarbohydrates
    case invalidFiber
    case invalidSugars
    case invalidAddedSugars
    case invalidSugarAlcohols
    case missingRequiredFields
    case duplicateBarcode
    case invalidServingSize
    case invalidNutritionTotal
    case nameTooShort
    case nameTooLong
    
    public var errorDescription: String? {
        switch self {
        case .invalidCarbohydrates:
            return NSLocalizedString("validation.error.carbs", 
                                    comment: "Carbohydrate value exceeds what's possible given the calories")
        case .invalidFiber:
            return NSLocalizedString("validation.error.fiber", 
                                    comment: "Fiber cannot exceed total carbohydrates")
        case .invalidSugars:
            return NSLocalizedString("validation.error.sugars", 
                                    comment: "Sugars cannot exceed total carbohydrates")
        case .invalidAddedSugars:
            return NSLocalizedString("validation.error.addedSugars", 
                                    comment: "Added sugars cannot exceed total sugars")
        case .invalidSugarAlcohols:
            return NSLocalizedString("validation.error.sugarAlcohols", 
                                    comment: "Sugar alcohols cannot exceed total carbohydrates")
        case .missingRequiredFields:
            return NSLocalizedString("validation.error.required", 
                                    comment: "Required nutrition fields are missing")
        case .duplicateBarcode:
            return NSLocalizedString("validation.error.duplicate", 
                                    comment: "An item with this barcode already exists")
        case .invalidServingSize:
            return NSLocalizedString("validation.error.servingSize", 
                                    comment: "Serving size must be greater than zero")
        case .invalidNutritionTotal:
            return NSLocalizedString("validation.error.nutritionTotal", 
                                    comment: "Total macronutrients exceed possible calories")
        case .nameTooShort:
            return NSLocalizedString("validation.error.nameShort", 
                                    comment: "Name must be at least 2 characters")
        case .nameTooLong:
            return NSLocalizedString("validation.error.nameLong", 
                                    comment: "Name cannot exceed 100 characters")
        }
    }
}

// MARK: - FoodItem Validation
extension FoodItem {
    
    /// Comprehensive validation of nutrition data
    func validateNutrition() throws {
        // Name validation
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.count < 2 {
            throw ValidationError.nameTooShort
        }
        if trimmedName.count > 100 {
            throw ValidationError.nameTooLong
        }
        
        // Serving size validation
        if servingSize <= 0 {
            throw ValidationError.invalidServingSize
        }
        
        // Macronutrient validation (skip for very low calorie foods)
        if calories > 10 {
            // Maximum possible calories from macros (using Atwater factors)
            let maxCaloriesFromMacros = (totalCarbs * 4) + (protein * 4) + (totalFat * 9)
            
            // Allow 50% tolerance for rounding, alcohol calories, and food label variations
            // This is more realistic for actual food products
            if maxCaloriesFromMacros > 0 && calories > maxCaloriesFromMacros * 1.5 {
                throw ValidationError.invalidNutritionTotal
            }
        }
        
        // Carbohydrate validation (skip for very low calorie foods)
        if calories > 10 {
            // Carbs shouldn't exceed calories/4 (with 50% tolerance for food label variations)
            let maxCarbsFromCalories = calories / 4
            if totalCarbs > maxCarbsFromCalories * 1.5 {
                throw ValidationError.invalidCarbohydrates
            }
        }
        
        // Fiber validation
        if fiber > totalCarbs {
            throw ValidationError.invalidFiber
        }
        
        // Sugar validation
        if sugars > totalCarbs {
            throw ValidationError.invalidSugars
        }
        
        // Added sugars validation
        if addedSugars > sugars {
            throw ValidationError.invalidAddedSugars
        }
        
        // Sugar alcohols validation
        if sugarAlcohols > totalCarbs {
            throw ValidationError.invalidSugarAlcohols
        }
        
        // Ensure non-negative values
        let nutritionValues = [
            calories, totalCarbs, fiber, sugars, addedSugars,
            sugarAlcohols, protein, totalFat, saturatedFat,
            transFat, sodium
        ]
        
        if nutritionValues.contains(where: { $0 < 0 }) {
            throw ValidationError.missingRequiredFields
        }
    }
    
    /// Validate before saving
    override public func validateForInsert() throws {
        try super.validateForInsert()
        try validateNutrition()
    }
    
    override public func validateForUpdate() throws {
        try super.validateForUpdate()
        try validateNutrition()
    }
}

// MARK: - Duplicate Detection
extension NSManagedObjectContext {
    
    /// Find duplicate food item by barcode or name/brand combination
    func findDuplicateFoodItem(barcode: String?, name: String, brand: String?) throws -> FoodItem? {
        // Check barcode first if provided
        if let barcode = barcode, !barcode.isEmpty {
            let request = FoodItem.fetchRequest()
            request.predicate = NSPredicate(format: "barcode == %@", barcode)
            request.fetchLimit = 1
            
            if let existing = try fetch(request).first {
                return existing
            }
        }
        
        // Check name + brand combination
        let request = FoodItem.fetchRequest()
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if let brand = brand, !brand.isEmpty {
            let normalizedBrand = brand.trimmingCharacters(in: .whitespacesAndNewlines)
            request.predicate = NSPredicate(
                format: "name ==[c] %@ AND brand ==[c] %@", 
                normalizedName, normalizedBrand
            )
        } else {
            // For items without brand, only match if both have no brand
            request.predicate = NSPredicate(
                format: "name ==[c] %@ AND (brand == nil OR brand == '')", 
                normalizedName
            )
        }
        request.fetchLimit = 1
        
        return try fetch(request).first
    }
    
    /// Find similar food items (for suggestions)
    func findSimilarFoodItems(to name: String, limit: Int = 5) throws -> [FoodItem] {
        let request = FoodItem.fetchRequest()
        
        let words = name.components(separatedBy: .whitespaces)
            .filter { $0.count > 2 } // Ignore short words
        
        guard !words.isEmpty else { return [] }
        
        // Create predicates for each significant word
        let predicates = words.map { word in
            NSPredicate(format: "name CONTAINS[cd] %@ OR brand CONTAINS[cd] %@", word, word)
        }
        
        request.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: predicates)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \FoodItem.useCount, ascending: false),
            NSSortDescriptor(keyPath: \FoodItem.name, ascending: true)
        ]
        request.fetchLimit = limit
        
        return try fetch(request)
    }
}

// MARK: - MealEntry Validation
extension MealEntry {
    
    /// Validate meal entry data
    func validateMealEntry() throws {
        // Quantity validation
        if quantity <= 0 {
            throw ValidationError.invalidServingSize
        }
        
        // Ensure food item is set
        if foodItem == nil {
            throw ValidationError.missingRequiredFields
        }
        
        // Validate glucose values if provided
        if glucoseBefore < 0 || glucoseBefore > 600 {
            throw ValidationError.missingRequiredFields
        }
        
        if glucoseAfter < 0 || glucoseAfter > 600 {
            throw ValidationError.missingRequiredFields
        }
        
        if insulinUnits < 0 || insulinUnits > 200 {
            throw ValidationError.missingRequiredFields
        }
    }
    
    override public func validateForInsert() throws {
        try super.validateForInsert()
        try validateMealEntry()

        // DO NOT calculate nutrition during validation - causes infinite recursion!
        // Nutrition should be calculated BEFORE save, not DURING validation
    }

    override public func validateForUpdate() throws {
        try super.validateForUpdate()
        try validateMealEntry()

        // DO NOT recalculate nutrition during validation - causes infinite recursion!
        // Nutrition should be calculated BEFORE save, not DURING validation
    }
}

// MARK: - GlucoseReading Validation
extension GlucoseReading {
    
    /// Validate glucose reading
    func validateGlucoseReading() throws {
        // Validate glucose value range (20-600 mg/dL)
        if value < 20 || value > 600 {
            throw ValidationError.missingRequiredFields
        }
    }
    
    override public func validateForInsert() throws {
        try super.validateForInsert()
        try validateGlucoseReading()
    }
    
    override public func validateForUpdate() throws {
        try super.validateForUpdate()
        try validateGlucoseReading()
    }
}

// MARK: - Batch Validation
extension NSManagedObjectContext {
    
    /// Validate all pending changes
    func validateAllPendingChanges() throws {
        // Validate inserted objects
        for object in insertedObjects {
            try object.validateForInsert()
        }
        
        // Validate updated objects
        for object in updatedObjects {
            try object.validateForUpdate()
        }
        
        // Check for duplicates in batch inserts
        let insertedFoodItems = insertedObjects.compactMap { $0 as? FoodItem }
        try validateBatchFoodItems(insertedFoodItems)
    }
    
    /// Validate batch of food items for duplicates
    private func validateBatchFoodItems(_ items: [FoodItem]) throws {
        var barcodes = Set<String>()
        var nameAndBrands = Set<String>()
        
        for item in items {
            // Check barcode uniqueness
            if let barcode = item.barcode, !barcode.isEmpty {
                if barcodes.contains(barcode) {
                    throw ValidationError.duplicateBarcode
                }
                barcodes.insert(barcode)
                
                // Also check against existing items
                if try findDuplicateFoodItem(barcode: barcode, name: item.name, brand: item.brand) != nil {
                    throw ValidationError.duplicateBarcode
                }
            }
            
            // Check name+brand uniqueness
            let key = "\(item.name.lowercased()):\(item.brand?.lowercased() ?? "")"
            if nameAndBrands.contains(key) {
                throw ValidationError.duplicateBarcode
            }
            nameAndBrands.insert(key)
        }
    }
}