//
//  MemoryDecisionLog+CoreDataProperties.swift
//  balli
//
//  Core Data properties for MemoryDecisionLog
//

import Foundation
import CoreData

extension MemoryDecisionLog {

    @NSManaged public var decision: String?
    @NSManaged public var confidence: Double
    @NSManaged public var metadata: String?
    @NSManaged public var timestamp: Date?
    @NSManaged public var isActive: Bool

}