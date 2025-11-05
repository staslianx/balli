//
//  MealEventBuilder.swift
//  balli
//
//  Builds rich MealEvent objects with glucose response and activity context
//  Swift 6 strict concurrency compliant
//

import Foundation
import CoreData
import OSLog

/// Actor for building MealEvent objects from Core Data entities
/// Assembles meal data with glucose response and activity context
actor MealEventBuilder {
    // MARK: - Properties

    private let repository: ExportDataRepository
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.balli", category: "MealEventBuilder")

    // MARK: - Configuration

    /// Window before meal to look for baseline glucose (minutes)
    private let baselineWindowMinutes = 30

    /// Window after meal to analyze glucose response (minutes)
    private let responseWindowMinutes = 180 // 3 hours

    /// Window around meal to look for insulin entries (minutes)
    private let insulinWindowMinutes = 30

    // MARK: - Initialization

    init(repository: ExportDataRepository) {
        self.repository = repository
    }

    // MARK: - Build Meal Events

    /// Build meal events from date range
    /// - Parameter dateRange: Date interval to query
    /// - Returns: Array of MealEvent objects with glucose and activity context
    func buildMealEvents(in dateRange: DateInterval) async throws -> [MealEvent] {
        logger.info("🏗️ [BUILDER] Building meal events for \(dateRange.start) to \(dateRange.end)")

        // Fetch all meals in range
        let meals = try await repository.fetchMeals(in: dateRange)

        guard !meals.isEmpty else {
            logger.info("ℹ️ [BUILDER] No meals found in date range")
            return []
        }

        logger.info("📊 [BUILDER] Found \(meals.count) meals to process")

        // Build events concurrently
        var events: [MealEvent] = []

        for meal in meals {
            if let event = try await buildMealEvent(from: meal) {
                events.append(event)
            }
        }

        logger.info("✅ [BUILDER] Built \(events.count) meal events")
        return events
    }

    /// Build single meal event from MealEntry
    /// - Parameter meal: MealEntry Core Data object
    /// - Returns: MealEvent with glucose and activity data, or nil if insufficient data
    private func buildMealEvent(from meal: MealEntry) async throws -> MealEvent? {
        let timestamp = meal.timestamp

        logger.debug("🏗️ [BUILDER] Building event for meal at \(timestamp)")

        // 1. Extract meal data
        let mealType = meal.mealType
        let carbs = meal.consumedCarbs
        let protein = meal.consumedProtein
        let fat = meal.consumedFat
        let calories = meal.consumedCalories

        // 2. Find associated insulin
        let insulinEntries = try await repository.fetchInsulinEntries(
            for: timestamp,
            windowMinutes: insulinWindowMinutes
        )

        let bolusInsulin = insulinEntries
            .filter { $0.medicationType == "rapid" || $0.medicationType == "bolus" }
            .reduce(0.0) { $0 + $1.dosage }

        let basalEntries = insulinEntries.filter { $0.medicationType == "basal" || $0.medicationType == "long_acting" }
        let basalRate = basalEntries.first?.dosage

        // 3. Build glucose response
        let glucoseResponse = try await buildGlucoseResponse(for: timestamp)

        // 4. Build activity context
        let activityContext = try await buildActivityContext(for: timestamp)

        // 5. Extract meal details
        let mealName = meal.foodItem?.name
        let foods = meal.foodItem.map { [$0.name] }
        let notes = meal.notes
        let photo = meal.photoData != nil ? "embedded" : nil

        // 6. Determine source
        let source = "manual" // All meals are manual entries or food item selections

        return MealEvent(
            timestamp: timestamp,
            mealType: mealType,
            carbs: carbs,
            protein: protein > 0 ? protein : nil,
            fat: fat > 0 ? fat : nil,
            calories: calories > 0 ? calories : nil,
            bolusInsulin: bolusInsulin > 0 ? bolusInsulin : nil,
            basalRate: basalRate,
            glucoseBefore: glucoseResponse?.baseline,
            glucoseResponse: glucoseResponse,
            activityContext: activityContext,
            mealName: mealName,
            foods: foods,
            notes: notes,
            photo: photo,
            source: source,
            confidence: nil
        )
    }

    // MARK: - Glucose Response Builder

    /// Build glucose response for a meal
    /// - Parameter mealTimestamp: Time of the meal
    /// - Returns: GlucoseResponse or nil if insufficient data
    private func buildGlucoseResponse(for mealTimestamp: Date) async throws -> GlucoseResponse? {
        // Fetch glucose readings in window (30 min before, 180 min after)
        let readings = try await repository.fetchGlucoseReadings(
            around: mealTimestamp,
            minutesBefore: baselineWindowMinutes,
            minutesAfter: responseWindowMinutes
        )

        guard !readings.isEmpty else {
            logger.debug("ℹ️ [BUILDER] No glucose readings found for meal at \(mealTimestamp)")
            return nil
        }

        // Convert to (timestamp, value) tuples
        let glucoseData = readings.map { reading -> (timestamp: Date, value: Double) in
            return (timestamp: reading.timestamp, value: reading.value)
        }

        // Use GlucoseResponse.build to create response
        let response = GlucoseResponse.build(
            mealTimestamp: mealTimestamp,
            readings: glucoseData,
            windowMinutes: responseWindowMinutes
        )

        if response != nil {
            logger.debug("✅ [BUILDER] Built glucose response with \(glucoseData.count) readings")
        } else {
            logger.debug("⚠️ [BUILDER] Insufficient glucose data for response")
        }

        return response
    }

    // MARK: - Activity Context Builder

    /// Build activity context for a meal
    /// - Parameter mealTimestamp: Time of the meal
    /// - Returns: ActivityContext or nil if no data available
    private func buildActivityContext(for mealTimestamp: Date) async throws -> ActivityContext? {
        // Get date for meal (ignoring time)
        let calendar = Calendar.current
        let mealDate = calendar.startOfDay(for: mealTimestamp)

        // Fetch daily activity for that date
        guard let dailyActivity = try await repository.fetchDailyActivity(for: mealDate) else {
            logger.debug("ℹ️ [BUILDER] No activity data for \(mealDate)")
            return ActivityContext.empty(date: mealDate)
        }

        // Use ActivityContext.build to create context
        let context = ActivityContext.build(from: dailyActivity, mealTimestamp: mealTimestamp)

        if context != nil {
            logger.debug("✅ [BUILDER] Built activity context")
        } else {
            logger.debug("⚠️ [BUILDER] Could not build activity context")
        }

        return context
    }

}
