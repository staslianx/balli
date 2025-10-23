//
//  FoodItem+CoreDataClass.swift
//  balli
//
//  Created by Core Data Model Generator
//

import Foundation
import CoreData

@objc(FoodItem)
public class FoodItem: NSManagedObject, @unchecked Sendable {
    
    override public func awakeFromInsert() {
        super.awakeFromInsert()
        setPrimitiveValue(UUID(), forKey: "id")
        setPrimitiveValue(Date(), forKey: "dateAdded")
        setPrimitiveValue(Date(), forKey: "lastModified")
        setPrimitiveValue("manual", forKey: "source")
        setPrimitiveValue(0, forKey: "useCount")
        setPrimitiveValue(false, forKey: "isFavorite")
        setPrimitiveValue(false, forKey: "isVerified")
    }
    
    override public func willSave() {
        super.willSave()

        // Don't update lastModified if:
        // 1. Object is being inserted (already set in awakeFromInsert)
        // 2. No changes besides lastModified itself
        // 3. lastModified is already in the changed values (prevents recursion)
        guard !isInserted else { return }
        guard hasChanges else { return }
        guard !changedValues().keys.contains("lastModified") else { return }

        setPrimitiveValue(Date(), forKey: "lastModified")
    }
}