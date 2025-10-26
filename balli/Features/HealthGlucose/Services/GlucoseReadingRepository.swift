//
//  GlucoseReadingRepository.swift
//  balli
//
//  Repository for persisting glucose readings to CoreData
//  Handles deduplication, batch operations, and historical queries
//  Swift 6 strict concurrency compliant
//

import Foundation
import CoreData
import OSLog

/// Actor-based repository for thread-safe glucose reading persistence
actor GlucoseReadingRepository {

    // MARK: - Properties

    private let persistenceController: Persistence.PersistenceController
    private let logger = AppLoggers.Health.glucose

    // MARK: - Initialization

    init(persistenceController: Persistence.PersistenceController = .shared) {
        self.persistenceController = persistenceController
    }

    // MARK: - Save Operations

    /// Save a single glucose reading to CoreData with deduplication
    /// - Parameter reading: The HealthGlucoseReading to save
    /// - Returns: The saved CoreData GlucoseReading, or nil if duplicate or invalid
    func saveReading(from healthReading: HealthGlucoseReading) async throws -> GlucoseReading? {
        logger.info("Saving glucose reading: \(healthReading.value) mg/dL at \(healthReading.timestamp)")

        // Validate glucose value range
        guard isValidGlucoseValue(healthReading.value) else {
            logger.warning("⚠️ Skipping invalid glucose value: \(healthReading.value) mg/dL (out of physiological range \(Self.minPhysiologicalGlucose)-\(Self.maxPhysiologicalGlucose))")
            return nil
        }

        // Validate timestamp
        guard isValidTimestamp(healthReading.timestamp) else {
            logger.warning("⚠️ Skipping reading with future timestamp: \(healthReading.timestamp)")
            return nil
        }

        // Map bundle identifier to CoreData source enum value
        let coreDataSource = mapSourceToCoreData(healthReading.source)
        logger.debug("Mapped source '\(healthReading.source ?? "nil")' -> '\(coreDataSource)'")

        // Check for duplicates
        if try await isDuplicate(timestamp: healthReading.timestamp, source: coreDataSource) {
            logger.debug("Skipping duplicate reading at \(healthReading.timestamp)")
            return nil
        }

        // Create in background context
        let reading = try await persistenceController.performBackgroundTask { context in
            let reading = GlucoseReading(context: context)
            reading.id = healthReading.id
            reading.timestamp = healthReading.timestamp
            reading.value = healthReading.value
            reading.source = coreDataSource
            reading.deviceName = healthReading.device
            reading.syncStatus = "synced"

            try context.save()
            return reading
        }

        logger.info("✅ Saved glucose reading: \(reading.id) with source '\(coreDataSource)'")
        return reading
    }

    /// Batch save multiple glucose readings with deduplication
    /// - Parameter readings: Array of HealthGlucoseReading to save
    /// - Returns: Count of successfully saved readings (excluding duplicates)
    func saveReadings(from healthReadings: [HealthGlucoseReading]) async throws -> Int {
        guard !healthReadings.isEmpty else {
            logger.debug("No readings to save")
            return 0
        }

        logger.info("Batch saving \(healthReadings.count) glucose readings...")

        // Filter out invalid and duplicate readings
        var tempUniqueReadings: [HealthGlucoseReading] = []
        var invalidCount = 0

        for reading in healthReadings {
            // Validate glucose value and timestamp
            guard isValidGlucoseValue(reading.value) else {
                invalidCount += 1
                logger.debug("Skipping invalid value: \(reading.value) mg/dL")
                continue
            }

            guard isValidTimestamp(reading.timestamp) else {
                invalidCount += 1
                logger.debug("Skipping future timestamp: \(reading.timestamp)")
                continue
            }

            let coreDataSource = mapSourceToCoreData(reading.source)
            if !(try await isDuplicate(timestamp: reading.timestamp, source: coreDataSource)) {
                tempUniqueReadings.append(reading)
            }
        }

        if invalidCount > 0 {
            logger.info("Filtered \(invalidCount) invalid readings (out of range or future timestamp)")
        }

        if tempUniqueReadings.isEmpty {
            logger.info("All \(healthReadings.count) readings were duplicates or invalid, skipping save")
            return 0
        }

        logger.info("Found \(tempUniqueReadings.count) unique readings to save (filtered \(healthReadings.count - tempUniqueReadings.count - invalidCount) duplicates)")

        // Make immutable copy for closure capture
        let uniqueReadings = tempUniqueReadings
        let count = uniqueReadings.count

        // Prepare source mappings before entering background task
        let readingsWithMappedSources: [(reading: HealthGlucoseReading, coreDataSource: String)] = uniqueReadings.map { reading in
            let coreDataSource = mapSourceToCoreData(reading.source)
            return (reading, coreDataSource)
        }

        // Batch save in background context
        try await persistenceController.performBackgroundTask { context in
            for (healthReading, coreDataSource) in readingsWithMappedSources {
                let reading = GlucoseReading(context: context)
                reading.id = healthReading.id
                reading.timestamp = healthReading.timestamp
                reading.value = healthReading.value
                reading.source = coreDataSource
                reading.deviceName = healthReading.device
                reading.syncStatus = "synced"
            }

            try context.save()
        }

        logger.info("✅ Batch saved \(count) glucose readings")
        return count
    }

    // MARK: - Deduplication

    /// Check if a reading with the same timestamp and source already exists
    /// - Parameters:
    ///   - timestamp: Reading timestamp
    ///   - source: Reading source (e.g., "dexcom_share", "healthkit")
    /// - Returns: True if duplicate exists
    func isDuplicate(timestamp: Date, source: String) async throws -> Bool {
        let request = GlucoseReading.fetchRequest()

        // Match within 1 second window to account for minor timestamp differences
        let startDate = timestamp.addingTimeInterval(-1)
        let endDate = timestamp.addingTimeInterval(1)

        request.predicate = NSPredicate(
            format: "timestamp >= %@ AND timestamp <= %@ AND source == %@",
            startDate as NSDate,
            endDate as NSDate,
            source
        )
        request.fetchLimit = 1

        let results = try await persistenceController.fetch(request)
        return !results.isEmpty
    }

    // MARK: - Fetch Operations

    /// Fetch glucose readings for a specific time range
    /// - Parameters:
    ///   - startDate: Start of time range
    ///   - endDate: End of time range
    ///   - source: Optional source filter
    /// - Returns: Array of GlucoseReading entities
    func fetchReadings(
        startDate: Date,
        endDate: Date,
        source: String? = nil
    ) async throws -> [GlucoseReading] {
        let request = GlucoseReading.fetchRequest()

        var predicates: [NSPredicate] = [
            NSPredicate(
                format: "timestamp >= %@ AND timestamp <= %@",
                startDate as NSDate,
                endDate as NSDate
            )
        ]

        if let source = source {
            predicates.append(NSPredicate(format: "source == %@", source))
        }

        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]

        let readings = try await persistenceController.fetch(request)
        logger.debug("Fetched \(readings.count) glucose readings from \(startDate) to \(endDate)")
        return readings
    }

    /// Fetch the most recent glucose reading
    /// - Parameter source: Optional source filter
    /// - Returns: Most recent GlucoseReading, or nil if none exist
    func fetchLatestReading(source: String? = nil) async throws -> GlucoseReading? {
        let request = GlucoseReading.fetchRequest()

        if let source = source {
            request.predicate = NSPredicate(format: "source == %@", source)
        }

        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        request.fetchLimit = 1

        let readings = try await persistenceController.fetch(request)
        return readings.first
    }

    /// Fetch all glucose readings count for statistics
    /// - Returns: Total count of stored readings
    func fetchReadingsCount() async throws -> Int {
        let request = GlucoseReading.fetchRequest()
        request.includesSubentities = false
        request.includesPropertyValues = false
        let results = try await persistenceController.fetch(request)
        return results.count
    }

    // MARK: - Cleanup Operations

    /// Delete old glucose readings to manage storage
    /// - Parameter date: Delete readings older than this date
    /// - Returns: Count of deleted readings
    @discardableResult
    func deleteOldReadings(olderThan date: Date) async throws -> Int {
        logger.info("Deleting glucose readings older than \(date)...")

        let request = GlucoseReading.fetchRequest()
        request.predicate = NSPredicate(format: "timestamp < %@", date as NSDate)

        let readingsToDelete = try await persistenceController.fetch(request)
        let count = readingsToDelete.count

        guard count > 0 else {
            logger.debug("No old readings to delete")
            return 0
        }

        try await persistenceController.performBackgroundTask { context in
            for reading in readingsToDelete {
                // Get object in this context
                if let objectToDelete = try? context.existingObject(with: reading.objectID) {
                    context.delete(objectToDelete)
                }
            }
            try context.save()
        }

        logger.info("✅ Deleted \(count) old glucose readings")
        return count
    }

    /// Delete all glucose readings from a specific source
    /// - Parameter source: Source identifier
    /// - Returns: Count of deleted readings
    @discardableResult
    func deleteReadings(fromSource source: String) async throws -> Int {
        logger.info("Deleting all readings from source: \(source)")

        let request = GlucoseReading.fetchRequest()
        request.predicate = NSPredicate(format: "source == %@", source)

        let readingsToDelete = try await persistenceController.fetch(request)
        let count = readingsToDelete.count

        guard count > 0 else {
            logger.debug("No readings found for source: \(source)")
            return 0
        }

        try await persistenceController.performBackgroundTask { context in
            for reading in readingsToDelete {
                if let objectToDelete = try? context.existingObject(with: reading.objectID) {
                    context.delete(objectToDelete)
                }
            }
            try context.save()
        }

        logger.info("✅ Deleted \(count) readings from source: \(source)")
        return count
    }
}

// MARK: - Source Mapping

extension GlucoseReadingRepository {
    /// Map bundle identifier or source string to CoreData GlucoseSource enum value
    /// This prevents conflicts between Dexcom Official API and SHARE API
    /// - Parameter bundleId: Bundle identifier or source string from HealthGlucoseReading
    /// - Returns: CoreData source enum raw value
    func mapSourceToCoreData(_ bundleId: String?) -> String {
        guard let bundleId = bundleId else {
            return GlucoseSource.manual.rawValue
        }

        // Map bundle identifiers to specific source types
        switch bundleId {
        case "com.dexcom.cgm":
            // Official Dexcom API
            return GlucoseSource.dexcomOfficial.rawValue

        case "com.dexcom.share":
            // Dexcom SHARE API (unofficial, real-time)
            return GlucoseSource.dexcomShare.rawValue

        case "com.apple.health", "healthkit":
            // HealthKit
            return GlucoseSource.healthKit.rawValue

        case "manual", "unknown":
            // Manual entry
            return GlucoseSource.manual.rawValue

        case "cgm", "dexcom":
            // Legacy - default to official API
            return GlucoseSource.dexcomOfficial.rawValue

        default:
            // Unknown source - log and treat as manual
            logger.warning("Unknown source bundle ID: '\(bundleId)' - treating as manual")
            return GlucoseSource.manual.rawValue
        }
    }
}

// MARK: - Validation

extension GlucoseReadingRepository {
    /// Physiological glucose range limits (mg/dL)
    static let minPhysiologicalGlucose: Double = 40.0
    static let maxPhysiologicalGlucose: Double = 400.0

    /// Validate glucose reading is within physiological range
    /// - Parameter value: Glucose value in mg/dL
    /// - Returns: True if valid, false if out of range
    func isValidGlucoseValue(_ value: Double) -> Bool {
        return value >= Self.minPhysiologicalGlucose &&
               value <= Self.maxPhysiologicalGlucose
    }

    /// Validate glucose reading is not in future
    /// - Parameter timestamp: Reading timestamp
    /// - Returns: True if timestamp is not in future
    func isValidTimestamp(_ timestamp: Date) -> Bool {
        return timestamp <= Date()
    }
}

// MARK: - Convenience Extensions

extension GlucoseReadingRepository {
    /// Recommended retention period for glucose readings (180 days)
    static let defaultRetentionDays = 180

    /// Clean up readings older than retention period
    func cleanupOldReadings() async throws {
        let cutoffDate = Calendar.current.date(
            byAdding: .day,
            value: -Self.defaultRetentionDays,
            to: Date()
        ) ?? Date()

        try await deleteOldReadings(olderThan: cutoffDate)
    }
}
