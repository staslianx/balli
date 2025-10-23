//
//  PerformanceMonitor.swift
//  balli
//
//  Monitors and tracks performance metrics for persistence operations
//

import Foundation
import os.log

/// Monitors performance of persistence operations
actor PerformanceMonitor {
    private let logger = os.Logger(subsystem: "com.balli.diabetes", category: "Performance")
    
    // Metrics storage
    private var metrics: [String: [PerformanceMetric]] = [:]
    
    // Configuration
    private let maxMetricsPerOperation = 100
    private let slowOperationThreshold: TimeInterval = 1.0
    
    // Statistics
    private var totalOperations = 0
    private var slowOperations = 0
    
    // MARK: - Types
    
    struct PerformanceMetric {
        let operation: String
        let duration: TimeInterval
        let timestamp: Date
        let success: Bool
        let fromCache: Bool
        let metadata: [String: Any]?
        
        init(
            operation: String,
            duration: TimeInterval,
            timestamp: Date = Date(),
            success: Bool = true,
            fromCache: Bool = false,
            metadata: [String: Any]? = nil
        ) {
            self.operation = operation
            self.duration = duration
            self.timestamp = timestamp
            self.success = success
            self.fromCache = fromCache
            self.metadata = metadata
        }
    }
    
    public struct OperationStatistics: Sendable {
        public let operation: String
        public let count: Int
        public let averageDuration: TimeInterval
        public let minDuration: TimeInterval
        public let maxDuration: TimeInterval
        public let successRate: Double
        public let cacheHitRate: Double
        public let p50Duration: TimeInterval // Median
        public let p95Duration: TimeInterval // 95th percentile
        public let p99Duration: TimeInterval // 99th percentile
        
        var isPerformant: Bool {
            // Check if meets performance targets
            switch operation {
            case let op where op.contains("fetch"):
                return averageDuration < 0.05 // 50ms target for fetches
            case let op where op.contains("save"):
                return averageDuration < 0.1 // 100ms target for saves
            case let op where op.contains("batch"):
                return count > 0 && (Double(count) / averageDuration) > 1000 // 1000 items/sec
            default:
                return averageDuration < 0.5 // 500ms default
            }
        }
    }
    
    enum OperationType: String {
        case fetch = "fetch"
        case save = "save"
        case batchInsert = "batch_insert"
        case batchUpdate = "batch_update"
        case batchDelete = "batch_delete"
        case transaction = "transaction"
        case migration = "migration"
        case maintenance = "maintenance"
    }
    
    // MARK: - Public API
    
    /// Measure the performance of an operation
    func measure<T: Sendable>(
        operation: String,
        metadata: [String: Any]? = nil,
        block: @Sendable () async throws -> T
    ) async throws -> T {
        let startTime = Date()
        var success = false
        
        defer {
            let duration = Date().timeIntervalSince(startTime)
            Task {
                self.recordOperation(
                    type: operation,
                    duration: duration,
                    success: success,
                    metadata: metadata
                )
            }
        }
        
        do {
            let result = try await block()
            success = true
            return result
        } catch {
            success = false
            throw error
        }
    }
    
    /// Record an operation metric
    func recordOperation(
        type: OperationType,
        duration: TimeInterval,
        success: Bool = true,
        fromCache: Bool = false,
        metadata: [String: Any]? = nil
    ) {
        recordOperation(
            type: type.rawValue,
            duration: duration,
            success: success,
            fromCache: fromCache,
            metadata: metadata
        )
    }
    
    /// Record an operation metric with custom type
    func recordOperation(
        type: String,
        duration: TimeInterval,
        success: Bool = true,
        fromCache: Bool = false,
        metadata: [String: Any]? = nil
    ) {
        totalOperations += 1
        
        if duration > slowOperationThreshold {
            slowOperations += 1
            logger.warning("Slow operation '\(type)': \(String(format: "%.3f", duration))s")
        }
        
        let metric = PerformanceMetric(
            operation: type,
            duration: duration,
            success: success,
            fromCache: fromCache,
            metadata: metadata
        )
        
        // Store metric
        var operationMetrics = metrics[type] ?? []
        operationMetrics.append(metric)
        
        // Keep only recent metrics
        if operationMetrics.count > maxMetricsPerOperation {
            let cutoff = Date().addingTimeInterval(-3600) // Keep last hour
            operationMetrics = operationMetrics.filter { $0.timestamp > cutoff }
        }
        
        metrics[type] = operationMetrics
        
        // Log if operation failed
        if !success {
            logger.error("Operation '\(type)' failed after \(String(format: "%.3f", duration))s")
        }
    }
    
    /// Get statistics for a specific operation
    func statistics(for operation: String) -> OperationStatistics? {
        guard let operationMetrics = metrics[operation], !operationMetrics.isEmpty else {
            return nil
        }
        
        let durations = operationMetrics.map { $0.duration }.sorted()
        let successCount = operationMetrics.filter { $0.success }.count
        let cacheHitCount = operationMetrics.filter { $0.fromCache }.count
        
        return OperationStatistics(
            operation: operation,
            count: operationMetrics.count,
            averageDuration: durations.reduce(0, +) / Double(durations.count),
            minDuration: durations.first ?? 0,
            maxDuration: durations.last ?? 0,
            successRate: Double(successCount) / Double(operationMetrics.count),
            cacheHitRate: Double(cacheHitCount) / Double(operationMetrics.count),
            p50Duration: percentile(durations, 0.5),
            p95Duration: percentile(durations, 0.95),
            p99Duration: percentile(durations, 0.99)
        )
    }
    
    /// Get all operation statistics
    func allStatistics() -> [OperationStatistics] {
        metrics.keys.compactMap { statistics(for: $0) }
    }
    
    /// Get performance summary
    func performanceSummary() -> PerformanceSummary {
        let allStats = allStatistics()
        
        let fetchStats = allStats.filter { $0.operation.contains("fetch") }
        let saveStats = allStats.filter { $0.operation.contains("save") }
        let batchStats = allStats.filter { $0.operation.contains("batch") }
        
        return PerformanceSummary(
            totalOperations: totalOperations,
            slowOperations: slowOperations,
            averageFetchTime: average(fetchStats.map { $0.averageDuration }),
            averageSaveTime: average(saveStats.map { $0.averageDuration }),
            averageBatchTime: average(batchStats.map { $0.averageDuration }),
            overallSuccessRate: average(allStats.map { $0.successRate }),
            overallCacheHitRate: average(allStats.map { $0.cacheHitRate }),
            performanceScore: calculatePerformanceScore(allStats)
        )
    }
    
    /// Clear all metrics
    func reset() {
        metrics.removeAll()
        totalOperations = 0
        slowOperations = 0
        logger.info("Performance metrics reset")
    }
    
    /// Export metrics for analysis
    func exportMetrics() -> Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        do {
            let exportData = PerformanceExport(
                timestamp: Date(),
                metrics: metrics,
                summary: performanceSummary()
            )
            return try encoder.encode(exportData)
        } catch {
            logger.error("Failed to export metrics: \(error)")
            return nil
        }
    }
    
    // MARK: - Private Methods
    
    private func percentile(_ values: [TimeInterval], _ percentile: Double) -> TimeInterval {
        guard !values.isEmpty else { return 0 }
        
        let index = Int(Double(values.count - 1) * percentile)
        return values[index]
    }
    
    private func average(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }
    
    private func calculatePerformanceScore(_ stats: [OperationStatistics]) -> Double {
        guard !stats.isEmpty else { return 100 }
        
        let performantOperations = stats.filter { $0.isPerformant }.count
        return (Double(performantOperations) / Double(stats.count)) * 100
    }
    
    // MARK: - Alerts
    
    /// Check if performance is degrading
    func checkPerformanceHealth() -> PerformanceHealth {
        let summary = performanceSummary()
        
        var issues: [PerformanceIssue] = []
        
        // Check fetch performance
        if summary.averageFetchTime > 0.05 { // 50ms threshold
            issues.append(PerformanceIssue(
                type: .slowFetch,
                severity: summary.averageFetchTime > 0.1 ? .high : .medium,
                description: "Fetch operations averaging \(Int(summary.averageFetchTime * 1000))ms"
            ))
        }
        
        // Check save performance
        if summary.averageSaveTime > 0.1 { // 100ms threshold
            issues.append(PerformanceIssue(
                type: .slowSave,
                severity: summary.averageSaveTime > 0.5 ? .high : .medium,
                description: "Save operations averaging \(Int(summary.averageSaveTime * 1000))ms"
            ))
        }
        
        // Check slow operation rate
        let slowRate = totalOperations > 0 ? Double(slowOperations) / Double(totalOperations) : 0
        if slowRate > 0.1 { // More than 10% slow
            issues.append(PerformanceIssue(
                type: .highSlowRate,
                severity: slowRate > 0.25 ? .high : .medium,
                description: "\(Int(slowRate * 100))% of operations are slow"
            ))
        }
        
        // Check cache hit rate
        if summary.overallCacheHitRate < 0.5 { // Less than 50% cache hits
            issues.append(PerformanceIssue(
                type: .lowCacheHitRate,
                severity: .low,
                description: "Cache hit rate is only \(Int(summary.overallCacheHitRate * 100))%"
            ))
        }
        
        return PerformanceHealth(
            isHealthy: issues.isEmpty,
            issues: issues,
            score: summary.performanceScore
        )
    }
}

// MARK: - Supporting Types

struct PerformanceSummary: Codable, Sendable {
    let totalOperations: Int
    let slowOperations: Int
    let averageFetchTime: TimeInterval
    let averageSaveTime: TimeInterval
    let averageBatchTime: TimeInterval
    let overallSuccessRate: Double
    let overallCacheHitRate: Double
    let performanceScore: Double
    
    var slowOperationRate: Double {
        totalOperations > 0 ? Double(slowOperations) / Double(totalOperations) : 0
    }
}

struct PerformanceExport: Codable {
    let timestamp: Date
    let metrics: [String: [PerformanceMonitor.PerformanceMetric]]
    let summary: PerformanceSummary
}

struct PerformanceHealth: Sendable {
    let isHealthy: Bool
    let issues: [PerformanceIssue]
    let score: Double
}

struct PerformanceIssue: Sendable {
    let type: IssueType
    let severity: Severity
    let description: String
    
    enum IssueType: Sendable {
        case slowFetch
        case slowSave
        case highSlowRate
        case lowCacheHitRate
        case degradingPerformance
    }
    
    enum Severity: Sendable {
        case low
        case medium
        case high
    }
}

// Make PerformanceMetric Codable for export
extension PerformanceMonitor.PerformanceMetric: Codable {
    enum CodingKeys: String, CodingKey {
        case operation
        case duration
        case timestamp
        case success
        case fromCache
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        operation = try container.decode(String.self, forKey: .operation)
        duration = try container.decode(TimeInterval.self, forKey: .duration)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        success = try container.decode(Bool.self, forKey: .success)
        fromCache = try container.decode(Bool.self, forKey: .fromCache)
        metadata = nil // Metadata not decoded for simplicity
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(operation, forKey: .operation)
        try container.encode(duration, forKey: .duration)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(success, forKey: .success)
        try container.encode(fromCache, forKey: .fromCache)
        // Metadata not encoded for simplicity
    }
}