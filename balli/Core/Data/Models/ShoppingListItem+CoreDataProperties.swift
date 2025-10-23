//
//  ShoppingListItem+CoreDataProperties.swift
//  balli
//
//  Created by Core Data Model Generator
//

import Foundation
import CoreData

extension ShoppingListItem {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<ShoppingListItem> {
        return NSFetchRequest<ShoppingListItem>(entityName: "ShoppingListItem")
    }
    
    // MARK: - Identifiers
    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var category: String?
    
    // MARK: - Status
    @NSManaged public var isCompleted: Bool
    @NSManaged public var sortOrder: Int32
    
    // MARK: - Additional Info
    @NSManaged public var notes: String?
    @NSManaged public var quantity: String?
    @NSManaged public var brand: String?
    
    // MARK: - Recipe Association
    @NSManaged public var recipeId: UUID?
    @NSManaged public var recipeName: String?
    @NSManaged public var isFromRecipe: Bool
    @NSManaged public var measurementUnit: String?
    
    // MARK: - Metadata
    @NSManaged public var dateCreated: Date
    @NSManaged public var lastModified: Date
    @NSManaged public var dateCompleted: Date?
}

extension ShoppingListItem : Identifiable {
}