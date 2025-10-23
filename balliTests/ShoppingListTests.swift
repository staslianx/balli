//
//  ShoppingListTests.swift
//  balliTests
//
//  Unit tests for shopping list functionality
//

import XCTest
import CoreData
@testable import balli

final class ShoppingListTests: XCTestCase {
    
    var testContext: NSManagedObjectContext!
    var persistenceController: PersistenceController!
    
    override func setUpWithError() throws {
        // Create in-memory persistence controller for testing
        persistenceController = PersistenceController(inMemory: true)
        testContext = persistenceController.viewContext
    }
    
    override func tearDownWithError() throws {
        testContext = nil
        persistenceController = nil
    }
    
    // MARK: - Model Tests
    
    func testShoppingListItemCreation() throws {
        // Given
        let itemName = "Test Item"
        let category = ShoppingListItem.ShoppingCategory.dairy.rawValue
        let quantity = "1 liter"
        let notes = "Test notes"
        
        // When
        let item = ShoppingListItem.create(
            name: itemName,
            category: category,
            quantity: quantity,
            notes: notes,
            in: testContext
        )
        
        // Then
        XCTAssertEqual(item.name, itemName)
        XCTAssertEqual(item.category, category)
        XCTAssertEqual(item.quantity, quantity)
        XCTAssertEqual(item.notes, notes)
        XCTAssertFalse(item.isCompleted)
        XCTAssertNotNil(item.id)
        XCTAssertNotNil(item.dateCreated)
        XCTAssertNil(item.dateCompleted)
        XCTAssertEqual(item.sortOrder, 0) // First item should have sort order 0
    }
    
    func testShoppingListItemCompletion() throws {
        // Given
        let item = ShoppingListItem.create(
            name: "Test Item",
            category: ShoppingListItem.ShoppingCategory.general.rawValue,
            in: testContext
        )
        XCTAssertFalse(item.isCompleted)
        XCTAssertNil(item.dateCompleted)
        
        // When
        item.isCompleted = true
        
        // Force Core Data to call willSave
        try testContext.save()
        
        // Then
        XCTAssertTrue(item.isCompleted)
        XCTAssertNotNil(item.dateCompleted)
    }
    
    func testShoppingListItemDisplayName() throws {
        // Given
        let itemWithQuantity = ShoppingListItem.create(
            name: "Milk",
            quantity: "1 liter",
            in: testContext
        )
        
        let itemWithoutQuantity = ShoppingListItem.create(
            name: "Bread",
            in: testContext
        )
        
        // Then
        XCTAssertEqual(itemWithQuantity.displayName, "1 liter Milk")
        XCTAssertEqual(itemWithoutQuantity.displayName, "Bread")
    }
    
    func testShoppingListItemValidation() throws {
        // Given
        let validItem = ShoppingListItem.create(name: "Valid Item", in: testContext)
        let invalidItem = ShoppingListItem(context: testContext)
        invalidItem.name = "" // Empty name should be invalid
        
        // Then
        XCTAssertTrue(validItem.isValid)
        XCTAssertFalse(invalidItem.isValid)
        XCTAssertTrue(invalidItem.validationErrors.contains("Ürün adı boş olamaz"))
    }
    
    func testShoppingListItemCategories() throws {
        // Given
        let categories = ShoppingListItem.allCategories
        
        // Then
        XCTAssertFalse(categories.isEmpty)
        XCTAssertTrue(categories.contains(ShoppingListItem.ShoppingCategory.dairy.rawValue))
        XCTAssertTrue(categories.contains(ShoppingListItem.ShoppingCategory.general.rawValue))
        
        // Test category icon
        let item = ShoppingListItem.create(
            name: "Test",
            category: ShoppingListItem.ShoppingCategory.dairy.rawValue,
            in: testContext
        )
        XCTAssertEqual(item.categoryIcon, ShoppingListItem.ShoppingCategory.dairy.icon)
    }
    
    func testShoppingListItemSortOrder() throws {
        // Given
        let item1 = ShoppingListItem.create(name: "First Item", in: testContext)
        let item2 = ShoppingListItem.create(name: "Second Item", in: testContext)
        let item3 = ShoppingListItem.create(name: "Third Item", in: testContext)
        
        try testContext.save()
        
        // Then
        XCTAssertEqual(item1.sortOrder, 0)
        XCTAssertEqual(item2.sortOrder, 1)
        XCTAssertEqual(item3.sortOrder, 2)
    }
    
    // MARK: - Fetch Request Tests
    
    func testFetchIncompleteItems() throws {
        // Given
        let incompleteItem = ShoppingListItem.create(name: "Incomplete", in: testContext)
        let completedItem = ShoppingListItem.create(name: "Complete", in: testContext)
        completedItem.isCompleted = true
        
        try testContext.save()
        
        // When
        let request = ShoppingListItem.fetchIncompleteItems()
        let results = try testContext.fetch(request)
        
        // Then
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.name, "Incomplete")
    }
    
    func testFetchCompletedItems() throws {
        // Given
        let incompleteItem = ShoppingListItem.create(name: "Incomplete", in: testContext)
        let completedItem = ShoppingListItem.create(name: "Complete", in: testContext)
        completedItem.isCompleted = true
        
        try testContext.save()
        
        // When
        let request = ShoppingListItem.fetchCompletedItems()
        let results = try testContext.fetch(request)
        
        // Then
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.name, "Complete")
    }
    
    func testFetchItemsByCategory() throws {
        // Given
        let dairyItem = ShoppingListItem.create(
            name: "Milk",
            category: ShoppingListItem.ShoppingCategory.dairy.rawValue,
            in: testContext
        )
        let meatItem = ShoppingListItem.create(
            name: "Chicken",
            category: ShoppingListItem.ShoppingCategory.meat.rawValue,
            in: testContext
        )
        
        try testContext.save()
        
        // When
        let dairyRequest = ShoppingListItem.fetchItems(in: ShoppingListItem.ShoppingCategory.dairy.rawValue)
        let dairyResults = try testContext.fetch(dairyRequest)
        
        // Then
        XCTAssertEqual(dairyResults.count, 1)
        XCTAssertEqual(dairyResults.first?.name, "Milk")
    }
    
    // MARK: - Performance Tests
    
    func testPerformanceCreateManyItems() throws {
        measure {
            // Create 100 items
            for i in 0..<100 {
                _ = ShoppingListItem.create(
                    name: "Item \(i)",
                    category: ShoppingListItem.ShoppingCategory.general.rawValue,
                    in: testContext
                )
            }
            
            do {
                try testContext.save()
            } catch {
                XCTFail("Failed to save context: \(error)")
            }
        }
    }
}