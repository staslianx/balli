//
//  ScanImage+CoreDataClass.swift
//  balli
//
//  Created by Core Data Model Generator
//

import Foundation
import CoreData

@objc(ScanImage)
public class ScanImage: NSManagedObject, @unchecked Sendable {
    
    override public func awakeFromInsert() {
        super.awakeFromInsert()
        setPrimitiveValue(UUID(), forKey: "id")
        setPrimitiveValue(Date(), forKey: "scanDate")
        setPrimitiveValue("nutrition_label", forKey: "imageType")
        setPrimitiveValue(false, forKey: "aiProcessed")
        setPrimitiveValue(0.0, forKey: "processingTime")
    }
}