//
//  HealthKitServiceRefactored.swift
//  balli
//
//  Refactored HealthKit service coordinating specialized sub-services
//  Swift 6 strict concurrency compliant
//

import Foundation
import HealthKit
import OSLog

// MARK: - Refactored HealthKit Service Implementation

actor HealthKitServiceRefactored: HealthKitServiceProtocol {
    // MARK: - Properties

    private let healthStore: HKHealthStore
    private let logger = AppLoggers.Health.glucose

    // Specialized services
    private let authManager: HealthKitAuthorizationManager
    private let glucoseService: HealthKitGlucoseService
    private let nutritionService: HealthKitNutritionService
    private let activityService: HealthKitActivityService

    // MARK: - Initialization

    init() {
        guard HKHealthStore.isHealthDataAvailable() else {
            logger.error("HealthKit is not available on this device")
            self.healthStore = HKHealthStore()
            // Initialize services even if not available for graceful degradation
            self.authManager = HealthKitAuthorizationManager(healthStore: HKHealthStore())
            self.glucoseService = HealthKitGlucoseService(
                healthStore: HKHealthStore(),
                authManager: authManager
            )
            self.nutritionService = HealthKitNutritionService(
                healthStore: HKHealthStore(),
                authManager: authManager
            )
            self.activityService = HealthKitActivityService(
                healthStore: HKHealthStore(),
                authManager: authManager
            )
            return
        }

        self.healthStore = HKHealthStore()

        // Initialize specialized services
        self.authManager = HealthKitAuthorizationManager(healthStore: healthStore)
        self.glucoseService = HealthKitGlucoseService(
            healthStore: healthStore,
            authManager: authManager
        )
        self.nutritionService = HealthKitNutritionService(
            healthStore: healthStore,
            authManager: authManager
        )
        self.activityService = HealthKitActivityService(
            healthStore: healthStore,
            authManager: authManager
        )

        logger.info("✅ HealthKit services initialized")
    }

    // MARK: - Authorization (Delegate to AuthManager)

    func requestAuthorization() async throws -> Bool {
        let result = try await authManager.requestAuthorization()

        // Setup background delivery after authorization
        if result {
            await glucoseService.setupBackgroundDelivery()
        }

        return result
    }

    func isAuthorized(for type: HKQuantityType? = nil) async -> Bool {
        return await authManager.isAuthorized(for: type)
    }

    // MARK: - Glucose Data (Delegate to GlucoseService)

    func getGlucoseReadings(from startDate: Date, to endDate: Date, limit: Int) async throws -> [HealthGlucoseReading] {
        return try await glucoseService.getGlucoseReadings(from: startDate, to: endDate, limit: limit)
    }

    func saveGlucoseReading(_ reading: HealthGlucoseReading) async throws {
        try await glucoseService.saveGlucoseReading(reading)
    }

    // MARK: - Nutrition Data (Delegate to NutritionService)

    func getNutritionData(from startDate: Date, to endDate: Date) async throws -> [HealthNutritionEntry] {
        return try await nutritionService.getNutritionData(from: startDate, to: endDate)
    }

    func saveNutritionData(_ nutrition: HealthNutritionEntry) async throws {
        try await nutritionService.saveNutritionData(nutrition)
    }

    // MARK: - Workout Data (Delegate to ActivityService)

    func getWorkoutData(from startDate: Date, to endDate: Date) async throws -> [HealthWorkoutEntry] {
        return try await activityService.getWorkoutData(from: startDate, to: endDate)
    }

    // MARK: - Activity Data (Delegate to ActivityService)

    /// Get activity data (steps and calories) with built-in debouncing
    func getActivityData(from startDate: Date, to endDate: Date) async throws -> (steps: Double, calories: Double) {
        return try await activityService.getActivityData(from: startDate, to: endDate)
    }

    /// Get steps data for a specific time range
    func getSteps(from startDate: Date, to endDate: Date) async throws -> Double {
        return try await activityService.getSteps(from: startDate, to: endDate)
    }

    /// Get active calories for a specific time range
    func getActiveCalories(from startDate: Date, to endDate: Date) async throws -> Double {
        return try await activityService.getActiveCalories(from: startDate, to: endDate)
    }

    // MARK: - Statistics (Delegate to GlucoseService)

    func getGlucoseStatistics(for dateInterval: DateInterval) async throws -> GlucoseStatistics {
        return try await glucoseService.getGlucoseStatistics(for: dateInterval)
    }

    func analyzeGlucosePatterns(mealTime: Date, windowHours: Int = 4) async throws -> GlucosePattern {
        return try await glucoseService.analyzeGlucosePatterns(mealTime: mealTime, windowHours: windowHours)
    }
}

// MARK: - Type Alias for Backward Compatibility

/// Backward compatibility: existing code can continue using HealthKitService
typealias HealthKitService = HealthKitServiceRefactored
