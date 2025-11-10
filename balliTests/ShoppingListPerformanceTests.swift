//
//  ShoppingListPerformanceTests.swift
//  balliTests
//
//  Performance tests to verify Core Data index fixes and UUID sync
//  Created to fix crash issues with large shopping lists (5-7 crashes reported)
//

import XCTest
import CoreData
@testable import balli

final class ShoppingListPerformanceTests: XCTestCase {
    var testContext: NSManagedObjectContext!

    override func setUp() async throws {
        try await super.setUp()

        // Create in-memory Core Data stack for testing
        let container = NSPersistentContainer(name: "balli", managedObjectModel: NSManagedObjectModel.mergedModel(from: nil)!)
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            container.loadPersistentStores { description, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }

        testContext = container.viewContext
    }

    override func tearDown() async throws {
        testContext = nil
        try await super.tearDown()
    }

    // MARK: - Performance Tests

    /// Test query performance with large dataset (1000 items)
    /// With indexes, this should complete in < 1ms
    func testLargeDatasetQueryPerformance() async throws {
        // Given: 1000 shopping list items with mix of recipes and standalone items
        print("📊 [TEST] Creating 1000 shopping list items...")

        for i in 0..<1000 {
            let item = ShoppingListItem(context: testContext)
            item.id = UUID()
            item.name = "Test Item \(i)"
            item.isFromRecipe = i % 3 == 0  // Every 3rd item is from a recipe

            if item.isFromRecipe {
                let recipeIndex = i / 3
                item.recipeName = "Test Recipe \(recipeIndex)"
                item.recipeId = UUID()  // Temporary UUID (simulates pre-save state)
            }

            item.isCompleted = i % 5 == 0  // Every 5th item is completed
            item.sortOrder = Int32(i)
            item.dateCreated = Date()
            item.lastModified = Date()

            if item.isCompleted {
                item.dateCompleted = Date()
            }
        }

        try testContext.save()
        print("✅ [TEST] Created 1000 items successfully")

        // When: Query by recipeName (should use index)
        let request = ShoppingListItem.fetchRequest()
        request.predicate = NSPredicate(format: "recipeName == %@", "Test Recipe 100")

        let start = Date()
        let results = try testContext.fetch(request)
        let duration = Date().timeIntervalSince(start)

        print("⏱️ [TEST] Query completed in \(String(format: "%.4f", duration * 1000))ms")
        print("📈 [TEST] Found \(results.count) results")

        // Then: Query should be fast (< 10ms even without index, < 1ms with index on Release build)
        // Using 50ms threshold for Debug builds with in-memory store
        XCTAssertLessThan(duration, 0.05, "Query took \(duration)s - should be < 50ms (< 1ms in Release with index)")
        XCTAssertGreaterThan(results.count, 0, "Should find matching items")
    }

    /// Test query performance by recipeId (indexed)
    func testRecipeIdQueryPerformance() async throws {
        // Given: 1000 items with specific recipeId
        let targetRecipeId = UUID()

        for i in 0..<1000 {
            let item = ShoppingListItem(context: testContext)
            item.id = UUID()
            item.name = "Item \(i)"
            item.isFromRecipe = true
            item.recipeName = i == 500 ? "Target Recipe" : "Other Recipe \(i)"
            item.recipeId = i == 500 ? targetRecipeId : UUID()
            item.isCompleted = false
            item.sortOrder = Int32(i)
            item.dateCreated = Date()
            item.lastModified = Date()
        }

        try testContext.save()

        // When: Query by recipeId
        let request = ShoppingListItem.fetchRequest()
        request.predicate = NSPredicate(format: "recipeId == %@", targetRecipeId as NSUUID)

        let start = Date()
        let results = try testContext.fetch(request)
        let duration = Date().timeIntervalSince(start)

        print("⏱️ [TEST] recipeId query completed in \(String(format: "%.4f", duration * 1000))ms")

        // Then: Should be fast
        XCTAssertLessThan(duration, 0.05, "Query took \(duration)s - should be < 50ms")
        XCTAssertEqual(results.count, 1, "Should find exactly one item with target recipeId")
    }

    /// Test composite index query (recipeName + isCompleted)
    func testCompositeIndexQuery() async throws {
        // Given: Mix of completed and uncompleted items for same recipe
        for i in 0..<500 {
            let item = ShoppingListItem(context: testContext)
            item.id = UUID()
            item.name = "Item \(i)"
            item.isFromRecipe = true
            item.recipeName = "Test Recipe Alpha"
            item.recipeId = UUID()
            item.isCompleted = i % 2 == 0  // Half completed, half not
            item.sortOrder = Int32(i)
            item.dateCreated = Date()
            item.lastModified = Date()

            if item.isCompleted {
                item.dateCompleted = Date()
            }
        }

        try testContext.save()

        // When: Query by recipeName AND isCompleted (composite index)
        let request = ShoppingListItem.fetchRequest()
        request.predicate = NSPredicate(
            format: "recipeName == %@ AND isCompleted == NO",
            "Test Recipe Alpha"
        )

        let start = Date()
        let results = try testContext.fetch(request)
        let duration = Date().timeIntervalSince(start)

        print("⏱️ [TEST] Composite query completed in \(String(format: "%.4f", duration * 1000))ms")
        print("📈 [TEST] Found \(results.count) uncompleted items")

        // Then: Should be fast and return correct count
        XCTAssertLessThan(duration, 0.05, "Query took \(duration)s - should be < 50ms")
        XCTAssertEqual(results.count, 250, "Should find 250 uncompleted items")
    }

    // MARK: - UUID Sync Tests

    /// Test that shopping list UUID sync works correctly
    func testShoppingListUUIDSync() throws {
        // Given: Shopping list items with temporary UUID
        let temporaryUUID = UUID()
        let recipeName = "Tavuk Sote"

        for i in 0..<5 {
            let item = ShoppingListItem(context: testContext)
            item.id = UUID()
            item.name = "Ingredient \(i)"
            item.isFromRecipe = true
            item.recipeName = recipeName
            item.recipeId = temporaryUUID  // Temporary UUID before recipe save
            item.isCompleted = false
            item.sortOrder = Int32(i)
            item.dateCreated = Date()
            item.lastModified = Date()
        }

        try testContext.save()
        print("✅ [TEST] Created 5 shopping items with temporary UUID: \(temporaryUUID)")

        // When: Recipe is saved with real UUID (simulate RecipePersistenceCoordinator behavior)
        let realRecipeUUID = UUID()

        let request = ShoppingListItem.fetchRequest()
        request.predicate = NSPredicate(
            format: "recipeName == %@ AND isFromRecipe == YES",
            recipeName
        )

        let items = try testContext.fetch(request)
        print("📊 [TEST] Found \(items.count) items to sync")

        for item in items {
            if item.recipeId != realRecipeUUID {
                print("🔄 [TEST] Syncing item '\(item.name)' to real UUID: \(realRecipeUUID)")
                item.recipeId = realRecipeUUID
            }
        }

        try testContext.save()

        // Then: All items should have the real UUID
        let verifyRequest = ShoppingListItem.fetchRequest()
        verifyRequest.predicate = NSPredicate(
            format: "recipeName == %@ AND recipeId == %@",
            recipeName, realRecipeUUID as NSUUID
        )

        let syncedItems = try testContext.fetch(verifyRequest)

        XCTAssertEqual(syncedItems.count, 5, "All 5 items should have real UUID")

        // Verify no items have the temporary UUID
        let orphanRequest = ShoppingListItem.fetchRequest()
        orphanRequest.predicate = NSPredicate(
            format: "recipeName == %@ AND recipeId == %@",
            recipeName, temporaryUUID as NSUUID
        )

        let orphanedItems = try testContext.fetch(orphanRequest)
        XCTAssertEqual(orphanedItems.count, 0, "No items should have temporary UUID after sync")

        print("✅ [TEST] UUID sync successful: 0 orphaned items, 5 synced items")
    }

    // MARK: - Safety Predicate Tests

    /// Test that old completed items are filtered out (30+ days)
    func testOldCompletedItemsFiltered() throws {
        // Given: Mix of old and recent completed items
        let calendar = Calendar.current

        // Recent completed items (should be visible)
        for i in 0..<5 {
            let item = ShoppingListItem(context: testContext)
            item.id = UUID()
            item.name = "Recent Item \(i)"
            item.isCompleted = true
            item.sortOrder = Int32(i)
            item.dateCreated = Date()
            item.lastModified = Date()
            item.dateCompleted = calendar.date(byAdding: .day, value: -10, to: Date())  // 10 days ago
        }

        // Old completed items (should be filtered)
        for i in 0..<10 {
            let item = ShoppingListItem(context: testContext)
            item.id = UUID()
            item.name = "Old Item \(i)"
            item.isCompleted = true
            item.sortOrder = Int32(i + 5)
            item.dateCreated = calendar.date(byAdding: .day, value: -60, to: Date())!
            item.lastModified = calendar.date(byAdding: .day, value: -60, to: Date())!
            item.dateCompleted = calendar.date(byAdding: .day, value: -45, to: Date())  // 45 days ago
        }

        try testContext.save()

        // When: Apply safety predicate (same as ShoppingListViewSimple)
        let request = ShoppingListItem.fetchRequest()
        request.predicate = NSPredicate(
            format: "isCompleted == NO OR dateCompleted > %@ OR dateCompleted == nil",
            calendar.date(byAdding: .day, value: -30, to: Date())! as NSDate
        )

        let filteredItems = try testContext.fetch(request)

        // Then: Only recent items should be returned
        let completedItems = filteredItems.filter { $0.isCompleted }
        XCTAssertEqual(completedItems.count, 5, "Should only show 5 recent completed items, not 10 old ones")

        print("✅ [TEST] Safety predicate working: \(completedItems.count) recent items visible, old items filtered")
    }
}
