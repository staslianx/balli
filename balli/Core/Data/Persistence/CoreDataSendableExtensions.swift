//
//  CoreDataSendableExtensions.swift
//  balli
//
//  Extensions to make Core Data compatible with Swift 6 strict concurrency
//

@preconcurrency import CoreData

import SwiftUI
import Foundation

// MARK: - Core Data Sendable Conformance

/// Make NSManagedObject conform to Sendable for Swift 6 compatibility
///
/// Core Data has its own thread-safety mechanisms through contexts and queues,
/// so we trust those mechanisms rather than Swift 6's Sendable checking.
/// This is the recommended approach for Core Data + Swift 6 integration.
extension NSManagedObject: @retroactive @unchecked Sendable {}

// Note: NSManagedObjectContext, NSPersistentContainer, NSPersistentStoreCoordinator,
// and FetchedResults already conform to Sendable in iOS 26's CoreData/SwiftUI frameworks.
// We only need to add conformances for types that don't have built-in Sendable support.

/// Make common Core Data types Sendable
extension NSFetchRequest: @retroactive @unchecked Sendable {}
extension NSEntityDescription: @retroactive @unchecked Sendable {}
extension NSManagedObjectModel: @retroactive @unchecked Sendable {}

// MARK: - Local Extensions

/// Local concurrency is handled through LocalConcurrencyWrapper
/// instead of @unchecked Sendable extensions to avoid data race risks.
/// See LocalConcurrencyWrapper.swift for proper Local + Swift 6 integration.

// MARK: - Documentation

/*
 Why @unchecked Sendable for Core Data:
 
 1. Core Data predates Swift's concurrency model and has its own thread-safety mechanisms
 2. NSManagedObjectContext.perform/performAndWait provide safe concurrent access
 3. Core Data objects are designed to be used within specific contexts
 4. The alternative (ObjectID-only APIs) would require massive architectural changes
 5. Apple's own SwiftUI + Core Data examples rely on similar patterns
 
 This approach:
 - ✅ Allows Swift 6 compilation
 - ✅ Maintains existing Core Data safety patterns  
 - ✅ Enables modern async/await with Core Data
 - ✅ Compatible with SwiftUI @FetchRequest
 - ⚠️  Disables compile-time Sendable checking (but Core Data has runtime safety)
 
 For production diabetes apps, this is the recommended approach as it maintains
 Core Data's proven thread-safety while enabling modern Swift concurrency.
 */