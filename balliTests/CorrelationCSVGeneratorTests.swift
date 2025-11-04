//
//  CorrelationCSVGeneratorTests.swift
//  balliTests
//
//  Tests for Correlation CSV generation
//

import XCTest
@testable import balli

final class CorrelationCSVGeneratorTests: XCTestCase {

    var generator: CorrelationCSVGenerator!

    override func setUp() {
        generator = CorrelationCSVGenerator()
    }

    // MARK: - Generation Tests

    func testGenerate_EmptyEvents() throws {
        // Given
        let events: [MealEvent] = []
        let dateRange = DateInterval(start: Date().addingTimeInterval(-86400), end: Date())

        // When
        let data = try generator.generate(mealEvents: events, dateRange: dateRange)

        // Then
        XCTAssertFalse(data.isEmpty, "Should generate header even with no events")

        let csv = String(data: data, encoding: .utf8)!
        let lines = csv.components(separatedBy: "\n")

        XCTAssertEqual(lines.count, 2, "Should have header + empty line")
        XCTAssertTrue(lines[0].contains("timestamp"), "Header should contain timestamp")
        XCTAssertTrue(lines[0].contains("carbs_g"), "Header should contain carbs_g")
        XCTAssertTrue(lines[0].contains("glucose_before_mg_dl"), "Header should contain glucose")
    }

    func testGenerate_SingleEvent() throws {
        // Given
        let event = createTestMealEvent()
        let dateRange = DateInterval(start: Date().addingTimeInterval(-86400), end: Date())

        // When
        let data = try generator.generate(mealEvents: [event], dateRange: dateRange)

        // Then
        let csv = String(data: data, encoding: .utf8)!
        let lines = csv.components(separatedBy: "\n").filter { !$0.isEmpty }

        XCTAssertEqual(lines.count, 2, "Should have header + 1 data row")

        // Verify data row contains expected values
        let dataRow = lines[1]
        XCTAssertTrue(dataRow.contains("breakfast"), "Should contain meal type")
        XCTAssertTrue(dataRow.contains("50.0"), "Should contain carbs value")
    }

    func testGenerate_CSVFormat() throws {
        // Given
        let event = createTestMealEvent()
        let dateRange = DateInterval(start: Date().addingTimeInterval(-86400), end: Date())

        // When
        let data = try generator.generate(mealEvents: [event], dateRange: dateRange)

        // Then
        let csv = String(data: data, encoding: .utf8)!
        let lines = csv.components(separatedBy: "\n").filter { !$0.isEmpty }

        // Verify header structure
        let header = lines[0]
        let headerFields = header.components(separatedBy: ",")

        // Should have 40+ columns
        XCTAssertGreaterThanOrEqual(headerFields.count, 40, "Should have comprehensive column set")

        // Verify key columns exist
        XCTAssertTrue(headerFields.contains("timestamp"))
        XCTAssertTrue(headerFields.contains("meal_type"))
        XCTAssertTrue(headerFields.contains("carbs_g"))
        XCTAssertTrue(headerFields.contains("glucose_before_mg_dl"))
        XCTAssertTrue(headerFields.contains("steps_2h_before"))
    }

    func testGenerate_HandlesSpecialCharacters() throws {
        // Given - Event with notes containing comma and quotes
        var event = createTestMealEvent()
        event = MealEvent(
            timestamp: event.timestamp,
            mealType: event.mealType,
            carbs: event.carbs,
            protein: event.protein,
            fat: event.fat,
            calories: event.calories,
            bolusInsulin: event.bolusInsulin,
            basalRate: event.basalRate,
            glucoseBefore: event.glucoseBefore,
            glucoseResponse: event.glucoseResponse,
            activityContext: event.activityContext,
            mealName: "Breakfast, with \"special\" items",
            foods: event.foods,
            notes: "Contains, comma and \"quotes\"",
            photo: event.photo,
            source: event.source,
            confidence: event.confidence
        )

        let dateRange = DateInterval(start: Date().addingTimeInterval(-86400), end: Date())

        // When
        let data = try generator.generate(mealEvents: [event], dateRange: dateRange)

        // Then - Should not crash and should properly escape
        XCTAssertFalse(data.isEmpty)

        let csv = String(data: data, encoding: .utf8)!
        // Escaped values should be in quotes
        XCTAssertTrue(csv.contains("\"Breakfast, with \"\"special\"\" items\""))
        XCTAssertTrue(csv.contains("\"Contains, comma and \"\"quotes\"\"\""))
    }

    // MARK: - Helper Methods

    private func createTestMealEvent() -> MealEvent {
        let glucoseResponse = GlucoseResponse(
            baseline: 100,
            peak: 150,
            peakTime: Date().addingTimeInterval(3600),
            peakMinutesFromMeal: 60,
            change1h: 40,
            change2h: 30,
            change3h: 10,
            readings: [],
            auc: 120.5,
            timeToBaseline: 150
        )

        let activityContext = ActivityContext(
            steps2hBefore: 1000,
            steps2hAfter: 1500,
            activeCalories: 200,
            totalCalories: 250,
            exerciseMinutes: 30,
            distance: 2000.0,
            date: Date(),
            source: "apple_health"
        )

        return MealEvent(
            timestamp: Date(),
            mealType: "breakfast",
            carbs: 50.0,
            protein: 20.0,
            fat: 15.0,
            calories: 400.0,
            bolusInsulin: 5.0,
            basalRate: 1.0,
            glucoseBefore: 100.0,
            glucoseResponse: glucoseResponse,
            activityContext: activityContext,
            mealName: "Test Breakfast",
            foods: ["Eggs", "Toast"],
            notes: "Test meal",
            photo: nil,
            source: "manual",
            confidence: nil
        )
    }
}
