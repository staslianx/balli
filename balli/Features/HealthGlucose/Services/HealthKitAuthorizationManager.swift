//
//  HealthKitAuthorizationManager.swift
//  balli
//
//  Manages HealthKit authorization and permissions
//  Swift 6 strict concurrency compliant
//

import Foundation
import HealthKit
import OSLog

// MARK: - Authorization Manager

actor HealthKitAuthorizationManager {
    // MARK: - Properties

    private let healthStore: HKHealthStore
    private let logger = AppLoggers.Health.glucose
    private var authorizationStatus: HKAuthorizationStatus = .notDetermined

    // Data types we request permission for
    private let glucoseType = HKQuantityType(.bloodGlucose)
    private let carbsType = HKQuantityType(.dietaryCarbohydrates)
    private let caloriesType = HKQuantityType(.dietaryEnergyConsumed)
    private let proteinType = HKQuantityType(.dietaryProtein)
    private let fatType = HKQuantityType(.dietaryFatTotal)
    private let fiberType = HKQuantityType(.dietaryFiber)
    private let sugarType = HKQuantityType(.dietarySugar)
    private let sodiumType = HKQuantityType(.dietarySodium)
    private let stepsType = HKQuantityType(.stepCount)
    private let activeCaloriesType = HKQuantityType(.activeEnergyBurned)

    // MARK: - Initialization

    init(healthStore: HKHealthStore) {
        self.healthStore = healthStore

        Task {
            await checkAuthorizationStatus()
        }
    }

    // MARK: - Authorization Methods

    func requestAuthorization() async throws -> Bool {
        logger.info("Requesting HealthKit authorization")

        // Define types to read (glucose, nutrition, and activity)
        let typesToRead: Set<HKObjectType> = [
            glucoseType,
            carbsType,
            caloriesType,
            proteinType,
            fatType,
            fiberType,
            sugarType,
            sodiumType,
            stepsType,
            activeCaloriesType
        ]

        // We're read-only as per requirements
        let typesToWrite: Set<HKSampleType> = []

        do {
            try await healthStore.requestAuthorization(
                toShare: typesToWrite,
                read: typesToRead
            )

            // For read-only permissions, we can't reliably check the status
            // HealthKit doesn't reveal read authorization status for privacy
            // We'll assume success if no error was thrown
            authorizationStatus = healthStore.authorizationStatus(for: glucoseType)
            logger.info("HealthKit authorization completed. Status: \(String(describing: self.authorizationStatus))")

            // Return true since the authorization request succeeded
            return true
        } catch {
            logger.error("HealthKit authorization failed: \(error.localizedDescription)")
            throw HealthKitError.authorizationFailed(error)
        }
    }

    func isAuthorized(for type: HKQuantityType? = nil) async -> Bool {
        // Use the specified type or default to glucose
        let typeToCheck = type ?? glucoseType

        // For read permissions, we can't definitively know the status from HealthKit
        // The only reliable way is to try a test query
        let status = healthStore.authorizationStatus(for: typeToCheck)

        // If status is notDetermined, we definitely don't have permission
        if status == .notDetermined {
            logger.debug("HealthKit authorization not determined for \(typeToCheck.identifier)")
            return false
        }

        // Try a test query to verify actual authorization
        // Query for minimal data in the last minute to test access
        let testPredicate = HKQuery.predicateForSamples(
            withStart: Date().addingTimeInterval(-60),
            end: Date(),
            options: .strictStartDate
        )

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: typeToCheck,
                predicate: testPredicate,
                limit: 1,
                sortDescriptors: nil
            ) { _, samples, error in
                // If we get a privacy error (error code 6), we don't have permission
                if let error = error as NSError?, error.code == 6 {
                    self.logger.debug("HealthKit authorization test failed with privacy error for \(typeToCheck.identifier)")
                    continuation.resume(returning: false)
                } else if error != nil {
                    // Other errors might just mean no data, not lack of permission
                    self.logger.debug("HealthKit authorization test completed with non-privacy error for \(typeToCheck.identifier)")
                    continuation.resume(returning: true)
                } else {
                    // No error means we have permission (even if no samples returned)
                    self.logger.debug("HealthKit authorization test succeeded for \(typeToCheck.identifier)")
                    continuation.resume(returning: true)
                }
            }

            healthStore.execute(query)
        }
    }

    // MARK: - Status Checking

    private func checkAuthorizationStatus() async {
        authorizationStatus = healthStore.authorizationStatus(for: glucoseType)
        logger.info("Current authorization status: \(String(describing: self.authorizationStatus))")
    }

    func getAuthorizationStatus() async -> HKAuthorizationStatus {
        await checkAuthorizationStatus()
        return authorizationStatus
    }
}
