//
//  HosgeldinViewModel.swift
//  balli
//
//  Main coordinator for Hosgeldin dashboard state
//

import Foundation
import SwiftUI
import CoreData
import Combine
import OSLog

@MainActor
final class HosgeldinViewModel: ObservableObject {
    // MARK: - UI State

    @Published var currentCardIndex: Int? = 0
    @Published var showingCamera = false
    @Published var showingManualEntry = false
    @Published var showingRecipeEntry = false
    @Published var showingSettings = false
    @Published var showingVoiceInput = false
    @Published var isLongPressing = false

    // MARK: - Child ViewModels

    let glucoseChartViewModel: GlucoseChartViewModel
    let activityMetricsViewModel: ActivityMetricsViewModel

    // MARK: - Dependencies

    private let dexcomService: DexcomService
    private let dexcomShareService: DexcomShareService
    private let logger = AppLoggers.Health.glucose
    private var cancellables = Set<AnyCancellable>()

    // PERFORMANCE: Debouncing to prevent excessive refreshes on tab switches
    private var lastAppearTime: Date?
    // CRITICAL FIX: Reduced from 300s (5 min) to 30s
    // The old 5-minute debounce was preventing necessary refreshes when user switches tabs
    // 30 seconds is sufficient to prevent spam while allowing fresh data on tab switches
    private let minimumRefreshInterval: TimeInterval = 30 // 30 seconds

    // MARK: - Initialization

    init(
        healthKitService: HealthKitServiceProtocol,
        dexcomService: DexcomService,
        dexcomShareService: DexcomShareService,
        healthKitPermissions: HealthKitPermissionManager,
        viewContext: NSManagedObjectContext? = nil
    ) {
        self.dexcomService = dexcomService
        self.dexcomShareService = dexcomShareService

        // Initialize child ViewModels
        self.glucoseChartViewModel = GlucoseChartViewModel(
            healthKitService: healthKitService,
            dexcomService: dexcomService,
            dexcomShareService: dexcomShareService,
            healthKitPermissions: healthKitPermissions,
            viewContext: viewContext
        )

        self.activityMetricsViewModel = ActivityMetricsViewModel(
            healthKitService: healthKitService,
            healthKitPermissions: healthKitPermissions
        )
    }

    // MARK: - Lifecycle Methods

    func onAppear() {
        // PERFORMANCE: Check if enough time has passed since last refresh
        // Don't reload data on every tab switch - use 5-minute threshold like Dexcom
        let now = Date()
        let shouldRefresh: Bool

        if let lastAppear = lastAppearTime {
            let timeSinceLastAppear = now.timeIntervalSince(lastAppear)
            shouldRefresh = timeSinceLastAppear >= minimumRefreshInterval

            if !shouldRefresh {
                logger.debug("⚡️ Skipping data refresh - last refreshed \(Int(timeSinceLastAppear))s ago (threshold: \(Int(self.minimumRefreshInterval))s)")
            } else {
                logger.info("🔄 Refreshing data - \(Int(timeSinceLastAppear))s since last refresh (threshold: \(Int(self.minimumRefreshInterval))s)")
            }
        } else {
            // First time appearing - always load
            shouldRefresh = true
            logger.info("🔄 Initial data load on first appear")
        }

        // NOTE: Continuous sync is now handled by DexcomSyncCoordinator.shared
        // which runs independently of view lifecycle via AppLifecycleCoordinator
        // No need for view-based Timer that dies when view disappears

        // Only refresh data if threshold met
        if shouldRefresh {
            lastAppearTime = now
            glucoseChartViewModel.loadGlucoseData()
            activityMetricsViewModel.loadActivityData()

            // Trigger immediate sync in the background
            Task {
                await DexcomSyncCoordinator.shared.syncNow()
            }
        }

        // Subscribe to glucose data updates (only once)
        if cancellables.isEmpty {
            NotificationCenter.default.publisher(for: .glucoseDataUpdated)
                .sink { [weak self] _ in
                    self?.glucoseChartViewModel.loadGlucoseData()
                }
                .store(in: &cancellables)
        }
    }

    func onDisappear() {
        // NOTE: No need to stop sync - DexcomSyncCoordinator continues running
        // Only clean up view-specific subscriptions
        cancellables.removeAll()
    }

    func onDexcomConnectionChange(_ isConnected: Bool) {
        // Reload data when Dexcom connection status changes
        if isConnected {
            // Connection restored - trigger immediate sync
            Task {
                await DexcomSyncCoordinator.shared.syncNow()
            }
            glucoseChartViewModel.loadGlucoseData()
        }
    }
}

// MARK: - Preview Support

#if DEBUG
extension HosgeldinViewModel {
    /// Create preview ViewModel with mock dependencies
    static func preview(viewContext: NSManagedObjectContext) -> HosgeldinViewModel {
        let mockHealthKit = MockHealthKitService()
        let mockDexcom = DexcomService.previewConnected
        let mockDexcomShare = DexcomShareService.preview
        let mockPermissions = HealthKitPermissionManager.shared

        return HosgeldinViewModel(
            healthKitService: mockHealthKit,
            dexcomService: mockDexcom,
            dexcomShareService: mockDexcomShare,
            healthKitPermissions: mockPermissions,
            viewContext: viewContext
        )
    }
}
#endif
