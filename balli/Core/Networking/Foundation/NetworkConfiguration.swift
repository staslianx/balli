//
//  NetworkConfiguration.swift
//  balli
//
//  Network layer configuration
//

import Foundation

/// Configuration for network layer with environment-based settings
final class NetworkConfiguration: ObservableObject, Sendable {
    static let shared = NetworkConfiguration()
    
    // MARK: - Environment Configuration
    
    private let isProduction = !_isDebugAssertConfiguration()
    private let productionBaseURL = "https://us-central1-balli-project.cloudfunctions.net"

    /// Base URL for network functions
    /// Always points to the production Functions endpoint unless a runtime override is provided.
    var baseURL: String {
        if let override = UserDefaults.standard.string(forKey: "balli.customBaseURL"),
           !override.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return override
        }

        return productionBaseURL
    }
    
    // MARK: - Timeout Configuration
    
    /// Request timeout for standard API calls
    let standardTimeout: TimeInterval = 30.0
    
    /// Request timeout for AI/streaming operations
    let aiTimeout: TimeInterval = 120.0
    
    /// Resource timeout for file uploads
    let uploadTimeout: TimeInterval = 300.0
    
    // MARK: - Retry Configuration
    
    /// Maximum number of retry attempts
    let maxRetryAttempts = 3
    
    /// Base delay for exponential backoff (in seconds)
    let retryBaseDelay: Double = 1.0
    
    /// Maximum delay for exponential backoff (in seconds)
    let retryMaxDelay: Double = 10.0
    
    // MARK: - Rate Limiting
    
    /// Maximum requests per minute for health data endpoints
    let healthDataRateLimit = 60
    
    /// Maximum requests per minute for AI endpoints
    let aiRateLimit = 30
    
    // MARK: - Security Configuration
    
    /// Enable request/response logging (disabled in production for HIPAA compliance)
    var enableLogging: Bool {
        return !isProduction
    }
    
    /// Enable health data encryption in requests
    let enableHealthDataEncryption = true
    
    /// API version for versioned endpoints
    let apiVersion = "v1"
    
    // MARK: - Health Data Compliance
    
    /// Fields that should be encrypted before transmission
    let encryptedHealthFields: Set<String> = [
        "glucoseLevel",
        "bloodPressure",
        "heartRate",
        "medications",
        "symptoms",
        "personalNotes"
    ]
    
    /// Fields that should be sanitized from logs
    let sensitiveLogFields: Set<String> = [
        "glucoseLevel",
        "bloodPressure",
        "heartRate",
        "medications",
        "symptoms",
        "personalNotes",
        "birthDate",
        "address",
        "phone"
    ]
    
    private init() {}
}

// MARK: - Environment Detection Extensions

extension NetworkConfiguration {
    /// Current environment description
    var environmentDescription: String {
        return isProduction ? "Production" : "Development"
    }
    
    /// Check if running in emulator mode
    var isEmulatorMode: Bool {
        return !isProduction
    }
}
