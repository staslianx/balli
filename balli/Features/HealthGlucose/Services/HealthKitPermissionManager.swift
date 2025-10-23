//
//  HealthKitPermissionManager.swift
//  balli
//
//  Centralized HealthKit permission management to prevent authorization loops
//  Requests ALL required permissions upfront and maintains authorization state
//

import Foundation
import HealthKit
import OSLog

/// Manages HealthKit permissions with proper state tracking and loop prevention
@MainActor
final class HealthKitPermissionManager: ObservableObject {
    // MARK: - Singleton
    static let shared = HealthKitPermissionManager()

    // MARK: - Published State
    @Published private(set) var hasRequestedAuthorization = false
    @Published private(set) var authorizationStatus: AuthorizationStatus = .notDetermined

    // MARK: - Private Properties
    private let healthStore: HKHealthStore
    private let logger = AppLoggers.Health.permissions
    private var isRequestingAuthorization = false

    // UserDefaults keys for persisting permission status
    private let activityPermissionKey = "hasActivityDataPermission"
    private let glucosePermissionKey = "hasGlucoseDataPermission"

    // MARK: - Authorization Status
    enum AuthorizationStatus {
        case notDetermined
        case requesting
        case authorized
        case denied
        case restricted
        case partiallyAuthorized(granted: Set<HKObjectType>, denied: Set<HKObjectType>)

        var isFullyAuthorized: Bool {
            if case .authorized = self { return true }
            return false
        }

        var canAccessData: Bool {
            switch self {
            case .authorized, .partiallyAuthorized:
                return true
            case .notDetermined, .requesting, .denied, .restricted:
                return false
            }
        }
    }

    // MARK: - Required Health Types
    private let requiredHealthTypes: Set<HKObjectType> = {
        var types = Set<HKObjectType>()

        // Glucose monitoring
        types.insert(HKQuantityType(.bloodGlucose))

        // Activity tracking
        types.insert(HKQuantityType(.stepCount))
        types.insert(HKQuantityType(.activeEnergyBurned))

        // Nutrition tracking
        types.insert(HKQuantityType(.dietaryCarbohydrates))
        types.insert(HKQuantityType(.dietaryEnergyConsumed))
        types.insert(HKQuantityType(.dietaryProtein))
        types.insert(HKQuantityType(.dietaryFatTotal))
        types.insert(HKQuantityType(.dietaryFiber))
        types.insert(HKQuantityType(.dietarySugar))
        types.insert(HKQuantityType(.dietarySodium))

        return types
    }()

    // MARK: - Initialization
    private init() {
        guard HKHealthStore.isHealthDataAvailable() else {
            logger.error("HealthKit is not available on this device")
            self.healthStore = HKHealthStore()
            self.authorizationStatus = .restricted
            return
        }

        self.healthStore = HKHealthStore()
        logger.info("HealthKitPermissionManager initialized")

        // Check if we've already requested authorization
        checkCurrentAuthorizationStatus()
    }

    // MARK: - Public API

    /// Request all required HealthKit permissions upfront
    /// This should be called once at app launch or first use
    func requestAllPermissions() async throws {
        // Prevent multiple simultaneous requests
        guard !isRequestingAuthorization else {
            logger.info("Authorization request already in progress, skipping")
            return
        }

        // Don't re-request if already authorized
        if authorizationStatus.isFullyAuthorized {
            logger.info("Already fully authorized, skipping request")
            return
        }

        isRequestingAuthorization = true
        authorizationStatus = .requesting

        defer {
            isRequestingAuthorization = false
        }

        logger.info("Requesting authorization for \(self.requiredHealthTypes.count) HealthKit types")

        do {
            // Request authorization for all types at once
            try await healthStore.requestAuthorization(
                toShare: [], // Read-only access
                read: requiredHealthTypes
            )

            // Mark that we've requested (even if denied)
            hasRequestedAuthorization = true
            UserDefaults.standard.set(true, forKey: "hasRequestedHealthKitAuthorization")

            // Check the actual authorization status after request
            await checkDetailedAuthorizationStatus()

            logger.info("Authorization request completed with status: \(String(describing: self.authorizationStatus))")
        } catch {
            logger.error("Authorization request failed: \(error.localizedDescription)")
            authorizationStatus = .denied
            throw HealthKitError.authorizationFailed(error)
        }
    }

    /// Check if a specific type is authorized
    func isAuthorized(for type: HKQuantityType) async -> Bool {
        // For READ permissions, we must use a test query
        // Query for any samples in a large time window to test access
        let testPredicate = HKQuery.predicateForSamples(
            withStart: Date().addingTimeInterval(-86400 * 365), // Last year
            end: Date(),
            options: .strictStartDate
        )

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: testPredicate,
                limit: 1,
                sortDescriptors: nil
            ) { _, samples, error in
                // Check for privacy error (error code 6 in HealthKit domain)
                if let error = error as NSError? {
                    // Code 6 = HKErrorAuthorizationNotDetermined (no permission)
                    if error.code == 6 {
                        continuation.resume(returning: false)
                        return
                    }
                }

                // If we get here, we have permission (even if samples is empty/nil)
                // Empty results just mean no data exists, not lack of permission
                continuation.resume(returning: true)
            }

            healthStore.execute(query)
        }
    }

    /// Check if all required types are authorized
    func areAllTypesAuthorized() async -> Bool {
        // Check a few critical types with actual test queries
        let criticalTypes = [
            HKQuantityType(.bloodGlucose),
            HKQuantityType(.stepCount),
            HKQuantityType(.activeEnergyBurned)
        ]

        for type in criticalTypes {
            let isAuth = await isAuthorized(for: type)
            if !isAuth {
                logger.notice("Type \(type.identifier) is not authorized")
                return false
            }
        }

        logger.info("All critical types are authorized")
        return true
    }

    // MARK: - Simplified Permission Helpers

    /// Refresh authorization status (call when returning from Settings)
    func refreshAuthorizationStatus() async {
        logger.debug("Refreshing authorization status...")

        // Clear cached permission states to force fresh checks
        UserDefaults.standard.removeObject(forKey: activityPermissionKey)
        UserDefaults.standard.removeObject(forKey: glucosePermissionKey)

        await checkDetailedAuthorizationStatus()
    }

    /// Check if we have access to activity data (steps OR calories)
    /// This is the recommended way to check activity permissions
    func hasActivityDataAccess() async -> Bool {
        // FAST PATH: Check cached permission status from UserDefaults
        // This avoids async calls on every app launch
        let cachedPermission = UserDefaults.standard.bool(forKey: activityPermissionKey)
        if cachedPermission {
            logger.debug("Using cached activity permission (granted)")
            return true
        }

        // Quick check of overall authorization state
        guard authorizationStatus.canAccessData else {
            logger.debug("No HealthKit access - activity data unavailable")
            return false
        }

        // Check if we have at least one activity data type authorized
        let hasStepsAccess = await isAuthorized(for: HKQuantityType(.stepCount))
        let hasCaloriesAccess = await isAuthorized(for: HKQuantityType(.activeEnergyBurned))

        let hasAccess = hasStepsAccess || hasCaloriesAccess

        if hasAccess {
            logger.info("Activity data access confirmed (steps: \(hasStepsAccess), calories: \(hasCaloriesAccess))")
            // Cache the permission status
            UserDefaults.standard.set(true, forKey: activityPermissionKey)
        } else {
            logger.debug("No activity data access available")
            // Clear cache if permission was revoked
            UserDefaults.standard.set(false, forKey: activityPermissionKey)
        }

        return hasAccess
    }

    /// Check if we have access to glucose data
    /// This is the recommended way to check glucose permissions
    func hasGlucoseDataAccess() async -> Bool {
        // FAST PATH: Check cached permission status from UserDefaults
        let cachedPermission = UserDefaults.standard.bool(forKey: glucosePermissionKey)
        if cachedPermission {
            logger.debug("Using cached glucose permission (granted)")
            return true
        }

        // Quick check of overall authorization state
        guard authorizationStatus.canAccessData else {
            logger.debug("No HealthKit access - glucose data unavailable")
            return false
        }

        // Check glucose-specific authorization
        let hasAccess = await isAuthorized(for: HKQuantityType(.bloodGlucose))

        if hasAccess {
            logger.info("Glucose data access confirmed")
            // Cache the permission status
            UserDefaults.standard.set(true, forKey: glucosePermissionKey)
        } else {
            logger.debug("No glucose data access available")
            // Clear cache if permission was revoked
            UserDefaults.standard.set(false, forKey: glucosePermissionKey)
        }

        return hasAccess
    }

    /// Check if we have access to nutrition data
    /// This is the recommended way to check nutrition permissions
    func hasNutritionDataAccess() async -> Bool {
        // Quick check of overall authorization state
        guard authorizationStatus.canAccessData else {
            logger.debug("No HealthKit access - nutrition data unavailable")
            return false
        }

        // Check if we have at least one nutrition data type authorized
        let hasCarbsAccess = await isAuthorized(for: HKQuantityType(.dietaryCarbohydrates))
        let hasCaloriesAccess = await isAuthorized(for: HKQuantityType(.dietaryEnergyConsumed))

        let hasAccess = hasCarbsAccess || hasCaloriesAccess

        if hasAccess {
            logger.info("Nutrition data access confirmed (carbs: \(hasCarbsAccess), calories: \(hasCaloriesAccess))")
        } else {
            logger.debug("No nutrition data access available")
        }

        return hasAccess
    }

    /// Check if all required app permissions are granted
    /// Returns true only if glucose AND activity data are accessible
    func hasAllRequiredPermissions() async -> Bool {
        let hasGlucose = await hasGlucoseDataAccess()
        let hasActivity = await hasActivityDataAccess()

        let hasAll = hasGlucose && hasActivity

        if hasAll {
            logger.info("All required permissions granted")
        } else {
            logger.notice("Missing required permissions (glucose: \(hasGlucose), activity: \(hasActivity))")
        }

        return hasAll
    }

    /// Request missing permissions with clear user guidance
    /// This will only request permissions that are not yet authorized
    func requestMissingPermissions() async throws {
        logger.info("Checking for missing permissions...")

        // If already fully authorized, no need to request
        if await hasAllRequiredPermissions() {
            logger.info("All permissions already granted")
            return
        }

        // Request all permissions (will show system dialog for missing ones)
        try await requestAllPermissions()
    }

    /// Reset authorization state (for testing/debugging)
    func resetAuthorizationState() {
        hasRequestedAuthorization = false
        authorizationStatus = .notDetermined
        UserDefaults.standard.removeObject(forKey: "hasRequestedHealthKitAuthorization")
        logger.info("Authorization state reset")
    }

    // MARK: - Private Helpers

    private func checkCurrentAuthorizationStatus() {
        // Check if we've previously requested authorization
        hasRequestedAuthorization = UserDefaults.standard.bool(forKey: "hasRequestedHealthKitAuthorization")

        if hasRequestedAuthorization {
            // We've requested before, check if still authorized
            Task {
                await checkDetailedAuthorizationStatus()
            }
        } else {
            authorizationStatus = .notDetermined
        }
    }

    private func checkDetailedAuthorizationStatus() async {
        // For READ permissions, HealthKit authorization status is unreliable due to iOS privacy
        // The only way to verify is through actual test queries
        var grantedTypes = Set<HKObjectType>()
        var deniedTypes = Set<HKObjectType>()

        for type in requiredHealthTypes {
            guard let quantityType = type as? HKQuantityType else { continue }

            // Perform test query to verify actual access
            if await isAuthorized(for: quantityType) {
                grantedTypes.insert(type)
            } else {
                deniedTypes.insert(type)
            }
        }

        // Update status based on results
        if grantedTypes.count == requiredHealthTypes.count {
            authorizationStatus = .authorized
        } else if grantedTypes.isEmpty {
            authorizationStatus = .denied
        } else {
            authorizationStatus = .partiallyAuthorized(granted: grantedTypes, denied: deniedTypes)
        }

        logger.info("Authorization status checked: \(grantedTypes.count) granted, \(deniedTypes.count) denied")
    }
}

// MARK: - User Guidance

extension HealthKitPermissionManager {
    /// Permission error types for clearer user messaging
    enum PermissionError {
        case activityDataRequired
        case glucoseDataRequired
        case nutritionDataRequired
        case allPermissionsRequired
        case healthKitNotAvailable
        case generalAccessDenied
    }

    /// Get bilingual user-friendly message for specific permission errors
    func getErrorMessage(for error: PermissionError, language: String = "tr") -> String {
        if language == "en" {
            switch error {
            case .activityDataRequired:
                return "Activity data access required. Please grant access to Steps or Active Calories in Settings > Health > Data Access & Devices > balli."
            case .glucoseDataRequired:
                return "Glucose data access required. Please grant access to Blood Glucose in Settings > Health > Data Access & Devices > balli."
            case .nutritionDataRequired:
                return "Nutrition data access required. Please grant access to nutrition types in Settings > Health > Data Access & Devices > balli."
            case .allPermissionsRequired:
                return "Full HealthKit access required. Please grant all permissions in Settings > Health > Data Access & Devices > balli."
            case .healthKitNotAvailable:
                return "HealthKit is not available on this device."
            case .generalAccessDenied:
                return "HealthKit access denied. Please enable permissions in Settings > Health > Data Access & Devices > balli."
            }
        } else {
            // Turkish messages
            switch error {
            case .activityDataRequired:
                return "Aktivite verilerine erişim gerekli. Lütfen Ayarlar > Sağlık > Veri Erişimi ve Cihazlar > balli'den Adım veya Aktif Kalori izinlerini verin."
            case .glucoseDataRequired:
                return "Kan şekeri verilerine erişim gerekli. Lütfen Ayarlar > Sağlık > Veri Erişimi ve Cihazlar > balli'den Kan Şekeri iznini verin."
            case .nutritionDataRequired:
                return "Beslenme verilerine erişim gerekli. Lütfen Ayarlar > Sağlık > Veri Erişimi ve Cihazlar > balli'den beslenme izinlerini verin."
            case .allPermissionsRequired:
                return "Tüm HealthKit izinleri gerekli. Lütfen Ayarlar > Sağlık > Veri Erişimi ve Cihazlar > balli'den tüm izinleri verin."
            case .healthKitNotAvailable:
                return "HealthKit bu cihazda kullanılamıyor."
            case .generalAccessDenied:
                return "HealthKit erişimi reddedildi. Lütfen Ayarlar > Sağlık > Veri Erişimi ve Cihazlar > balli'den izinleri etkinleştirin."
            }
        }
    }

    /// Get user-friendly message for current authorization state
    func getUserGuidanceMessage() -> String {
        switch authorizationStatus {
        case .notDetermined:
            return "İzin gerekli. Kan şekeri ve aktivite verilerine erişim için HealthKit izni verin."
        case .requesting:
            return "İzin isteniyor..."
        case .authorized:
            return "Tüm izinler verildi"
        case .denied:
            return getErrorMessage(for: .generalAccessDenied)
        case .restricted:
            return getErrorMessage(for: .healthKitNotAvailable)
        case .partiallyAuthorized(_, let denied):
            return "Bazı izinler eksik (\(denied.count) reddedildi). Tam işlevsellik için Ayarlar'dan tüm izinleri verin."
        }
    }

    /// Check if user should be shown Settings button
    var shouldShowSettingsButton: Bool {
        switch authorizationStatus {
        case .denied, .partiallyAuthorized:
            return true
        case .notDetermined, .requesting, .authorized, .restricted:
            return false
        }
    }

    /// Open iOS Settings app to app-specific settings where user can manage HealthKit permissions
    /// Uses SwiftUI-native notification pattern - no UIKit dependency
    func openHealthKitSettings() {
        logger.info("Requesting Settings open for HealthKit permissions")
        SettingsOpener.requestSettingsOpen()
    }
}
