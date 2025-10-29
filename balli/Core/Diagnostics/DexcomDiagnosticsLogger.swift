//
//  DexcomDiagnosticsLogger.swift
//  balli
//
//  Dexcom-specific diagnostic log capture and export
//  Swift 6 strict concurrency compliant
//  Captures FORENSIC logs for debugging auto-logout and data contamination
//

import Foundation
import OSLog
import UIKit

/// Actor-based logger that captures Dexcom-specific forensic logs
actor DexcomDiagnosticsLogger {

    // MARK: - Singleton

    static let shared = DexcomDiagnosticsLogger()

    // MARK: - Properties

    private var logEntries: [LogEntry] = []
    private let maxLogEntries = 10000 // ~24 hours of logs at 1 entry per 10 seconds
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.anaxoniclabs.balli", category: "DexcomDiagnostics")

    // MARK: - Log Entry Model

    struct LogEntry: Identifiable, Sendable {
        let id = UUID()
        let timestamp: Date
        let level: LogLevel
        let category: LogCategory
        let message: String

        enum LogLevel: String, Sendable {
            case info = "ℹ️"
            case warning = "⚠️"
            case error = "❌"
            case success = "✅"
            case debug = "🔍"
        }

        enum LogCategory: String, Sendable {
            case authentication = "🔐 Auth"
            case connection = "🔌 Connection"
            case tokenRefresh = "🔄 Token Refresh"
            case dataSync = "📊 Data Sync"
            case keychain = "🔑 Keychain"
            case lifecycle = "♻️ Lifecycle"
            case repository = "💾 Repository"
        }

        var formattedTimestamp: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss.SSS"
            return formatter.string(from: timestamp)
        }

        var fullLogLine: String {
            "\(formattedTimestamp) \(level.rawValue) \(category.rawValue): \(message)"
        }
    }

    // MARK: - Initialization

    private init() {
        logger.info("DexcomDiagnosticsLogger initialized - ready to capture Dexcom logs")
    }

    // MARK: - Log Capture

    /// Log an authentication event
    func logAuth(_ message: String, level: LogEntry.LogLevel = .info) {
        addEntry(category: .authentication, level: level, message: message)
    }

    /// Log a connection event
    func logConnection(_ message: String, level: LogEntry.LogLevel = .info) {
        addEntry(category: .connection, level: level, message: message)
    }

    /// Log a token refresh event
    func logTokenRefresh(_ message: String, level: LogEntry.LogLevel = .info) {
        addEntry(category: .tokenRefresh, level: level, message: message)
    }

    /// Log a data sync event
    func logDataSync(_ message: String, level: LogEntry.LogLevel = .info) {
        addEntry(category: .dataSync, level: level, message: message)
    }

    /// Log a keychain event
    func logKeychain(_ message: String, level: LogEntry.LogLevel = .info) {
        addEntry(category: .keychain, level: level, message: message)
    }

    /// Log an app lifecycle event
    func logLifecycle(_ message: String, level: LogEntry.LogLevel = .info) {
        addEntry(category: .lifecycle, level: level, message: message)
    }

    /// Log a repository/data persistence event
    func logRepository(_ message: String, level: LogEntry.LogLevel = .info) {
        addEntry(category: .repository, level: level, message: message)
    }

    /// Add a log entry
    private func addEntry(category: LogEntry.LogCategory, level: LogEntry.LogLevel, message: String) {
        let entry = LogEntry(
            timestamp: Date(),
            level: level,
            category: category,
            message: message
        )

        logEntries.append(entry)

        // Trim old entries if exceeding max
        if logEntries.count > maxLogEntries {
            logEntries.removeFirst(logEntries.count - maxLogEntries)
        }

        // Also log to system logger for Console.app
        switch level {
        case .info, .success, .debug:
            logger.info("\(category.rawValue): \(message)")
        case .warning:
            logger.warning("\(category.rawValue): \(message)")
        case .error:
            logger.error("\(category.rawValue): \(message)")
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

    /// Get logs by level
    func getLogs(level: LogEntry.LogLevel) -> [LogEntry] {
        logEntries.filter { $0.level == level }
    }

    /// Get error logs only
    func getErrorLogs() -> [LogEntry] {
        logEntries.filter { $0.level == .error }
    }

    /// Get recent logs (last N entries)
    func getRecentLogs(count: Int = 100) -> [LogEntry] {
        Array(logEntries.suffix(count))
    }

    // MARK: - Statistics

    /// Get log statistics
    func getStatistics() -> LogStatistics {
        let totalLogs = logEntries.count
        let errorCount = logEntries.filter { $0.level == .error }.count
        let warningCount = logEntries.filter { $0.level == .warning }.count
        let oldestLog = logEntries.first?.timestamp
        let newestLog = logEntries.last?.timestamp

        let categoryCounts = Dictionary(grouping: logEntries) { $0.category }
            .mapValues { $0.count }

        return LogStatistics(
            totalLogs: totalLogs,
            errorCount: errorCount,
            warningCount: warningCount,
            oldestLogDate: oldestLog,
            newestLogDate: newestLog,
            categoryCounts: categoryCounts
        )
    }

    struct LogStatistics: Sendable {
        let totalLogs: Int
        let errorCount: Int
        let warningCount: Int
        let oldestLogDate: Date?
        let newestLogDate: Date?
        let categoryCounts: [LogEntry.LogCategory: Int]

        var duration: TimeInterval? {
            guard let oldest = oldestLogDate, let newest = newestLogDate else { return nil }
            return newest.timeIntervalSince(oldest)
        }

        var durationDescription: String {
            guard let duration = duration else { return "No logs" }
            let hours = Int(duration / 3600)
            let minutes = Int((duration.truncatingRemainder(dividingBy: 3600)) / 60)
            return "\(hours)h \(minutes)m"
        }
    }

    // MARK: - Export

    /// Export logs to a formatted string
    func exportLogsAsText() -> String {
        var output = """
        ═══════════════════════════════════════════════════════════════
        BALLI - DEXCOM DIAGNOSTICS LOG EXPORT
        ═══════════════════════════════════════════════════════════════

        Export Date: \(Date().formatted(date: .complete, time: .complete))
        Total Logs: \(logEntries.count)

        """

        let stats = getStatistics()
        output += """

        📊 STATISTICS
        ───────────────────────────────────────────────────────────────
        Log Duration: \(stats.durationDescription)
        Total Entries: \(stats.totalLogs)
        Errors: \(stats.errorCount)
        Warnings: \(stats.warningCount)

        By Category:
        """

        for (category, count) in stats.categoryCounts.sorted(by: { $0.value > $1.value }) {
            output += "\n  \(category.rawValue): \(count)"
        }

        output += """


        📝 DETAILED LOGS
        ═══════════════════════════════════════════════════════════════

        """

        for entry in logEntries {
            output += "\(entry.fullLogLine)\n"
        }

        output += """

        ═══════════════════════════════════════════════════════════════
        END OF LOG EXPORT
        ═══════════════════════════════════════════════════════════════
        """

        return output
    }

    /// Export logs as JSON
    func exportLogsAsJSON() throws -> Data {
        struct ExportData: Codable {
            let exportDate: Date
            let deviceInfo: DeviceInfo
            let statistics: StatisticsData
            let logs: [LogData]

            struct DeviceInfo: Codable {
                let model: String
                let systemVersion: String
                let appVersion: String
            }

            struct StatisticsData: Codable {
                let totalLogs: Int
                let errorCount: Int
                let warningCount: Int
                let durationSeconds: Double?
            }

            struct LogData: Codable {
                let timestamp: Date
                let level: String
                let category: String
                let message: String
            }
        }

        let stats = getStatistics()
        let exportData = ExportData(
            exportDate: Date(),
            deviceInfo: ExportData.DeviceInfo(
                model: UIDevice.current.model,
                systemVersion: UIDevice.current.systemVersion,
                appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
            ),
            statistics: ExportData.StatisticsData(
                totalLogs: stats.totalLogs,
                errorCount: stats.errorCount,
                warningCount: stats.warningCount,
                durationSeconds: stats.duration
            ),
            logs: logEntries.map { entry in
                ExportData.LogData(
                    timestamp: entry.timestamp,
                    level: entry.level.rawValue,
                    category: entry.category.rawValue,
                    message: entry.message
                )
            }
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(exportData)
    }

    /// Save logs to a file and return the file URL
    func saveLogsToFile(format: ExportFormat = .text) throws -> URL {
        let filename: String
        let data: Data

        let timestamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")

        switch format {
        case .text:
            filename = "dexcom-diagnostics-\(timestamp).txt"
            data = exportLogsAsText().data(using: .utf8) ?? Data()
        case .json:
            filename = "dexcom-diagnostics-\(timestamp).json"
            data = try exportLogsAsJSON()
        }

        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(filename)

        try data.write(to: fileURL)

        logger.info("Exported Dexcom diagnostic logs to: \(fileURL.path)")
        return fileURL
    }

    enum ExportFormat {
        case text
        case json
    }

    // MARK: - Clear Logs

    /// Clear all logs
    func clearLogs() {
        logEntries.removeAll()
        logger.info("Cleared all Dexcom diagnostic logs")
    }
}
