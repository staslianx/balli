//
//  AppLifecycleCoordinator.swift
//  balli
//
//  App lifecycle event coordination and UserDefaults preference management
//  Created by Claude on 4.08.2025.
//

import Foundation
import CoreData
import UIKit
import OSLog
import SwiftData
@preconcurrency import UserNotifications

actor AppLifecycleCoordinator {
    static let shared = AppLifecycleCoordinator()

    private let logger = AppLoggers.App.lifecycle

    // MARK: - App State Properties

    private var isFirstLaunch: Bool = false
    private var lastForegroundTime: Date?
    private var lastBackgroundTime: Date?
    private var appLaunchTime: Date
    private var hasMigratedToFTS5: Bool = false
    
    // MARK: - User Preferences State
    
    private var userPreferences: [String: Any] = [:]
    private let userDefaults = UserDefaults.standard
    
    private init() {
        self.appLaunchTime = Date()
        let firstLaunch = !userDefaults.bool(forKey: "HasLaunchedBefore")
        self.isFirstLaunch = firstLaunch
        self.hasMigratedToFTS5 = userDefaults.bool(forKey: "HasMigratedToFTS5")

        logger.info("AppStateManager initialized - First launch: \(firstLaunch)")

        if firstLaunch {
            userDefaults.set(true, forKey: "HasLaunchedBefore")
            userDefaults.set(Date(), forKey: "FirstLaunchDate")
        }

        // Initialize empty preferences, will be loaded when first accessed
        self.userPreferences = [:]

        // Load preferences asynchronously after initialization
        Task {
            await self.loadUserPreferences()
        }
    }
    
    // MARK: - App Lifecycle Management
    
    func refreshAppState() {
        logger.debug("Refreshing app state")

        lastForegroundTime = Date()

        // Check if this is a cold start or returning from background
        if let backgroundTime = lastBackgroundTime {
            let timeInBackground = Date().timeIntervalSince(backgroundTime)
            logger.info("App was in background for \(timeInBackground, format: .fixed(precision: 1)) seconds")

            // If app was in background for more than 30 minutes, treat as fresh start
            if timeInBackground > 1800 { // 30 minutes
                logger.notice("Treating as fresh start due to long background time")
                // Refresh data that might be stale
            }
        }
    }
    
    func saveCurrentState() {
        logger.debug("Saving current app state")

        // Save user preferences
        saveUserPreferences()

        // Update last active timestamp
        userDefaults.set(Date(), forKey: "LastActiveTime")
    }

    func handleForegroundTransition() {
        logger.info("Handling foreground transition")

        lastForegroundTime = Date()

        // Clear the graceful background flag (we're now active)
        userDefaults.set(false, forKey: "AppWentToBackgroundGracefully")

        // Check for missed notifications
        Task { @MainActor in
            let notificationCenter = UNUserNotificationCenter.current()
            let deliveredNotifications = await notificationCenter.deliveredNotifications()

            if !deliveredNotifications.isEmpty {
                logger.info("Found \(deliveredNotifications.count) delivered notifications")
            }
        }
    }

    func handleBackgroundTransition() {
        logger.info("Handling background transition")

        lastBackgroundTime = Date()

        // Mark that app gracefully entered background (not terminated)
        userDefaults.set(true, forKey: "AppWentToBackgroundGracefully")
        userDefaults.set(Date(), forKey: "LastBackgroundTime")

        // 💾 SESSION MANAGEMENT: Save active research session (without clearing it)
        Task { @MainActor in
            await saveActiveResearchSession()
        }

        // Save any critical data before going to background
        saveCurrentState()
    }

    func handleUserActivity(_ userActivity: NSUserActivity) {
        logger.info("Handling user activity: \(userActivity.activityType, privacy: .public)")

        switch userActivity.activityType {
        case "com.anaxoniclabs.balli.state-restoration":
            logger.debug("Restoring app state from user activity")
            // Handle state restoration
        case NSUserActivityTypeBrowsingWeb:
            if let url = userActivity.webpageURL {
                logger.info("Opening web URL: \(url, privacy: .public)")
            }
        default:
            logger.debug("Unknown user activity type")
        }
    }

    func handleOpenURL(_ url: URL, options: UIScene.OpenURLOptions? = nil) {
        logger.info("Handling URL: \(url, privacy: .public)")

        // Parse deep links for the diabetes app
        // Examples: balli://add-meal, balli://log-blood-sugar
        // OAuth callback: com.anaxoniclabs.balli://callback?code=...

        guard url.scheme == "balli" || url.scheme == "com.anaxoniclabs.balli" else {
            logger.error("Unknown URL scheme: \(url.scheme ?? "nil", privacy: .public)")
            return
        }

        // Check if this is a Dexcom OAuth callback
        if url.path.hasPrefix("/callback") || url.host == "callback" {
            logger.info("📱 Dexcom OAuth callback received")

            // Extract authorization code from query parameters
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let code = components.queryItems?.first(where: { $0.name == "code" })?.value {
                logger.info("✅ Authorization code received: \(code.prefix(10))...")

                // Post notification for DexcomAuthManager to handle
                Task { @MainActor in
                    NotificationCenter.default.post(
                        name: NSNotification.Name("DexcomAuthorizationCodeReceived"),
                        object: nil,
                        userInfo: ["code": code, "url": url]
                    )
                }
            } else {
                logger.error("❌ OAuth callback missing authorization code")
            }
            return
        }

        // Handle other deep links
        switch url.host {
        case "add-meal":
            logger.info("Deep link: Add meal")
        case "log-blood-sugar":
            logger.info("Deep link: Log blood sugar")
        case "scan-label":
            logger.info("Deep link: Scan nutrition label")
        default:
            logger.error("Unknown deep link: \(url.host ?? "nil", privacy: .public)")
        }
    }
    
    // MARK: - Core Data Management
    
    func saveContext() async {
        logger.debug("Saving Core Data context")

        // Use the new persistence controller
        do {
            try await PersistenceController.shared.save()
            logger.info("Core Data context saved successfully")
        } catch {
            logger.error("Core Data save failed: \(error.localizedDescription)")

            // In production, handle this more gracefully
            // For now, log the error but don't crash
            logger.fault("Critical data save failure: \(error)")
        }
    }

    // MARK: - User Preferences Management

    private func loadUserPreferences() {
        logger.debug("Loading user preferences")

        // Load diabetes-specific preferences
        userPreferences = [
            "preferredUnits": userDefaults.string(forKey: "PreferredUnits") ?? "mg/dL",
            "targetBloodSugar": userDefaults.double(forKey: "TargetBloodSugar"),
            "notificationsEnabled": userDefaults.bool(forKey: "NotificationsEnabled"),
            "carbRatio": userDefaults.double(forKey: "CarbRatio"),
            "insulinSensitivity": userDefaults.double(forKey: "InsulinSensitivity")
        ]

        logger.info("Loaded \(self.userPreferences.count) user preferences")
    }

    private func saveUserPreferences() {
        logger.debug("Saving user preferences")

        for (key, value) in userPreferences {
            switch value {
            case let stringValue as String:
                userDefaults.set(stringValue, forKey: key)
            case let doubleValue as Double:
                userDefaults.set(doubleValue, forKey: key)
            case let boolValue as Bool:
                userDefaults.set(boolValue, forKey: key)
            default:
                logger.error("Unknown preference type for key: \(key, privacy: .public)")
            }
        }

        userDefaults.synchronize()
        logger.debug("User preferences saved")
    }
    
    // MARK: - Getters for App State

    var isFirstLaunchProperty: Bool {
        isFirstLaunch
    }

    var appLaunchTimeValue: Date {
        appLaunchTime
    }

    var lastForegroundTimeValue: Date? {
        lastForegroundTime
    }

    var lastBackgroundTimeProperty: Date? {
        lastBackgroundTime
    }

    /// Check if app gracefully went to background (vs being terminated)
    /// Returns true if app was backgrounded, false if app was killed/crashed
    var wasGracefullyBackgrounded: Bool {
        userDefaults.bool(forKey: "AppWentToBackgroundGracefully")
    }

    /// Get the last background time from UserDefaults (persists across app termination)
    var persistedLastBackgroundTime: Date? {
        userDefaults.object(forKey: "LastBackgroundTime") as? Date
    }

    func getUserPreference<T: Sendable>(for key: String, as type: T.Type) -> T? {
        return userPreferences[key] as? T
    }

    func setUserPreference<T: Sendable>(key: String, value: T) {
        userPreferences[key] = value
        logger.debug("Updated preference \(key, privacy: .public)")
    }

    // MARK: - Research Session Management

    /// Saves the active research session when app backgrounds (WITHOUT clearing it)
    /// This ensures sessions are backed up to storage without losing conversation history
    @MainActor
    private func saveActiveResearchSession() async {
        logger.info("💾 Saving active research session due to app backgrounding")

        // Post notification that will be observed by MedicalResearchViewModel
        // Session will be saved to storage but kept active for conversation continuity
        NotificationCenter.default.post(
            name: NSNotification.Name("SaveActiveResearchSession"),
            object: nil
        )

        logger.info("💾 Posted session save notification")
    }

    // MARK: - FTS5 Migration

    /// Migrates existing completed research sessions to FTS5 index
    /// Call this once on app launch after adding FTS5 support
    /// - Parameters:
    ///   - fts5Manager: The FTS5 manager instance
    ///   - storageActor: The session storage actor for fetching sessions
    func migrateToFTS5IfNeeded(
        fts5Manager: FTS5Manager,
        storageActor: SessionStorageActor
    ) async {
        // Check if migration already completed
        guard !hasMigratedToFTS5 else {
            logger.info("FTS5 migration already completed, skipping")
            return
        }

        logger.warning("🔄 Starting FTS5 migration for existing sessions...")

        do {
            // Extract session data within the storage actor to avoid Sendable issues
            let sessionsToMigrate = try await storageActor.extractSessionDataForMigration()

            logger.info("Found \(sessionsToMigrate.count) completed sessions to migrate")

            // Perform migration
            try await fts5Manager.migrateExistingSessions(sessions: sessionsToMigrate)

            // Mark migration as complete
            hasMigratedToFTS5 = true
            userDefaults.set(true, forKey: "HasMigratedToFTS5")
            userDefaults.set(Date(), forKey: "FTS5MigrationDate")

            logger.info("✅ FTS5 migration completed successfully")
        } catch {
            logger.error("❌ FTS5 migration failed: \(error.localizedDescription)")
            // Don't mark as complete so it will retry next launch
        }
    }
}