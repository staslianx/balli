//
//  NutritionVariant+CoreDataClass.swift
//  balli
//
//  Created by Core Data Model Generator
//

import Foundation
import CoreData

@objc(NutritionVariant)
public class NutritionVariant: NSManagedObject, @unchecked Sendable {
    
    override public func awakeFromInsert() {
        super.awakeFromInsert()
        setPrimitiveValue(UUID(), forKey: "id")
        setPrimitiveValue("serving", forKey: "servingUnit")
    }
}