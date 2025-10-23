//
//  HealthKitActivityService.swift
//  balli
//
//  Handles activity and workout data queries from HealthKit
//  Swift 6 strict concurrency compliant
//

import Foundation
import HealthKit
import OSLog

// MARK: - Activity Service

actor HealthKitActivityService {
    // MARK: - Properties

    private let healthStore: HKHealthStore
    private let authManager: HealthKitAuthorizationManager
    private let logger = AppLoggers.Health.glucose

    // Activity data types
    private let stepsType = HKQuantityType(.stepCount)
    private let activeCaloriesType = HKQuantityType(.activeEnergyBurned)

    // Actor-isolated throttling for rate limiting
    private var lastActivityLoadTime: Date?
    private let activityLoadThrottleInterval: TimeInterval = 5

    // MARK: - Initialization

    init(healthStore: HKHealthStore, authManager: HealthKitAuthorizationManager) {
        self.healthStore = healthStore
        self.authManager = authManager
    }

    // MARK: - Activity Data Queries

    /// Actor-isolated method to get activity data (steps and calories) with throttling
    func getActivityData(from startDate: Date, to endDate: Date) async throws -> (steps: Double, calories: Double) {
        // Simple throttling: check time since last load
        if let lastLoad = lastActivityLoadTime {
            let timeSinceLastLoad = Date().timeIntervalSince(lastLoad)
            if timeSinceLastLoad < self.activityLoadThrottleInterval {
                logger.debug("Activity fetch throttled - \(String(format: "%.1f", self.activityLoadThrottleInterval - timeSinceLastLoad))s remaining")
                throw HealthKitError.debounced(remainingTime: self.activityLoadThrottleInterval - timeSinceLastLoad)
            }
        }

        // Update last load time and execute
        lastActivityLoadTime = Date()
        logger.info("Fetching activity data from \(startDate) to \(endDate)")

        // Fetch steps and calories in parallel
        async let stepsTask = getSteps(from: startDate, to: endDate)
        async let caloriesTask = getActiveCalories(from: startDate, to: endDate)

        let steps = try await stepsTask
        let calories = try await caloriesTask

        return (steps, calories)
    }

    func getSteps(from startDate: Date, to endDate: Date) async throws -> Double {
        logger.info("Fetching steps from \(startDate) to \(endDate)")

        guard await authManager.isAuthorized(for: stepsType) else {
            throw HealthKitError.notAuthorized
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: stepsType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, error in
                if let error = error {
                    self.logger.error("Failed to fetch steps: \(error.localizedDescription)")
                    continuation.resume(throwing: HealthKitError.queryFailed(error))
                    return
                }

                let steps = result?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                self.logger.info("Retrieved \(steps) steps")
                continuation.resume(returning: steps)
            }

            healthStore.execute(query)
        }
    }

    func getActiveCalories(from startDate: Date, to endDate: Date) async throws -> Double {
        logger.info("Fetching active calories from \(startDate) to \(endDate)")

        guard await authManager.isAuthorized(for: activeCaloriesType) else {
            throw HealthKitError.notAuthorized
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: activeCaloriesType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, error in
                if let error = error {
                    // "No data available" is a normal state, not an error - treat as 0 calories
                    let errorDescription = error.localizedDescription
                    if errorDescription.contains("No data available") || errorDescription.contains("no data") {
                        self.logger.info("No active calories data available for this period (treating as 0)")
                        continuation.resume(returning: 0)
                    } else {
                        // Only throw for actual errors, not empty data
                        self.logger.error("Failed to fetch active calories: \(errorDescription)")
                        continuation.resume(throwing: HealthKitError.queryFailed(error))
                    }
                    return
                }

                let calories = result?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
                self.logger.info("Retrieved \(calories) kcal")
                continuation.resume(returning: calories)
            }

            healthStore.execute(query)
        }
    }

    // MARK: - Workout Data

    func getWorkoutData(from startDate: Date, to endDate: Date) async throws -> [HealthWorkoutEntry] {
        logger.info("Fetching workout data from \(startDate) to \(endDate)")

        guard await authManager.isAuthorized() else {
            throw HealthKitError.notAuthorized
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
            ) { _, samples, error in
                Task {
                    if let error = error {
                        self.logger.error("Failed to fetch workouts: \(error.localizedDescription)")
                        continuation.resume(throwing: HealthKitError.queryFailed(error))
                        return
                    }

                    guard let workouts = samples as? [HKWorkout] else {
                        continuation.resume(returning: [])
                        return
                    }

                    let entries = workouts.map { workout in
                        // Use statistics for iOS 18+ to avoid deprecation warning
                        let energyBurned: Double?
                        if #available(iOS 18.0, *) {
                            energyBurned = workout.statistics(for: HKQuantityType(.activeEnergyBurned))?.sumQuantity()?.doubleValue(for: .kilocalorie())
                        } else {
                            energyBurned = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie())
                        }

                        return HealthWorkoutEntry(
                            workoutType: workout.workoutActivityType,
                            startDate: workout.startDate,
                            endDate: workout.endDate,
                            duration: workout.duration,
                            totalEnergyBurned: energyBurned,
                            distance: workout.totalDistance?.doubleValue(for: .meter())
                        )
                    }

                    self.logger.info("Retrieved \(entries.count) workouts")
                    continuation.resume(returning: entries)
                }
            }

            healthStore.execute(query)
        }
    }
}
