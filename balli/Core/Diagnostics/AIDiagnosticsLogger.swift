//
//  AIDiagnosticsLogger.swift
//  balli
//
//  AI operations diagnostic log capture and export
//  Swift 6 strict concurrency compliant
//  Captures logs for leaven analysis, nutrition calculation, recipe generation, and research
//

import Foundation
import OSLog
import UIKit
import FirebaseCrashlytics

/// Actor-based logger that captures AI operations forensic logs
actor AIDiagnosticsLogger {

    // MARK: - Singleton

    static let shared = AIDiagnosticsLogger()

    // MARK: - Properties

    private var logEntries: [LogEntry] = []
    private let maxLogEntries = 10000 // ~1000 AI operations worth of logs
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.anaxoniclabs.balli", category: "AIDiagnostics")

    // MARK: - Log Entry Model

    struct LogEntry: Identifiable, Sendable {
        let id = UUID()
        let timestamp: Date
        let level: LogLevel
        let category: LogCategory
        let message: String
        let operationId: String?
        let metadata: [String: String]?

        enum LogLevel: String, Sendable {
            case info = "ℹ️"
            case warning = "⚠️"
            case error = "❌"
            case success = "✅"
            case debug = "🔍"
        }

        enum LogCategory: String, Sendable {
            case leavenAnalysis = "🍞 Leaven Analysis"
            case nutritionCalculation = "🥗 Nutrition Calc"
            case recipeGeneration = "📝 Recipe Gen"
            case research = "🔬 Research"
            case geminiAPI = "🤖 Gemini API"
            case streaming = "📡 Streaming"
            case imageProcessing = "📸 Image Processing"
            case errorHandling = "⚠️ Error Handling"
            case performance = "⚡ Performance"
        }

        var formattedTimestamp: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss.SSS"
            return formatter.string(from: timestamp)
        }

        var fullLogLine: String {
            var line = "\(formattedTimestamp) \(level.rawValue) \(category.rawValue): \(message)"
            if let operationId = operationId {
                line += " [Op: \(operationId.prefix(8))]"
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

        // AI-specific stats
        let leavenAnalysisCount: Int
        let nutritionCalculationCount: Int
        let recipeGenerationCount: Int
        let researchCount: Int
        let geminiAPICallCount: Int
        let streamingEventCount: Int
        let imageProcessingCount: Int
        let errorHandlingCount: Int

        var durationDescription: String {
            guard let oldest = oldestLog, let newest = newestLog else {
                return "Kayıt Yok"
            }
            let duration = newest.timeIntervalSince(oldest)
            if duration < 60 {
                return "\(Int(duration))s"
            } else if duration < 3600 {
                return "\(Int(duration / 60))m"
            } else {
                return "\(Int(duration / 3600))h \(Int((duration.truncatingRemainder(dividingBy: 3600)) / 60))m"
            }
        }
    }

    // MARK: - Initialization

    private init() {
        logger.info("AIDiagnosticsLogger initialized - ready to capture AI operation logs")
    }

    // MARK: - Log Capture

    /// Log a leaven analysis event
    func logLeavenAnalysis(_ message: String, operationId: String? = nil, metadata: [String: String]? = nil, level: LogEntry.LogLevel = .info) {
        addEntry(category: .leavenAnalysis, level: level, message: message, operationId: operationId, metadata: metadata)

        // Send to Crashlytics for error tracking
        if level == .error {
            Crashlytics.crashlytics().record(error: NSError(
                domain: "com.anaxoniclabs.balli.ai.leaven",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: message]
            ))
        }
    }

    /// Log a nutrition calculation event
    func logNutritionCalculation(_ message: String, operationId: String? = nil, metadata: [String: String]? = nil, level: LogEntry.LogLevel = .info) {
        addEntry(category: .nutritionCalculation, level: level, message: message, operationId: operationId, metadata: metadata)

        if level == .error {
            Crashlytics.crashlytics().record(error: NSError(
                domain: "com.anaxoniclabs.balli.ai.nutrition",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: message]
            ))
        }
    }

    /// Log a recipe generation event
    func logRecipeGeneration(_ message: String, operationId: String? = nil, metadata: [String: String]? = nil, level: LogEntry.LogLevel = .info) {
        addEntry(category: .recipeGeneration, level: level, message: message, operationId: operationId, metadata: metadata)

        if level == .error {
            Crashlytics.crashlytics().record(error: NSError(
                domain: "com.anaxoniclabs.balli.ai.recipe",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: message]
            ))
        }
    }

    /// Log a research operation event
    func logResearch(_ message: String, operationId: String? = nil, metadata: [String: String]? = nil, level: LogEntry.LogLevel = .info) {
        addEntry(category: .research, level: level, message: message, operationId: operationId, metadata: metadata)

        if level == .error {
            Crashlytics.crashlytics().record(error: NSError(
                domain: "com.anaxoniclabs.balli.ai.research",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: message]
            ))
        }
    }

    /// Log a Gemini API call
    func logGeminiAPI(_ message: String, operationId: String? = nil, metadata: [String: String]? = nil, level: LogEntry.LogLevel = .info) {
        addEntry(category: .geminiAPI, level: level, message: message, operationId: operationId, metadata: metadata)

        if level == .error {
            Crashlytics.crashlytics().record(error: NSError(
                domain: "com.anaxoniclabs.balli.ai.gemini",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: message]
            ))
        }
    }

    /// Log a streaming event
    func logStreaming(_ message: String, operationId: String? = nil, metadata: [String: String]? = nil, level: LogEntry.LogLevel = .debug) {
        addEntry(category: .streaming, level: level, message: message, operationId: operationId, metadata: metadata)
    }

    /// Log an image processing event
    func logImageProcessing(_ message: String, operationId: String? = nil, metadata: [String: String]? = nil, level: LogEntry.LogLevel = .info) {
        addEntry(category: .imageProcessing, level: level, message: message, operationId: operationId, metadata: metadata)

        if level == .error {
            Crashlytics.crashlytics().record(error: NSError(
                domain: "com.anaxoniclabs.balli.ai.image",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: message]
            ))
        }
    }

    /// Log an error handling event
    func logErrorHandling(_ message: String, operationId: String? = nil, metadata: [String: String]? = nil, level: LogEntry.LogLevel = .warning) {
        addEntry(category: .errorHandling, level: level, message: message, operationId: operationId, metadata: metadata)
    }

    /// Log a performance event
    func logPerformance(_ message: String, operationId: String? = nil, metadata: [String: String]? = nil, level: LogEntry.LogLevel = .info) {
        addEntry(category: .performance, level: level, message: message, operationId: operationId, metadata: metadata)
    }

    /// Add a log entry
    private func addEntry(category: LogEntry.LogCategory, level: LogEntry.LogLevel, message: String, operationId: String?, metadata: [String: String]?) {
        let entry = LogEntry(
            timestamp: Date(),
            level: level,
            category: category,
            message: message,
            operationId: operationId,
            metadata: metadata
        )

        logEntries.append(entry)

        // Trim old entries if exceeding max
        if logEntries.count > maxLogEntries {
            logEntries.removeFirst(logEntries.count - maxLogEntries)
        }

        // Also log to system logger for Console.app
        let logMessage = "\(category.rawValue): \(message)" + (operationId.map { " [Op: \($0.prefix(8))]" } ?? "")
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

        // Send breadcrumb to Crashlytics for all events
        Crashlytics.crashlytics().log("\(level.rawValue) \(category.rawValue): \(message)")
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

    /// Get logs by operation ID
    func getLogs(operationId: String) -> [LogEntry] {
        logEntries.filter { $0.operationId == operationId }
    }

    /// Get logs by level
    func getLogs(level: LogEntry.LogLevel) -> [LogEntry] {
        logEntries.filter { $0.level == level }
    }

    /// Get error logs only
    func getErrorLogs() -> [LogEntry] {
        logEntries.filter { $0.level == .error }
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
            leavenAnalysisCount: logEntries.filter { $0.category == .leavenAnalysis }.count,
            nutritionCalculationCount: logEntries.filter { $0.category == .nutritionCalculation }.count,
            recipeGenerationCount: logEntries.filter { $0.category == .recipeGeneration }.count,
            researchCount: logEntries.filter { $0.category == .research }.count,
            geminiAPICallCount: logEntries.filter { $0.category == .geminiAPI }.count,
            streamingEventCount: logEntries.filter { $0.category == .streaming }.count,
            imageProcessingCount: logEntries.filter { $0.category == .imageProcessing }.count,
            errorHandlingCount: logEntries.filter { $0.category == .errorHandling }.count
        )
    }

    // MARK: - Clear Logs

    /// Clear all log entries
    func clearLogs() {
        logEntries.removeAll()
        logger.info("All AI diagnostic logs cleared")
        Crashlytics.crashlytics().log("AI diagnostic logs cleared by user")
    }

    // MARK: - Export

    enum ExportFormat {
        case text
        case json
    }

    /// Save logs to file and return URL for sharing
    func saveLogsToFile(format: ExportFormat) async throws -> URL {
        let fileName: String
        let content: String

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = dateFormatter.string(from: Date())

        switch format {
        case .text:
            fileName = "ai_diagnostics_\(timestamp).txt"
            content = await generateTextExport()
        case .json:
            fileName = "ai_diagnostics_\(timestamp).json"
            content = try await generateJSONExport()
        }

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try content.write(to: tempURL, atomically: true, encoding: .utf8)

        logger.info("Exported AI diagnostic logs to \(tempURL.path)")
        Crashlytics.crashlytics().log("AI diagnostic logs exported as \(format)")
        return tempURL
    }

    private func generateTextExport() async -> String {
        // Access @MainActor-isolated UIDevice properties safely
        let deviceModel = await MainActor.run { UIDevice.current.model }
        let systemVersion = await MainActor.run { UIDevice.current.systemVersion }

        let stats = getStatistics()

        var output = """
        ═══════════════════════════════════════════════════════════════
        BALLI - AI İŞLEMLERİ TANI KAYITLARI
        ═══════════════════════════════════════════════════════════════

        Dışa Aktarım Tarihi: \(Date().formatted(date: .complete, time: .complete))
        Toplam Kayıt: \(logEntries.count)
        Cihaz: \(deviceModel)
        iOS Sürümü: \(systemVersion)
        Uygulama Sürümü: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Bilinmiyor")

        ═══════════════════════════════════════════════════════════════
        📊 İSTATİSTİKLER
        ───────────────────────────────────────────────────────────────
        Kayıt Süresi: \(stats.durationDescription)
        Toplam Giriş: \(stats.totalLogs)
        Hatalar: \(stats.errorCount)
        Uyarılar: \(stats.warningCount)

        Kategoriye Göre:
          🍞 Maya Analizi: \(stats.leavenAnalysisCount)
          🥗 Besin Hesaplama: \(stats.nutritionCalculationCount)
          📝 Tarif Oluşturma: \(stats.recipeGenerationCount)
          🔬 Araştırma: \(stats.researchCount)
          🤖 Gemini API: \(stats.geminiAPICallCount)
          📡 Streaming: \(stats.streamingEventCount)
          📸 Görüntü İşleme: \(stats.imageProcessingCount)
          ⚠️ Hata Yönetimi: \(stats.errorHandlingCount)

        ═══════════════════════════════════════════════════════════════
        📝 DETAYLI KAYITLAR
        ═══════════════════════════════════════════════════════════════

        """

        for entry in logEntries {
            output += entry.fullLogLine + "\n"
        }

        output += """

        ═══════════════════════════════════════════════════════════════
        KAYIT İHRACATI SONU
        ═══════════════════════════════════════════════════════════════
        """

        return output
    }

    private func generateJSONExport() async throws -> String {
        // Access @MainActor-isolated UIDevice properties safely
        let deviceModel = await MainActor.run { UIDevice.current.model }
        let systemVersion = await MainActor.run { UIDevice.current.systemVersion }

        let stats = getStatistics()

        let exportData: [String: Any] = [
            "exportDate": ISO8601DateFormatter().string(from: Date()),
            "device": deviceModel,
            "iosVersion": systemVersion,
            "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown",
            "statistics": [
                "totalLogs": stats.totalLogs,
                "errorCount": stats.errorCount,
                "warningCount": stats.warningCount,
                "durationDescription": stats.durationDescription,
                "leavenAnalysisCount": stats.leavenAnalysisCount,
                "nutritionCalculationCount": stats.nutritionCalculationCount,
                "recipeGenerationCount": stats.recipeGenerationCount,
                "researchCount": stats.researchCount,
                "geminiAPICallCount": stats.geminiAPICallCount,
                "streamingEventCount": stats.streamingEventCount,
                "imageProcessingCount": stats.imageProcessingCount,
                "errorHandlingCount": stats.errorHandlingCount
            ],
            "logs": logEntries.map { entry in
                var dict: [String: Any] = [
                    "timestamp": ISO8601DateFormatter().string(from: entry.timestamp),
                    "level": entry.level.rawValue,
                    "category": entry.category.rawValue,
                    "message": entry.message
                ]
                if let operationId = entry.operationId {
                    dict["operationId"] = operationId
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
