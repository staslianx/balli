//
//  LocalAppConfigurationManager.swift
//  balli
//
//  App configuration manager with local services only
//  Provides configuration and health monitoring for local mock service
//

import Foundation
import UIKit
import SwiftUI
import Combine
import os.log

// MARK: - Service Type Enum

public enum ChatServiceType: String, CaseIterable, Sendable {
    case mock = "mock"
    case cloud = "cloud"

    public var displayName: String {
        switch self {
        case .mock: return "Local Service"
        case .cloud: return "Cloud Service"
        }
    }
}

// MARK: - App Health Report

public struct AppHealthReport: Sendable {
    let overallHealth: HealthStatus
    let serviceHealth: [String: HealthStatus]
    let lastChecked: Date
    let recommendations: [String]
    
    public enum HealthStatus: String, Sendable {
        case healthy = "healthy"
        case degraded = "degraded"
        case unhealthy = "unhealthy"
        
        public var color: String {
            switch self {
            case .healthy: return "green"
            case .degraded: return "yellow"
            case .unhealthy: return "red"
            }
        }
        
        public var icon: String {
            switch self {
            case .healthy: return "checkmark.circle.fill"
            case .degraded: return "exclamationmark.triangle.fill"
            case .unhealthy: return "xmark.circle.fill"
            }
        }
    }
}

// MARK: - App Configuration Manager
@MainActor
public final class AppConfigurationManager: ObservableObject {
    public static let shared = AppConfigurationManager()
    
    private let logger = OSLog(subsystem: "com.balli.diabetes", category: "AppConfiguration")
    
    // MARK: - Published Properties
    @Published public private(set) var isReady = false
    @Published public private(set) var configurationError: Error?
    @Published public private(set) var currentServiceType: ChatServiceType = .mock
    @Published public private(set) var lastHealthCheck: AppHealthReport?
    
    // Legacy configuration properties
    @Published var isMaintenanceMode: Bool = false
    @Published var minAppVersion: String = "1.0.0"
    @Published var maxDailyScans: Int = 100
    @Published var featureFlags: [String: Bool] = [:]
    
    // MARK: - Service References
    public let authManager = LocalAuthenticationManager.shared
    // Mock service removed - no longer needed
    
    private var cancellables = Set<AnyCancellable>()
    private var healthCheckTask: Task<Void, Never>?
    
    private init() {
        loadConfiguration()
    }
    
    deinit {
        healthCheckTask?.cancel()
    }
    
    // MARK: - Configuration Methods
    
    public func configure(application: UIApplication) async throws {
        // CRITICAL FIX: Move configuration work off MainActor
        // This prevents blocking the UI on app launch
        await Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }

            os_log(.info, log: self.logger, "Starting app configuration with cloud services")

            // Load configuration asynchronously
            await self.loadConfigurationAsync()

            // Use Firebase cloud services for recipe generation and chat
            await MainActor.run {
                self.currentServiceType = .cloud
                os_log(.info, log: self.logger, "Using Firebase cloud service")
            }

            // Setup health monitoring in background
            await self.startHealthMonitoring()

            await MainActor.run {
                self.isReady = true
                os_log(.info, log: self.logger, "App configuration completed successfully with cloud services")
            }
        }.value
    }

    private func loadConfigurationAsync() async {
        // Load service preference without blocking main thread
        let serviceType: ChatServiceType
        let savedValue = await Task.detached {
            UserDefaults.standard.string(forKey: "preferred_service_type")
        }.value

        if let saved = savedValue, let type = ChatServiceType(rawValue: saved) {
            serviceType = type
        } else {
            serviceType = .cloud
        }

        await MainActor.run {
            self.currentServiceType = serviceType
            self.loadDefaultConfiguration()
        }
    }
    
    func refreshConfiguration() async {
        os_log(.info, log: logger, "Refreshing app configuration")

        // Perform health check
        let healthReport = await performHealthCheck()
        await MainActor.run {
            self.lastHealthCheck = healthReport
            // Load default configuration on main thread
            self.loadDefaultConfiguration()
        }
    }
    
    // MARK: - Service Type Management
    
    public func setServiceType(_ type: ChatServiceType) async {
        currentServiceType = type
        UserDefaults.standard.set(type.rawValue, forKey: "preferred_service_type")
        os_log(.info, log: logger, "Service type set to: %{public}@", type.displayName)
    }
    
    // MARK: - Health Monitoring
    
    private func startHealthMonitoring() {
        // PERFORMANCE FIX: Removed periodic health check loop - battery killer
        // Health checks can be triggered manually via performHealthCheck() or forceHealthCheck()
        // For a personal app with 2 users, continuous health monitoring is overkill

        // Perform ONE initial health check
        healthCheckTask = Task { [weak self] in
            guard let self = self else { return }
            let healthReport = await self.performHealthCheck()
            await MainActor.run {
                self.lastHealthCheck = healthReport
            }
        }
    }
    
    public func performHealthCheck() async -> AppHealthReport {
        var serviceHealth: [String: AppHealthReport.HealthStatus] = [:]
        let recommendations: [String] = []

        // Mock service is always healthy
        serviceHealth["mock"] = .healthy
        
        // Overall health is always healthy with local service
        let overallHealth: AppHealthReport.HealthStatus = .healthy
        
        return AppHealthReport(
            overallHealth: overallHealth,
            serviceHealth: serviceHealth,
            lastChecked: Date(),
            recommendations: recommendations
        )
    }
    
    // MARK: - Feature Flags
    
    func isFeatureEnabled(_ featureName: String) -> Bool {
        return featureFlags[featureName] ?? false
    }
    
    func updateFeatureFlag(_ featureName: String, enabled: Bool) {
        featureFlags[featureName] = enabled
        os_log(.info, log: logger, "Feature flag '%{public}@' set to: %d", featureName, enabled)
    }
    
    // MARK: - Configuration Loading
    
    private func loadConfiguration() {
        // Load service preference - default to cloud services
        if let saved = UserDefaults.standard.string(forKey: "preferred_service_type"),
           let type = ChatServiceType(rawValue: saved) {
            currentServiceType = type
        } else {
            currentServiceType = .cloud
        }
        loadDefaultConfiguration()
    }
    
    private func loadDefaultConfiguration() {
        // Load default configuration values
        isMaintenanceMode = false
        minAppVersion = "1.0.0"
        maxDailyScans = 100
        
        // Set default feature flags
        featureFlags = [
            "voiceRecording": true,
            "medicalSearch": true,
            "recipeGeneration": true,
            "nutritionAnalysis": true,
            "shoppingList": true,
            "emergencyDetection": true,
            "healthDataTracking": true
        ]
    }
    
    // MARK: - Public API
    
    /// Gets the appropriate service for current chat operations
    public var currentChatService: String {
        return "Local Mock Service"
    }
    
    /// Checks if the app is ready for normal operation
    public var isAppReady: Bool {
        return isReady
    }
    
    /// Gets user-friendly status message
    public var statusMessage: String {
        if !isReady {
            return "Uygulama yapılandırılıyor..."
        }
        return "Yerel servis hazır"
    }
    
    /// Forces a service health evaluation
    public func forceHealthCheck() async {
        let healthReport = await performHealthCheck()
        await MainActor.run {
            self.lastHealthCheck = healthReport
        }
    }
    
    /// Debug information for troubleshooting
    public var debugInfo: [String: Any] {
        return [
            "isReady": isReady,
            "currentServiceType": currentServiceType.rawValue,
            "lastHealthCheck": lastHealthCheck?.lastChecked.timeIntervalSince1970 ?? 0,
            "overallHealth": lastHealthCheck?.overallHealth.rawValue ?? "unknown",
            "featureFlags": featureFlags
        ]
    }
    
    /// Resets the configuration after logout
    public func resetConfiguration() async {
        // Stop health monitoring
        healthCheckTask?.cancel()
        healthCheckTask = nil
        
        // Reset state
        isReady = false
        currentServiceType = .mock
        configurationError = nil
        lastHealthCheck = nil
        
        // Clear user preferences
        UserDefaults.standard.removeObject(forKey: "preferred_service_type")
        
        // Reload default configuration
        loadDefaultConfiguration()
        
        os_log(.info, log: logger, "Configuration reset after logout")
    }
}
