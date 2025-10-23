//
//  balliApp.swift
//  balli
//
//  Main app entry point - Modern SwiftUI App lifecycle
//  iOS 26 compliant with native SwiftUI patterns
//

import SwiftUI
import CoreData
import OSLog

@main
struct balliApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    let persistenceController = Persistence.PersistenceController.shared

    @StateObject private var appConfiguration = AppConfigurationManager.shared
    @StateObject private var healthKitPermissions = HealthKitPermissionManager.shared

    private let logger = Logger(subsystem: "com.anaxoniclabs.balli", category: "app.lifecycle")

    init() {
        // Register background tasks for memory sync
        Task { @MainActor in
            MemorySyncCoordinator.shared.registerBackgroundTasks()
            MemorySyncCoordinator.shared.setupNetworkObserver()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.viewContext)
                .environmentObject(appConfiguration)
                .environmentObject(healthKitPermissions)
                .injectDependencies() // This sets up all our AI/Memory services!
                .captureWindow() // Capture window for ASWebAuthenticationSession
                .tint(AppTheme.primaryPurple)
                .accentColor(AppTheme.primaryPurple)
                .enableSettingsOpener() // Enable SwiftUI-native Settings opener
                .preferredColorScheme(.light)
                .onAppear {
                    configureApp()
                }
                .task {
                    // Sync memory on app launch (non-blocking)
                    await MemorySyncCoordinator.shared.syncOnAppLaunch()
                }
                .onChange(of: scenePhase) { oldPhase, newPhase in
                    handleScenePhaseChange(oldPhase: oldPhase, newPhase: newPhase)
                }
                .onOpenURL { url in
                    handleOpenURL(url)
                }
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { userActivity in
                    handleUserActivity(userActivity)
                }
                .onContinueUserActivity("com.anaxoniclabs.balli.state-restoration") { userActivity in
                    handleUserActivity(userActivity)
                }
                .userActivity("com.anaxoniclabs.balli.state-restoration") { activity in
                    configureStateRestoration(activity)
                }
        }
    }

    // MARK: - App Configuration

    private func configureApp() {
        logger.info("🚀 Balli app initializing")

        // Force light mode (synchronous, no blocking)
        applyLightMode()

        #if DEBUG
        // Generate mock meal data for simulator/debug builds
        Task {
            await generateDebugMealData()
        }
        #endif

        // CRITICAL FIX: Defer app configuration to background priority
        // This prevents blocking keyboard appearance on cold start
        Task.detached(priority: .background) {
            do {
                // Configure app completely off main thread
                let app = await UIApplication.shared
                try await appConfiguration.configure(application: app)
            } catch {
                logger.error("App configuration failed: \(error.localizedDescription)")
            }
        }

        // Request HealthKit permissions upfront on app launch
        // This prevents infinite loops from repeated per-type requests
        Task {
            do {
                try await healthKitPermissions.requestAllPermissions()
            } catch {
                logger.error("HealthKit authorization failed: \(error.localizedDescription)")
                // Non-fatal - app continues to work with limited functionality
            }
        }

        // Initialize FTS5 Manager for cross-conversation memory (recall)
        Task.detached(priority: .background) {
            do {
                // Initialize FTS5Manager
                let fts5Manager = try FTS5Manager()
                await MainActor.run {
                    logger.info("✅ FTS5Manager initialized successfully")
                }

                // Get model container from main actor
                let container = await MainActor.run {
                    ResearchSessionModelContainer.shared.container
                }

                // Run one-time migration to index existing completed sessions
                let storageActor = SessionStorageActor(
                    modelContainer: container,
                    fts5Manager: fts5Manager
                )

                await AppLifecycleCoordinator.shared.migrateToFTS5IfNeeded(
                    fts5Manager: fts5Manager,
                    storageActor: storageActor
                )

                await MainActor.run {
                    logger.info("✅ FTS5 migration check complete")
                }
            } catch {
                await MainActor.run {
                    logger.error("❌ FTS5 initialization failed: \(error.localizedDescription)")
                    // Non-fatal - recall feature won't work but app continues
                }
            }
        }
    }

    // MARK: - Scene Lifecycle

    private func handleScenePhaseChange(oldPhase: ScenePhase, newPhase: ScenePhase) {
        switch newPhase {
        case .active:
            logger.info("⚡ Scene became active")

            // Notify permission managers that app is active
            NotificationCenter.default.post(name: .sceneDidBecomeActive, object: nil)

            // Refresh app state when becoming active
            Task.detached(priority: .background) {
                await AppLifecycleCoordinator.shared.handleForegroundTransition()
                await AppLifecycleCoordinator.shared.refreshAppState()

                // Schedule any pending background tasks
                await MainActor.run {
                    appDelegate.scheduleHealthSyncTask()
                }
            }

        case .background:
            logger.info("🌙 Scene entered background")

            // Perform background save and cleanup with guaranteed completion time
            Task { @MainActor in
                // Request background execution time to ensure save completes
                let backgroundTaskID = await UIApplication.shared.beginBackgroundTask(withName: "SaveContext") {
                    self.logger.warning("⚠️ Background save task expired")
                }

                // Perform save operations
                await AppLifecycleCoordinator.shared.handleBackgroundTransition()
                await AppLifecycleCoordinator.shared.saveContext()

                // End background task
                await UIApplication.shared.endBackgroundTask(backgroundTaskID)
            }

        case .inactive:
            logger.info("⏸️ Scene became inactive")

            // Save current state before going inactive
            Task {
                await AppLifecycleCoordinator.shared.saveCurrentState()
            }

        @unknown default:
            break
        }
    }

    // MARK: - URL Handling

    private func handleOpenURL(_ url: URL) {
        logger.info("🔗 Opening URL: \(url, privacy: .public)")

        Task {
            await AppLifecycleCoordinator.shared.handleOpenURL(url)
        }
    }

    // MARK: - User Activity

    private func handleUserActivity(_ userActivity: NSUserActivity) {
        logger.info("🔗 Continuing user activity: \(userActivity.activityType, privacy: .public)")

        Task {
            await AppLifecycleCoordinator.shared.handleUserActivity(userActivity)
        }
    }

    // MARK: - State Restoration

    private func configureStateRestoration(_ activity: NSUserActivity) {
        logger.debug("💾 Configuring state restoration activity")

        activity.title = "Balli App State"
        activity.userInfo = [
            "timestamp": Date().timeIntervalSince1970,
            "version": "1.0"
        ]
    }

    // MARK: - Utilities

    private func applyLightMode() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }

        for window in windowScene.windows {
            window.overrideUserInterfaceStyle = .light
        }
    }

    #if DEBUG
    /// Generate mock meal data for debugging in simulator
    private func generateDebugMealData() async {
        let context = persistenceController.viewContext

        // Check if we already have meal entries (don't duplicate)
        let fetchRequest = MealEntry.fetchRequest()
        fetchRequest.fetchLimit = 1

        do {
            let existingMeals = try context.fetch(fetchRequest)
            if !existingMeals.isEmpty {
                logger.debug("Mock meal data already exists, skipping generation")
                return
            }
        } catch {
            logger.error("Failed to check for existing meals: \(error.localizedDescription)")
            return
        }

        // Create mock meal entries at specific times today
        // Chart shows 6am-6am (24 hours), so place meals within that window
        let calendar = Calendar.current
        let now = Date()

        // Get today at 6am (chart start time)
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = 6
        components.minute = 0
        components.second = 0

        guard let today6am = calendar.date(from: components) else {
            logger.error("Failed to calculate 6am time")
            return
        }

        // Create meals at specific times relative to 6am start
        let mealData: [(hoursAfter6am: Double, mealType: String, carbs: Double)] = [
            (3.0, "breakfast", 45.0),   // 9:00 AM - Breakfast - 45g carbs
            (3.5, "breakfast", 12.0),   // 9:30 AM - Coffee/snack - 12g carbs
            (6.5, "snack", 25.0),       // 12:30 PM - Snack - 25g carbs
            (8.0, "lunch", 38.0)        // 2:00 PM - Lunch - 38g carbs
        ]

        for (hoursAfter6am, mealType, carbs) in mealData {
            let meal = MealEntry(context: context)
            meal.id = UUID()
            meal.timestamp = today6am.addingTimeInterval(hoursAfter6am * 3600)
            meal.mealType = mealType

            // Only carbs are tracked
            meal.consumedCarbs = carbs

            // Set defaults for other fields
            meal.quantity = 1.0
            meal.unit = "serving"
            meal.portionGrams = 0.0
            meal.consumedProtein = 0.0
            meal.consumedFat = 0.0
            meal.consumedCalories = 0.0
            meal.consumedFiber = 0.0
            meal.glucoseBefore = 0.0
            meal.glucoseAfter = 0.0
            meal.insulinUnits = 0.0
        }

        do {
            try context.save()
            logger.info("✅ Generated mock meal data for debugging")
        } catch {
            logger.error("Failed to save mock meal data: \(error.localizedDescription)")
        }
    }
    #endif
}