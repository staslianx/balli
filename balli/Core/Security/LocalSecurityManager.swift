//
//  LocalSecurityManager.swift
//  balli
//
//  Provides basic rate limiting and security checks
//

import Foundation

// MARK: - Local Security Manager
actor SecurityManager {
    static let shared = SecurityManager()
    
    // MARK: - Rate Limiting Properties
    private var scanHistory: [Date] = []
    private let maxScansPerHour = 30
    private let maxScansPerDay = 100
    
    private init() {}
    
    // MARK: - Public Methods
    func canPerformAIScan() async -> Bool {
        // Clean up old entries
        await cleanupOldScans()
        
        // Check hourly limit
        let oneHourAgo = Date().addingTimeInterval(-3600)
        let recentScans = scanHistory.filter { $0 > oneHourAgo }
        if recentScans.count >= maxScansPerHour {
            return false
        }
        
        // Check daily limit
        let oneDayAgo = Date().addingTimeInterval(-86400)
        let dailyScans = scanHistory.filter { $0 > oneDayAgo }
        if dailyScans.count >= maxScansPerDay {
            return false
        }
        
        return true
    }
    
    func recordAIScan() async {
        scanHistory.append(Date())
        await cleanupOldScans()
    }
    
    func getRemainingScans() async -> Int {
        await cleanupOldScans()
        
        let oneHourAgo = Date().addingTimeInterval(-3600)
        let recentScans = scanHistory.filter { $0 > oneHourAgo }
        
        return max(0, maxScansPerHour - recentScans.count)
    }
    
    // MARK: - API Security Methods
    func validateAPIAccess() async -> Bool {
        // Always return true for local development
        return true
    }
    
    // MARK: - API Key Security (for test compatibility)
    nonisolated static func validateBundleID() -> Bool {
        guard let bundleId = Bundle.main.bundleIdentifier else {
            return false
        }
        return bundleId == "com.anaxoniclabs.balli"
    }
    
    nonisolated static func obfuscateAPIKey(_ key: String) -> String {
        // Simple Base64 encoding for obfuscation
        return Data(key.utf8).base64EncodedString()
    }
    
    nonisolated static func deobfuscateAPIKey(_ obfuscatedKey: String) -> String {
        guard let data = Data(base64Encoded: obfuscatedKey),
              let decodedKey = String(data: data, encoding: .utf8) else {
            return ""
        }
        return decodedKey
    }
    
    // MARK: - Private Methods
    private func cleanupOldScans() async {
        let oneDayAgo = Date().addingTimeInterval(-86400)
        scanHistory = scanHistory.filter { $0 > oneDayAgo }
    }
}