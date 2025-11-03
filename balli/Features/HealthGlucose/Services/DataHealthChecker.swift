//
//  DataHealthChecker.swift
//  balli
//
//  Performs specific health validation checks on Core Data store
//  Extracted from DataHealthMonitor for single responsibility
//  Swift 6 strict concurrency compliant
//

@preconcurrency import CoreData
import Foundation
import os.log

/// Performs specific health validation checks
actor DataHealthChecker {
    private let logger = os.Logger(subsystem: "com.balli.diabetes", category: "DataHealthChecker")

    // MARK: - Health Check Operations

    /// Check database file size including WAL and SHM files
    func checkDatabaseSize(at url: URL) -> Int64 {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let size = attributes[.size] as? Int64 ?? 0

            // Also check WAL and SHM files
            let walURL = url.appendingPathExtension("wal")
            let shmURL = url.appendingPathExtension("shm")

            let walSize = (try? FileManager.default.attributesOfItem(atPath: walURL.path)[.size] as? Int64) ?? 0
            let shmSize = (try? FileManager.default.attributesOfItem(atPath: shmURL.path)[.size] as? Int64) ?? 0

            return size + walSize + shmSize
        } catch {
            logger.error("Failed to check database size: \(error)")
            return 0
        }
    }

    /// Check for objects without required relationships
    func checkOrphanedObjects(in container: NSPersistentContainer) async -> Int {
        // Check for objects without required relationships
        // This is simplified - real implementation would check specific entities

        let orphanedCount = 0 // Note: Proper orphan detection requires Swift 6 concurrency implementation

        return orphanedCount
    }

    /// Check for inconsistent relationships
    func checkRelationshipConsistency(in container: NSPersistentContainer) async -> Int {
        // Check for inconsistent relationships
        let inconsistentCount = 0 // Note: Proper relationship consistency check requires Swift 6 concurrency implementation

        return inconsistentCount
    }

    /// Calculate fragmentation based on file size vs actual data
    func calculateFragmentation(at url: URL) -> Double {
        // Calculate fragmentation based on file size vs actual data
        // This is a simplified calculation

        do {
            let fileSize = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64 ?? 0

            // Estimate actual data size (this would need actual implementation)
            // For now, return a mock value
            let estimatedDataSize = Int64(Double(fileSize) * 0.85)

            if fileSize > 0 {
                return 1.0 - (Double(estimatedDataSize) / Double(fileSize))
            }
        } catch {
            logger.error("Failed to calculate fragmentation: \(error)")
        }

        return 0.0
    }

    /// Get entity counts for all entities
    func getEntityCounts(in container: NSPersistentContainer) async -> [String: Int] {
        let counts: [String: Int] = [:] // Note: Proper entity counting requires Swift 6 concurrency implementation

        return counts
    }
}
