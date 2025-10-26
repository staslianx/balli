//
//  MealEntryMigrationPolicy.swift
//  balli
//
//  Custom migration policy to handle MealEntry schema changes
//

import CoreData
import OSLog

/// Custom migration policy for MealEntry entity to handle lastModified attribute addition
final class MealEntryMigrationPolicy: NSEntityMigrationPolicy {

    private let logger = AppLoggers.Data.migration

    override func createDestinationInstances(
        forSource sInstance: NSManagedObject,
        in mapping: NSEntityMapping,
        manager: NSMigrationManager
    ) throws {
        try super.createDestinationInstances(forSource: sInstance, in: mapping, manager: manager)

        let destinationInstances = manager.destinationInstances(
            forEntityMappingName: mapping.name ?? "",
            sourceInstances: [sInstance]
        )

        for destinationInstance in destinationInstances {
            // Set default value for lastModified if it's nil
            if destinationInstance.value(forKey: "lastModified") == nil {
                // Use timestamp as fallback, or current date if timestamp is nil
                let defaultDate = (sInstance.value(forKey: "timestamp") as? Date) ?? Date()
                destinationInstance.setValue(defaultDate, forKey: "lastModified")
                logger.debug("Set default lastModified for MealEntry: \(destinationInstance.objectID)")
            }

            // Ensure firestoreSyncStatus has a default value
            if let syncStatus = destinationInstance.value(forKey: "firestoreSyncStatus") as? String,
               syncStatus.isEmpty {
                destinationInstance.setValue("pending", forKey: "firestoreSyncStatus")
            }
        }
    }
}
