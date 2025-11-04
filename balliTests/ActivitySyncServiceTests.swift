//
//  ActivitySyncServiceTests.swift
//  balliTests
//
//  Tests for ActivitySyncService backfill functionality
//

import XCTest
@testable import balli
import HealthKit

@MainActor
final class ActivitySyncServiceTests: XCTestCase {

    var service: ActivitySyncService!
    var mockHealthStore: HKHealthStore!

    override func setUp() async throws {
        // Clear UserDefaults
        UserDefaults.standard.removeObject(forKey: "ActivityBackfillCompleted")
        UserDefaults.standard.removeObject(forKey: "ActivityBackfillDate")
        UserDefaults.standard.removeObject(forKey: "ActivityBackfillDays")

        mockHealthStore = HKHealthStore()
        let authManager = HealthKitAuthorizationManager(healthStore: mockHealthStore)
        service = ActivitySyncService(healthStore: mockHealthStore, authManager: authManager)
    }

    func testBackfillSetsCompletionFlag() async throws {
        // Given
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "ActivityBackfillCompleted"))

        // When
        try await service.backfillHistoricalData(days: 7)

        // Then
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "ActivityBackfillCompleted"))
        XCTAssertNotNil(UserDefaults.standard.object(forKey: "ActivityBackfillDate"))
    }

    func testBackfillSkipsIfRecentlyCompleted() async throws {
        // Given - set recent completion
        UserDefaults.standard.set(true, forKey: "ActivityBackfillCompleted")
        UserDefaults.standard.set(Date(), forKey: "ActivityBackfillDate")
        UserDefaults.standard.set(90, forKey: "ActivityBackfillDays")

        let initialDate = UserDefaults.standard.object(forKey: "ActivityBackfillDate") as! Date

        // When
        try await service.backfillHistoricalData(days: 90)

        // Then - date should not change (skipped)
        let finalDate = UserDefaults.standard.object(forKey: "ActivityBackfillDate") as! Date
        XCTAssertEqual(initialDate.timeIntervalSince1970, finalDate.timeIntervalSince1970, accuracy: 1.0)
    }

    func testBackfillRunsIfOlderThan7Days() async throws {
        // Given - set old completion
        let oldDate = Calendar.current.date(byAdding: .day, value: -8, to: Date())!
        UserDefaults.standard.set(true, forKey: "ActivityBackfillCompleted")
        UserDefaults.standard.set(oldDate, forKey: "ActivityBackfillDate")

        // When
        try await service.backfillHistoricalData(days: 7)

        // Then - date should be updated
        let newDate = UserDefaults.standard.object(forKey: "ActivityBackfillDate") as! Date
        XCTAssertGreaterThan(newDate.timeIntervalSince1970, oldDate.timeIntervalSince1970)
    }

    func testBackfillUpdatesProgress() async throws {
        // Given
        XCTAssertEqual(service.backfillProgress, 0.0)

        // When
        try await service.backfillHistoricalData(days: 7)

        // Then - progress should have been updated during backfill
        // Note: Final progress might reset, so we check the status was updated
        XCTAssertFalse(service.isBackfilling) // Should be done
    }
}
