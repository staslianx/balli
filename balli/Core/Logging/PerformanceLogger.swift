//
//  PerformanceLogger.swift
//  balli
//
//  Created by Claude on 9.08.2025.
//

import Foundation
import os.log

// MARK: - Performance-Aware Logger Wrapper
actor PerformanceLogger {
    private let subsystem: String
    private let category: String
    private let osLogger: os.Logger
    private var logBuffer: [LogEntry] = []
    private let bufferSize = 100
    
    #if DEBUG
    private let logLevel: OSLogType = .debug
    private let enableBuffering = false  // Immediate logging in debug
    #else
    private let logLevel: OSLogType = .error  // Production: errors only
    private let enableBuffering = true   // Buffer non-critical logs
    #endif
    
    private struct LogEntry {
        let message: String
        let type: OSLogType
        let timestamp: Date
    }
    
    init(subsystem: String, category: String) {
        self.subsystem = subsystem
        self.category = category
        self.osLogger = os.Logger(subsystem: subsystem, category: category)
    }
    
    // MARK: - Logging Methods
    
    func debug(_ message: String) {
        log(message, type: .debug)
    }
    
    func info(_ message: String) {
        log(message, type: .info)
    }
    
    func warning(_ message: String) {
        log(message, type: .default)
    }
    
    func error(_ message: String) {
        log(message, type: .error)
    }
    
    func fault(_ message: String) {
        log(message, type: .fault)
    }
    
    // MARK: - Core Logging Implementation
    
    private func log(_ message: String, type: OSLogType) {
        #if DEBUG
        // Debug builds: log immediately for development visibility
        osLogger.log(level: type, "\(message, privacy: .public)")
        #else
        // Production builds: performance-aware logging
        if shouldLogImmediately(type: type) {
            osLogger.log(level: type, "\(message, privacy: .public)")
        } else if enableBuffering {
            bufferLog(message: message, type: type)
        }
        #endif
    }
    
    private func shouldLogImmediately(type: OSLogType) -> Bool {
        // Always log errors and faults immediately
        return type == .error || type == .fault
    }
    
    private func bufferLog(message: String, type: OSLogType) {
        let entry = LogEntry(message: message, type: type, timestamp: Date())
        logBuffer.append(entry)
        
        // Flush buffer when it gets too large
        if logBuffer.count >= bufferSize {
            flushBuffer()
        }
    }
    
    private func flushBuffer() {
        for entry in logBuffer {
            osLogger.log(level: entry.type, "\(entry.message, privacy: .public)")
        }
        logBuffer.removeAll(keepingCapacity: true)
    }
    
    // MARK: - Performance Monitoring
    
    func logPerformanceMetric(operation: String, duration: TimeInterval, success: Bool) {
        #if DEBUG
        let status = success ? "✅" : "❌"
        let message = "\(status) \(operation): \(String(format: "%.2f", duration))s"
        osLogger.log(level: .info, "\(message, privacy: .public)")
        #else
        // In production, only log performance issues
        if duration > 1.0 || !success {
            let status = success ? "⚠️" : "❌"
            let message = "\(status) \(operation): \(String(format: "%.2f", duration))s"
            osLogger.log(level: .default, "\(message, privacy: .public)")
        }
        #endif
    }
    
    // MARK: - Memory Pressure Aware Logging
    
    func logWithMemoryAwareness(_ message: String, type: OSLogType = .info) {
        // Check memory pressure
        let memoryPressure = getMemoryPressure()
        
        switch memoryPressure {
        case .low:
            log(message, type: type)
        case .moderate:
            // Only log warnings and errors
            if type == .default || type == .error || type == .fault {
                log(message, type: type)
            }
        case .high:
            // Only log errors and faults
            if type == .error || type == .fault {
                log(message, type: type)
            }
        }
    }
    
    private func getMemoryPressure() -> MemoryPressure {
        let info = ProcessInfo.processInfo
        let physicalMemory = info.physicalMemory
        let footprint = getCurrentMemoryFootprint()
        
        let usagePercent = Double(footprint) / Double(physicalMemory) * 100
        
        switch usagePercent {
        case 0..<5: return .low
        case 5..<10: return .moderate
        default: return .high
        }
    }
    
    private func getCurrentMemoryFootprint() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        return result == KERN_SUCCESS ? info.resident_size : 0
    }
    
    // MARK: - Cleanup
    
    deinit {
        // Flush any remaining buffered logs synchronously
        if !logBuffer.isEmpty {
            for entry in logBuffer {
                osLogger.log(level: entry.type, "\(entry.message, privacy: .public)")
            }
        }
    }
}

// MARK: - Supporting Types

enum MemoryPressure {
    case low
    case moderate
    case high
}

// MARK: - Global Logger Factory (Legacy)
// ⚠️ DEPRECATED: Use AppLoggers in Core/Utilities instead
//
// Migration Guide:
// OLD: await PerformanceAppLoggers.shared.logger(category: "network").info("Request")
// NEW: AppLoggers.Network.api.info("Request")
//
// See Core/Utilities/AppLoggers.swift for the modern logging API.

@available(*, deprecated, message: "Use AppLoggers instead. See Core/Utilities/AppLoggers.swift")
@MainActor
final class PerformanceAppLoggers: @unchecked Sendable {
    @available(*, deprecated, message: "Use AppLoggers instead")
    static let shared = PerformanceAppLoggers()
    private var loggers: [String: PerformanceLogger] = [:]

    private init() {}

    func logger(subsystem: String = "com.balli.diabetes", category: String) -> PerformanceLogger {
        let key = "\(subsystem).\(category)"

        if let existingLogger = loggers[key] {
            return existingLogger
        }

        let newLogger = PerformanceLogger(subsystem: subsystem, category: category)
        loggers[key] = newLogger
        return newLogger
    }
}

// MARK: - Convenience Extensions

extension PerformanceLogger {
    // Performance budget tracking
    func trackOperation<T: Sendable>(
        _ name: String,
        maxDuration: TimeInterval = 1.0,
        operation: @Sendable () async throws -> T
    ) async rethrows -> T {
        let startTime = Date()
        
        let result = try await operation()
        
        let duration = Date().timeIntervalSince(startTime)
        logPerformanceMetric(
            operation: name,
            duration: duration,
            success: duration <= maxDuration
        )
        
        return result
    }
}