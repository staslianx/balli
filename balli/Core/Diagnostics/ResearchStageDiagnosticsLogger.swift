//
//  ResearchStageDiagnosticsLogger.swift
//  balli
//
//  Research stage diagnostic log capture and export
//  Swift 6 strict concurrency compliant
//  Captures FORENSIC logs for debugging stage visibility issues
//

import Foundation
import OSLog
import UIKit

/// Actor-based logger that captures research stage forensic logs
actor ResearchStageDiagnosticsLogger {

    // MARK: - Singleton

    static let shared = ResearchStageDiagnosticsLogger()

    // MARK: - Properties

    private var logEntries: [LogEntry] = []
    private let maxLogEntries = 10000 // ~1000 research queries worth of logs
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.anaxoniclabs.balli", category: "ResearchStageDiagnostics")

    // MARK: - Log Entry Model

    struct LogEntry: Identifiable, Sendable {
        let id = UUID()
        let timestamp: Date
        let level: LogLevel
        let category: LogCategory
        let message: String
        let answerId: String?
        let metadata: [String: String]?

        enum LogLevel: String, Sendable {
            case info = "ℹ️"
            case warning = "⚠️"
            case error = "❌"
            case success = "✅"
            case debug = "🔍"
        }

        enum LogCategory: String, Sendable {
            case sseEvent = "📡 SSE Event"
            case stageQueue = "📋 Stage Queue"
            case stageTransition = "🔄 Stage Transition"
            case observer = "👁️ Observer"
            case viewRendering = "🎨 View Rendering"
            case viewReadySignal = "🚦 View Ready"
            case timing = "⏱️ Timing"
            case dataFlow = "🔀 Data Flow"
        }

        var formattedTimestamp: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss.SSS"
            return formatter.string(from: timestamp)
        }

        var fullLogLine: String {
            var line = "\(formattedTimestamp) \(level.rawValue) \(category.rawValue): \(message)"
            if let answerId = answerId {
                line += " [Answer: \(answerId.prefix(8))]"
            }
            if let metadata = metadata, !metadata.isEmpty {
                let metaStr = metadata.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
                line += " {\(metaStr)}"
            }
            return line
        }
    }

    // MARK: - Statistics

    struct LogStatistics: Sendable {
        let totalLogs: Int
        let errorCount: Int
        let warningCount: Int
        let oldestLog: Date?
        let newestLog: Date?

        // Stage-specific stats
        let sseEventCount: Int
        let stageTransitionCount: Int
        let observerPollCount: Int
        let viewRenderCount: Int
        let viewReadySignalCount: Int

        var durationDescription: String {
            guard let oldest = oldestLog, let newest = newestLog else {
                return "N/A"
            }
            let duration = newest.timeIntervalSince(oldest)
            if duration < 60 {
                return "\(Int(duration))s"
            } else if duration < 3600 {
                return "\(Int(duration / 60))m"
            } else {
                return "\(Int(duration / 3600))h"
            }
        }
    }

    // MARK: - Initialization

    private init() {
        logger.info("ResearchStageDiagnosticsLogger initialized - ready to capture research stage logs")
    }

    // MARK: - Log Capture

    /// Log an SSE event received from backend
    func logSSEEvent(_ message: String, answerId: String? = nil, metadata: [String: String]? = nil, level: LogEntry.LogLevel = .info) {
        addEntry(category: .sseEvent, level: level, message: message, answerId: answerId, metadata: metadata)
    }

    /// Log a stage queue operation
    func logStageQueue(_ message: String, answerId: String? = nil, metadata: [String: String]? = nil, level: LogEntry.LogLevel = .info) {
        addEntry(category: .stageQueue, level: level, message: message, answerId: answerId, metadata: metadata)
    }

    /// Log a stage transition
    func logStageTransition(_ message: String, answerId: String? = nil, metadata: [String: String]? = nil, level: LogEntry.LogLevel = .info) {
        addEntry(category: .stageTransition, level: level, message: message, answerId: answerId, metadata: metadata)
    }

    /// Log an observer event
    func logObserver(_ message: String, answerId: String? = nil, metadata: [String: String]? = nil, level: LogEntry.LogLevel = .debug) {
        addEntry(category: .observer, level: level, message: message, answerId: answerId, metadata: metadata)
    }

    /// Log a view rendering event
    func logViewRendering(_ message: String, answerId: String? = nil, metadata: [String: String]? = nil, level: LogEntry.LogLevel = .info) {
        addEntry(category: .viewRendering, level: level, message: message, answerId: answerId, metadata: metadata)
    }

    /// Log a view ready signal
    func logViewReady(_ message: String, answerId: String? = nil, metadata: [String: String]? = nil, level: LogEntry.LogLevel = .info) {
        addEntry(category: .viewReadySignal, level: level, message: message, answerId: answerId, metadata: metadata)
    }

    /// Log a timing event
    func logTiming(_ message: String, answerId: String? = nil, metadata: [String: String]? = nil, level: LogEntry.LogLevel = .info) {
        addEntry(category: .timing, level: level, message: message, answerId: answerId, metadata: metadata)
    }

    /// Log a data flow event
    func logDataFlow(_ message: String, answerId: String? = nil, metadata: [String: String]? = nil, level: LogEntry.LogLevel = .debug) {
        addEntry(category: .dataFlow, level: level, message: message, answerId: answerId, metadata: metadata)
    }

    /// Add a log entry
    private func addEntry(category: LogEntry.LogCategory, level: LogEntry.LogLevel, message: String, answerId: String?, metadata: [String: String]?) {
        let entry = LogEntry(
            timestamp: Date(),
            level: level,
            category: category,
            message: message,
            answerId: answerId,
            metadata: metadata
        )

        logEntries.append(entry)

        // Trim old entries if exceeding max
        if logEntries.count > maxLogEntries {
            logEntries.removeFirst(logEntries.count - maxLogEntries)
        }

        // Also log to system logger for Console.app
        let logMessage = "\(category.rawValue): \(message)" + (answerId.map { " [Answer: \($0.prefix(8))]" } ?? "")
        switch level {
        case .info, .success:
            logger.info("\(logMessage)")
        case .warning:
            logger.warning("\(logMessage)")
        case .error:
            logger.error("\(logMessage)")
        case .debug:
            logger.debug("\(logMessage)")
        }
    }

    // MARK: - Log Retrieval

    /// Get all log entries
    func getAllLogs() -> [LogEntry] {
        logEntries
    }

    /// Get logs from the last N hours
    func getLogsFromLastHours(_ hours: Int) -> [LogEntry] {
        let cutoffDate = Date().addingTimeInterval(-Double(hours) * 3600)
        return logEntries.filter { $0.timestamp >= cutoffDate }
    }

    /// Get logs by category
    func getLogs(category: LogEntry.LogCategory) -> [LogEntry] {
        logEntries.filter { $0.category == category }
    }

    /// Get logs by answer ID
    func getLogs(answerId: String) -> [LogEntry] {
        logEntries.filter { $0.answerId == answerId }
    }

    /// Get logs by level
    func getLogs(level: LogEntry.LogLevel) -> [LogEntry] {
        logEntries.filter { $0.level == level }
    }

    // MARK: - Statistics

    /// Get statistics about captured logs
    func getStatistics() -> LogStatistics {
        LogStatistics(
            totalLogs: logEntries.count,
            errorCount: logEntries.filter { $0.level == .error }.count,
            warningCount: logEntries.filter { $0.level == .warning }.count,
            oldestLog: logEntries.first?.timestamp,
            newestLog: logEntries.last?.timestamp,
            sseEventCount: logEntries.filter { $0.category == .sseEvent }.count,
            stageTransitionCount: logEntries.filter { $0.category == .stageTransition }.count,
            observerPollCount: logEntries.filter { $0.category == .observer }.count,
            viewRenderCount: logEntries.filter { $0.category == .viewRendering }.count,
            viewReadySignalCount: logEntries.filter { $0.category == .viewReadySignal }.count
        )
    }

    // MARK: - Clear Logs

    /// Clear all log entries
    func clearLogs() {
        logEntries.removeAll()
        logger.info("All research stage diagnostic logs cleared")
    }

    // MARK: - Export

    enum ExportFormat {
        case text
        case json
    }

    /// Save logs to file and return URL for sharing
    func saveLogsToFile(format: ExportFormat) throws -> URL {
        let fileName: String
        let content: String

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = dateFormatter.string(from: Date())

        switch format {
        case .text:
            fileName = "research_stage_diagnostics_\(timestamp).txt"
            content = generateTextExport()
        case .json:
            fileName = "research_stage_diagnostics_\(timestamp).json"
            content = try generateJSONExport()
        }

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try content.write(to: tempURL, atomically: true, encoding: .utf8)

        logger.info("Exported research stage logs to \(tempURL.path)")
        return tempURL
    }

    private func generateTextExport() -> String {
        var output = """
        ===============================================
        RESEARCH STAGE DIAGNOSTICS EXPORT
        ===============================================
        Export Date: \(Date())
        Total Logs: \(logEntries.count)
        Device: \(UIDevice.current.model)
        iOS Version: \(UIDevice.current.systemVersion)
        ===============================================


        """

        for entry in logEntries {
            output += entry.fullLogLine + "\n"
        }

        return output
    }

    private func generateJSONExport() throws -> String {
        let exportData: [String: Any] = [
            "exportDate": ISO8601DateFormatter().string(from: Date()),
            "device": UIDevice.current.model,
            "iosVersion": UIDevice.current.systemVersion,
            "totalLogs": logEntries.count,
            "logs": logEntries.map { entry in
                var dict: [String: Any] = [
                    "timestamp": ISO8601DateFormatter().string(from: entry.timestamp),
                    "level": entry.level.rawValue,
                    "category": entry.category.rawValue,
                    "message": entry.message
                ]
                if let answerId = entry.answerId {
                    dict["answerId"] = answerId
                }
                if let metadata = entry.metadata {
                    dict["metadata"] = metadata
                }
                return dict
            }
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: exportData, options: [.prettyPrinted, .sortedKeys])
        return String(data: jsonData, encoding: .utf8) ?? ""
    }
}
