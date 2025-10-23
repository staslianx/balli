//
//  GlucoseReading+CoreDataClass.swift
//  balli
//
//  Created by Core Data Model Generator
//

import Foundation
import CoreData

@objc(GlucoseReading)
public class GlucoseReading: NSManagedObject, @unchecked Sendable {
    
    override public func awakeFromInsert() {
        super.awakeFromInsert()
        setPrimitiveValue(UUID(), forKey: "id")
        setPrimitiveValue(Date(), forKey: "timestamp")
        setPrimitiveValue("manual", forKey: "source")
        setPrimitiveValue("pending", forKey: "syncStatus")
    }
}