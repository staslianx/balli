//
//  EventJSONGeneratorTests.swift
//  balliTests
//
//  Tests for Event JSON generation
//

import XCTest
@testable import balli

final class EventJSONGeneratorTests: XCTestCase {

    var generator: EventJSONGenerator!

    override func setUp() {
        generator = EventJSONGenerator()
    }

    // MARK: - Generation Tests

    func testGenerate_ValidJSON() throws {
        // Given
        let event = createTestMealEvent()
        let dateRange = DateInterval(start: Date().addingTimeInterval(-86400), end: Date())

        // When
        let data = try generator.generate(mealEvents: [event], dateRange: dateRange)

        // Then
        XCTAssertFalse(data.isEmpty)

        // Verify it's valid JSON
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertNotNil(json, "Should be valid JSON")

        // Verify structure
        XCTAssertNotNil(json?["metadata"], "Should have metadata")
        XCTAssertNotNil(json?["events"], "Should have events array")
    }

    func testGenerate_MetadataStructure() throws {
        // Given
        let events = [createTestMealEvent()]
        let startDate = Date().addingTimeInterval(-86400)
        let endDate = Date()
        let dateRange = DateInterval(start: startDate, end: endDate)

        // When
        let data = try generator.generate(mealEvents: events, dateRange: dateRange)

        // Then
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let metadata = json["metadata"] as! [String: Any]

        XCTAssertEqual(metadata["format"] as? String, "event_json")
        XCTAssertEqual(metadata["version"] as? String, "1.0")
        XCTAssertEqual(metadata["eventCount"] as? Int, 1)
        XCTAssertNotNil(metadata["exportDate"])
        XCTAssertNotNil(metadata["startDate"])
        XCTAssertNotNil(metadata["endDate"])
    }

    func testGenerate_EventsArray() throws {
        // Given
        let event1 = createTestMealEvent()
        let event2 = createTestMealEvent()
        let dateRange = DateInterval(start: Date().addingTimeInterval(-86400), end: Date())

        // When
        let data = try generator.generate(mealEvents: [event1, event2], dateRange: dateRange)

        // Then
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let events = json["events"] as! [[String: Any]]

        XCTAssertEqual(events.count, 2, "Should have 2 events")

        // Verify event structure
        let firstEvent = events[0]
        XCTAssertNotNil(firstEvent["timestamp"])
        XCTAssertNotNil(firstEvent["mealType"])
        XCTAssertNotNil(firstEvent["carbs"])
        XCTAssertNotNil(firstEvent["glucoseResponse"])
        XCTAssertNotNil(firstEvent["activityContext"])
    }

    func testGenerate_ISO8601Dates() throws {
        // Given
        let event = createTestMealEvent()
        let dateRange = DateInterval(start: Date().addingTimeInterval(-86400), end: Date())

        // When
        let data = try generator.generate(mealEvents: [event], dateRange: dateRange)

        // Then
        let jsonString = String(data: data, encoding: .utf8)!

        // ISO8601 dates should be in format: "2025-01-04T12:34:56Z"
        let iso8601Pattern = "\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}Z"
        let regex = try NSRegularExpression(pattern: iso8601Pattern)
        let matches = regex.matches(in: jsonString, range: NSRange(jsonString.startIndex..., in: jsonString))

        XCTAssertGreaterThan(matches.count, 0, "Should contain ISO8601 formatted dates")
    }

    func testGenerate_PrettyPrinted() throws {
        // Given
        let event = createTestMealEvent()
        let dateRange = DateInterval(start: Date().addingTimeInterval(-86400), end: Date())

        // When
        let data = try generator.generate(mealEvents: [event], dateRange: dateRange)

        // Then
        let jsonString = String(data: data, encoding: .utf8)!

        // Pretty printed JSON should have newlines and indentation
        XCTAssertTrue(jsonString.contains("\n"), "Should be pretty printed with newlines")
        XCTAssertTrue(jsonString.contains("  "), "Should have indentation")
    }

    func testGenerate_EmptyEvents() throws {
        // Given
        let dateRange = DateInterval(start: Date().addingTimeInterval(-86400), end: Date())

        // When
        let data = try generator.generate(mealEvents: [], dateRange: dateRange)

        // Then
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let metadata = json["metadata"] as! [String: Any]
        let events = json["events"] as! [[String: Any]]

        XCTAssertEqual(metadata["eventCount"] as? Int, 0)
        XCTAssertEqual(events.count, 0)
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
            readings: [
                GlucosePoint(timestamp: Date(), value: 100, minutesFromMeal: 0),
                GlucosePoint(timestamp: Date().addingTimeInterval(3600), value: 150, minutesFromMeal: 60)
            ],
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
