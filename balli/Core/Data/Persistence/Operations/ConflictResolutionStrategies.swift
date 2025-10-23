//
//  ConflictResolutionStrategies.swift
//  balli
//
//  Handles different conflict resolution strategies for Core Data conflicts
//

@preconcurrency import CoreData
import Foundation
import os.log

/// Contains the core resolution strategies for handling conflicts
@PersistenceActor
public final class ConflictResolutionStrategies {
    private let logger = os.Logger(subsystem: "com.balli.diabetes", category: "ConflictResolutionStrategies")
    
    // MARK: - Resolution Strategy Implementation
    
    public func performResolution(
        context: ConflictResolver.ConflictContext,
        strategy: ConflictResolver.ConflictResolutionStrategy
    ) async throws -> ConflictResolver.ConflictResolution {
        
        switch strategy {
        case .clientWins:
            return try await clientWinsResolution(context: context)
            
        case .serverWins:
            return try await serverWinsResolution(context: context)
            
        case .merge:
            return try await mergeResolution(context: context)
            
        case .timestamp:
            return try await timestampResolution(context: context)
            
        case .userPrompt:
            return try await userPromptResolution(context: context)
            
        case .custom(let resolverName):
            throw ConflictResolutionError.customResolverNotFound(resolverName) // Will be handled by ConflictResolver
            
        case .fail:
            throw ConflictResolutionError.resolutionRefused(context.conflictType)
        }
    }
    
    // MARK: - Individual Strategy Implementations
    
    private func clientWinsResolution(context: ConflictResolver.ConflictContext) async throws -> ConflictResolver.ConflictResolution {
        return ConflictResolver.ConflictResolution(
            resolvedValues: context.localValues,
            strategy: .clientWins,
            confidence: 1.0,
            reasoning: "Client values take precedence"
        )
    }
    
    private func serverWinsResolution(context: ConflictResolver.ConflictContext) async throws -> ConflictResolver.ConflictResolution {
        return ConflictResolver.ConflictResolution(
            resolvedValues: context.remoteValues,
            strategy: .serverWins,
            confidence: 1.0,
            reasoning: "Server values take precedence"
        )
    }
    
    private func mergeResolution(context: ConflictResolver.ConflictContext) async throws -> ConflictResolver.ConflictResolution {
        let mergeLogic = ConflictMergeLogic()
        
        var mergedValues = context.remoteValues
        var confidence = 0.8
        let reasoning = "Intelligent merge applied"
        
        // Apply merge logic based on entity type and field types
        for (key, localValue) in context.localValues {
            let remoteValue = context.remoteValues[key]
            
            let mergedValue = try await mergeLogic.mergeValues(
                key: key,
                localValue: localValue,
                remoteValue: remoteValue,
                entity: context.entity
            )
            
            mergedValues[key] = mergedValue.value
            confidence = min(confidence, mergedValue.confidence)
        }
        
        return ConflictResolver.ConflictResolution(
            resolvedValues: mergedValues,
            strategy: .merge,
            confidence: confidence,
            reasoning: reasoning
        )
    }
    
    private func timestampResolution(context: ConflictResolver.ConflictContext) async throws -> ConflictResolver.ConflictResolution {
        // Use modification timestamps to determine which values to use
        let localTimestamp = context.localValues["modificationDate"] as? Date ?? Date.distantPast
        let remoteTimestamp = context.remoteValues["modificationDate"] as? Date ?? Date.distantPast
        
        let useLocal = localTimestamp > remoteTimestamp
        let resolvedValues = useLocal ? context.localValues : context.remoteValues
        
        return ConflictResolver.ConflictResolution(
            resolvedValues: resolvedValues,
            strategy: .timestamp,
            confidence: 0.9,
            reasoning: "Most recent timestamp wins: \(useLocal ? "local" : "remote")"
        )
    }
    
    private func userPromptResolution(context: ConflictResolver.ConflictContext) async throws -> ConflictResolver.ConflictResolution {
        // In a real app, this would show UI to the user
        // For now, we'll fall back to merge strategy
        logger.warning("User prompt resolution requested but not implemented, falling back to merge")
        return try await mergeResolution(context: context)
    }
}