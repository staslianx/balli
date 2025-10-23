//
//  ShoppingListIntegrationTests.swift
//  balliTests
//
//  Integration tests for shopping list tap-to-edit functionality
//

import XCTest
import CoreData
import SwiftUI
@testable import balli

class ShoppingListIntegrationTests: XCTestCase {
    var persistenceController: PersistenceController!
    var viewContext: NSManagedObjectContext!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Use preview controller for testing
        persistenceController = PersistenceController.preview
        viewContext = persistenceController.container.viewContext
    }
    
    override func tearDownWithError() throws {
        // Clean up test data
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = ShoppingListItem.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        try viewContext.execute(deleteRequest)
        try viewContext.save()
        
        persistenceController = nil
        viewContext = nil
        try super.tearDownWithError()
    }
    
    func testShoppingListItemBasicOperations() throws {
        // Test basic shopping list item creation
        let item = ShoppingListItem.create(
            name: "Test Item",
            category: "general",
            quantity: "2",
            notes: "Test notes",
            in: viewContext
        )
        
        XCTAssertNotNil(item)
        XCTAssertEqual(item.name, "Test Item")
        XCTAssertEqual(item.category, "general")
        XCTAssertEqual(item.quantity, "2")
        XCTAssertEqual(item.notes, "Test notes")
        XCTAssertFalse(item.isCompleted)
        XCTAssertNotNil(item.id)
        XCTAssertNotNil(item.dateCreated)
        XCTAssertNotNil(item.lastModified)
        
        // Test saving
        try viewContext.save()
        
        // Verify persistence
        let fetchRequest: NSFetchRequest<ShoppingListItem> = ShoppingListItem.fetchRequest()
        let items = try viewContext.fetch(fetchRequest)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.name, "Test Item")
    }
    
    func testShoppingListItemEditing() throws {
        // Create original item
        let item = ShoppingListItem.create(
            name: "Original Name",
            category: "general",
            quantity: "1",
            notes: "Original notes",
            in: viewContext
        )
        
        try viewContext.save()
        
        let originalModified = item.lastModified
        
        // Simulate tap-to-edit workflow (wait to ensure different timestamps)
        Thread.sleep(forTimeInterval: 0.01)
        
        // Edit the item (simulates what happens in saveEditedItem)
        item.name = "Edited Name"
        item.quantity = "3"
        item.notes = "Edited notes"
        item.lastModified = Date()
        
        try viewContext.save()
        
        // Verify changes
        XCTAssertEqual(item.name, "Edited Name")
        XCTAssertEqual(item.quantity, "3")
        XCTAssertEqual(item.notes, "Edited notes")
        XCTAssertGreaterThan(item.lastModified, originalModified)
        
        // Verify persistence by refetching
        let fetchRequest: NSFetchRequest<ShoppingListItem> = ShoppingListItem.fetchRequest()
        let items = try viewContext.fetch(fetchRequest)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.name, "Edited Name")
    }
    
    func testShoppingListItemCompletion() throws {
        // Create item
        let item = ShoppingListItem.create(
            name: "Toggle Test Item",
            category: "general",
            quantity: nil,
            notes: nil,
            in: viewContext
        )
        
        try viewContext.save()
        
        // Initial state should be not completed
        XCTAssertFalse(item.isCompleted)
        XCTAssertNil(item.dateCompleted)
        
        // Toggle to completed
        let originalModified = item.lastModified
        Thread.sleep(forTimeInterval: 0.01)
        
        item.isCompleted = true
        item.lastModified = Date()
        item.dateCompleted = Date()
        
        try viewContext.save()
        
        XCTAssertTrue(item.isCompleted)
        XCTAssertNotNil(item.dateCompleted)
        XCTAssertGreaterThan(item.lastModified, originalModified)
        
        // Toggle back to not completed
        item.isCompleted = false
        item.dateCompleted = nil
        item.lastModified = Date()
        
        try viewContext.save()
        
        XCTAssertFalse(item.isCompleted)
        XCTAssertNil(item.dateCompleted)
    }
    
    func testShoppingListSortingOrder() throws {
        // Create items with different completion states and sort orders
        let completedItem = ShoppingListItem.create(name: "Completed Item", category: "general", quantity: nil, notes: nil, in: viewContext)
        completedItem.isCompleted = true
        completedItem.sortOrder = 1
        
        let pendingItem = ShoppingListItem.create(name: "Pending Item", category: "general", quantity: nil, notes: nil, in: viewContext)
        pendingItem.isCompleted = false
        pendingItem.sortOrder = 2
        
        try viewContext.save()
        
        // Test sort descriptors (same as used in ShoppingListView)
        let fetchRequest: NSFetchRequest<ShoppingListItem> = ShoppingListItem.fetchRequest()
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(keyPath: \ShoppingListItem.isCompleted, ascending: true),
            NSSortDescriptor(keyPath: \ShoppingListItem.sortOrder, ascending: true)
        ]
        
        let items = try viewContext.fetch(fetchRequest)
        
        // Pending items should come first (isCompleted: false), then completed items
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[0].name, "Pending Item")
        XCTAssertFalse(items[0].isCompleted)
        XCTAssertEqual(items[1].name, "Completed Item")
        XCTAssertTrue(items[1].isCompleted)
    }
    
    func testEmptyNameHandling() throws {
        // Test that empty/whitespace names are handled properly (simulates validation)
        let trimmedName = "   ".trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertTrue(trimmedName.isEmpty)
        
        let validName = "  Valid Name  ".trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertEqual(validName, "Valid Name")
        XCTAssertFalse(validName.isEmpty)
        
        // Test that trimmed valid name can be saved
        let item = ShoppingListItem.create(name: validName, category: "general", quantity: nil, notes: nil, in: viewContext)
        XCTAssertEqual(item.name, "Valid Name")
        
        try viewContext.save()
        
        let fetchRequest: NSFetchRequest<ShoppingListItem> = ShoppingListItem.fetchRequest()
        let items = try viewContext.fetch(fetchRequest)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.name, "Valid Name")
    }
    
    func testMultipleItemsEditingScenario() throws {
        // Test scenario where user might edit multiple items
        let item1 = ShoppingListItem.create(name: "Item 1", category: "general", quantity: nil, notes: nil, in: viewContext)
        let item2 = ShoppingListItem.create(name: "Item 2", category: "general", quantity: nil, notes: nil, in: viewContext)
        
        try viewContext.save()
        
        // Simulate editing both items with slight delays
        Thread.sleep(forTimeInterval: 0.01)
        
        item1.name = "Edited Item 1"
        item1.lastModified = Date()
        
        Thread.sleep(forTimeInterval: 0.01)
        
        item2.name = "Edited Item 2"  
        item2.lastModified = Date()
        
        try viewContext.save()
        
        // Both edits should persist
        XCTAssertEqual(item1.name, "Edited Item 1")
        XCTAssertEqual(item2.name, "Edited Item 2")
        
        // Verify with fetch
        let fetchRequest: NSFetchRequest<ShoppingListItem> = ShoppingListItem.fetchRequest()
        let items = try viewContext.fetch(fetchRequest)
        XCTAssertEqual(items.count, 2)
        
        let sortedItems = items.sorted { $0.name < $1.name }
        XCTAssertEqual(sortedItems[0].name, "Edited Item 1")
        XCTAssertEqual(sortedItems[1].name, "Edited Item 2")
    }
}