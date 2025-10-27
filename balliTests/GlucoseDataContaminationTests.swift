//
//  GlucoseDataContaminationTests.swift
//  balliTests
//
//  Comprehensive tests for glucose data deduplication and validation
//  Tests duplicate detection, invalid value rejection, and source-specific handling
//  Focuses on debugging vertical line artifacts and data contamination
//

import XCTest
import CoreData
@testable import balli

/// Test Suite 4: Data Contamination
/// Tests GlucoseReadingRepository deduplication and validation
final class GlucoseDataContaminationTests: XCTestCase {

    var repository: GlucoseReadingRepository!
    var persistenceController: Persistence.PersistenceController!
    var testContext: NSManagedObjectContext!

    override func setUp() async throws {
        // Create in-memory Core Data stack for testing
        persistenceController = Persistence.PersistenceController(inMemory: true)
        testContext = persistenceController.container.viewContext
        repository = GlucoseReadingRepository(persistenceController: persistenceController)
    }

    override func tearDown() async throws {
        // Clean up
        repository = nil
        testContext = nil
        persistenceController = nil
    }

    // MARK: - Duplicate Detection Tests

    func testSaveReading_DetectsDuplicate_WithinOneSecondWindow() async throws {
        // Given: First reading at timestamp T
        let timestamp = Date()
        let firstReading = HealthGlucoseReading(
            id: UUID(),
            value: 120.0,
            timestamp: timestamp,
            device: "Dexcom G7",
            source: "com.dexcom.cgm"
        )

        // Save first reading
        let saved1 = try await repository.saveReading(from: firstReading)
        XCTAssertNotNil(saved1, "First reading should be saved")

        // When: Try to save duplicate at timestamp T + 0.5 seconds (within 1-second window)
        let duplicateTimestamp = timestamp.addingTimeInterval(0.5)
        let duplicateReading = HealthGlucoseReading(
            id: UUID(), // Different ID
            value: 121.0, // Different value
            timestamp: duplicateTimestamp,
            source: "com.dexcom.cgm" // Same source
        )

        let saved2 = try await repository.saveReading(from: duplicateReading)

        // Then: Second reading should be rejected as duplicate
        XCTAssertNil(saved2, "Duplicate reading within 1-second window should be rejected")
    }

    func testSaveReading_AllowsDifferentSources_SameTimestamp() async throws {
        // Given: Reading from Official API
        let timestamp = Date()
        let officialReading = HealthGlucoseReading(
            id: UUID(),
            value: 120.0,
            timestamp: timestamp,
            source: "com.dexcom.cgm" // Official API
        )

        // Save official reading
        let saved1 = try await repository.saveReading(from: officialReading)
        XCTAssertNotNil(saved1, "Official reading should be saved")

        // When: Save reading from Share API at same timestamp
        let shareReading = HealthGlucoseReading(
            id: UUID(),
            value: 120.0,
            timestamp: timestamp,
            source: "com.dexcom.share" // Share API
        )

        let saved2 = try await repository.saveReading(from: shareReading)

        // Then: Share reading should be saved (different source)
        XCTAssertNotNil(saved2, "Reading from different source should be saved")
    }

    func testSaveReading_LogsDuplicateDetection() async throws {
        // Given: First reading
        let timestamp = Date()
        let firstReading = HealthGlucoseReading(
            id: UUID(),
            value: 120.0,
            timestamp: timestamp,
            device: "Dexcom G7",
            source: "com.dexcom.cgm"
        )
        _ = try await repository.saveReading(from: firstReading)

        // When: Try to save duplicate (should trigger forensic log at line 55)
        let duplicateReading = HealthGlucoseReading(
            id: UUID(),
            value: 120.0,
            timestamp: timestamp,
            device: "Dexcom G7",
            source: "com.dexcom.cgm"
        )
        let saved = try await repository.saveReading(from: duplicateReading)

        // Then: Should be rejected with forensic log
        XCTAssertNil(saved, "Duplicate should be rejected")
        // Forensic log to verify:
        // "⚠️ FORENSIC: DUPLICATE DETECTED - reading already exists at <timestamp> from source 'dexcom_official'"
    }

    // MARK: - Invalid Glucose Value Tests

    func testSaveReading_RejectsValueBelowPhysiologicalRange() async throws {
        // Given: Reading with value below 40 mg/dL (physiological minimum)
        let invalidReading = HealthGlucoseReading(
            id: UUID(),
            value: 30.0, // Below minimum
            timestamp: Date(),
            device: "Dexcom G7",
            source: "com.dexcom.cgm"
        )

        // When: Try to save invalid reading
        let saved = try await repository.saveReading(from: invalidReading)

        // Then: Should be rejected
        XCTAssertNil(saved, "Reading below 40 mg/dL should be rejected")
    }

    func testSaveReading_RejectsValueAbovePhysiologicalRange() async throws {
        // Given: Reading with value above 400 mg/dL (physiological maximum)
        let invalidReading = HealthGlucoseReading(
            id: UUID(),
            value: 450.0, // Above maximum
            timestamp: Date(),
            device: "Dexcom G7",
            source: "com.dexcom.cgm"
        )

        // When: Try to save invalid reading
        let saved = try await repository.saveReading(from: invalidReading)

        // Then: Should be rejected
        XCTAssertNil(saved, "Reading above 400 mg/dL should be rejected")
    }

    func testSaveReading_AcceptsValidBoundaryValues() async throws {
        // Given: Readings at physiological boundaries
        let minReading = HealthGlucoseReading(
            id: UUID(),
            value: 40.0, // Minimum valid
            timestamp: Date(),
            device: "Dexcom G7",
            source: "com.dexcom.cgm"
        )

        let maxReading = HealthGlucoseReading(
            id: UUID(),
            value: 400.0, // Maximum valid
            timestamp: Date().addingTimeInterval(10),
            device: "Dexcom G7",
            source: "com.dexcom.cgm"
        )

        // When: Save boundary values
        let savedMin = try await repository.saveReading(from: minReading)
        let savedMax = try await repository.saveReading(from: maxReading)

        // Then: Both should be accepted
        XCTAssertNotNil(savedMin, "40 mg/dL should be accepted")
        XCTAssertNotNil(savedMax, "400 mg/dL should be accepted")
    }

    func testSaveReading_LogsInvalidValue() async throws {
        // Given: Invalid reading (vertical line artifact - value = 0 or negative)
        let artifactReading = HealthGlucoseReading(
            id: UUID(),
            value: 0.0, // Invalid - causes vertical line
            timestamp: Date(),
            device: "Dexcom G7",
            source: "com.dexcom.cgm"
        )

        // When: Try to save invalid reading (should trigger forensic log at line 39)
        let saved = try await repository.saveReading(from: artifactReading)

        // Then: Should be rejected with forensic log
        XCTAssertNil(saved, "Invalid value should be rejected")
        // Forensic log to verify:
        // "⚠️ FORENSIC: Rejecting invalid glucose value: 0.0 mg/dL (out of physiological range 40.0-400.0)"
    }

    // MARK: - Future Timestamp Tests

    func testSaveReading_RejectsFutureTimestamp() async throws {
        // Given: Reading with future timestamp (1 hour from now)
        let futureTimestamp = Date().addingTimeInterval(3600) // 1 hour future
        let futureReading = HealthGlucoseReading(
            id: UUID(),
            value: 120.0,
            timestamp: futureTimestamp,
            device: "Dexcom G7",
            source: "com.dexcom.cgm"
        )

        // When: Try to save future reading
        let saved = try await repository.saveReading(from: futureReading)

        // Then: Should be rejected
        XCTAssertNil(saved, "Reading with future timestamp should be rejected")
    }

    func testSaveReading_LogsFutureTimestamp() async throws {
        // Given: Reading with future timestamp
        let futureTimestamp = Date().addingTimeInterval(3600)
        let futureReading = HealthGlucoseReading(
            id: UUID(),
            value: 120.0,
            timestamp: futureTimestamp,
            device: "Dexcom G7",
            source: "com.dexcom.cgm"
        )

        // When: Try to save (should trigger forensic log at line 45)
        let saved = try await repository.saveReading(from: futureReading)

        // Then: Should be rejected with forensic log
        XCTAssertNil(saved, "Future timestamp should be rejected")
        // Forensic log to verify:
        // "⚠️ FORENSIC: Rejecting reading with future timestamp: <timestamp>"
    }

    // MARK: - Source Mapping Tests

    func testMapSourceToCoreData_OfficialAPI() async {
        // Given: Official Dexcom API bundle ID
        let bundleId = "com.dexcom.cgm"

        // When: Map to CoreData source
        let coreDataSource = await repository.mapSourceToCoreData(bundleId)

        // Then: Should map to dexcom_official
        XCTAssertEqual(coreDataSource, GlucoseSource.dexcomOfficial.rawValue, "Should map to dexcom_official")
    }

    func testMapSourceToCoreData_ShareAPI() async {
        // Given: Dexcom Share API bundle ID
        let bundleId = "com.dexcom.share"

        // When: Map to CoreData source
        let coreDataSource = await repository.mapSourceToCoreData(bundleId)

        // Then: Should map to dexcom_share
        XCTAssertEqual(coreDataSource, GlucoseSource.dexcomShare.rawValue, "Should map to dexcom_share")
    }

    func testMapSourceToCoreData_HealthKit() async {
        // Given: HealthKit bundle ID
        let bundleId = "com.apple.health"

        // When: Map to CoreData source
        let coreDataSource = await repository.mapSourceToCoreData(bundleId)

        // Then: Should map to healthkit
        XCTAssertEqual(coreDataSource, GlucoseSource.healthKit.rawValue, "Should map to healthkit")
    }

    func testMapSourceToCoreData_Manual() async {
        // Given: Manual entry or unknown source
        let bundleId = "manual"

        // When: Map to CoreData source
        let coreDataSource = await repository.mapSourceToCoreData(bundleId)

        // Then: Should map to manual
        XCTAssertEqual(coreDataSource, GlucoseSource.manual.rawValue, "Should map to manual")
    }

    func testMapSourceToCoreData_UnknownSource() async {
        // Given: Unknown bundle ID
        let bundleId = "com.unknown.app"

        // When: Map to CoreData source
        let coreDataSource = await repository.mapSourceToCoreData(bundleId)

        // Then: Should default to manual
        XCTAssertEqual(coreDataSource, GlucoseSource.manual.rawValue, "Unknown source should default to manual")
    }

    // MARK: - Batch Save Tests

    func testSaveReadings_FiltersInvalidValues() async throws {
        // Given: Mix of valid and invalid readings
        let readings = [
            HealthGlucoseReading(id: UUID(), value: 120.0, timestamp: Date(), device: "G7", source: "com.dexcom.cgm"), // Valid
            HealthGlucoseReading(id: UUID(), value: 30.0, timestamp: Date().addingTimeInterval(5), device: "G7", source: "com.dexcom.cgm"), // Invalid - too low
            HealthGlucoseReading(id: UUID(), value: 130.0, timestamp: Date().addingTimeInterval(10), device: "G7", source: "com.dexcom.cgm"), // Valid
            HealthGlucoseReading(id: UUID(), value: 500.0, timestamp: Date().addingTimeInterval(15), device: "G7", source: "com.dexcom.cgm"), // Invalid - too high
        ]

        // When: Batch save
        let savedCount = try await repository.saveReadings(from: readings)

        // Then: Only valid readings should be saved (2 out of 4)
        XCTAssertEqual(savedCount, 2, "Should save only 2 valid readings")
    }

    func testSaveReadings_FiltersDuplicates() async throws {
        // Given: First batch of readings
        let firstBatch = [
            HealthGlucoseReading(id: UUID(), value: 120.0, timestamp: Date(), device: "G7", source: "com.dexcom.cgm"),
            HealthGlucoseReading(id: UUID(), value: 130.0, timestamp: Date().addingTimeInterval(300), device: "G7", source: "com.dexcom.cgm"),
        ]
        _ = try await repository.saveReadings(from: firstBatch)

        // When: Try to save overlapping batch (1 new, 1 duplicate)
        let secondBatch = [
            HealthGlucoseReading(id: UUID(), value: 120.0, timestamp: Date(), device: "G7", source: "com.dexcom.cgm"), // Duplicate
            HealthGlucoseReading(id: UUID(), value: 140.0, timestamp: Date().addingTimeInterval(600), device: "G7", source: "com.dexcom.cgm"), // New
        ]
        let savedCount = try await repository.saveReadings(from: secondBatch)

        // Then: Only new reading should be saved (1 out of 2)
        XCTAssertEqual(savedCount, 1, "Should save only 1 new reading, filtering duplicate")
    }

    func testSaveReadings_AllDuplicates_ReturnsZero() async throws {
        // Given: First batch
        let firstBatch = [
            HealthGlucoseReading(id: UUID(), value: 120.0, timestamp: Date(), device: "G7", source: "com.dexcom.cgm"),
        ]
        _ = try await repository.saveReadings(from: firstBatch)

        // When: Try to save same readings again
        let savedCount = try await repository.saveReadings(from: firstBatch)

        // Then: Should return 0 (all duplicates)
        XCTAssertEqual(savedCount, 0, "Should save 0 readings when all are duplicates")
    }

    // MARK: - Same Reading from Both APIs Tests

    func testSaveReading_BothAPIs_StoresSeparately() async throws {
        // Given: Same glucose reading from Official API
        let timestamp = Date()
        let officialReading = HealthGlucoseReading(
            id: UUID(),
            value: 120.0,
            timestamp: timestamp,
            device: "Dexcom G7",
            source: "com.dexcom.cgm" // Official API
        )
        let savedOfficial = try await repository.saveReading(from: officialReading)
        XCTAssertNotNil(savedOfficial, "Official API reading should be saved")

        // When: Save same reading from Share API
        let shareReading = HealthGlucoseReading(
            id: UUID(),
            value: 120.0,
            timestamp: timestamp,
            device: "Dexcom G7",
            source: "com.dexcom.share" // Share API
        )
        let savedShare = try await repository.saveReading(from: shareReading)

        // Then: Share API reading should also be saved (different source)
        XCTAssertNotNil(savedShare, "Share API reading should be saved separately")

        // And: Both readings should exist in database
        let allReadings = try await repository.fetchReadings(
            startDate: timestamp.addingTimeInterval(-10),
            endDate: timestamp.addingTimeInterval(10)
        )
        XCTAssertEqual(allReadings.count, 2, "Should have 2 readings (one from each source)")
    }

    // MARK: - Forensic Logging Verification Tests

    func testSaveReading_TriggersForensicLogs() async throws {
        // Given: Valid reading
        let reading = HealthGlucoseReading(
            id: UUID(),
            value: 120.0,
            timestamp: Date(),
            device: "Dexcom G7",
            source: "com.dexcom.cgm"
        )

        // When: Save reading (should trigger forensic logs at lines 33-76)
        let saved = try await repository.saveReading(from: reading)

        // Then: Should be saved with forensic logs
        XCTAssertNotNil(saved, "Reading should be saved")
        // Forensic logs to verify:
        // - "🔍 FORENSIC [GlucoseReadingRepository]: saveReading called"
        // - "🔍 FORENSIC: Value: 120.0 mg/dL, Timestamp: <timestamp>, Source: com.dexcom.cgm"
        // - "🔍 FORENSIC: Mapped source 'com.dexcom.cgm' -> 'dexcom_official'"
        // - "✅ FORENSIC: No duplicate found, proceeding to save..."
        // - "✅ FORENSIC: Successfully saved reading: <id> with source 'dexcom_official'"
    }

    // MARK: - Validation Helper Tests

    func testIsValidGlucoseValue_EdgeCases() async {
        // Test boundary values
        let valid40 = await repository.isValidGlucoseValue(40.0)
        XCTAssertTrue(valid40, "40 mg/dL should be valid")

        let valid400 = await repository.isValidGlucoseValue(400.0)
        XCTAssertTrue(valid400, "400 mg/dL should be valid")

        let invalid39 = await repository.isValidGlucoseValue(39.9)
        XCTAssertFalse(invalid39, "39.9 mg/dL should be invalid")

        let invalid400 = await repository.isValidGlucoseValue(400.1)
        XCTAssertFalse(invalid400, "400.1 mg/dL should be invalid")

        let invalidZero = await repository.isValidGlucoseValue(0.0)
        XCTAssertFalse(invalidZero, "0 mg/dL should be invalid (causes vertical line)")

        let invalidNegative = await repository.isValidGlucoseValue(-10.0)
        XCTAssertFalse(invalidNegative, "Negative value should be invalid")
    }

    func testIsValidTimestamp_EdgeCases() async {
        // Test timestamp validation
        let now = Date()
        let past = now.addingTimeInterval(-3600) // 1 hour ago
        let future = now.addingTimeInterval(3600) // 1 hour future

        let validPast = await repository.isValidTimestamp(past)
        XCTAssertTrue(validPast, "Past timestamp should be valid")

        let validNow = await repository.isValidTimestamp(now)
        XCTAssertTrue(validNow, "Current timestamp should be valid")

        let invalidFuture = await repository.isValidTimestamp(future)
        XCTAssertFalse(invalidFuture, "Future timestamp should be invalid")
    }

    // MARK: - Fetch Operations Tests

    func testFetchReadings_FiltersByDateRange() async throws {
        // Given: Readings at different times
        let baseDate = Date()
        let readings = [
            HealthGlucoseReading(id: UUID(), value: 120.0, timestamp: baseDate.addingTimeInterval(-3600), device: "G7", source: "com.dexcom.cgm"), // 1 hour ago
            HealthGlucoseReading(id: UUID(), value: 130.0, timestamp: baseDate.addingTimeInterval(-1800), device: "G7", source: "com.dexcom.cgm"), // 30 min ago
            HealthGlucoseReading(id: UUID(), value: 140.0, timestamp: baseDate, device: "G7", source: "com.dexcom.cgm"), // Now
        ]
        _ = try await repository.saveReadings(from: readings)

        // When: Fetch readings from last 45 minutes
        let startDate = baseDate.addingTimeInterval(-2700) // 45 min ago
        let endDate = baseDate
        let fetchedReadings = try await repository.fetchReadings(startDate: startDate, endDate: endDate)

        // Then: Should get 2 readings (30 min ago and now)
        XCTAssertEqual(fetchedReadings.count, 2, "Should fetch 2 readings within date range")
    }

    func testFetchReadings_FiltersBySource() async throws {
        // Given: Readings from different sources at same time
        let timestamp = Date()
        let readings = [
            HealthGlucoseReading(id: UUID(), value: 120.0, timestamp: timestamp, device: "G7", source: "com.dexcom.cgm"), // Official
            HealthGlucoseReading(id: UUID(), value: 120.0, timestamp: timestamp.addingTimeInterval(1), device: "G7", source: "com.dexcom.share"), // Share
        ]
        _ = try await repository.saveReadings(from: readings)

        // When: Fetch only Official API readings
        let startDate = timestamp.addingTimeInterval(-10)
        let endDate = timestamp.addingTimeInterval(10)
        let officialReadings = try await repository.fetchReadings(
            startDate: startDate,
            endDate: endDate,
            source: GlucoseSource.dexcomOfficial.rawValue
        )

        // Then: Should get only 1 reading (Official API)
        XCTAssertEqual(officialReadings.count, 1, "Should fetch only Official API readings")
        XCTAssertEqual(officialReadings.first?.source, GlucoseSource.dexcomOfficial.rawValue, "Source should be dexcom_official")
    }

    // MARK: - Latest Reading Tests

    func testFetchLatestReading_ReturnsNewest() async throws {
        // Given: Multiple readings at different times
        let baseDate = Date()
        let readings = [
            HealthGlucoseReading(id: UUID(), value: 120.0, timestamp: baseDate.addingTimeInterval(-3600), device: "G7", source: "com.dexcom.cgm"),
            HealthGlucoseReading(id: UUID(), value: 130.0, timestamp: baseDate.addingTimeInterval(-1800), device: "G7", source: "com.dexcom.cgm"),
            HealthGlucoseReading(id: UUID(), value: 140.0, timestamp: baseDate, device: "G7", source: "com.dexcom.cgm"), // Latest
        ]
        _ = try await repository.saveReadings(from: readings)

        // When: Fetch latest reading
        let latest = try await repository.fetchLatestReading()

        // Then: Should get most recent reading
        XCTAssertNotNil(latest, "Should have latest reading")
        XCTAssertEqual(latest?.value, 140.0, "Latest reading should have value 140.0")
    }
}
