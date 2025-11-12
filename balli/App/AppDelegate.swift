//
//  AppDelegate.swift
//  balli
//
//  Minimal UIKit app delegate for UIKit-only features
//  Most lifecycle logic moved to SwiftUI App in balliApp.swift
//

import UIKit
import UserNotifications
import OSLog
import BackgroundTasks
import FirebaseCore
import FirebaseCrashlytics

/// Minimal AppDelegate handling only UIKit-specific features that cannot be done in SwiftUI:
/// - Orientation lock (UIKit-only API)
/// - Background task registration (BGTaskScheduler requires UIApplicationDelegate)
/// - Push notification registration (cleaner here than in SwiftUI)
/// - Notification response handling (deep linking for meal reminders)
/// - Offline queue monitoring and sync
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    private let logger = AppLoggers.App.lifecycle

    // MARK: - Orientation Lock

    /// Global orientation lock for the app (portrait only)
    static var orientationLock = UIInterfaceOrientationMask.portrait

    // MARK: - App Lifecycle

    @MainActor
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        logger.info("🚀 AppDelegate initialized - UIKit features configured")

        // CRITICAL: Configure Firebase before any Firebase services are used
        // Only configure if GoogleService-Info.plist exists
        if let filePath = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
           FileManager.default.fileExists(atPath: filePath) {
            FirebaseApp.configure()
            logger.info("🔥 Firebase configured successfully")
            
            // Initialize Crashlytics for crash reporting
            Crashlytics.crashlytics()
            logger.info("📊 Crashlytics initialized for crash reporting")
        } else {
            logger.warning("⚠️ GoogleService-Info.plist not found - Firebase features disabled")
        }

        // Start network monitoring for offline support (app-level subscriber)
        NetworkMonitor.shared.startMonitoring(subscriber: "AppDelegate")
        logger.info("📡 Network monitoring started for offline queue management")

        // Configure background task registration
        configureBackgroundRefresh()

        // Set up notification center delegate for handling notification taps
        UNUserNotificationCenter.current().delegate = self

        // Request notification permissions
        Task {
            await requestNotificationPermissions()
        }

        return true
    }

    // MARK: - Orientation Support

    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return AppDelegate.orientationLock
    }

    // MARK: - Background Task Registration

    private func configureBackgroundRefresh() {
        logger.debug("🔄 Registering background task handlers")

        // Register handler for health sync background task
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.anaxoniclabs.balli.healthsync",
            using: nil
        ) { task in
            guard let processingTask = task as? BGProcessingTask else {
                self.logger.error("❌ Background task is not a BGProcessingTask")
                task.setTaskCompleted(success: false)
                return
            }
            self.handleHealthSyncTask(processingTask)
        }

        // Register Dexcom background refresh using injected dependency
        Task { @MainActor in
            let dependencies = DependencyContainer.shared
            dependencies.dexcomBackgroundRefreshManager.registerBackgroundTask()
        }
    }

    private func handleHealthSyncTask(_ task: BGProcessingTask) {
        logger.info("📊 Background health sync task started")

        // Note: Background health sync implementation pending
        task.setTaskCompleted(success: true)
    }

    /// Schedules a background health sync task
    /// Called from balliApp.swift when app becomes active
    @MainActor
    func scheduleHealthSyncTask() {
        #if targetEnvironment(simulator)
        // Background tasks don't work in simulator - this is expected behavior
        logger.debug("📅 Skipping background task scheduling (not supported in simulator)")
        return
        #else
        logger.debug("📅 Scheduling health sync background task")

        let request = BGProcessingTaskRequest(identifier: "com.anaxoniclabs.balli.healthsync")
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes

        do {
            try BGTaskScheduler.shared.submit(request)
            logger.info("✅ Health sync background task scheduled")
        } catch {
            logger.error("❌ Failed to schedule background task: \(error.localizedDescription)")
        }
        #endif
    }

    // MARK: - Push Notifications

    private func requestNotificationPermissions() async {
        logger.debug("🔔 Requesting notification permissions")

        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .badge, .sound]
            )

            if granted {
                logger.info("✅ Notification permissions granted")

                // Register for remote notifications
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            } else {
                logger.warning("⚠️ Notification permissions denied")
            }
        } catch {
            logger.error("❌ Failed to request notification permissions: \(error.localizedDescription)")
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Handle notification presentation when app is in foreground
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification banner even when app is active
        completionHandler([.banner, .sound])
    }

    /// Handle notification tap (opens app and routes to appropriate screen)
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // Extract data before crossing actor boundaries (Swift 6 concurrency safety)
        let identifier = response.notification.request.identifier

        Task { @MainActor in
            self.logger.info("🔔 User tapped notification: \(identifier)")

            // Create response copy with just the identifier we need
            // This avoids sending the entire UNNotificationResponse across actor boundaries
            NotificationRouter.shared.handleNotificationIdentifier(identifier)
        }

        completionHandler()
    }
}