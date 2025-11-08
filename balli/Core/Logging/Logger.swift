//
//  Logger.swift
//  balli
//
//  Created by Claude on 4.08.2025.
//
// ⚠️ DEPRECATED: This legacy logger is deprecated. Use AppLoggers instead.
//
// Migration Guide:
// OLD: LegacyLogger.shared.info("Message", category: .app)
// NEW: AppLoggers.App.lifecycle.info("Message")
//
// See Core/Utilities/AppLoggers.swift for available categories and usage examples.
//
// This file is kept for backward compatibility only and will be removed in a future version.

import Foundation
import os.log

@available(*, deprecated, message: "Use AppLoggers instead. See Core/Utilities/AppLoggers.swift for the modern logging API.")
final class LegacyLogger: Sendable {
    @available(*, deprecated, message: "Use AppLoggers instead")
    static let shared = LegacyLogger()
    
    // MARK: - Categories
    
    enum Category: String, CaseIterable {
        case app = "App"
        case camera = "Camera" 
        case ai = "AI"
        case health = "Health"
        case data = "Data"
        case ui = "UI"
        case network = "Network"
        case performance = "Performance"
        case security = "Security"
        case authentication = "Authentication"
        case session = "Session"
        
        var icon: String {
            switch self {
            case .app: return "📱"
            case .camera: return "📸"
            case .ai: return "🤖"
            case .health: return " "
            case .data: return "💾"
            case .ui: return "🎨"
            case .network: return "🌐"
            case .performance: return "⚡"
            case .security: return "🔒"
            case .authentication: return "🔐"
            case .session: return "⏱️"
            }
        }
    }
    
    // MARK: - Properties
    
    private let subsystem: String
    private let loggers: [Category: OSLog]
    
    // MARK: - Initialization
    
    private init() {
        self.subsystem = Bundle.main.bundleIdentifier ?? "com.anaxoniclabs.balli"
        
        var tempLoggers: [Category: OSLog] = [:]
        for category in Category.allCases {
            tempLoggers[category] = OSLog(subsystem: subsystem, category: category.rawValue)
        }
        self.loggers = tempLoggers
    }
    
    // MARK: - Logging Methods
    
    func debug(_ message: String, category: Category = .app, file: String = #file, function: String = #function, line: Int = #line) {
        guard let logger = loggers[category] else { return }
        
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let formattedMessage = "\(category.icon) [\(fileName):\(line)] \(function) - \(message)"
        
        os_log(.debug, log: logger, "%{public}@", formattedMessage)
    }
    
    func info(_ message: String, category: Category = .app, file: String = #file, function: String = #function, line: Int = #line) {
        guard let logger = loggers[category] else { return }
        
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let formattedMessage = "\(category.icon) [\(fileName):\(line)] \(function) - \(message)"
        
        os_log(.info, log: logger, "%{public}@", formattedMessage)
    }
    
    func warning(_ message: String, category: Category = .app, file: String = #file, function: String = #function, line: Int = #line) {
        guard let logger = loggers[category] else { return }
        
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let formattedMessage = "⚠️ \(category.icon) [\(fileName):\(line)] \(function) - \(message)"
        
        os_log(.error, log: logger, "%{public}@", formattedMessage)
    }
    
    func error(_ message: String, category: Category = .app, file: String = #file, function: String = #function, line: Int = #line) {
        guard let logger = loggers[category] else { return }
        
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let formattedMessage = "❌ \(category.icon) [\(fileName):\(line)] \(function) - \(message)"
        
        os_log(.fault, log: logger, "%{public}@", formattedMessage)
    }
    
    func critical(_ message: String, category: Category = .app, file: String = #file, function: String = #function, line: Int = #line) {
        guard let logger = loggers[category] else { return }
        
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let formattedMessage = "🚨 \(category.icon) [\(fileName):\(line)] \(function) - CRITICAL: \(message)"
        
        os_log(.fault, log: logger, "%{public}@", formattedMessage)
    }
    
    // MARK: - Diabetes-Specific Logging
    
    func logBloodSugar(_ value: Double, unit: String = "mg/dL") {
        info("Blood sugar logged: \(value) \(unit)", category: .health)
    }
    
    func logCarbs(_ amount: Double, foodName: String = "") {
        let food = foodName.isEmpty ? "" : " (\(foodName))"
        info("Carbs logged: \(amount)g\(food)", category: .health)
    }
    
    func logAIAnalysis(confidence: Double, item: String) {
        info("AI analysis: \(item) with \(Int(confidence * 100))% confidence", category: .ai)
    }
    
    func logCameraEvent(_ event: String) {
        info("Camera: \(event)", category: .camera)
    }
    
    func logPerformance(_ operation: String, duration: TimeInterval) {
        info("Performance: \(operation) took \(String(format: "%.3f", duration))s", category: .performance)
    }
    
    func logDataOperation(_ operation: String, success: Bool) {
        if success {
            info("Data: \(operation) completed successfully", category: .data)
        } else {
            error("Data: \(operation) failed", category: .data)
        }
    }
    
    // MARK: - Privacy-Safe Logging
    
    func logSensitiveData(_ operation: String, success: Bool) {
        // For HIPAA compliance, don't log actual health data values
        if success {
            info("Health data operation completed: \(operation)", category: .security)
        } else {
            error("Health data operation failed: \(operation)", category: .security)
        }
    }
}

// MARK: - Convenience Extensions

@available(*, deprecated, message: "Use AppLoggers instead")
extension LegacyLogger {
    static func debug(_ message: String, category: Category = .app, file: String = #file, function: String = #function, line: Int = #line) {
        shared.debug(message, category: category, file: file, function: function, line: line)
    }

    static func info(_ message: String, category: Category = .app, file: String = #file, function: String = #function, line: Int = #line) {
        shared.info(message, category: category, file: file, function: function, line: line)
    }

    static func warning(_ message: String, category: Category = .app, file: String = #file, function: String = #function, line: Int = #line) {
        shared.warning(message, category: category, file: file, function: function, line: line)
    }

    static func error(_ message: String, category: Category = .app, file: String = #file, function: String = #function, line: Int = #line) {
        shared.error(message, category: category, file: file, function: function, line: line)
    }

    static func critical(_ message: String, category: Category = .app, file: String = #file, function: String = #function, line: Int = #line) {
        shared.critical(message, category: category, file: file, function: function, line: line)
    }
}