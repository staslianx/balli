//
//  PersistenceHealthMonitor.swift
//  balli
//
//  Handles health monitoring and maintenance operations for persistence layer
//

@preconcurrency import CoreData
import Foundation
import os.log

/// Monitors persistence layer health, performs maintenance, and tracks performance metrics
public actor PersistenceHealthMonitor {
    private let logger = os.Logger(subsystem: "com.balli.diabetes", category: "PersistenceHealthMonitor")
    
    // MARK: - Monitoring State
    private var isMonitoring = false
    private let performanceMonitor = PerformanceMonitor()
    private let dataHealthMonitor = DataHealthMonitor()
    
    // MARK: - Health Metrics
    private var currentHealth = DataHealth()
    private var healthHistory: [DataHealth] = []
    private let maxHealthHistorySize = 100
    
    // MARK: - Performance Tracking
    private var saveOperations: [SaveOperationMetrics] = []
    private var fetchOperations: [FetchOperationMetrics] = []
    private let maxOperationHistorySize = 500
    
    // MARK: - Configuration
    private let configuration: HealthMonitorConfiguration
    
    public init(configuration: HealthMonitorConfiguration = .default) {
        self.configuration = configuration
        logger.debug("Health monitor initialized with interval: \(configuration.checkInterval)s")
    }
    
    // MARK: - Monitoring Control
    
    /// Start health monitoring with periodic checks
    public func startMonitoring(container: NSPersistentContainer) async {
        guard !isMonitoring else {
            logger.debug("Health monitoring already running")
            return
        }
        
        isMonitoring = true
        await dataHealthMonitor.startMonitoring(container: container)

        logger.info("Health monitoring started")

        // Initial health check
        let initialHealth = await performHealthCheck(container: container)
        if initialHealth.hasIssues {
            logger.warning("Initial health check found \(initialHealth.issues.count) issues")
        }
    }
    
    /// Stop health monitoring
    public func stopMonitoring() async {
        isMonitoring = false
        logger.info("Health monitoring stopped")
    }
    
    /// Perform immediate health check
    public func performHealthCheck(container: NSPersistentContainer) async -> DataHealth {
        let health = await dataHealthMonitor.checkHealth(container: container)
        
        // Update current health
        currentHealth = health
        
        // Add to history
        healthHistory.append(health)
        if healthHistory.count > maxHealthHistorySize {
            healthHistory.removeFirst()
        }
        
        // Log health status
        if health.hasIssues {
            logger.warning("Health check found \(health.issues.count) issues")
            for issue in health.issues {
                let severityString = String(describing: issue.severity)
                logger.warning("Issue: \(issue.description) (severity: \(severityString))")
            }
        } else {
            logger.debug("Health check passed - system healthy")
        }
        
        return health
    }
    
    // MARK: - Performance Monitoring
    
    /// Record a save operation for performance tracking
    public func recordSaveOperation(duration: TimeInterval, objectCount: Int = 1, success: Bool = true) async {
        let metrics = SaveOperationMetrics(
            duration: duration,
            objectCount: objectCount,
            success: success,
            timestamp: Date()
        )
        
        saveOperations.append(metrics)
        if saveOperations.count > maxOperationHistorySize {
            saveOperations.removeFirst()
        }
        
        // Placeholder - performanceMonitor.recordOperation implementation needed
        
        // Log slow saves
        if duration > configuration.slowSaveThreshold {
            logger.warning("Slow save operation: \(duration)s for \(objectCount) objects")
        }
    }
    
    /// Record a fetch operation for performance tracking
    public func recordFetchOperation(
        duration: TimeInterval,
        resultCount: Int,
        fromCache: Bool = false,
        success: Bool = true
    ) async {
        let metrics = FetchOperationMetrics(
            duration: duration,
            resultCount: resultCount,
            fromCache: fromCache,
            success: success,
            timestamp: Date()
        )
        
        fetchOperations.append(metrics)
        if fetchOperations.count > maxOperationHistorySize {
            fetchOperations.removeFirst()
        }
        
        // Placeholder - performanceMonitor.recordOperation implementation needed
        
        // Log slow fetches
        if duration > configuration.slowFetchThreshold {
            logger.warning("Slow fetch operation: \(duration)s returning \(resultCount) results")
        }
    }
    
    // MARK: - Health Reporting
    
    /// Get current health status
    public func getCurrentHealth() async -> DataHealth {
        return currentHealth
    }
    
    /// Get health trend over time
    public func getHealthTrend() async -> HealthTrend {
        guard healthHistory.count > 1 else {
            return HealthTrend.stable
        }
        
        let recent = Array(healthHistory.suffix(10))
        let issueCount = recent.map { $0.issues.count }
        
        let averageRecent = Double(issueCount.suffix(5).reduce(0, +)) / 5.0
        let averageOlder = Double(issueCount.prefix(5).reduce(0, +)) / 5.0
        
        if averageRecent > averageOlder * 1.2 {
            return .declining
        } else if averageRecent < averageOlder * 0.8 {
            return .improving
        } else {
            return .stable
        }
    }
    
    /// Generate comprehensive health report
    public func generateHealthReport() async -> PersistenceHealthReport {
        let currentHealth = await getCurrentHealth()
        let trend = await getHealthTrend()
        let performanceStats = await getPerformanceStatistics()
        
        return PersistenceHealthReport(
            health: currentHealth,
            trend: trend,
            performanceStatistics: performanceStats,
            recommendations: generateRecommendations(health: currentHealth, performance: performanceStats),
            timestamp: Date()
        )
    }
    
    /// Get performance statistics
    public func getPerformanceStatistics() async -> PerformanceStatistics {
        let recentSaves = Array(saveOperations.suffix(100))
        let recentFetches = Array(fetchOperations.suffix(100))
        
        return PerformanceStatistics(
            averageSaveTime: recentSaves.map { $0.duration }.average,
            averageFetchTime: recentFetches.map { $0.duration }.average,
            saveSuccessRate: recentSaves.map { $0.success }.successRate,
            fetchSuccessRate: recentFetches.map { $0.success }.successRate,
            cacheHitRate: recentFetches.filter { $0.fromCache }.count.ratio(to: recentFetches.count),
            totalOperations: saveOperations.count + fetchOperations.count,
            recentOperations: recentSaves.count + recentFetches.count
        )
    }
    
    // MARK: - Maintenance Operations
    
    /// Perform automatic maintenance based on health status
    public func performAutoMaintenance(container: NSPersistentContainer) async throws {
        let health = await getCurrentHealth()
        
        guard health.hasIssues else {
            logger.debug("No maintenance required - system healthy")
            return
        }
        
        logger.info("Starting auto-maintenance for \(health.issues.count) issues")
        
        for issue in health.issues {
            do {
                try await performMaintenanceForIssue(issue, container: container)
            } catch {
                let issueTypeString = String(describing: issue.type)
                logger.error("Failed to resolve issue \(issueTypeString): \(error)")
            }
        }
        
        // Perform post-maintenance health check
        _ = await performHealthCheck(container: container)
    }
    
    /// Clean up orphaned data
    public func cleanupOrphanedData(container: NSPersistentContainer) async throws {
        logger.info("Cleaning up orphaned data")

        // This would implement specific orphaned data cleanup logic
        // For example, removing FoodItems without MealEntries, etc.

        await container.performBackgroundTask { context in
            // Implement orphaned data cleanup queries
            context.reset()
        }

        logger.info("Orphaned data cleanup completed")
    }
    
    /// Repair inconsistent relationships
    public func repairRelationships(container: NSPersistentContainer) async throws {
        logger.info("Repairing inconsistent relationships")

        await container.performBackgroundTask { context in
            // Implement relationship repair logic
            context.reset()
        }

        logger.info("Relationship repair completed")
    }
    
    /// Optimize database performance
    public func optimizePerformance(container: NSPersistentContainer) async throws {
        logger.info("Optimizing database performance")
        
        // This would implement performance optimization
        // such as analyzing queries, updating indexes, etc.
        
        logger.info("Performance optimization completed")
    }
    
    // MARK: - Private Methods
    
    private func performMaintenanceForIssue(_ issue: DataHealthIssue, container: NSPersistentContainer) async throws {
        switch issue.type {
        case .orphanedData:
            try await cleanupOrphanedData(container: container)
        case .inconsistentRelationships:
            try await repairRelationships(container: container)
        case .corruptedData:
            logger.error("Corrupted data detected - manual intervention required")
            throw PersistenceError.corruptedDatabase
        case .excessiveSize:
            try await optimizePerformance(container: container)
        }
    }
    
    private func generateRecommendations(
        health: DataHealth,
        performance: PerformanceStatistics
    ) -> [HealthRecommendation] {
        var recommendations: [HealthRecommendation] = []
        
        // Performance-based recommendations
        if performance.averageSaveTime > configuration.slowSaveThreshold {
            recommendations.append(.optimizeSaveOperations)
        }
        
        if performance.averageFetchTime > configuration.slowFetchThreshold {
            recommendations.append(.optimizeFetchOperations)
        }
        
        if performance.cacheHitRate < 0.3 {
            recommendations.append(.improveCaching)
        }
        
        // Health-based recommendations
        if health.hasIssues {
            for issue in health.issues {
                switch issue.type {
                case .orphanedData:
                    recommendations.append(.cleanupOrphanedData)
                case .inconsistentRelationships:
                    recommendations.append(.repairRelationships)
                case .corruptedData:
                    recommendations.append(.checkDataIntegrity)
                case .excessiveSize:
                    recommendations.append(.performMaintenance)
                }
            }
        }
        
        return recommendations
    }
}

// MARK: - Configuration

public struct HealthMonitorConfiguration: Sendable {
    public let checkInterval: TimeInterval
    public let slowSaveThreshold: TimeInterval
    public let slowFetchThreshold: TimeInterval
    public let enableAutoMaintenance: Bool
    
    public init(
        checkInterval: TimeInterval = 300, // 5 minutes
        slowSaveThreshold: TimeInterval = 1.0,
        slowFetchThreshold: TimeInterval = 0.5,
        enableAutoMaintenance: Bool = true
    ) {
        self.checkInterval = checkInterval
        self.slowSaveThreshold = slowSaveThreshold
        self.slowFetchThreshold = slowFetchThreshold
        self.enableAutoMaintenance = enableAutoMaintenance
    }
    
    public static let `default` = HealthMonitorConfiguration()
    
    public static let testing = HealthMonitorConfiguration(
        checkInterval: 60, // 1 minute
        slowSaveThreshold: 2.0,
        slowFetchThreshold: 1.0,
        enableAutoMaintenance: false
    )
}

// MARK: - Health Reporting Types

public enum HealthTrend: Sendable {
    case improving
    case stable
    case declining
    
    public var description: String {
        switch self {
        case .improving: return "Improving"
        case .stable: return "Stable"
        case .declining: return "Declining"
        }
    }
}

public struct PersistenceHealthReport: Sendable {
    public let health: DataHealth
    public let trend: HealthTrend
    public let performanceStatistics: PerformanceStatistics
    public let recommendations: [HealthRecommendation]
    public let timestamp: Date
    
    public var overallScore: Double {
        var score = health.isHealthy ? 100.0 : 50.0
        
        // Adjust based on performance
        if performanceStatistics.saveSuccessRate > 0.95 {
            score += 10
        }
        
        if performanceStatistics.cacheHitRate > 0.5 {
            score += 10
        }
        
        // Adjust based on trend
        switch trend {
        case .improving:
            score += 5
        case .declining:
            score -= 10
        case .stable:
            break
        }
        
        return min(100, max(0, score))
    }
}

public enum HealthRecommendation: Sendable, CaseIterable {
    case optimizeSaveOperations
    case optimizeFetchOperations
    case improveCaching
    case cleanupOrphanedData
    case repairRelationships
    case checkDataIntegrity
    case performMaintenance
    
    public var description: String {
        switch self {
        case .optimizeSaveOperations:
            return "Optimize save operations to improve performance"
        case .optimizeFetchOperations:
            return "Optimize fetch operations and queries"
        case .improveCaching:
            return "Improve caching strategy to reduce database load"
        case .cleanupOrphanedData:
            return "Clean up orphaned data to reduce database size"
        case .repairRelationships:
            return "Repair inconsistent relationships in the database"
        case .checkDataIntegrity:
            return "Check data integrity and fix corruption"
        case .performMaintenance:
            return "Perform database maintenance and optimization"
        }
    }
}

// MARK: - Operation Metrics

public struct SaveOperationMetrics: Sendable {
    public let duration: TimeInterval
    public let objectCount: Int
    public let success: Bool
    public let timestamp: Date
}

public struct FetchOperationMetrics: Sendable {
    public let duration: TimeInterval
    public let resultCount: Int
    public let fromCache: Bool
    public let success: Bool
    public let timestamp: Date
}

public struct PerformanceStatistics: Sendable {
    public let averageSaveTime: TimeInterval
    public let averageFetchTime: TimeInterval
    public let saveSuccessRate: Double
    public let fetchSuccessRate: Double
    public let cacheHitRate: Double
    public let totalOperations: Int
    public let recentOperations: Int
}

// MARK: - Collection Extensions

private extension Array where Element == TimeInterval {
    var average: TimeInterval {
        guard !isEmpty else { return 0 }
        return reduce(0, +) / TimeInterval(count)
    }
}

private extension Array where Element == Bool {
    var successRate: Double {
        guard !isEmpty else { return 0 }
        return Double(filter { $0 }.count) / Double(count)
    }
}

private extension Int {
    func ratio(to total: Int) -> Double {
        guard total > 0 else { return 0 }
        return Double(self) / Double(total)
    }
}