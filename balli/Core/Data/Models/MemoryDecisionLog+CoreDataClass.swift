//
//  MemoryDecisionLog+CoreDataClass.swift
//  balli
//
//  Core Data class for memory decision logging
//

import Foundation
import CoreData

@objc(MemoryDecisionLog)
public class MemoryDecisionLog: NSManagedObject, @unchecked Sendable {
    
    // MARK: - Core Data Lifecycle
    
    public override func awakeFromInsert() {
        super.awakeFromInsert()
        
        // Set default values
        self.timestamp = Date()
        self.isActive = true
    }
    
    // MARK: - Convenience Initializers
    
    convenience init(context: NSManagedObjectContext,
                     decision: String,
                     confidence: Double = 0.0,
                     metadata: String? = nil) {
        self.init(context: context)
        
        self.decision = decision
        self.confidence = confidence
        self.metadata = metadata
        self.timestamp = Date()
        self.isActive = true
    }
    
    // MARK: - Business Logic
    
    public var isHighConfidence: Bool {
        return confidence >= 0.8
    }
    
    public var ageInMinutes: Int {
        return Int(Date().timeIntervalSince(timestamp ?? Date()) / 60)
    }
    
    public var isExpired: Bool {
        let expirationMinutes = 60 // 1 hour
        return ageInMinutes > expirationMinutes
    }
}

// MARK: - Fetch Requests

extension MemoryDecisionLog {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<MemoryDecisionLog> {
        return NSFetchRequest<MemoryDecisionLog>(entityName: "MemoryDecisionLog")
    }
    
    public class func activeLogsFetchRequest() -> NSFetchRequest<MemoryDecisionLog> {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "isActive == YES")
        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        return request
    }
    
    public class func highConfidenceLogsFetchRequest() -> NSFetchRequest<MemoryDecisionLog> {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "isActive == YES AND confidence >= 0.8")
        request.sortDescriptors = [NSSortDescriptor(key: "confidence", ascending: false)]
        return request
    }
}