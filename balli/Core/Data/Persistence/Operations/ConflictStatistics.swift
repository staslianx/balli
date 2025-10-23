//
//  ConflictStatistics.swift
//  balli
//
//  Tracks and manages conflict resolution statistics and metrics
//

import Foundation
import os.log

/// Manages statistics and metrics for conflict resolution operations
@PersistenceActor
public final class ConflictStatistics {
    private let logger = os.Logger(subsystem: "com.balli.diabetes", category: "ConflictStatistics")
    
    // Statistics tracking
    private var resolvedConflicts = 0
    private var failedResolutions = 0
    private var conflictsByType: [ConflictResolver.ConflictType: Int] = [:]
    private var resolutionsByStrategy: [ConflictResolver.ConflictResolutionStrategy: Int] = [:]
    private var averageConfidenceByType: [ConflictResolver.ConflictType: Double] = [:]
    private var resolutionTimes: [ConflictResolver.ConflictType: TimeInterval] = [:]
    
    // Timing
    private var resolutionStartTimes: [String: Date] = [:]
    
    public init() {}
    
    // MARK: - Statistics Recording
    
    /// Record a successful conflict resolution
    public func recordResolution(
        _ resolution: ConflictResolver.ConflictResolution,
        forContext context: ConflictResolver.ConflictContext,
        resolutionId: String
    ) {
        resolvedConflicts += 1
        conflictsByType[context.conflictType, default: 0] += 1
        resolutionsByStrategy[resolution.strategy, default: 0] += 1
        
        // Update average confidence
        let currentAverage = averageConfidenceByType[context.conflictType] ?? 0.0
        let currentCount = conflictsByType[context.conflictType] ?? 1
        let newAverage = ((currentAverage * Double(currentCount - 1)) + resolution.confidence) / Double(currentCount)
        averageConfidenceByType[context.conflictType] = newAverage
        
        // Record timing if available
        if let startTime = resolutionStartTimes.removeValue(forKey: resolutionId) {
            let duration = Date().timeIntervalSince(startTime)
            resolutionTimes[context.conflictType] = duration
            logger.debug("Conflict resolution took \(duration)s for \(context.conflictType.rawValue)")
        }
        
        logger.debug("Recorded successful resolution of \(context.conflictType.rawValue) with confidence \(resolution.confidence)")
    }
    
    /// Record a failed conflict resolution
    public func recordFailure(
        forContext context: ConflictResolver.ConflictContext,
        error: Error,
        resolutionId: String
    ) {
        failedResolutions += 1
        
        // Clean up timing
        resolutionStartTimes.removeValue(forKey: resolutionId)
        
        logger.error("Recorded failed resolution of \(context.conflictType.rawValue): \(error)")
    }
    
    /// Start timing a resolution operation
    public func startTiming(forResolutionId resolutionId: String) {
        resolutionStartTimes[resolutionId] = Date()
    }
    
    // MARK: - Statistics Access
    
    /// Get overall conflict statistics
    public var overallStatistics: (resolved: Int, failed: Int, successRate: Double) {
        let total = resolvedConflicts + failedResolutions
        let successRate = total > 0 ? Double(resolvedConflicts) / Double(total) : 0.0
        return (resolvedConflicts, failedResolutions, successRate)
    }
    
    /// Get conflicts broken down by type
    public var conflictsByTypeStatistics: [ConflictResolver.ConflictType: Int] {
        return conflictsByType
    }
    
    /// Get resolutions broken down by strategy
    public var resolutionsByStrategyStatistics: [ConflictResolver.ConflictResolutionStrategy: Int] {
        return resolutionsByStrategy
    }
    
    /// Get average confidence by conflict type
    public var averageConfidenceStatistics: [ConflictResolver.ConflictType: Double] {
        return averageConfidenceByType
    }
    
    /// Get average resolution times by conflict type
    public var averageResolutionTimes: [ConflictResolver.ConflictType: TimeInterval] {
        return resolutionTimes
    }
    
    /// Get comprehensive statistics report
    public var detailedReport: ConflictStatisticsReport {
        let overall = overallStatistics
        
        return ConflictStatisticsReport(
            totalConflicts: overall.resolved + overall.failed,
            resolvedConflicts: overall.resolved,
            failedResolutions: overall.failed,
            successRate: overall.successRate,
            conflictsByType: conflictsByType,
            resolutionsByStrategy: resolutionsByStrategy,
            averageConfidenceByType: averageConfidenceByType,
            averageResolutionTimes: resolutionTimes
        )
    }
    
    // MARK: - Statistics Management
    
    /// Reset all statistics
    public func resetStatistics() {
        resolvedConflicts = 0
        failedResolutions = 0
        conflictsByType.removeAll()
        resolutionsByStrategy.removeAll()
        averageConfidenceByType.removeAll()
        resolutionTimes.removeAll()
        resolutionStartTimes.removeAll()
        
        logger.info("Conflict resolution statistics reset")
    }
    
    /// Export statistics to a dictionary for serialization
    public func exportStatistics() -> [String: Any] {
        let overall = overallStatistics
        
        return [
            "totalConflicts": overall.resolved + overall.failed,
            "resolvedConflicts": overall.resolved,
            "failedResolutions": overall.failed,
            "successRate": overall.successRate,
            "conflictsByType": conflictsByType.mapKeys { $0.rawValue },
            "resolutionsByStrategy": resolutionsByStrategy.mapKeys { $0.description },
            "averageConfidenceByType": averageConfidenceByType.mapKeys { $0.rawValue },
            "averageResolutionTimes": resolutionTimes.mapKeys { $0.rawValue }
        ]
    }
}

// MARK: - Statistics Report Structure

public struct ConflictStatisticsReport: Sendable {
    public let totalConflicts: Int
    public let resolvedConflicts: Int
    public let failedResolutions: Int
    public let successRate: Double
    public let conflictsByType: [ConflictResolver.ConflictType: Int]
    public let resolutionsByStrategy: [ConflictResolver.ConflictResolutionStrategy: Int]
    public let averageConfidenceByType: [ConflictResolver.ConflictType: Double]
    public let averageResolutionTimes: [ConflictResolver.ConflictType: TimeInterval]
    
    public var summary: String {
        return """
        Conflict Resolution Statistics:
        - Total Conflicts: \(totalConflicts)
        - Resolved: \(resolvedConflicts)
        - Failed: \(failedResolutions)
        - Success Rate: \(String(format: "%.1f", successRate * 100))%
        - Most Common Conflict Type: \(mostCommonConflictType?.rawValue ?? "N/A")
        - Most Used Strategy: \(mostUsedStrategy?.description ?? "N/A")
        """
    }
    
    public var mostCommonConflictType: ConflictResolver.ConflictType? {
        return conflictsByType.max(by: { $0.value < $1.value })?.key
    }
    
    public var mostUsedStrategy: ConflictResolver.ConflictResolutionStrategy? {
        return resolutionsByStrategy.max(by: { $0.value < $1.value })?.key
    }
}

// MARK: - Helper Extensions

private extension Dictionary {
    func mapKeys<NewKey>(_ transform: (Key) -> NewKey) -> [NewKey: Value] {
        return Dictionary<NewKey, Value>(uniqueKeysWithValues: self.map { (transform($0.key), $0.value) })
    }
}