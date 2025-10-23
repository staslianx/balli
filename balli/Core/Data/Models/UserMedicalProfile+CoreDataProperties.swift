//
//  UserMedicalProfile+CoreDataProperties.swift
//  balli
//
//  Created by Core Data Model Generator
//

import Foundation
import CoreData

extension UserMedicalProfile {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<UserMedicalProfile> {
        return NSFetchRequest<UserMedicalProfile>(entityName: "UserMedicalProfile")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var lastUpdated: Date?
    @NSManaged public var insulinToCarbRatio: String?
    @NSManaged public var correctionFactor: Int32
    @NSManaged public var targetBloodSugar: Int32
    @NSManaged public var diabetesType: String?
    @NSManaged public var restrictions: NSObject?
    @NSManaged public var preferredCuisines: NSObject?
    @NSManaged public var dislikedIngredients: NSObject?
    @NSManaged public var preferredLanguage: String?

}