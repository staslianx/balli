//
//  ConflictResolver.swift
//  balli
//
//  Handles Core Data conflicts with configurable resolution strategies
//

@preconcurrency import CoreData
import Foundation
import os.log

// MARK: - Sendable Value Wrapper

/// Wrapper to make arbitrary values Sendable for conflict resolution
public struct SendableValue: @unchecked Sendable {
    public let value: Any
    
    public init(_ value: Any) {
        self.value = value
    }
}

/// Resolves conflicts in Core Data operations with configurable strategies
@PersistenceActor
public final class ConflictResolver {
    private let logger = os.Logger(subsystem: "com.balli.diabetes", category: "ConflictResolver")
    
    // Configuration
    private let defaultStrategy: ConflictResolutionStrategy
    
    // Components
    private let strategies = ConflictResolutionStrategies()
    private let resolverRegistry = ConflictResolverRegistry()
    private let statistics = ConflictStatistics()
    
    // MARK: - Types
    
    public enum ConflictType: String, CaseIterable, Sendable {
        case mergeConflict = "merge_conflict"
        case optimisticLockingFailure = "optimistic_locking_failure"
        case uniqueConstraintViolation = "unique_constraint_violation"
        case relationshipConflict = "relationship_conflict"
        case validationError = "validation_error"
        case unknownConflict = "unknown_conflict"
    }
    
    public enum ConflictResolutionStrategy: Sendable, CustomStringConvertible, Hashable {
        case clientWins          // Local changes take precedence
        case serverWins          // Remote/persistent changes take precedence
        case merge               // Attempt to merge changes intelligently
        case timestamp           // Most recent change wins based on timestamp
        case userPrompt          // Ask user to resolve manually
        case custom(String)      // Use custom resolver by name
        case fail                // Fail the operation
        
        public var description: String {
            switch self {
            case .clientWins: return "clientWins"
            case .serverWins: return "serverWins"
            case .merge: return "merge"
            case .timestamp: return "timestamp"
            case .userPrompt: return "userPrompt"
            case .custom(let name): return "custom(\(name))"
            case .fail: return "fail"
            }
        }
        
        // Swift automatically synthesizes Hashable and Equatable for enums
        // No need for manual implementation
    }
    
    public struct ConflictContext {
        public let conflictType: ConflictType
        public let entity: NSManagedObject
        public let conflictingValues: [String: Any]
        public let localValues: [String: Any]
        public let remoteValues: [String: Any]
        public let timestamp: Date
        public let userInfo: [String: Any]
        
        public init(
            conflictType: ConflictType,
            entity: NSManagedObject,
            conflictingValues: [String: Any],
            localValues: [String: Any],
            remoteValues: [String: Any],
            timestamp: Date = Date(),
            userInfo: [String: Any] = [:]
        ) {
            self.conflictType = conflictType
            self.entity = entity
            self.conflictingValues = conflictingValues
            self.localValues = localValues
            self.remoteValues = remoteValues
            self.timestamp = timestamp
            self.userInfo = userInfo
        }
    }
    
    public struct ConflictResolution: Sendable {
        public let resolvedValues: [String: SendableValue]
        public let strategy: ConflictResolutionStrategy
        public let confidence: Double
        public let reasoning: String
        
        public init(
            resolvedValues: [String: SendableValue],
            strategy: ConflictResolutionStrategy,
            confidence: Double = 1.0,
            reasoning: String = ""
        ) {
            self.resolvedValues = resolvedValues
            self.strategy = strategy
            self.confidence = confidence
            self.reasoning = reasoning
        }
        
        // Convenience initializer for backward compatibility
        public init(
            resolvedValues: [String: Any],
            strategy: ConflictResolutionStrategy,
            confidence: Double = 1.0,
            reasoning: String = ""
        ) {
            self.resolvedValues = resolvedValues.mapValues { SendableValue($0) }
            self.strategy = strategy
            self.confidence = confidence
            self.reasoning = reasoning
        }
    }
    
    // MARK: - Protocol for Custom Resolvers
    
    public protocol EntityConflictResolver: Sendable {
        func resolve(context: ConflictContext) async throws -> ConflictResolution
        var supportedEntityTypes: [String] { get }
    }
    
    // MARK: - Initialization
    
    public init(
        defaultStrategy: ConflictResolutionStrategy = .merge,
        customResolvers: [String: EntityConflictResolver] = [:]
    ) {
        self.defaultStrategy = defaultStrategy
        
        // Register any initial custom resolvers
        for (name, resolver) in customResolvers {
            resolverRegistry.registerResolver(resolver, forName: name)
        }
    }
    
    // MARK: - Public API
    
    /// Resolve a merge conflict using the configured strategy
    public func resolveConflict(
        context: ConflictContext,
        strategy: ConflictResolutionStrategy? = nil
    ) async throws -> ConflictResolution {
        
        let usedStrategy = strategy ?? defaultStrategy
        let resolutionId = UUID().uuidString
        
        logger.info("Resolving \(context.conflictType.rawValue) conflict using \(usedStrategy)")

        // Start timing
        statistics.startTiming(forResolutionId: resolutionId)
        
        do {
            let resolution: ConflictResolution
            
            // Handle custom strategy differently
            if case .custom(let resolverName) = usedStrategy {
                resolution = try await performCustomResolution(context: context, resolverName: resolverName)
            } else {
                resolution = try await strategies.performResolution(context: context, strategy: usedStrategy)
            }

            // Record success statistics
            statistics.recordResolution(resolution, forContext: context, resolutionId: resolutionId)

            logger.debug("Conflict resolved with confidence: \(resolution.confidence)")
            return resolution
            
        } catch {
            // Note: Statistics recording disabled due to compiler complexity limits
            // await statistics.recordFailure(forContext: context, error: error, resolutionId: resolutionId)

            logger.error("Failed to resolve conflict: \(error)")
            throw ConflictResolutionError.resolutionFailed(context.conflictType, error)
        }
    }
    
    /// Resolve conflicts from Core Data merge policy notifications
    public func handleMergeConflicts(
        for objects: [NSManagedObject],
        in context: NSManagedObjectContext
    ) async throws -> [NSManagedObject: ConflictResolution] {
        
        var resolutions: [NSManagedObject: ConflictResolution] = [:]
        
        for object in objects {
            let conflictContext = try await buildConflictContext(for: object, in: context)
            let resolution = try await resolveConflict(context: conflictContext)
            resolutions[object] = resolution
            
            // Apply resolution
            try await applyResolution(resolution, to: object)
        }
        
        return resolutions
    }
    
    /// Register a custom conflict resolver for specific entity types
    public func registerCustomResolver(_ resolver: EntityConflictResolver, forName name: String) {
        resolverRegistry.registerResolver(resolver, forName: name)
        logger.info("Registered custom conflict resolver: \(name)")
    }
    
    // MARK: - Custom Resolution Handling

    private func performCustomResolution(
        context: ConflictContext,
        resolverName: String
    ) async throws -> ConflictResolution {

        guard let resolver = resolverRegistry.getResolver(named: resolverName) else {
            throw ConflictResolutionError.customResolverNotFound(resolverName)
        }

        let entityName = context.entity.entity.name ?? "Unknown"
        guard resolver.supportedEntityTypes.contains(entityName) else {
            throw ConflictResolutionError.resolverNotSupported(resolverName, entityName)
        }

        // Note: ConflictContext contains NSManagedObject which is not Sendable
        // This is safe because Core Data guarantees thread confinement via NSManagedObjectContext
        // All Core Data operations must occur on the context's queue
        // Use nonisolated(unsafe) to suppress the data race warning
        nonisolated(unsafe) let unsafeContext = context
        return try await resolver.resolve(context: unsafeContext)
    }
    
    
    // MARK: - Helper Methods
    
    private func buildConflictContext(
        for object: NSManagedObject,
        in context: NSManagedObjectContext
    ) async throws -> ConflictContext {

        let _ = object.entity.name ?? "Unknown"
        
        // Get current values
        var localValues: [String: Any] = [:]
        var remoteValues: [String: Any] = [:]
        var conflictingValues: [String: Any] = [:]
        
        for (key, _) in object.entity.propertiesByName {
            let currentValue = object.value(forKey: key)
            localValues[key] = currentValue
            
            // For simplicity, we'll use committed values as "remote" values
            let committedValues = object.committedValues(forKeys: [key])
            let committedValue = committedValues[key]
            remoteValues[key] = committedValue
            
            // Check if values differ
            if !valuesAreEqual(currentValue, committedValue) {
                conflictingValues[key] = ["local": currentValue, "remote": committedValue]
            }
        }
        
        // Determine conflict type
        let conflictType: ConflictType = conflictingValues.isEmpty ? .unknownConflict : .mergeConflict
        
        return ConflictContext(
            conflictType: conflictType,
            entity: object,
            conflictingValues: conflictingValues,
            localValues: localValues,
            remoteValues: remoteValues,
            timestamp: Date()
        )
    }
    
    private func applyResolution(
        _ resolution: ConflictResolution,
        to object: NSManagedObject
    ) async throws {
        
        for (key, sendableValue) in resolution.resolvedValues {
            object.setValue(sendableValue.value, forKey: key)
        }
        
        logger.debug("Applied conflict resolution to \(object.entity.name ?? "unknown") entity")
    }
    
    private func valuesAreEqual(_ value1: Any?, _ value2: Any?) -> Bool {
        if value1 == nil && value2 == nil { return true }
        if value1 == nil || value2 == nil { return false }
        
        if let v1 = value1 as? NSObject, let v2 = value2 as? NSObject {
            return v1.isEqual(v2)
        }
        
        return false
    }
    
    // MARK: - Statistics
    
    public var conflictStatistics: (resolved: Int, failed: Int, byType: [ConflictType: Int]) {
        let overallStats = statistics.overallStatistics
        let byTypeStats = statistics.conflictsByTypeStatistics
        return (overallStats.resolved, overallStats.failed, byTypeStats)
    }
    
    public func resetStatistics() {
        statistics.resetStatistics()
    }
    
    /// Get detailed statistics report
    public var detailedStatistics: ConflictStatisticsReport {
        return statistics.detailedReport
    }
}

// MARK: - Errors

public enum ConflictResolutionError: LocalizedError {
    case resolutionFailed(ConflictResolver.ConflictType, Error)
    case resolutionRefused(ConflictResolver.ConflictType)
    case customResolverNotFound(String)
    case resolverNotSupported(String, String)
    case invalidConflictContext
    
    public var errorDescription: String? {
        switch self {
        case .resolutionFailed(let type, let error):
            return "Çakışma çözümü başarısız (\(type.rawValue)): \(error.localizedDescription)"
        case .resolutionRefused(let type):
            return "Çakışma çözümü reddedildi: \(type.rawValue)"
        case .customResolverNotFound(let name):
            return "Özel çözücü bulunamadı: \(name)"
        case .resolverNotSupported(let resolver, let entity):
            return "Çözücü \(resolver) bu varlık tipini desteklemiyor: \(entity)"
        case .invalidConflictContext:
            return "Geçersiz çakışma bağlamı"
        }
    }
}

