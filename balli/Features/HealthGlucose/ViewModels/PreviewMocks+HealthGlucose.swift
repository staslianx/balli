//
//  PreviewMocks+HealthGlucose.swift
//  balli
//
//  Preview mock factories for HealthGlucose feature
//  Provides comprehensive mock data for all HealthGlucose ViewModels
//  Swift 6 strict concurrency compliant
//

import Foundation
import SwiftUI
import HealthKit
import CoreData

// MARK: - Mock HealthKit Service for Previews

/// Preview-specific mock HealthKit service with predefined data
actor PreviewHealthKitService: HealthKitServiceProtocol {
    private var mockGlucoseData: [HealthGlucoseReading] = []
    private var mockActivitySteps: Double = 8542
    private var mockActivityCalories: Double = 425

    init(withGlucoseData: Bool = true, withActivityData: Bool = true) {
        if withGlucoseData {
            // Initialize mock glucose data synchronously in actor init
            let calendar = Calendar.current
            let now = Date()
            var readings: [HealthGlucoseReading] = []

            for i in 0..<72 {
                guard let timestamp = calendar.date(byAdding: .minute, value: -i * 5, to: now) else { continue }
                let baseValue = 120.0
                let variation = sin(Double(i) / 10.0) * 30.0
                let noise = Double.random(in: -5...5)
                let value = max(70, min(200, baseValue + variation + noise))

                readings.append(HealthGlucoseReading(
                    value: value,
                    timestamp: timestamp,
                    device: "Mock Dexcom G7",
                    source: "Preview Mock Data"
                ))
            }

            mockGlucoseData = readings.sorted { $0.timestamp < $1.timestamp }
        }
        if withActivityData {
            mockActivitySteps = 8542
            mockActivityCalories = 425
        }
    }

    func requestAuthorization() async throws -> Bool { true }
    func isAuthorized(for type: HKQuantityType?) async -> Bool { true }

    func getGlucoseReadings(from startDate: Date, to endDate: Date, limit: Int) async throws -> [HealthGlucoseReading] {
        mockGlucoseData.filter { $0.timestamp >= startDate && $0.timestamp <= endDate }
    }

    func saveGlucoseReading(_ reading: HealthGlucoseReading) async throws {
        mockGlucoseData.append(reading)
    }

    func getNutritionData(from startDate: Date, to endDate: Date) async throws -> [HealthNutritionEntry] { [] }
    func saveNutritionData(_ nutrition: HealthNutritionEntry) async throws {}
    func getWorkoutData(from startDate: Date, to endDate: Date) async throws -> [HealthWorkoutEntry] { [] }

    func getActivityData(from startDate: Date, to endDate: Date) async throws -> (steps: Double, calories: Double) {
        (mockActivitySteps, mockActivityCalories)
    }

    func getSteps(from startDate: Date, to endDate: Date) async throws -> Double {
        mockActivitySteps
    }

    func getActiveCalories(from startDate: Date, to endDate: Date) async throws -> Double {
        mockActivityCalories
    }
}

// MARK: - Mock HealthKit Permission Manager

extension HealthKitPermissionManager {
    /// Preview mock with full permissions granted
    @MainActor
    static var preview: HealthKitPermissionManager {
        let manager = HealthKitPermissionManager.shared
        // In a real preview, permissions would be mocked to always return true
        return manager
    }

    /// Preview mock in permission denied state
    @MainActor
    static var previewDenied: HealthKitPermissionManager {
        let manager = HealthKitPermissionManager.shared
        // In a real preview, permissions would be mocked to always return false
        return manager
    }
}

// MARK: - ActivityMetricsViewModel Preview Mocks

extension ActivityMetricsViewModel {
    /// Preview with healthy activity data
    @MainActor
    static var preview: ActivityMetricsViewModel {
        let service = PreviewHealthKitService(withActivityData: true)
        let permissions = HealthKitPermissionManager.preview
        let viewModel = ActivityMetricsViewModel(
            healthKitService: service,
            healthKitPermissions: permissions
        )

        // Pre-populate with sample data
        viewModel.todaySteps = 8542
        viewModel.yesterdaySteps = 7650
        viewModel.todayCalories = 425
        viewModel.yesterdayCalories = 390

        return viewModel
    }

    /// Preview with high activity data
    @MainActor
    static var previewHighActivity: ActivityMetricsViewModel {
        let service = PreviewHealthKitService(withActivityData: true)
        let permissions = HealthKitPermissionManager.preview
        let viewModel = ActivityMetricsViewModel(
            healthKitService: service,
            healthKitPermissions: permissions
        )

        viewModel.todaySteps = 15230
        viewModel.yesterdaySteps = 10200
        viewModel.todayCalories = 780
        viewModel.yesterdayCalories = 550

        return viewModel
    }

    /// Preview with low activity data
    @MainActor
    static var previewLowActivity: ActivityMetricsViewModel {
        let service = PreviewHealthKitService(withActivityData: true)
        let permissions = HealthKitPermissionManager.preview
        let viewModel = ActivityMetricsViewModel(
            healthKitService: service,
            healthKitPermissions: permissions
        )

        viewModel.todaySteps = 2340
        viewModel.yesterdaySteps = 5200
        viewModel.todayCalories = 120
        viewModel.yesterdayCalories = 310

        return viewModel
    }

    /// Preview with error state
    @MainActor
    static var previewError: ActivityMetricsViewModel {
        let service = PreviewHealthKitService(withActivityData: false)
        let permissions = HealthKitPermissionManager.previewDenied
        let viewModel = ActivityMetricsViewModel(
            healthKitService: service,
            healthKitPermissions: permissions
        )

        viewModel.errorMessage = "HealthKit izni gerekli. Lütfen Ayarlar > Gizlilik > Sağlık'tan izin verin."

        return viewModel
    }

    /// Preview with loading state
    @MainActor
    static var previewLoading: ActivityMetricsViewModel {
        let service = PreviewHealthKitService(withActivityData: true)
        let permissions = HealthKitPermissionManager.preview
        let viewModel = ActivityMetricsViewModel(
            healthKitService: service,
            healthKitPermissions: permissions
        )

        // Loading state - no data yet
        viewModel.todaySteps = 0
        viewModel.todayCalories = 0

        return viewModel
    }
}

// MARK: - GlucoseChartViewModel Preview Mocks

extension GlucoseChartViewModel {
    /// Preview with realistic glucose data
    @MainActor
    static var preview: GlucoseChartViewModel {
        let healthKitService = PreviewHealthKitService(withGlucoseData: true)
        let dexcomService = DexcomService.mock
        // TODO: Create DexcomShareService.mock like DexcomService.mock to eliminate this force cast
        let dexcomShareService = DependencyContainer.shared.dexcomShareService as! DexcomShareService
        let permissions = HealthKitPermissionManager.preview

        let viewModel = GlucoseChartViewModel(
            healthKitService: healthKitService,
            dexcomService: dexcomService,
            dexcomShareService: dexcomShareService,
            healthKitPermissions: permissions,
            viewContext: nil
        )

        // Pre-populate with mock data
        let now = Date()
        let calendar = Calendar.current
        var dataPoints: [GlucoseDataPoint] = []

        for i in 0..<72 {
            guard let timestamp = calendar.date(byAdding: .minute, value: -i * 5, to: now) else { continue }
            let baseValue = 120.0
            let variation = sin(Double(i) / 10.0) * 30.0
            let value = max(70, min(200, baseValue + variation))
            dataPoints.append(GlucoseDataPoint(time: timestamp, value: value))
        }

        viewModel.glucoseData = dataPoints.sorted { $0.time < $1.time }
        viewModel.dataSource = "Preview Mock Data"

        return viewModel
    }

    /// Preview with high glucose readings
    @MainActor
    static var previewHighGlucose: GlucoseChartViewModel {
        let healthKitService = PreviewHealthKitService(withGlucoseData: true)
        let dexcomService = DexcomService.mock
        // TODO: Create DexcomShareService.mock like DexcomService.mock to eliminate this force cast
        let dexcomShareService = DependencyContainer.shared.dexcomShareService as! DexcomShareService
        let permissions = HealthKitPermissionManager.preview

        let viewModel = GlucoseChartViewModel(
            healthKitService: healthKitService,
            dexcomService: dexcomService,
            dexcomShareService: dexcomShareService,
            healthKitPermissions: permissions,
            viewContext: nil
        )

        // High glucose readings
        let now = Date()
        let calendar = Calendar.current
        var dataPoints: [GlucoseDataPoint] = []

        for i in 0..<50 {
            guard let timestamp = calendar.date(byAdding: .minute, value: -i * 5, to: now) else { continue }
            let value = Double.random(in: 180...250) // High range
            dataPoints.append(GlucoseDataPoint(time: timestamp, value: value))
        }

        viewModel.glucoseData = dataPoints.sorted { $0.time < $1.time }
        viewModel.dataSource = "Preview Mock - High"

        return viewModel
    }

    /// Preview with loading state
    @MainActor
    static var previewLoading: GlucoseChartViewModel {
        let healthKitService = PreviewHealthKitService(withGlucoseData: false)
        let dexcomService = DexcomService.mock
        // TODO: Create DexcomShareService.mock like DexcomService.mock to eliminate this force cast
        let dexcomShareService = DependencyContainer.shared.dexcomShareService as! DexcomShareService
        let permissions = HealthKitPermissionManager.preview

        let viewModel = GlucoseChartViewModel(
            healthKitService: healthKitService,
            dexcomService: dexcomService,
            dexcomShareService: dexcomShareService,
            healthKitPermissions: permissions,
            viewContext: nil
        )

        viewModel.isLoading = true
        viewModel.glucoseData = []

        return viewModel
    }

    /// Preview with error state
    @MainActor
    static var previewError: GlucoseChartViewModel {
        let healthKitService = PreviewHealthKitService(withGlucoseData: false)
        let dexcomService = DexcomService.mock
        // TODO: Create DexcomShareService.mock like DexcomService.mock to eliminate this force cast
        let dexcomShareService = DependencyContainer.shared.dexcomShareService as! DexcomShareService
        let permissions = HealthKitPermissionManager.previewDenied

        let viewModel = GlucoseChartViewModel(
            healthKitService: healthKitService,
            dexcomService: dexcomService,
            dexcomShareService: dexcomShareService,
            healthKitPermissions: permissions,
            viewContext: nil
        )

        viewModel.isLoading = false
        viewModel.errorMessage = "HealthKit izni gerekli. Lütfen Ayarlar > Gizlilik > Sağlık'tan kan şekeri verilerine erişim izni verin."
        viewModel.glucoseData = []

        return viewModel
    }

    /// Preview with empty state (no data available)
    @MainActor
    static var previewEmpty: GlucoseChartViewModel {
        let healthKitService = PreviewHealthKitService(withGlucoseData: false)
        let dexcomService = DexcomService.mock
        // TODO: Create DexcomShareService.mock like DexcomService.mock to eliminate this force cast
        let dexcomShareService = DependencyContainer.shared.dexcomShareService as! DexcomShareService
        let permissions = HealthKitPermissionManager.preview

        let viewModel = GlucoseChartViewModel(
            healthKitService: healthKitService,
            dexcomService: dexcomService,
            dexcomShareService: dexcomShareService,
            healthKitPermissions: permissions,
            viewContext: nil
        )

        viewModel.isLoading = false
        viewModel.glucoseData = []
        viewModel.errorMessage = "Son 6 saatte kan şekeri verisi bulunamadı"

        return viewModel
    }
}
