//
//  ConflictCustomResolvers.swift
//  balli
//
//  Custom conflict resolvers for specific entity types and business logic
//

@preconcurrency import CoreData
import Foundation

// MARK: - Predefined Custom Resolvers

/// Custom resolver for diabetes-related health data
public struct DiabetesDataConflictResolver: ConflictResolver.EntityConflictResolver, Sendable {
    public let supportedEntityTypes = ["GlucoseReading", "MealEntry", "InsulinDose", "FoodItem"]
    
    public func resolve(context: ConflictResolver.ConflictContext) async throws -> ConflictResolver.ConflictResolution {
        let entityName = context.entity.entity.name ?? ""
        
        switch entityName {
        case "GlucoseReading":
            return try await resolveGlucoseReading(context: context)
        case "MealEntry":
            return try await resolveMealEntry(context: context)
        case "InsulinDose":
            return try await resolveInsulinDose(context: context)
        case "FoodItem":
            return try await resolveFoodItem(context: context)
        default:
            throw ConflictResolutionError.resolverNotSupported("DiabetesDataConflictResolver", entityName)
        }
    }
    
    private func resolveGlucoseReading(context: ConflictResolver.ConflictContext) async throws -> ConflictResolver.ConflictResolution {
        // For glucose readings, prefer more recent readings and reasonable values
        var resolvedValues = context.localValues
        var confidence = 0.8
        
        // Check glucose value reasonableness
        if let localGlucose = context.localValues["value"] as? Double,
           let remoteGlucose = context.remoteValues["value"] as? Double {
            
            let localReasonable = (20...600).contains(localGlucose)
            let remoteReasonable = (20...600).contains(remoteGlucose)
            
            if !localReasonable && remoteReasonable {
                resolvedValues["value"] = remoteGlucose
                confidence = 0.9
            } else if localReasonable && !remoteReasonable {
                confidence = 0.9
            }
        }
        
        return ConflictResolver.ConflictResolution(
            resolvedValues: resolvedValues,
            strategy: .custom("DiabetesDataConflictResolver"),
            confidence: confidence,
            reasoning: "Diabetes-specific glucose reading resolution"
        )
    }
    
    private func resolveMealEntry(context: ConflictResolver.ConflictContext) async throws -> ConflictResolver.ConflictResolution {
        // For meal entries, merge carb counts and preserve meal timing
        var resolvedValues = context.localValues
        
        // Prefer more recent meal data but validate carb counts
        if let localCarbs = context.localValues["totalCarbohydrates"] as? Double,
           let remoteCarbs = context.remoteValues["totalCarbohydrates"] as? Double {
            
            // Use the more reasonable carb count
            if localCarbs < 0 && remoteCarbs >= 0 {
                resolvedValues["totalCarbohydrates"] = remoteCarbs
            } else if remoteCarbs < 0 && localCarbs >= 0 {
                // Keep local value
            } else {
                // Both reasonable or both unreasonable - prefer local
            }
        }
        
        return ConflictResolver.ConflictResolution(
            resolvedValues: resolvedValues,
            strategy: .custom("DiabetesDataConflictResolver"),
            confidence: 0.8,
            reasoning: "Meal entry validation applied"
        )
    }
    
    private func resolveInsulinDose(context: ConflictResolver.ConflictContext) async throws -> ConflictResolver.ConflictResolution {
        // For insulin doses, be very careful - prefer local values for safety
        return ConflictResolver.ConflictResolution(
            resolvedValues: context.localValues,
            strategy: .custom("DiabetesDataConflictResolver"),
            confidence: 0.9,
            reasoning: "Safety-first approach for insulin data"
        )
    }
    
    private func resolveFoodItem(context: ConflictResolver.ConflictContext) async throws -> ConflictResolver.ConflictResolution {
        // For food items, merge nutritional data intelligently
        var resolvedValues = context.remoteValues // Start with remote as base
        
        // Override with local values that seem more accurate
        for (key, localValue) in context.localValues {
            if key.contains("carbohydrates") || key.contains("calories") || key.contains("protein") {
                if let localNum = localValue as? Double,
                   let remoteNum = context.remoteValues[key] as? Double {
                    // Use the value that's more reasonable (not negative, not impossibly high)
                    if localNum >= 0 && localNum < 1000 && (remoteNum < 0 || remoteNum > 1000) {
                        resolvedValues[key] = localValue
                    }
                }
            } else {
                // For non-nutritional fields, prefer local values
                resolvedValues[key] = localValue
            }
        }
        
        return ConflictResolver.ConflictResolution(
            resolvedValues: resolvedValues,
            strategy: .custom("DiabetesDataConflictResolver"),
            confidence: 0.7,
            reasoning: "Nutritional data validation and merge applied"
        )
    }
}

// MARK: - Custom Resolver Registry

/// Manages custom conflict resolvers
@PersistenceActor
public final class ConflictResolverRegistry {
    private var customResolvers: [String: ConflictResolver.EntityConflictResolver] = [:]
    
    public init() {
        // Register default custom resolvers
        registerDefaultResolvers()
    }
    
    /// Register a custom conflict resolver for specific entity types
    public func registerResolver(_ resolver: ConflictResolver.EntityConflictResolver, forName name: String) {
        customResolvers[name] = resolver
    }
    
    /// Get a custom resolver by name
    public func getResolver(named name: String) -> ConflictResolver.EntityConflictResolver? {
        return customResolvers[name]
    }
    
    /// Get all registered resolver names
    public var registeredResolverNames: [String] {
        return Array(customResolvers.keys)
    }
    
    private func registerDefaultResolvers() {
        registerResolver(DiabetesDataConflictResolver(), forName: "DiabetesDataConflictResolver")
    }
}