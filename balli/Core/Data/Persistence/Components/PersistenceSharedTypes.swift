//
//  PersistenceSharedTypes.swift
//  balli
//
//  Shared types and configurations for persistence components
//

@preconcurrency import CoreData
import Foundation

// MARK: - Configuration

public struct PersistenceConfiguration: Sendable {
    public let modelName: String
    public let inMemory: Bool
    public let enableAutomaticMigration: Bool
    public let enableInferredMigration: Bool
    public let queryCacheSize: Int
    public let entityCacheSize: Int
    public let batchSize: Int
    public let healthCheckInterval: TimeInterval
    public let checkMigrationOnLoad: Bool
    
    public init(
        modelName: String = "balli",
        inMemory: Bool = false,
        enableAutomaticMigration: Bool = true,
        enableInferredMigration: Bool = true,
        queryCacheSize: Int = 100,
        entityCacheSize: Int = 500,
        batchSize: Int = 100,
        healthCheckInterval: TimeInterval = 300,
        checkMigrationOnLoad: Bool = true
    ) {
        self.modelName = modelName
        self.inMemory = inMemory
        self.enableAutomaticMigration = enableAutomaticMigration
        self.enableInferredMigration = enableInferredMigration
        self.queryCacheSize = queryCacheSize
        self.entityCacheSize = entityCacheSize
        self.batchSize = batchSize
        self.healthCheckInterval = healthCheckInterval
        self.checkMigrationOnLoad = checkMigrationOnLoad
    }
    
    public static let `default` = PersistenceConfiguration()
    
    public static let testing = PersistenceConfiguration(
        inMemory: true,
        enableAutomaticMigration: false,
        enableInferredMigration: false,
        queryCacheSize: 10,
        entityCacheSize: 50,
        batchSize: 10,
        healthCheckInterval: 60,
        checkMigrationOnLoad: false
    )
}

// MARK: - Cache Policies

public enum CachePolicy: Sendable {
    case useCache
    case reloadIgnoringCache
    case reloadAndCache
    case returnCacheDataElseLoad
    case returnCacheDataDontLoad
    
    public var shouldCheckCache: Bool {
        switch self {
        case .useCache, .returnCacheDataElseLoad, .returnCacheDataDontLoad:
            return true
        case .reloadIgnoringCache, .reloadAndCache:
            return false
        }
    }
    
    public var shouldUpdateCache: Bool {
        switch self {
        case .useCache, .reloadAndCache, .returnCacheDataElseLoad:
            return true
        case .reloadIgnoringCache, .returnCacheDataDontLoad:
            return false
        }
    }
}

// MARK: - Data Health

public struct DataHealth: Sendable {
    public let isHealthy: Bool
    public let issues: [DataHealthIssue]
    public let metrics: DataHealthMetrics
    
    public var hasIssues: Bool {
        !issues.isEmpty
    }
    
    public init(
        isHealthy: Bool = true,
        issues: [DataHealthIssue] = [],
        metrics: DataHealthMetrics = DataHealthMetrics()
    ) {
        self.isHealthy = isHealthy
        self.issues = issues
        self.metrics = metrics
    }
}

public struct DataHealthIssue: Sendable {
    public let type: IssueType
    public let severity: Severity
    public let description: String
    public let affectedCount: Int
    
    public enum IssueType: Sendable {
        case orphanedData
        case inconsistentRelationships
        case corruptedData
        case excessiveSize
    }
    
    public enum Severity: Sendable {
        case low
        case medium
        case high
        case critical
    }
    
    public init(
        type: IssueType,
        severity: Severity,
        description: String,
        affectedCount: Int = 0
    ) {
        self.type = type
        self.severity = severity
        self.description = description
        self.affectedCount = affectedCount
    }
}

// MARK: - Health Metrics

public struct DataHealthMetrics: Sendable {
    public let totalObjects: Int
    public let orphanedObjects: Int
    public let corruptedObjects: Int
    public let databaseSize: Int64
    public let lastMaintenanceDate: Date?
    
    public init(
        totalObjects: Int = 0,
        orphanedObjects: Int = 0,
        corruptedObjects: Int = 0,
        databaseSize: Int64 = 0,
        lastMaintenanceDate: Date? = nil
    ) {
        self.totalObjects = totalObjects
        self.orphanedObjects = orphanedObjects
        self.corruptedObjects = corruptedObjects
        self.databaseSize = databaseSize
        self.lastMaintenanceDate = lastMaintenanceDate
    }
}

// MARK: - Cache Statistics

// CacheStatistics moved to PersistenceActor.swift to avoid duplication

// MARK: - Batch Operation Results

// BatchOperationResult moved to BatchOperations.swift to avoid duplication

// MARK: - Errors

public enum PersistenceError: LocalizedError, Sendable {
    case saveFailed(Error)
    case fetchFailed(Error)
    case migrationFailed(Error)
    case validationFailed([String])
    case conflictResolutionFailed
    case corruptedDatabase
    case controllerDeallocated
    case transactionFailed(Error)
    case cacheError(Error)
    case invalidRequest(String)
    case batchOperationFailed(Error)

    public var errorDescription: String? {
        switch self {
        case .saveFailed(let error):
            return "Veri kaydedilemedi: \(error.localizedDescription)"
        case .fetchFailed(let error):
            return "Veri alınamadı: \(error.localizedDescription)"
        case .migrationFailed(let error):
            return "Veritabanı güncellenemedi: \(error.localizedDescription)"
        case .validationFailed(let errors):
            return "Doğrulama hatası: \(errors.joined(separator: ", "))"
        case .conflictResolutionFailed:
            return "Veri çakışması çözülemedi"
        case .corruptedDatabase:
            return "Veritabanı bozuk görünüyor"
        case .controllerDeallocated:
            return "Veri kontrolcüsü kullanılamıyor"
        case .transactionFailed(let error):
            return "İşlem başarısız: \(error.localizedDescription)"
        case .cacheError(let error):
            return "Önbellek hatası: \(error.localizedDescription)"
        case .invalidRequest(let message):
            return "Geçersiz istek: \(message)"
        case .batchOperationFailed(let error):
            return "Toplu işlem başarısız: \(error.localizedDescription)"
        }
    }
}