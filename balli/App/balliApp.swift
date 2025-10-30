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
    @StateObject private var syncCoordinator = AppSyncCoordinator.shared

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
            Group {
                // Show loading only on FIRST launch or if sync fails
                // After initial sync, app launches directly to main UI
                if syncCoordinator.state == .completed {
                    ContentView()
                } else if case .failed(let error) = syncCoordinator.state {
                    SyncErrorView(
                        error: error,
                        retry: {
                            Task {
                                await syncCoordinator.retrySync()
                            }
                        }
                    )
                } else {
                    // Loading only shown on FIRST app launch
                    LoadingSplashView(
                        progress: syncCoordinator.progress,
                        operation: syncCoordinator.currentOperation
                    )
                }
            }
            .environment(\.managedObjectContext, persistenceController.viewContext)
            .environmentObject(appConfiguration)
            .environmentObject(healthKitPermissions)
            .injectDependencies() // This sets up all our AI/Memory services!
            .captureWindow() // Capture window for ASWebAuthenticationSession
            .tint(AppTheme.primaryPurple)
            .accentColor(AppTheme.primaryPurple)
            .enableSettingsOpener() // Enable SwiftUI-native Settings opener
            .preferredColorScheme(.light)
            .task {
                // CRITICAL: Perform sync ONCE on first launch
                if syncCoordinator.state == .idle {
                    await syncCoordinator.performInitialSync()
                }

                // Sync memory on app launch (non-blocking)
                await MemorySyncCoordinator.shared.syncOnAppLaunch()
            }
            .onAppear {
                configureApp()
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
        logger.info("🚀 Balli app initializing (non-blocking operations)")

        // Force light mode (synchronous, no blocking)
        applyLightMode()

        // NOTE: Mock meal data generation removed - use real meal logging instead
        // NOTE: App configuration and HealthKit permissions moved to AppSyncCoordinator
        // This ensures they complete before main UI is shown

        // Schedule glucose data cleanup (runs every 7 days)
        Task.detached(priority: .background) {
            await AppLifecycleCoordinator.shared.checkAndCleanupGlucoseDataIfNeeded()
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

                // Schedule Dexcom background refresh (checks connection in 4 hours)
                DexcomBackgroundRefreshManager.shared.scheduleBackgroundRefresh()

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
}