//
//  PersistenceMonitor.swift
//  balli
//
//  Health monitoring and debugging for persistence layer
//

import CoreData
import OSLog

/// Monitors persistence health and provides debugging utilities
@PersistenceActor
public final class PersistenceMonitor {
    
    // MARK: - Properties
    
    private let logger = AppLoggers.Data.coredata
    private let container: NSPersistentContainer
    private var operationHistory: [OperationRecord] = []
    private let maxHistorySize = 100
    
    // MARK: - Types
    
    private struct OperationRecord {
        let operation: String
        let success: Bool
        let duration: TimeInterval?
        let timestamp: Date
    }
    
    // MARK: - Initialization
    
    public init(container: NSPersistentContainer) {
        self.container = container
    }
    
    // MARK: - Operation Logging
    
    public func logOperation(_ operation: String, success: Bool, duration: TimeInterval? = nil) {
        let record = OperationRecord(
            operation: operation,
            success: success,
            duration: duration,
            timestamp: Date()
        )
        
        operationHistory.append(record)
        
        // Trim history if needed
        if operationHistory.count > maxHistorySize {
            operationHistory.removeFirst(operationHistory.count - maxHistorySize)
        }
        
        // Log to system
        if success {
            logger.debug("\(operation) - Duration: \(duration ?? 0)s")
        } else {
            logger.error("\(operation) failed")
        }
    }
    
    // MARK: - Health Check
    
    public func checkHealth() async -> DataHealth {
        logger.info("Performing health check")
        
        var issues: [DataHealthIssue] = []
        
        // Check database size
        let databaseSize = await getDatabaseSize()
        if databaseSize > 100_000_000 { // 100MB
            issues.append(DataHealthIssue(
                type: .excessiveSize,
                severity: .medium,
                description: "Database size exceeds 100MB",
                affectedCount: 0
            ))
        }
        
        // Check for orphaned objects
        let orphanedCount = await checkOrphanedObjects()
        if orphanedCount > 0 {
            issues.append(DataHealthIssue(
                type: .orphanedData,
                severity: .low,
                description: "Found orphaned objects",
                affectedCount: orphanedCount
            ))
        }
        
        // Create metrics
        let metrics = DataHealthMetrics(
            totalObjects: await getTotalObjectCount(),
            orphanedObjects: orphanedCount,
            corruptedObjects: 0,
            databaseSize: databaseSize,
            lastMaintenanceDate: Date()
        )
        
        return DataHealth(
            isHealthy: issues.isEmpty,
            issues: issues,
            metrics: metrics
        )
    }
    
    // MARK: - Metrics
    
    public func getMetrics() async -> HealthMetrics {
        let entityCounts = await getEntityCounts()
        let databaseSize = await getDatabaseSize()
        
        return HealthMetrics(
            databaseSize: databaseSize,
            entityCounts: entityCounts,
            lastVacuum: nil,
            lastAnalyze: nil,
            fragmentationLevel: 0.0,
            orphanedObjectCount: await checkOrphanedObjects(),
            inconsistentRelationshipCount: 0
        )
    }
    
    // MARK: - Memory Management
    
    public func handleMemoryPressure() async {
        logger.warning("Handling memory pressure")
        
        // Reset contexts to free memory
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            container.viewContext.perform {
                self.container.viewContext.refreshAllObjects()
                continuation.resume()
            }
        }
        
        // Clear operation history
        operationHistory.removeAll()
        
        logger.info("Memory pressure handled")
    }
    
    // MARK: - Private Helpers
    
    private func getDatabaseSize() async -> Int64 {
        guard let storeURL = container.persistentStoreDescriptions.first?.url else {
            return 0
        }
        
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: storeURL.path)
            return attributes[.size] as? Int64 ?? 0
        } catch {
            logger.error("Failed to get database size: \(error)")
            return 0
        }
    }
    
    private func getTotalObjectCount() async -> Int {
        var total = 0
        let entities = container.managedObjectModel.entities
        
        for entity in entities {
            guard let entityName = entity.name else { continue }
            
            let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
            request.includesSubentities = false
            
            do {
                let count = try container.viewContext.count(for: request)
                total += count
            } catch {
                logger.error("Failed to count \(entityName): \(error)")
            }
        }
        
        return total
    }
    
    private func getEntityCounts() async -> [String: Int] {
        var counts: [String: Int] = [:]
        let entities = container.managedObjectModel.entities
        
        for entity in entities {
            guard let entityName = entity.name else { continue }
            
            let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
            request.includesSubentities = false
            
            do {
                counts[entityName] = try container.viewContext.count(for: request)
            } catch {
                logger.error("Failed to count \(entityName): \(error)")
                counts[entityName] = 0
            }
        }
        
        return counts
    }
    
    private func checkOrphanedObjects() async -> Int {
        // Placeholder for orphaned object detection
        // Would need specific business logic to determine what constitutes an orphaned object
        return 0
    }
}