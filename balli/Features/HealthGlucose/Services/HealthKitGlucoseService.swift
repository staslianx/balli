//
//  HealthKitGlucoseService.swift
//  balli
//
//  Handles glucose data queries and background monitoring
//  Swift 6 strict concurrency compliant
//

import Foundation
import HealthKit
import OSLog

// MARK: - Glucose Service

actor HealthKitGlucoseService {
    // MARK: - Properties

    private let healthStore: HKHealthStore
    private let authManager: HealthKitAuthorizationManager
    private let logger = AppLoggers.Health.glucose

    private let glucoseType = HKQuantityType(.bloodGlucose)

    // Actor-isolated throttling for rate limiting (simpler approach)
    // Increased to 30 seconds to prevent rapid polling and improve keyboard responsiveness
    private var lastGlucoseLoadTime: Date?
    private let glucoseLoadThrottleInterval: TimeInterval = 30

    // Background monitoring
    private var backgroundObserverQuery: HKObserverQuery?

    // MARK: - Initialization

    init(healthStore: HKHealthStore, authManager: HealthKitAuthorizationManager) {
        self.healthStore = healthStore
        self.authManager = authManager
    }

    // MARK: - Glucose Data Queries

    func getGlucoseReadings(from startDate: Date, to endDate: Date, limit: Int) async throws -> [HealthGlucoseReading] {
        // Simple throttling: check time since last load
        if let lastLoad = lastGlucoseLoadTime {
            let timeSinceLastLoad = Date().timeIntervalSince(lastLoad)
            if timeSinceLastLoad < self.glucoseLoadThrottleInterval {
                logger.debug("Glucose fetch throttled - \(String(format: "%.1f", self.glucoseLoadThrottleInterval - timeSinceLastLoad))s remaining")
                throw HealthKitError.debounced(remainingTime: self.glucoseLoadThrottleInterval - timeSinceLastLoad)
            }
        }

        // Update last load time and execute
        lastGlucoseLoadTime = Date()
        logger.info("Fetching glucose readings from \(startDate) to \(endDate)")

        // Ensure we have authorization
        guard await authManager.isAuthorized() else {
            logger.notice("HealthKit not authorized for glucose readings")
            throw HealthKitError.notAuthorized
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )

        let sortDescriptor = NSSortDescriptor(
            key: HKSampleSortIdentifierStartDate,
            ascending: false
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: glucoseType,
                predicate: predicate,
                limit: limit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    self.logger.error("Failed to fetch glucose readings: \(error.localizedDescription)")
                    continuation.resume(throwing: HealthKitError.queryFailed(error))
                    return
                }

                guard let glucoseSamples = samples as? [HKQuantitySample] else {
                    continuation.resume(returning: [])
                    return
                }

                // Convert samples to readings synchronously (no actor isolation needed)
                let readings = glucoseSamples.map { sample in
                    let mgDLUnit = HKUnit(from: "mg/dL")
                    let value = sample.quantity.doubleValue(for: mgDLUnit)

                    let device = sample.device?.name ?? sample.sourceRevision.source.name
                    let source = sample.sourceRevision.source.bundleIdentifier

                    var metadata: [String: String]? = nil
                    if let sampleMetadata = sample.metadata {
                        metadata = [:]
                        for (key, value) in sampleMetadata {
                            metadata?[key] = String(describing: value)
                        }
                    }

                    return HealthGlucoseReading(
                        id: UUID(),
                        value: value,
                        unit: mgDLUnit,
                        timestamp: sample.startDate,
                        device: device,
                        source: source,
                        metadata: metadata
                    )
                }

                self.logger.info("Retrieved \(readings.count) glucose readings")
                continuation.resume(returning: readings)
            }

            healthStore.execute(query)
        }
    }

    func saveGlucoseReading(_ reading: HealthGlucoseReading) async throws {
        // Read-only implementation as per requirements
        logger.info("Glucose saving skipped - read-only mode")
        throw HealthKitError.readOnlyMode
    }

    // MARK: - Statistics

    /// Get glucose statistics for weekly summary
    func getGlucoseStatistics(for dateInterval: DateInterval) async throws -> GlucoseStatistics {
        let readings = try await getGlucoseReadings(
            from: dateInterval.start,
            to: dateInterval.end,
            limit: HKObjectQueryNoLimit
        )

        guard !readings.isEmpty else {
            throw HealthKitError.invalidData
        }

        let values = readings.map { $0.value }
        let average = values.reduce(0, +) / Double(values.count)
        let min = values.min() ?? 0
        let max = values.max() ?? 0

        // Calculate time in range (70-180 mg/dL is typical target)
        let inRangeCount = values.filter { $0 >= 70 && $0 <= 180 }.count
        let timeInRange = Double(inRangeCount) / Double(values.count) * 100

        // Calculate standard deviation
        let variance = values.map { pow($0 - average, 2) }.reduce(0, +) / Double(values.count)
        let standardDeviation = sqrt(variance)

        return GlucoseStatistics(
            average: average,
            min: min,
            max: max,
            standardDeviation: standardDeviation,
            timeInRange: timeInRange,
            readingCount: values.count,
            dateInterval: dateInterval
        )
    }

    /// Analyze glucose patterns related to meals
    func analyzeGlucosePatterns(mealTime: Date, windowHours: Int = 4) async throws -> GlucosePattern {
        let startDate = mealTime.addingTimeInterval(-TimeInterval(windowHours * 3600 / 2))
        let endDate = mealTime.addingTimeInterval(TimeInterval(windowHours * 3600 / 2))

        let readings = try await getGlucoseReadings(
            from: startDate,
            to: endDate,
            limit: HKObjectQueryNoLimit
        )

        // Find pre-meal and post-meal readings
        let preMealReadings = readings.filter { $0.timestamp < mealTime }
        let postMealReadings = readings.filter { $0.timestamp >= mealTime }

        let preMealAverage = preMealReadings.isEmpty ? nil :
            preMealReadings.map { $0.value }.reduce(0, +) / Double(preMealReadings.count)

        let postMealPeak = postMealReadings.map { $0.value }.max()

        let glucoseRise: Double?
        if let preMealAvg = preMealAverage, let postPeak = postMealPeak {
            glucoseRise = postPeak - preMealAvg
        } else {
            glucoseRise = nil
        }

        return GlucosePattern(
            mealTime: mealTime,
            preMealAverage: preMealAverage,
            postMealPeak: postMealPeak,
            glucoseRise: glucoseRise,
            readingsAnalyzed: readings.count
        )
    }

    // MARK: - Background Monitoring

    func setupBackgroundDelivery() async {
        logger.info("Setting up background delivery for glucose monitoring")

        do {
            // Enable background delivery for glucose readings
            try await healthStore.enableBackgroundDelivery(
                for: glucoseType,
                frequency: .immediate
            )

            // Setup observer query for glucose changes
            setupGlucoseObserver()

            logger.info("Background delivery enabled for glucose monitoring")
        } catch {
            logger.error("Failed to enable background delivery: \(error.localizedDescription)")
        }
    }

    private func setupGlucoseObserver() {
        let query = HKObserverQuery(
            sampleType: glucoseType,
            predicate: nil
        ) { @Sendable _, completionHandler, error in
            if let error = error {
                AppLoggers.Health.glucose.error("Observer query error: \(error.localizedDescription)")
                completionHandler()
                return
            }

            // Post notification for glucose update
            Task { @MainActor in
                NotificationCenter.default.post(
                    name: .glucoseDataUpdated,
                    object: nil
                )
            }

            completionHandler()
        }

        backgroundObserverQuery = query
        healthStore.execute(query)

        logger.info("Glucose observer query started")
    }

    // MARK: - Cleanup

    deinit {
        if let query = backgroundObserverQuery {
            healthStore.stop(query)
        }
    }
}
