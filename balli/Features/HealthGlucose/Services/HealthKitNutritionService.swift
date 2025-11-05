//
//  HealthKitNutritionService.swift
//  balli
//
//  Handles nutrition data queries from HealthKit
//  Swift 6 strict concurrency compliant
//

import Foundation
import HealthKit
import OSLog

// MARK: - Nutrition Service

actor HealthKitNutritionService {
    // MARK: - Properties

    private let healthStore: HKHealthStore
    private let authManager: HealthKitAuthorizationManager
    private let logger = AppLoggers.Health.glucose

    // Nutrition data types
    private let carbsType = HKQuantityType(.dietaryCarbohydrates)
    private let caloriesType = HKQuantityType(.dietaryEnergyConsumed)
    private let proteinType = HKQuantityType(.dietaryProtein)
    private let fatType = HKQuantityType(.dietaryFatTotal)
    private let fiberType = HKQuantityType(.dietaryFiber)
    private let sugarType = HKQuantityType(.dietarySugar)
    private let sodiumType = HKQuantityType(.dietarySodium)

    // MARK: - Initialization

    init(healthStore: HKHealthStore, authManager: HealthKitAuthorizationManager) {
        self.healthStore = healthStore
        self.authManager = authManager
    }

    // MARK: - Nutrition Data Queries

    func getNutritionData(from startDate: Date, to endDate: Date) async throws -> [HealthNutritionEntry] {
        logger.info("Fetching nutrition data from \(startDate) to \(endDate)")

        guard await authManager.isAuthorized() else {
            throw HealthKitError.notAuthorized
        }

        var nutritionEntries: [Date: HealthNutritionEntry] = [:]

        // Fetch each nutrition type
        let nutritionTypes: [HKQuantityType] = [
            caloriesType,
            carbsType,
            proteinType,
            fatType,
            fiberType,
            sugarType,
            sodiumType
        ]

        for type in nutritionTypes {
            let samples = try await fetchNutritionSamples(
                type: type,
                from: startDate,
                to: endDate
            )

            for sample in samples {
                let date = sample.startDate
                let roundedDate = Calendar.current.dateInterval(of: .hour, for: date)?.start ?? date

                if nutritionEntries[roundedDate] == nil {
                    nutritionEntries[roundedDate] = HealthNutritionEntry(
                        timestamp: roundedDate
                    )
                }

                // Update the specific nutrition value - use guard instead of force unwrap
                guard var entry = nutritionEntries[roundedDate] else {
                    logger.error("Failed to retrieve nutrition entry that was just created - data corruption possible")
                    continue
                }

                let value = extractNutritionValue(from: sample, type: type)
                entry = updateNutritionEntry(entry, type: type, value: value)
                nutritionEntries[roundedDate] = entry
            }
        }

        let sortedEntries = nutritionEntries.values.sorted { $0.timestamp > $1.timestamp }
        logger.info("Retrieved \(sortedEntries.count) nutrition entries")

        return sortedEntries
    }

    func saveNutritionData(_ nutrition: HealthNutritionEntry) async throws {
        // Read-only implementation as per requirements
        logger.info("Nutrition saving skipped - read-only mode")
        throw HealthKitError.readOnlyMode
    }

    // MARK: - Helper Methods

    private func fetchNutritionSamples(
        type: HKQuantityType,
        from startDate: Date,
        to endDate: Date
    ) async throws -> [HKQuantitySample] {
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: HealthKitError.queryFailed(error))
                    return
                }

                let quantitySamples = samples as? [HKQuantitySample] ?? []
                continuation.resume(returning: quantitySamples)
            }

            healthStore.execute(query)
        }
    }

    private func extractNutritionValue(from sample: HKQuantitySample, type: HKQuantityType) -> Double {
        switch type {
        case caloriesType:
            return sample.quantity.doubleValue(for: .kilocalorie())
        case carbsType, proteinType, fatType, fiberType, sugarType:
            return sample.quantity.doubleValue(for: .gram())
        case sodiumType:
            return sample.quantity.doubleValue(for: .gramUnit(with: .milli))
        default:
            return 0
        }
    }

    private func updateNutritionEntry(_ entry: HealthNutritionEntry, type: HKQuantityType, value: Double) -> HealthNutritionEntry {
        switch type {
        case caloriesType:
            return HealthNutritionEntry(
                id: entry.id,
                timestamp: entry.timestamp,
                calories: value,
                carbohydrates: entry.carbohydrates,
                protein: entry.protein,
                totalFat: entry.totalFat,
                fiber: entry.fiber,
                sugar: entry.sugar,
                sodium: entry.sodium,
                mealType: entry.mealType
            )
        case carbsType:
            return HealthNutritionEntry(
                id: entry.id,
                timestamp: entry.timestamp,
                calories: entry.calories,
                carbohydrates: value,
                protein: entry.protein,
                totalFat: entry.totalFat,
                fiber: entry.fiber,
                sugar: entry.sugar,
                sodium: entry.sodium,
                mealType: entry.mealType
            )
        case proteinType:
            return HealthNutritionEntry(
                id: entry.id,
                timestamp: entry.timestamp,
                calories: entry.calories,
                carbohydrates: entry.carbohydrates,
                protein: value,
                totalFat: entry.totalFat,
                fiber: entry.fiber,
                sugar: entry.sugar,
                sodium: entry.sodium,
                mealType: entry.mealType
            )
        case fatType:
            return HealthNutritionEntry(
                id: entry.id,
                timestamp: entry.timestamp,
                calories: entry.calories,
                carbohydrates: entry.carbohydrates,
                protein: entry.protein,
                totalFat: value,
                fiber: entry.fiber,
                sugar: entry.sugar,
                sodium: entry.sodium,
                mealType: entry.mealType
            )
        case fiberType:
            return HealthNutritionEntry(
                id: entry.id,
                timestamp: entry.timestamp,
                calories: entry.calories,
                carbohydrates: entry.carbohydrates,
                protein: entry.protein,
                totalFat: entry.totalFat,
                fiber: value,
                sugar: entry.sugar,
                sodium: entry.sodium,
                mealType: entry.mealType
            )
        case sugarType:
            return HealthNutritionEntry(
                id: entry.id,
                timestamp: entry.timestamp,
                calories: entry.calories,
                carbohydrates: entry.carbohydrates,
                protein: entry.protein,
                totalFat: entry.totalFat,
                fiber: entry.fiber,
                sugar: value,
                sodium: entry.sodium,
                mealType: entry.mealType
            )
        case sodiumType:
            return HealthNutritionEntry(
                id: entry.id,
                timestamp: entry.timestamp,
                calories: entry.calories,
                carbohydrates: entry.carbohydrates,
                protein: entry.protein,
                totalFat: entry.totalFat,
                fiber: entry.fiber,
                sugar: entry.sugar,
                sodium: value,
                mealType: entry.mealType
            )
        default:
            return entry
        }
    }
}
