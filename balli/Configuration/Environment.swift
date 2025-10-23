//
//  Environment.swift
//  balli
//
//  Environment configuration for different deployment stages
//  Manages API endpoints and feature flags
//

import Foundation
import OSLog

// MARK: - Environment Definition

public enum AppEnvironment: CustomStringConvertible {
    case development
    case staging
    case production

    public var description: String {
        switch self {
        case .development: return "development"
        case .staging: return "staging"
        case .production: return "production"
        }
    }

    // MARK: - Current Environment Detection
    
    static var current: AppEnvironment {
        #if DEBUG
        // Check for override in UserDefaults (for testing)
        if let override = UserDefaults.standard.string(forKey: "environment_override") {
            switch override {
            case "staging":
                return .staging
            case "production":
                return .production
            default:
                return .development
            }
        }
        return .development
        #else
            #if STAGING
            return .staging
            #else
            return .production
            #endif
        #endif
    }
    
    // MARK: - API Configuration
    
    // MARK: - Local Configuration
    
    var enableLocalProcessing: Bool {
        return true // All processing is now local
    }
    
    // MARK: - Feature Flags
    
    var enableLocalAnalytics: Bool {
        return self == .production
    }
    
    var enableDebugLogging: Bool {
        return self == .development
    }
    
    var enableTestMode: Bool {
        return self == .development
    }
    
    var enableLocalCaching: Bool {
        switch self {
        case .development:
            return false
        case .staging:
            return true
        case .production:
            return true
        }
    }
    
    // MARK: - Rate Limits
    
    var rateLimitPerMinute: Int {
        switch self {
        case .development:
            return 100
        case .staging:
            return 20
        case .production:
            return 10
        }
    }
    
    var rateLimitPerHour: Int {
        switch self {
        case .development:
            return 1000
        case .staging:
            return 200
        case .production:
            return 100
        }
    }
    
    var rateLimitPerDay: Int {
        switch self {
        case .development:
            return 10000
        case .staging:
            return 2000
        case .production:
            return 1000
        }
    }
    
    // MARK: - Performance Settings
    
    var requestTimeout: TimeInterval {
        switch self {
        case .development:
            return 300 // 5 minutes for debugging
        case .staging:
            return 30
        case .production:
            return 60
        }
    }
    
    var maxCacheAge: TimeInterval {
        switch self {
        case .development:
            return 60 // 1 minute
        case .staging:
            return 1800 // 30 minutes
        case .production:
            return 3600 // 1 hour
        }
    }
    
    // MARK: - Monitoring
    
    var sentryDSN: String? {
        switch self {
        case .development:
            return nil
        case .staging:
            return "YOUR_STAGING_SENTRY_DSN" // Replace with actual DSN
        case .production:
            return "YOUR_PRODUCTION_SENTRY_DSN" // Replace with actual DSN
        }
    }
    
    var logLevel: LogLevel {
        switch self {
        case .development:
            return .debug
        case .staging:
            return .info
        case .production:
            return .warning
        }
    }
}

// MARK: - Log Level

public enum LogLevel: Int, Comparable {
    case debug = 0
    case info = 1
    case warning = 2
    case error = 3
    
    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Configuration Manager

@MainActor
public final class ConfigurationManager {
    public static let shared = ConfigurationManager()

    public let environment = AppEnvironment.current
    private var isConfigured = false
    private let logger = Logger(subsystem: "com.anaxoniclabs.balli", category: "app.configuration")

    private init() {}
    
    /// Configure the app for the current environment
    public func configure() {
        guard !isConfigured else { return }
        isConfigured = true

        logger.notice("Configuring Balli for \(self.environment) environment (Local Processing Mode)")

        // Configure logging
        configureLogging()

        // Configure network security
        configureNetworkSecurity()

        // Log configuration
        logConfiguration()
    }
    
    
    private func configureLogging() {
        // Configure app-wide logging
        // Note: OSLog automatically handles log levels based on build configuration
        // DEBUG builds show debug/info, RELEASE builds show notice/error/fault

        if environment.enableDebugLogging {
            logger.info("Debug logging enabled")
        } else {
            logger.info("Production logging enabled")
        }

        logger.info("Logging configured")
    }
    
    private func configureNetworkSecurity() {
        // Configure ATS exceptions for development
        if environment == .development {
            // Development allows localhost connections
            logger.notice("Network security relaxed for development")
        } else {
            // Production enforces strict HTTPS
            logger.info("Network security enforced")
        }
    }
    
    private func logConfiguration() {
        logger.notice("""
        Configuration Summary:
        Environment: \(self.environment), \
        Mode: Local Processing, \
        Analytics: \(self.environment.enableLocalAnalytics), \
        Caching: \(self.environment.enableLocalCaching), \
        Debug: \(self.environment.enableDebugLogging), \
        Test Mode: \(self.environment.enableTestMode), \
        Timeout: \(self.environment.requestTimeout)s, \
        Cache TTL: \(self.environment.maxCacheAge)s
        """)
    }
    
    /// Check if app is running in TestFlight
    public var isTestFlight: Bool {
        #if DEBUG
        return false
        #else
        // Use app receipt path checking without deprecated API
        guard let receiptURL = Bundle.main.url(forResource: "sandboxReceipt", withExtension: nil) else {
            return false
        }
        return FileManager.default.fileExists(atPath: receiptURL.path)
        #endif
    }

    /// Check if app is running in App Store
    public var isAppStore: Bool {
        guard !isTestFlight else { return false }

        #if DEBUG
        return false
        #else
        // Check for production receipt without deprecated API
        guard let receiptURL = Bundle.main.url(forResource: "receipt", withExtension: nil) else {
            return false
        }
        return FileManager.default.fileExists(atPath: receiptURL.path)
        #endif
    }
    
    /// Get user-friendly environment name
    public var environmentName: String {
        if isAppStore {
            return "Production"
        } else if isTestFlight {
            return "TestFlight"
        } else {
            switch environment {
            case .development:
                return "Development"
            case .staging:
                return "Staging"
            case .production:
                return "Production (Debug)"
            }
        }
    }
}

// MARK: - Environment Info View (for debugging)

import SwiftUI

public struct EnvironmentInfoView: View {
    let config = ConfigurationManager.shared
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Environment: \(config.environmentName)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("Mode: Local Processing")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            if config.environment.enableDebugLogging {
                Text("Debug Mode")
                    .font(.caption2)
                    .foregroundColor(.orange)
            }
        }
        .padding(8)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}