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
    private let logger = AppLoggers.Health.glucose
    private var syncTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    // PERFORMANCE: Debouncing to prevent excessive refreshes on tab switches
    private var lastAppearTime: Date?
    private let minimumRefreshInterval: TimeInterval = 300 // 5 minutes, matching Dexcom's update frequency

    // MARK: - Initialization

    init(
        healthKitService: HealthKitServiceProtocol,
        dexcomService: DexcomService,
        healthKitPermissions: HealthKitPermissionManager,
        viewContext: NSManagedObjectContext? = nil
    ) {
        self.dexcomService = dexcomService

        // Initialize child ViewModels
        self.glucoseChartViewModel = GlucoseChartViewModel(
            healthKitService: healthKitService,
            dexcomService: dexcomService,
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
                logger.info("🔄 Refreshing data - \(Int(timeSinceLastAppear))s since last refresh")
            }
        } else {
            // First time appearing - always load
            shouldRefresh = true
            logger.info("🔄 Initial data load on first appear")
        }

        // Start automatic Dexcom sync timer (every 5 minutes) - only if not already running
        if syncTimer == nil {
            syncTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    self?.syncDexcomData()
                }
            }
        }

        // Only refresh data if threshold met
        if shouldRefresh {
            lastAppearTime = now
            syncDexcomData()
            glucoseChartViewModel.loadGlucoseData()
            activityMetricsViewModel.loadActivityData()
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
        // Clean up timer to prevent memory leak
        syncTimer?.invalidate()
        syncTimer = nil
        cancellables.removeAll()
    }

    func onDexcomConnectionChange(_ isConnected: Bool) {
        // Reload data when Dexcom connection status changes
        if isConnected {
            syncDexcomData()
        }
    }

    // MARK: - Private Methods

    private func syncDexcomData() {
        Task {
            guard dexcomService.isConnected else { return }

            do {
                try await dexcomService.syncData()
                // After sync, reload glucose data to get fresh readings
                glucoseChartViewModel.loadGlucoseData()
            } catch {
                // Background sync errors are expected and not critical
                // Log for diagnostics but don't alert user
                logger.debug("Background Dexcom sync failed (expected): \(error.localizedDescription)")
            }
        }
    }
}
