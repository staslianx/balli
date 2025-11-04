//
//  ExportDataRepositoryTests.swift
//  balliTests
//
//  Tests for ExportDataRepository data access layer
//

import XCTest
@testable import balli
import CoreData

@MainActor
final class ExportDataRepositoryTests: XCTestCase {

    var repository: ExportDataRepository!
    var testContext: NSManagedObjectContext!

    override func setUp() async throws {
        // Create in-memory Core Data stack for testing
        let container = NSPersistentContainer(name: "balli")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]

        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Failed to load test store: \(error)")
            }
        }

        testContext = container.viewContext
        repository = ExportDataRepository(viewContext: testContext)
    }

    override func tearDown() async throws {
        testContext = nil
        repository = nil
    }

    // MARK: - Meal Data Tests

    func testFetchMeals_ReturnsCorrectCount() async throws {
        // Given - Create 3 meals
        let meal1 = createTestMeal(timestamp: Date().addingTimeInterval(-3600))
        let meal2 = createTestMeal(timestamp: Date().addingTimeInterval(-7200))
        let meal3 = createTestMeal(timestamp: Date().addingTimeInterval(-10800))

        try testContext.save()

        // When
        let startDate = Date().addingTimeInterval(-14400) // 4 hours ago
        let endDate = Date()
        let dateRange = DateInterval(start: startDate, end: endDate)

        let meals = try await repository.fetchMeals(in: dateRange)

        // Then
        XCTAssertEqual(meals.count, 3, "Should fetch all 3 meals")
        XCTAssertTrue(meals.contains(meal1))
        XCTAssertTrue(meals.contains(meal2))
        XCTAssertTrue(meals.contains(meal3))
    }

    func testFetchMeals_FiltersDateRange() async throws {
        // Given - Create meals outside range
        _ = createTestMeal(timestamp: Date().addingTimeInterval(-86400)) // 1 day ago
        let recentMeal = createTestMeal(timestamp: Date().addingTimeInterval(-3600)) // 1 hour ago

        try testContext.save()

        // When - Query last 2 hours
        let startDate = Date().addingTimeInterval(-7200)
        let endDate = Date()
        let dateRange = DateInterval(start: startDate, end: endDate)

        let meals = try await repository.fetchMeals(in: dateRange)

        // Then
        XCTAssertEqual(meals.count, 1, "Should only fetch recent meal")
        XCTAssertEqual(meals.first, recentMeal)
    }

    func testCountMeals() async throws {
        // Given
        _ = createTestMeal(timestamp: Date().addingTimeInterval(-3600))
        _ = createTestMeal(timestamp: Date().addingTimeInterval(-7200))

        try testContext.save()

        // When
        let dateRange = DateInterval(start: Date().addingTimeInterval(-14400), end: Date())
        let count = try await repository.countMeals(in: dateRange)

        // Then
        XCTAssertEqual(count, 2)
    }

    // MARK: - Glucose Data Tests

    func testFetchGlucoseReadings() async throws {
        // Given
        let reading1 = createTestGlucoseReading(timestamp: Date().addingTimeInterval(-1800), value: 120)
        let reading2 = createTestGlucoseReading(timestamp: Date().addingTimeInterval(-3600), value: 140)

        try testContext.save()

        // When
        let dateRange = DateInterval(start: Date().addingTimeInterval(-7200), end: Date())
        let readings = try await repository.fetchGlucoseReadings(in: dateRange)

        // Then
        XCTAssertEqual(readings.count, 2)
        XCTAssertTrue(readings.contains(reading1))
        XCTAssertTrue(readings.contains(reading2))
    }

    func testFetchGlucoseReadings_AroundMeal() async throws {
        // Given - Meal at T=0
        let mealTime = Date()

        // Readings: -30min, +30min, +60min, +120min
        let beforeReading = createTestGlucoseReading(timestamp: mealTime.addingTimeInterval(-1800), value: 100)
        let after30 = createTestGlucoseReading(timestamp: mealTime.addingTimeInterval(1800), value: 150)
        let after60 = createTestGlucoseReading(timestamp: mealTime.addingTimeInterval(3600), value: 160)
        let after120 = createTestGlucoseReading(timestamp: mealTime.addingTimeInterval(7200), value: 130)

        try testContext.save()

        // When - Fetch 30min before, 180min after
        let readings = try await repository.fetchGlucoseReadings(
            around: mealTime,
            minutesBefore: 30,
            minutesAfter: 180
        )

        // Then
        XCTAssertEqual(readings.count, 4)
        XCTAssertTrue(readings.contains(beforeReading))
        XCTAssertTrue(readings.contains(after30))
        XCTAssertTrue(readings.contains(after60))
        XCTAssertTrue(readings.contains(after120))
    }

    // MARK: - Validation Tests

    func testValidateDataAvailability_WithData() async throws {
        // Given
        _ = createTestMeal(timestamp: Date().addingTimeInterval(-3600))
        _ = createTestGlucoseReading(timestamp: Date().addingTimeInterval(-3600), value: 120)

        try testContext.save()

        // When
        let dateRange = DateInterval(start: Date().addingTimeInterval(-7200), end: Date())
        let result = try await repository.validateDataAvailability(in: dateRange)

        // Then
        XCTAssertTrue(result.hasData)
        XCTAssertEqual(result.mealCount, 1)
        XCTAssertEqual(result.glucoseCount, 1)
    }

    func testValidateDataAvailability_NoData() async throws {
        // When - Empty database
        let dateRange = DateInterval(start: Date().addingTimeInterval(-7200), end: Date())
        let result = try await repository.validateDataAvailability(in: dateRange)

        // Then
        XCTAssertFalse(result.hasData)
        XCTAssertEqual(result.mealCount, 0)
        XCTAssertEqual(result.glucoseCount, 0)
    }

    func testValidateDateRange_Valid() async throws {
        // Given
        let start = Date().addingTimeInterval(-86400) // 1 day ago
        let end = Date()
        let dateRange = DateInterval(start: start, end: end)

        // When/Then - Should not throw
        try await repository.validateDateRange(dateRange)
    }

    func testValidateDateRange_InvalidOrder() async throws {
        // Given - End before start
        let start = Date()
        let end = Date().addingTimeInterval(-86400)
        let dateRange = DateInterval(start: start, end: end)

        // When/Then
        do {
            try await repository.validateDateRange(dateRange)
            XCTFail("Should throw invalidDateRange error")
        } catch let error as ExportError {
            XCTAssertEqual(error, .invalidDateRange)
        }
    }

    func testValidateDateRange_FutureDate() async throws {
        // Given
        let start = Date()
        let end = Date().addingTimeInterval(86400) // Tomorrow
        let dateRange = DateInterval(start: start, end: end)

        // When/Then
        do {
            try await repository.validateDateRange(dateRange)
            XCTFail("Should throw futureDate error")
        } catch let error as ExportError {
            XCTAssertEqual(error, .futureDate)
        }
    }

    func testValidateDateRange_TooLarge() async throws {
        // Given - 400 days (max is 365)
        let start = Date().addingTimeInterval(-400 * 86400)
        let end = Date()
        let dateRange = DateInterval(start: start, end: end)

        // When/Then
        do {
            try await repository.validateDateRange(dateRange)
            XCTFail("Should throw dateRangeTooLarge error")
        } catch let error as ExportError {
            if case .dateRangeTooLarge(let days, let maximum) = error {
                XCTAssertEqual(maximum, 365)
                XCTAssertGreaterThanOrEqual(days, 400)
            } else {
                XCTFail("Wrong error type")
            }
        }
    }

    // MARK: - Helper Methods

    private func createTestMeal(timestamp: Date) -> MealEntry {
        let meal = MealEntry(context: testContext)
        meal.id = UUID()
        meal.timestamp = timestamp
        meal.mealType = "breakfast"
        meal.consumedCarbs = 50.0
        meal.consumedProtein = 20.0
        meal.consumedFat = 15.0
        meal.consumedCalories = 400.0
        meal.firestoreSyncStatus = "synced"
        return meal
    }

    private func createTestGlucoseReading(timestamp: Date, value: Double) -> GlucoseReading {
        let reading = GlucoseReading(context: testContext)
        reading.id = UUID()
        reading.timestamp = timestamp
        reading.value = value
        reading.source = "test"
        return reading
    }
}
