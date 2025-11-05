//
//  ShoppingListItemData.swift
//  balli
//
//  Sendable data transfer object for ShoppingListItem
//  Use this for passing shopping list data across actor boundaries
//

import Foundation

/// Thread-safe Sendable representation of a ShoppingListItem
/// Use this when you need to pass shopping list data across actor boundaries
/// or store it in Task-isolated contexts
struct ShoppingListItemData: Sendable, Identifiable {
    let id: UUID
    let name: String
    let quantity: String?
    let measurementUnit: String?
    let category: String?
    let notes: String?
    let brand: String?
    let isCompleted: Bool
    let isFromRecipe: Bool
    let recipeId: UUID?
    let recipeName: String?
    let sortOrder: Int32
    let dateCreated: Date
    let lastModified: Date
    let dateCompleted: Date?

    /// Create from Core Data entity
    init(from item: ShoppingListItem) {
        self.id = item.id
        self.name = item.name
        self.quantity = item.quantity
        self.measurementUnit = item.measurementUnit
        self.category = item.category
        self.notes = item.notes
        self.brand = item.brand
        self.isCompleted = item.isCompleted
        self.isFromRecipe = item.isFromRecipe
        self.recipeId = item.recipeId
        self.recipeName = item.recipeName
        self.sortOrder = item.sortOrder
        self.dateCreated = item.dateCreated
        self.lastModified = item.lastModified
        self.dateCompleted = item.dateCompleted
    }
}

// MARK: - Conversion Extension

extension ShoppingListItem {
    /// Convert to thread-safe Sendable data structure
    func toData() -> ShoppingListItemData {
        ShoppingListItemData(from: self)
    }
}
