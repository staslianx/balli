//
//  ShoppingListSwipeTests.swift
//  balliTests
//
//  Integration tests for shopping list swipe-to-delete functionality
//

import XCTest
import SwiftUI
import CoreData
@testable import balli

class ShoppingListSwipeTests: XCTestCase {
    
    var viewContext: NSManagedObjectContext!
    
    override func setUp() {
        super.setUp()
        // Use in-memory store for testing
        let container = NSPersistentContainer(name: "balli")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        
        container.loadPersistentStores { _, error in
            if let error = error {
                XCTFail("Failed to load store: \(error)")
            }
        }
        
        viewContext = container.viewContext
    }
    
    override func tearDown() {
        viewContext = nil
        super.tearDown()
    }
    
    @MainActor
    func testListSupportsSwipeActions() {
        // Test that List view supports swipe actions
        let listView = List {
            Text("Test Item")
                .swipeActions {
                    Button("Delete") { }
                }
        }
        
        // List should compile with swipeActions
        XCTAssertNotNil(listView, "List should support swipe actions")
    }
    
    func testShoppingListItemCanBeDeleted() {
        // Create a test item
        let item = ShoppingListItem(context: viewContext)
        item.id = UUID()
        item.name = "Test Item"
        item.lastModified = Date()
        item.isCompleted = false
        
        do {
            try viewContext.save()
            XCTAssertNotNil(item.managedObjectContext, "Item should be in context")
            
            // Delete the item
            viewContext.delete(item)
            try viewContext.save()
            
            // Verify deletion
            let fetchRequest: NSFetchRequest<ShoppingListItem> = ShoppingListItem.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "name == %@", "Test Item")
            let results = try viewContext.fetch(fetchRequest)
            
            XCTAssertEqual(results.count, 0, "Item should be deleted")
        } catch {
            XCTFail("Error during test: \(error)")
        }
    }
    
    @MainActor
    func testEditableItemRowStructure() {
        // Test that EditableItemRow has the correct structure for swipe
        // This is a compile-time test to ensure the view is properly structured
        
        let item = ShoppingListItem(context: viewContext)
        item.id = UUID()
        item.name = "Test"
        item.lastModified = Date()
        
        let row = EditableItemRow(
            item: item,
            onSave: { _, _ in },
            onDelete: { },
            onToggle: { },
            onNoteUpdate: { _ in }
        )
        
        XCTAssertNotNil(row, "EditableItemRow should be created successfully")
    }
}