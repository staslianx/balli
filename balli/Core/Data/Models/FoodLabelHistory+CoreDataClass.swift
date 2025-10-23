//
//  FoodLabelHistory+CoreDataClass.swift
//  balli
//
//  Created by Core Data Model Generator
//

import Foundation
import CoreData

@objc(FoodLabelHistory)
public class FoodLabelHistory: NSManagedObject, @unchecked Sendable {
    
    override public func awakeFromInsert() {
        super.awakeFromInsert()
        setPrimitiveValue(UUID(), forKey: "id")
        setPrimitiveValue(Date(), forKey: "scanDate")
        setPrimitiveValue(0.0, forKey: "carbsPer100g")
        setPrimitiveValue(0.0, forKey: "carbsPerServing")
        setPrimitiveValue(0.0, forKey: "sugars")
        setPrimitiveValue(0.0, forKey: "fiber")
    }
    
    // Computed properties
    public var netCarbsPer100g: Double {
        let fiberValue = self.fiber
        return max(0, carbsPer100g - (fiberValue > 5 ? fiberValue : 0))
    }
    
    public var netCarbsPerServing: Double {
        let fiberValue = self.fiber
        return max(0, carbsPerServing - (fiberValue > 5 ? fiberValue : 0))
    }
    
    public var hasNutritionData: Bool {
        return carbsPer100g > 0 || carbsPerServing > 0
    }
    
    // Helper methods
    public func updateNutritionData(
        carbsPer100g: Double,
        carbsPerServing: Double,
        servingSize: String,
        sugars: Double? = nil,
        fiber: Double? = nil
    ) {
        self.carbsPer100g = carbsPer100g
        self.carbsPerServing = carbsPerServing
        self.servingSize = servingSize
        if let sugars = sugars {
            self.sugars = sugars
        }
        if let fiber = fiber {
            self.fiber = fiber
        }
    }
}