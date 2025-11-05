//
//  ShoppingListItem+CoreDataClass.swift
//  balli
//
//  Created by Core Data Model Generator
//

import Foundation
import CoreData

@objc(ShoppingListItem)
public class ShoppingListItem: NSManagedObject, @unchecked Sendable {

    override public func awakeFromInsert() {
        super.awakeFromInsert()
        setPrimitiveValue(UUID(), forKey: "id")
        setPrimitiveValue(Date(), forKey: "dateCreated")
        setPrimitiveValue(Date(), forKey: "lastModified")
        setPrimitiveValue(false, forKey: "isCompleted")
        setPrimitiveValue(0, forKey: "sortOrder")
    }
    
    override public func willSave() {
        super.willSave()
        
        if hasChanges {
            setPrimitiveValue(Date(), forKey: "lastModified")
        }
        
        // Set completion date when item is marked as complete
        if changedValues()["isCompleted"] as? Bool == true && dateCompleted == nil {
            setPrimitiveValue(Date(), forKey: "dateCompleted")
        }
        
        // Clear completion date when item is marked as incomplete
        if changedValues()["isCompleted"] as? Bool == false {
            setPrimitiveValue(nil, forKey: "dateCompleted")
        }
    }
}