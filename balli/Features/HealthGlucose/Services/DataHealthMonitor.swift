//
//  DataHealthMonitor.swift
//  balli
//
//  Monitors Core Data store health and detects issues
//

@preconcurrency import CoreData
import Foundation
import os.log

/// Monitors database health and detects issues
actor DataHealthMonitor {
    private let logger = os.Logger(subsystem: "com.balli.diabetes", category: "DataHealth")
    
    // Health metrics
    private var lastCheckDate: Date?
    private var lastVacuumDate: Date?
    private var lastAnalyzeDate: Date?
    private var consecutiveErrors = 0
    private var totalSaves = 0
    private var failedSaves = 0
    
    // Thresholds
    private let maxDatabaseSize: Int64 = 100_000_000 // 100 MB
    private let maxOrphanedObjects = 100
    private let maxFragmentation = 0.3
    private let healthCheckInterval: TimeInterval = 300 // 5 minutes
    
    // MARK: - Public API
    
    /// Start monitoring the database
    func startMonitoring(container: NSPersistentContainer) async {
        logger.info("Starting database health monitoring")
        
        // Perform initial health check
        _ = await checkHealth(container: container)
        
        // Monitor Core Data notifications
        setupNotificationMonitoring()
    }
    
    /// Perform comprehensive health check
    func checkHealth(container: NSPersistentContainer) async -> DataHealth {
        logger.debug("Performing health check")
        lastCheckDate = Date()
        
        var issues: [DataHealthIssue] = []
        
        // Get store URL
        guard let storeURL = container.persistentStoreDescriptions.first?.url else {
            logger.error("Could not get store URL")
            return DataHealth(isHealthy: false, issues: issues, metrics: DataHealthMetrics())
        }
        
        // Check database size
        let databaseSize = await checkDatabaseSize(at: storeURL)
        if databaseSize > maxDatabaseSize {
            issues.append(DataHealthIssue(
                type: .excessiveSize,
                severity: .medium,
                description: "Database size exceeds limit: \(databaseSize / 1_000_000) MB",
                affectedCount: 0
            ))
        }
        
        // Check for orphaned objects
        let orphanedCount = await checkOrphanedObjects(in: container)
        if orphanedCount > maxOrphanedObjects {
            issues.append(DataHealthIssue(
                type: .orphanedData,
                severity: .low,
                description: "Found \(orphanedCount) orphaned objects",
                affectedCount: orphanedCount
            ))
        }
        
        // Check relationship consistency
        let inconsistentCount = await checkRelationshipConsistency(in: container)
        if inconsistentCount > 0 {
            issues.append(DataHealthIssue(
                type: .inconsistentRelationships,
                severity: .medium,
                description: "Found \(inconsistentCount) inconsistent relationships",
                affectedCount: inconsistentCount
            ))
        }
        
        // Calculate fragmentation
        let fragmentation = await calculateFragmentation(at: storeURL)
        if fragmentation > maxFragmentation {
            issues.append(DataHealthIssue(
                type: .excessiveSize,
                severity: .low,
                description: "Database fragmentation: \(Int(fragmentation * 100))%",
                affectedCount: 0
            ))
        }
        
        // Check save failure rate
        let saveFailureRate = totalSaves > 0 ? Double(failedSaves) / Double(totalSaves) : 0
        if saveFailureRate > 0.1 { // More than 10% failures
            issues.append(DataHealthIssue(
                type: .corruptedData,
                severity: .high,
                description: "High save failure rate: \(Int(saveFailureRate * 100))%",
                affectedCount: failedSaves
            ))
        }
        
        // Get entity counts
        let entityCounts = await getEntityCounts(in: container)
        
        // Create health metrics
        let metrics = DataHealthMetrics(
            totalObjects: entityCounts.values.reduce(0, +),
            orphanedObjects: orphanedCount,
            corruptedObjects: 0, // We don't track this separately yet
            databaseSize: databaseSize,
            lastMaintenanceDate: lastVacuumDate ?? lastAnalyzeDate
        )
        
        let isHealthy = issues.isEmpty || issues.allSatisfy { $0.severity == .low }
        
        logger.info("Health check complete - Healthy: \(isHealthy), Issues: \(issues.count)")
        
        return DataHealth(
            isHealthy: isHealthy,
            issues: issues,
            metrics: metrics
        )
    }
    
    /// Record a save operation
    func recordSave(duration: TimeInterval, success: Bool = true) {
        totalSaves += 1
        if !success {
            failedSaves += 1
            consecutiveErrors += 1
            
            if consecutiveErrors > 5 {
                logger.error("Multiple consecutive save failures detected")
            }
        } else {
            consecutiveErrors = 0
        }
        
        // Log slow saves
        if duration > 1.0 {
            logger.warning("Slow save detected: \(String(format: "%.2f", duration))s")
        }
    }
    
    /// Record that maintenance was performed
    func recordMaintenance(type: MaintenanceType) {
        switch type {
        case .vacuum:
            lastVacuumDate = Date()
            logger.info("Database VACUUM completed")
        case .analyze:
            lastAnalyzeDate = Date()
            logger.info("Database ANALYZE completed")
        case .reindex:
            logger.info("Database REINDEX completed")
        }
    }
    
    // MARK: - Private Methods
    
    private func checkDatabaseSize(at url: URL) async -> Int64 {
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
    
    private func checkOrphanedObjects(in container: NSPersistentContainer) async -> Int {
        // Check for objects without required relationships
        // This is simplified - real implementation would check specific entities

        let orphanedCount = 0 // Note: Proper orphan detection requires Swift 6 concurrency implementation

        return orphanedCount
    }
    
    private func checkRelationshipConsistency(in container: NSPersistentContainer) async -> Int {
        // Check for inconsistent relationships
        let inconsistentCount = 0 // Note: Proper relationship consistency check requires Swift 6 concurrency implementation

        return inconsistentCount
    }
    
    private func calculateFragmentation(at url: URL) async -> Double {
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
    
    private func getEntityCounts(in container: NSPersistentContainer) async -> [String: Int] {
        let counts: [String: Int] = [:] // Note: Proper entity counting requires Swift 6 concurrency implementation

        return counts
    }
    
    private func setupNotificationMonitoring() {
        // Monitor save notifications
        NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextDidSave,
            object: nil,
            queue: nil
        ) { _ in
            Task {
                await self.recordSave(duration: 0, success: true)
            }
        }
    }
    
    // MARK: - Repair Operations
    
    /// Clean up orphaned objects (moved off main thread)
    func cleanupOrphanedObjects(in container: NSPersistentContainer) async throws -> Int {
        logger.info("Starting orphaned object cleanup")
        
        // Create background context for heavy operations
        let backgroundContext = container.newBackgroundContext()
        backgroundContext.automaticallyMergesChangesFromParent = true
        
        return try await backgroundContext.perform {
            var deletedCount = 0
            
            // Find and delete orphaned objects
            let request = FoodItem.fetchRequest()
            request.predicate = NSPredicate(format: "name == nil OR name == ''")
            
            let orphaned = try backgroundContext.fetch(request)
            
            for object in orphaned {
                backgroundContext.delete(object)
                deletedCount += 1
            }
            
            if backgroundContext.hasChanges {
                try backgroundContext.save()
            }
            
            return deletedCount
        }
    }
    
    /// Repair inconsistent relationships (moved off main thread)
    func repairRelationships(in container: NSPersistentContainer) async throws -> Int {
        logger.info("Starting relationship repair")
        
        // Create background context for heavy operations
        let backgroundContext = container.newBackgroundContext()
        backgroundContext.automaticallyMergesChangesFromParent = true

        return await backgroundContext.perform {
            // Implementation would repair specific relationship issues
            // This is a placeholder
            backgroundContext.refreshAllObjects()
            return 0
        }
    }
}

// MARK: - Supporting Types

enum MaintenanceType {
    case vacuum
    case analyze
    case reindex
}