//
//  ActivityMetricsViewModel.swift
//  balli
//
//  Manages activity data (steps, calories) and percentage calculations
//

import Foundation
import SwiftUI
import HealthKit
import OSLog

@MainActor
final class ActivityMetricsViewModel: ObservableObject {
    // MARK: - Published State

    @Published var todaySteps: Double = 0
    @Published var yesterdaySteps: Double = 0
    @Published var todayCalories: Double = 0
    @Published var yesterdayCalories: Double = 0
    @Published var errorMessage: String?

    // Cache permission status to avoid flickering
    private var hasPermissionCache: Bool = false
    private var lastPermissionCheck: Date?

    // MARK: - Computed Properties

    var stepsChangePercent: Int {
        guard yesterdaySteps > 0 else { return 0 }
        let change = ((todaySteps / yesterdaySteps) - 1) * 100
        return Int(change.rounded())
    }

    var caloriesChangePercent: Int {
        guard yesterdayCalories > 0 else { return 0 }
        let change = ((todayCalories / yesterdayCalories) - 1) * 100
        return Int(change.rounded())
    }

    // MARK: - Dependencies

    private let healthKitService: HealthKitServiceProtocol
    private let healthKitPermissions: HealthKitPermissionManager
    private let logger = AppLoggers.Health.glucose

    // MARK: - Initialization

    init(
        healthKitService: HealthKitServiceProtocol,
        healthKitPermissions: HealthKitPermissionManager
    ) {
        self.healthKitService = healthKitService
        self.healthKitPermissions = healthKitPermissions
    }

    // MARK: - Public Methods

    /// Call this when app becomes active to re-check permissions
    func refreshPermissionsAndData() {
        Task {
            // Force permission manager to re-check authorization status
            await healthKitPermissions.refreshAuthorizationStatus()

            // Force permission re-check in this ViewModel
            lastPermissionCheck = nil
            hasPermissionCache = false
            loadActivityData()
        }
    }

    /// Load activity data (steps and calories) for today and yesterday
    func loadActivityData() {
        Task {
            // Use cached permission status if checked recently (within 5 seconds)
            // This prevents flickering when view reappears
            let shouldCheckPermission: Bool
            if let lastCheck = lastPermissionCheck, Date().timeIntervalSince(lastCheck) < 5 {
                shouldCheckPermission = false
                // Use cached status
                if !hasPermissionCache {
                    errorMessage = healthKitPermissions.getErrorMessage(for: .activityDataRequired)
                    resetAllMetrics()
                    return
                }
            } else {
                shouldCheckPermission = true
            }

            if shouldCheckPermission {
                // Check permissions and cache the result
                let hasPermission = await healthKitPermissions.hasActivityDataAccess()
                hasPermissionCache = hasPermission
                lastPermissionCheck = Date()

                if !hasPermission {
                    errorMessage = healthKitPermissions.getErrorMessage(for: .activityDataRequired)
                    resetAllMetrics()
                    return
                }
            }

            // Clear error message when we have permission
            errorMessage = nil

            let calendar = Calendar.current
            let now = Date()

            // Today's range (midnight to now)
            let todayStart = calendar.startOfDay(for: now)
            let todayEnd = now

            // Yesterday's range (midnight to midnight)
            guard let yesterdayStart = calendar.date(byAdding: .day, value: -1, to: todayStart) else { return }
            let yesterdayEnd = todayStart

            do {
                // Use actor's debounced method for today's data
                let (todayStepsData, todayCaloriesData) = try await healthKitService.getActivityData(
                    from: todayStart,
                    to: todayEnd
                )

                // Fetch yesterday's data separately (no debouncing needed for historical data)
                let yesterdayStepsData = try await healthKitService.getSteps(from: yesterdayStart, to: yesterdayEnd)

                var yesterdayCaloriesData: Double = 0
                do {
                    yesterdayCaloriesData = try await healthKitService.getActiveCalories(from: yesterdayStart, to: yesterdayEnd)
                } catch {
                    // No calories data for yesterday is expected (many users don't track it)
                    logger.debug("No calories data for yesterday (expected): \(error.localizedDescription)")
                }

                todaySteps = todayStepsData
                yesterdaySteps = yesterdayStepsData
                todayCalories = todayCaloriesData
                yesterdayCalories = yesterdayCaloriesData
            } catch let error as HealthKitError {
                // Handle actor-level debouncing/reentrancy gracefully
                switch error {
                case .alreadyLoading, .debounced:
                    // Silently ignore - actor is handling state management
                    break
                default:
                    errorMessage = error.localizedDescription
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Private Methods

    private func resetAllMetrics() {
        todaySteps = 0
        yesterdaySteps = 0
        todayCalories = 0
        yesterdayCalories = 0
    }
}
