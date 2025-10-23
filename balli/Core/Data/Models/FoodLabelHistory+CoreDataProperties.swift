//
//  FoodLabelHistory+CoreDataProperties.swift
//  balli
//
//  Created by Core Data Model Generator
//

import Foundation
import CoreData

extension FoodLabelHistory {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<FoodLabelHistory> {
        return NSFetchRequest<FoodLabelHistory>(entityName: "FoodLabelHistory")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var scanDate: Date?
    @NSManaged public var productName: String?
    @NSManaged public var brandName: String?
    @NSManaged public var barcode: String?
    @NSManaged public var carbsPer100g: Double
    @NSManaged public var carbsPerServing: Double
    @NSManaged public var servingSize: String?
    @NSManaged public var sugars: Double
    @NSManaged public var fiber: Double
    @NSManaged public var userNotes: String?
    @NSManaged public var imageData: Data?

}