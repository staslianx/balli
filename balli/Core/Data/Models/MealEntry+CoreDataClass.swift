//
//  MealEntry+CoreDataClass.swift
//  balli
//
//  Created by Core Data Model Generator
//

import Foundation
import CoreData

@objc(MealEntry)
public class MealEntry: NSManagedObject, @unchecked Sendable {

    override public func awakeFromInsert() {
        super.awakeFromInsert()
        setPrimitiveValue(UUID(), forKey: "id")
        setPrimitiveValue(Date(), forKey: "timestamp")
        setPrimitiveValue("snack", forKey: "mealType")
        setPrimitiveValue(1.0, forKey: "quantity")
        setPrimitiveValue("serving", forKey: "unit")
        setPrimitiveValue(Date(), forKey: "lastModified")
        setPrimitiveValue("pending", forKey: "firestoreSyncStatus")
        // Use a generated UUID as device identifier instead of UIDevice
        setPrimitiveValue(UUID().uuidString, forKey: "deviceId")
    }
}