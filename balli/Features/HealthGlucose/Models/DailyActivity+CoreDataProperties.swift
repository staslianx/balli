//
//  DailyActivity+CoreDataProperties.swift
//  balli
//
//  Created by Core Data Model Generator
//

import Foundation
import CoreData

extension DailyActivity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<DailyActivity> {
        return NSFetchRequest<DailyActivity>(entityName: "DailyActivity")
    }

    @NSManaged public var id: UUID
    @NSManaged public var date: Date
    @NSManaged public var steps: Int32
    @NSManaged public var activeCalories: Int32
    @NSManaged public var totalCalories: Int32
    @NSManaged public var distance: Double
    @NSManaged public var exerciseMinutes: Int32
    @NSManaged public var source: String
    @NSManaged public var lastSynced: Date
}

extension DailyActivity: Identifiable {

}
