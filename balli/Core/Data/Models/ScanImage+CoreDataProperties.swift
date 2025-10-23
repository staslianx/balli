//
//  ScanImage+CoreDataProperties.swift
//  balli
//
//  Created by Core Data Model Generator
//

import Foundation
import CoreData

extension ScanImage {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<ScanImage> {
        return NSFetchRequest<ScanImage>(entityName: "ScanImage")
    }
    
    // MARK: - Identifiers
    @NSManaged public var id: UUID
    @NSManaged public var imageData: Data
    @NSManaged public var thumbnailData: Data?
    @NSManaged public var scanDate: Date
    @NSManaged public var imageType: String
    
    // MARK: - AI Processing
    @NSManaged public var aiProcessed: Bool
    @NSManaged public var aiResponse: String?
    @NSManaged public var processingTime: Double
    @NSManaged public var aiModel: String?
    
    // MARK: - Relationships
    @NSManaged public var foodItem: FoodItem?
}

extension ScanImage : Identifiable {
}