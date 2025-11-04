//
//  DailyActivity+CoreDataClass.swift
//  balli
//
//  Created by Core Data Model Generator
//

import Foundation
import CoreData

@objc(DailyActivity)
public class DailyActivity: NSManagedObject, @unchecked Sendable {

    override public func awakeFromInsert() {
        super.awakeFromInsert()
        setPrimitiveValue(UUID(), forKey: "id")
        setPrimitiveValue(Date(), forKey: "date")
        setPrimitiveValue("apple_health", forKey: "source")
        setPrimitiveValue(Date(), forKey: "lastSynced")
        setPrimitiveValue(0, forKey: "steps")
        setPrimitiveValue(0, forKey: "activeCalories")
        setPrimitiveValue(0, forKey: "totalCalories")
    }
}
