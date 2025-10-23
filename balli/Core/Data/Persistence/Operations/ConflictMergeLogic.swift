//
//  ConflictMergeLogic.swift
//  balli
//
//  Handles intelligent merging of conflicting values in Core Data
//

@preconcurrency import CoreData
import Foundation
import os.log

/// Handles the intelligent merging of conflicting values
@PersistenceActor
public final class ConflictMergeLogic {
    private let logger = os.Logger(subsystem: "com.balli.diabetes", category: "ConflictMergeLogic")
    
    // MARK: - Merge Value Logic
    
    public func mergeValues(
        key: String,
        localValue: Any,
        remoteValue: Any?,
        entity: NSManagedObject
    ) async throws -> (value: Any, confidence: Double) {
        
        // Get attribute/relationship description
        guard let property = entity.entity.propertiesByName[key] else {
            // Unknown property, prefer local value
            return (localValue, 0.7)
        }
        
        if let attributeDesc = property as? NSAttributeDescription {
            return try await mergeAttribute(
                localValue: localValue,
                remoteValue: remoteValue,
                attributeDescription: attributeDesc
            )
        } else if let relationshipDesc = property as? NSRelationshipDescription {
            return try await mergeRelationship(
                localValue: localValue,
                remoteValue: remoteValue,
                relationshipDescription: relationshipDesc
            )
        }
        
        return (localValue, 0.5)
    }
    
    // MARK: - Attribute Merging
    
    private func mergeAttribute(
        localValue: Any,
        remoteValue: Any?,
        attributeDescription: NSAttributeDescription
    ) async throws -> (value: Any, confidence: Double) {
        
        guard let remoteValue = remoteValue else {
            return (localValue, 0.9) // Local value when remote is nil
        }
        
        switch attributeDescription.attributeType {
        case .stringAttributeType:
            return try await mergeStringAttributes(local: localValue, remote: remoteValue)
            
        case .integer16AttributeType, .integer32AttributeType, .integer64AttributeType:
            return try await mergeNumericAttributes(local: localValue, remote: remoteValue)
            
        case .doubleAttributeType, .floatAttributeType, .decimalAttributeType:
            return try await mergeNumericAttributes(local: localValue, remote: remoteValue)
            
        case .dateAttributeType:
            return try await mergeDateAttributes(local: localValue, remote: remoteValue)
            
        case .booleanAttributeType:
            return try await mergeBooleanAttributes(local: localValue, remote: remoteValue)
            
        default:
            // For other types, prefer local value
            return (localValue, 0.6)
        }
    }
    
    private func mergeStringAttributes(local: Any, remote: Any) async throws -> (value: Any, confidence: Double) {
        guard let localString = local as? String,
              let remoteString = remote as? String else {
            return (local, 0.5)
        }
        
        // If strings are similar, keep local. If very different, might need user input
        let similarity = stringSimilarity(localString, remoteString)
        
        if similarity > 0.8 {
            return (localString, 0.9) // Very similar, keep local
        } else if similarity < 0.3 {
            // Very different strings - in health data, prefer more recent or longer
            let useLocal = localString.count >= remoteString.count
            return (useLocal ? localString : remoteString, 0.4)
        } else {
            // Moderately different - keep local but with lower confidence
            return (localString, 0.6)
        }
    }
    
    private func mergeNumericAttributes(local: Any, remote: Any) async throws -> (value: Any, confidence: Double) {
        // For health data like glucose readings, prefer the local value if it's reasonable
        // Otherwise take the remote value
        
        if let localNumber = local as? NSNumber,
           let remoteNumber = remote as? NSNumber {
            
            let localDouble = localNumber.doubleValue
            let remoteDouble = remoteNumber.doubleValue
            
            // For health metrics, check if values are in reasonable ranges
            let isLocalReasonable = isHealthValueReasonable(localDouble)
            let isRemoteReasonable = isHealthValueReasonable(remoteDouble)
            
            if isLocalReasonable && !isRemoteReasonable {
                return (local, 0.9)
            } else if !isLocalReasonable && isRemoteReasonable {
                return (remote, 0.9)
            } else {
                // Both reasonable or both unreasonable - prefer local
                return (local, 0.7)
            }
        }
        
        return (local, 0.6)
    }
    
    private func mergeDateAttributes(local: Any, remote: Any) async throws -> (value: Any, confidence: Double) {
        guard let localDate = local as? Date,
              let remoteDate = remote as? Date else {
            return (local, 0.5)
        }
        
        // For timestamps, prefer the more recent date
        let useLocal = localDate > remoteDate
        return (useLocal ? localDate : remoteDate, 0.8)
    }
    
    private func mergeBooleanAttributes(local: Any, remote: Any) async throws -> (value: Any, confidence: Double) {
        guard let localBool = local as? Bool,
              let remoteBool = remote as? Bool else {
            return (local, 0.5)
        }
        
        // For boolean values, if they differ, prefer local with medium confidence
        return (localBool, localBool == remoteBool ? 1.0 : 0.6)
    }
    
    private func mergeRelationship(
        localValue: Any,
        remoteValue: Any?,
        relationshipDescription: NSRelationshipDescription
    ) async throws -> (value: Any, confidence: Double) {
        
        // Relationship merging is complex - for now, prefer local relationships
        // In a full implementation, you'd need to handle to-one vs to-many relationships
        return (localValue, 0.7)
    }
    
    // MARK: - Helper Methods
    
    private func stringSimilarity(_ s1: String, _ s2: String) -> Double {
        let longer = s1.count > s2.count ? s1 : s2
        let _ = s1.count > s2.count ? s2 : s1
        
        if longer.isEmpty { return 1.0 }
        
        let distance = levenshteinDistance(s1, s2)
        return (Double(longer.count) - Double(distance)) / Double(longer.count)
    }
    
    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let s1Array = Array(s1)
        let s2Array = Array(s2)
        let s1Count = s1Array.count
        let s2Count = s2Array.count
        
        var matrix = Array(repeating: Array(repeating: 0, count: s2Count + 1), count: s1Count + 1)
        
        for i in 0...s1Count {
            matrix[i][0] = i
        }
        
        for j in 0...s2Count {
            matrix[0][j] = j
        }
        
        for i in 1...s1Count {
            for j in 1...s2Count {
                let cost = s1Array[i-1] == s2Array[j-1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i-1][j] + 1,      // deletion
                    matrix[i][j-1] + 1,      // insertion
                    matrix[i-1][j-1] + cost   // substitution
                )
            }
        }
        
        return matrix[s1Count][s2Count]
    }
    
    private func isHealthValueReasonable(_ value: Double) -> Bool {
        // Basic reasonableness checks for common health metrics
        // This would be more sophisticated in a real implementation
        
        // Glucose readings (mg/dL): typically 20-600
        if value > 0 && value < 1000 {
            return true
        }
        
        return false
    }
}