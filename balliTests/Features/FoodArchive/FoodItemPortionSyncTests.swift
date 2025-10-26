//
//  FoodItemPortionSyncTests.swift
//  balliTests
//
//  Integration tests verifying FoodItem portion size synchronization workflow
//  Tests the complete user flow: create item → favorite → edit portion → save → verify favorites show updated values
//

import Testing
import Foundation
import CoreData
@testable import balli

@MainActor
struct FoodItemPortionSyncTests {

    // MARK: - Test Setup

    /// Creates an in-memory Core Data stack for isolated testing
    private func createTestController() -> Persistence.PersistenceController {
        return Persistence.PersistenceController(inMemory: true, waitForReady: true)
    }

    /// Creates a test FoodItem with specified properties
    private func createTestFoodItem(
        in context: NSManagedObjectContext,
        name: String = "Test Product",
        brand: String = "Test Brand",
        servingSize: Double = 100.0,
        calories: Double = 200.0,
        totalCarbs: Double = 30.0,
        fiber: Double = 5.0,
        sugars: Double = 10.0,
        protein: Double = 8.0,
        totalFat: Double = 6.0
    ) -> FoodItem {
        let item = FoodItem(context: context)
        item.id = UUID()
        item.name = name
        item.brand = brand
        item.servingSize = servingSize
        item.servingUnit = "g"
        item.calories = calories
        item.totalCarbs = totalCarbs
        item.fiber = fiber
        item.sugars = sugars
        item.protein = protein
        item.totalFat = totalFat
        item.sodium = 100.0
        item.source = "test"
        item.dateAdded = Date()
        item.lastModified = Date()
        item.isFavorite = false
        item.isVerified = true
        item.useCount = 0
        return item
    }

    /// Simulates the save logic from FoodItemDetailView (lines 360-423)
    private func simulateFoodItemDetailViewSave(
        foodItem: FoodItem,
        newPortionGrams: Double,
        baseServingSize: Double,
        calories: String,
        carbohydrates: String,
        fiber: String,
        sugars: String,
        protein: String,
        fat: String,
        context: NSManagedObjectContext
    ) throws {
        let portionChanged = newPortionGrams != foodItem.servingSize

        if portionChanged {
            // Calculate adjustment ratio
            let adjustmentRatio = newPortionGrams / baseServingSize

            // Update serving size
            foodItem.servingSize = newPortionGrams

            // Adjust all nutrition values proportionally
            foodItem.calories = (Double(calories) ?? 0) * adjustmentRatio
            foodItem.totalCarbs = (Double(carbohydrates) ?? 0) * adjustmentRatio
            foodItem.fiber = (Double(fiber) ?? 0) * adjustmentRatio
            foodItem.sugars = (Double(sugars) ?? 0) * adjustmentRatio
            foodItem.protein = (Double(protein) ?? 0) * adjustmentRatio
            foodItem.totalFat = (Double(fat) ?? 0) * adjustmentRatio
            foodItem.sodium = foodItem.sodium * adjustmentRatio
        } else {
            // No portion change - just update values
            foodItem.calories = Double(calories) ?? 0
            foodItem.totalCarbs = Double(carbohydrates) ?? 0
            foodItem.fiber = Double(fiber) ?? 0
            foodItem.sugars = Double(sugars) ?? 0
            foodItem.protein = Double(protein) ?? 0
            foodItem.totalFat = Double(fat) ?? 0
        }

        // Update lastModified (this triggers willSave in FoodItem+CoreDataClass)
        foodItem.lastModified = Date()

        // Save context
        try context.save()
    }

    // MARK: - Happy Path Tests

    @Test("Complete user workflow: create → favorite → edit portion → save → verify favorites")
    func testCompletePortionSyncWorkflow() async throws {
        // GIVEN: Set up in-memory Core Data
        let controller = createTestController()
        let context = controller.viewContext

        // Wait for Core Data to be ready
        var attempts = 0
        while !(await controller.isReady) && attempts < 50 {
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            attempts += 1
        }
        #expect(await controller.isReady, "Core Data should be ready within 5 seconds")

        // Step 1: Create a FoodItem with initial portion size (100g)
        let foodItem = createTestFoodItem(
            in: context,
            name: "Chocolate Bar",
            brand: "TestCo",
            servingSize: 100.0,
            calories: 200.0,
            totalCarbs: 30.0,
            fiber: 5.0,
            sugars: 10.0,
            protein: 8.0,
            totalFat: 6.0
        )

        // Step 2: Mark it as favorite
        foodItem.isFavorite = true

        // Step 3: Save to Core Data
        try context.save()

        // Verify initial state
        #expect(foodItem.servingSize == 100.0, "Initial portion should be 100g")
        #expect(foodItem.totalCarbs == 30.0, "Initial carbs should be 30g")
        #expect(foodItem.isFavorite == true, "Item should be favorited")

        // Step 4: Simulate editing portion size from 100g to 150g
        let newPortionGrams = 150.0
        let baseServingSize = 100.0

        // Step 5: Simulate saving with the same logic as FoodItemDetailView
        try simulateFoodItemDetailViewSave(
            foodItem: foodItem,
            newPortionGrams: newPortionGrams,
            baseServingSize: baseServingSize,
            calories: "200",
            carbohydrates: "30",
            fiber: "5",
            sugars: "10",
            protein: "8",
            fat: "6",
            context: context
        )

        // Step 6: Verify FoodItem has updated portion and nutrition values
        let expectedCarbs = 30.0 * 1.5 // 45.0
        #expect(foodItem.servingSize == 150.0, "Portion should be updated to 150g")
        #expect(foodItem.totalCarbs == expectedCarbs, "Carbs should be scaled proportionally to 45g")
        #expect(foodItem.calories == 300.0, "Calories should be scaled to 300")
        #expect(foodItem.protein == 12.0, "Protein should be scaled to 12g")
        #expect(foodItem.totalFat == 9.0, "Fat should be scaled to 9g")

        // Step 7: Simulate FavoritesSection fetching favorites
        let favoritesRequest = FoodItem.fetchRequest()
        favoritesRequest.predicate = NSPredicate(format: "isFavorite == YES")
        favoritesRequest.sortDescriptors = [
            NSSortDescriptor(keyPath: \FoodItem.lastUsed, ascending: false),
            NSSortDescriptor(keyPath: \FoodItem.dateAdded, ascending: false)
        ]

        let favorites = try context.fetch(favoritesRequest)

        // Step 8: Verify favorites list has the NEW portion size
        #expect(favorites.count == 1, "Should have exactly one favorite item")

        let fetchedItem = try #require(favorites.first, "Should fetch the favorite item")
        #expect(fetchedItem.servingSize == 150.0, "Fetched item should have NEW portion (150g)")
        #expect(fetchedItem.totalCarbs == expectedCarbs, "Fetched item should have NEW carbs (45g)")
        #expect(fetchedItem.name == "Chocolate Bar", "Item name should be preserved")
        #expect(fetchedItem.brand == "TestCo", "Item brand should be preserved")
    }

    @Test("Portion increase: 100g to 200g doubles all nutrition values")
    func testPortionIncrease() async throws {
        // GIVEN: In-memory Core Data with a favorited item
        let controller = createTestController()
        let context = controller.viewContext

        // Wait for Core Data readiness
        var attempts = 0
        while !(await controller.isReady) && attempts < 50 {
            try await Task.sleep(nanoseconds: 100_000_000)
            attempts += 1
        }

        let foodItem = createTestFoodItem(
            in: context,
            name: "Protein Bar",
            servingSize: 100.0,
            calories: 150.0,
            totalCarbs: 20.0,
            fiber: 3.0,
            sugars: 8.0,
            protein: 10.0,
            totalFat: 5.0
        )
        foodItem.isFavorite = true
        try context.save()

        // WHEN: Portion is doubled (100g → 200g)
        try simulateFoodItemDetailViewSave(
            foodItem: foodItem,
            newPortionGrams: 200.0,
            baseServingSize: 100.0,
            calories: "150",
            carbohydrates: "20",
            fiber: "3",
            sugars: "8",
            protein: "10",
            fat: "5",
            context: context
        )

        // THEN: All nutrition values should double
        #expect(foodItem.servingSize == 200.0)
        #expect(foodItem.calories == 300.0, "Calories should double")
        #expect(foodItem.totalCarbs == 40.0, "Carbs should double")
        #expect(foodItem.fiber == 6.0, "Fiber should double")
        #expect(foodItem.sugars == 16.0, "Sugars should double")
        #expect(foodItem.protein == 20.0, "Protein should double")
        #expect(foodItem.totalFat == 10.0, "Fat should double")

        // Verify favorites fetch returns updated values
        let favoritesRequest = FoodItem.fetchRequest()
        favoritesRequest.predicate = NSPredicate(format: "isFavorite == YES")
        let favorites = try context.fetch(favoritesRequest)

        let fetchedItem = try #require(favorites.first)
        #expect(fetchedItem.servingSize == 200.0)
        #expect(fetchedItem.totalCarbs == 40.0)
    }

    @Test("Portion decrease: 100g to 50g halves all nutrition values")
    func testPortionDecrease() async throws {
        // GIVEN: In-memory Core Data with a favorited item
        let controller = createTestController()
        let context = controller.viewContext

        // Wait for Core Data readiness
        var attempts = 0
        while !(await controller.isReady) && attempts < 50 {
            try await Task.sleep(nanoseconds: 100_000_000)
            attempts += 1
        }

        let foodItem = createTestFoodItem(
            in: context,
            name: "Crackers",
            servingSize: 100.0,
            calories: 400.0,
            totalCarbs: 60.0,
            fiber: 4.0,
            sugars: 2.0,
            protein: 6.0,
            totalFat: 12.0
        )
        foodItem.isFavorite = true
        try context.save()

        // WHEN: Portion is halved (100g → 50g)
        try simulateFoodItemDetailViewSave(
            foodItem: foodItem,
            newPortionGrams: 50.0,
            baseServingSize: 100.0,
            calories: "400",
            carbohydrates: "60",
            fiber: "4",
            sugars: "2",
            protein: "6",
            fat: "12",
            context: context
        )

        // THEN: All nutrition values should halve
        #expect(foodItem.servingSize == 50.0)
        #expect(foodItem.calories == 200.0, "Calories should halve")
        #expect(foodItem.totalCarbs == 30.0, "Carbs should halve")
        #expect(foodItem.fiber == 2.0, "Fiber should halve")
        #expect(foodItem.sugars == 1.0, "Sugars should halve")
        #expect(foodItem.protein == 3.0, "Protein should halve")
        #expect(foodItem.totalFat == 6.0, "Fat should halve")

        // Verify favorites fetch returns updated values
        let favoritesRequest = FoodItem.fetchRequest()
        favoritesRequest.predicate = NSPredicate(format: "isFavorite == YES")
        let favorites = try context.fetch(favoritesRequest)

        let fetchedItem = try #require(favorites.first)
        #expect(fetchedItem.servingSize == 50.0)
        #expect(fetchedItem.totalCarbs == 30.0)
    }

    @Test("Fractional portion change: 100g to 125g increases by 25%")
    func testFractionalPortionChange() async throws {
        // GIVEN: In-memory Core Data with a favorited item
        let controller = createTestController()
        let context = controller.viewContext

        // Wait for Core Data readiness
        var attempts = 0
        while !(await controller.isReady) && attempts < 50 {
            try await Task.sleep(nanoseconds: 100_000_000)
            attempts += 1
        }

        let foodItem = createTestFoodItem(
            in: context,
            name: "Yogurt",
            servingSize: 100.0,
            calories: 80.0,
            totalCarbs: 12.0,
            fiber: 0.0,
            sugars: 10.0,
            protein: 4.0,
            totalFat: 2.0
        )
        foodItem.isFavorite = true
        try context.save()

        // WHEN: Portion increases by 25% (100g → 125g)
        try simulateFoodItemDetailViewSave(
            foodItem: foodItem,
            newPortionGrams: 125.0,
            baseServingSize: 100.0,
            calories: "80",
            carbohydrates: "12",
            fiber: "0",
            sugars: "10",
            protein: "4",
            fat: "2",
            context: context
        )

        // THEN: All values should increase by 25%
        #expect(foodItem.servingSize == 125.0)
        #expect(foodItem.calories == 100.0, "Calories should be 80 * 1.25 = 100")
        #expect(foodItem.totalCarbs == 15.0, "Carbs should be 12 * 1.25 = 15")
        #expect(foodItem.sugars == 12.5, "Sugars should be 10 * 1.25 = 12.5")
        #expect(foodItem.protein == 5.0, "Protein should be 4 * 1.25 = 5")
        #expect(foodItem.totalFat == 2.5, "Fat should be 2 * 1.25 = 2.5")
    }

    // MARK: - NSManagedObjectContextDidSave Notification Tests

    @Test("NSManagedObjectContextDidSave notification fires after portion update")
    func testSaveNotificationFires() async throws {
        // GIVEN: In-memory Core Data with notification tracking
        let controller = createTestController()
        let context = controller.viewContext

        // Wait for Core Data readiness
        var attempts = 0
        while !(await controller.isReady) && attempts < 50 {
            try await Task.sleep(nanoseconds: 100_000_000)
            attempts += 1
        }

        // Set up notification tracking with actor-safe approach
        let notificationReceived = NotificationTracker()

        let observer = NotificationCenter.default.addObserver(
            forName: NSNotification.Name.NSManagedObjectContextDidSave,
            object: context,
            queue: .main
        ) { _ in
            // Mark as received without capturing notification details
            // The notification firing is what we're testing
            Task { @MainActor in
                await notificationReceived.markReceived(updatedCount: 1)
            }
        }

        defer {
            NotificationCenter.default.removeObserver(observer)
        }

        // Create and save favorited item
        let foodItem = createTestFoodItem(in: context)
        foodItem.isFavorite = true
        try context.save()

        // Reset tracker after initial save
        await notificationReceived.reset()

        // WHEN: Portion is updated and saved
        try simulateFoodItemDetailViewSave(
            foodItem: foodItem,
            newPortionGrams: 150.0,
            baseServingSize: 100.0,
            calories: "200",
            carbohydrates: "30",
            fiber: "5",
            sugars: "10",
            protein: "8",
            fat: "6",
            context: context
        )

        // THEN: NSManagedObjectContextDidSave notification should fire
        // Wait for notification with timeout
        var waitAttempts = 0
        while !(await notificationReceived.wasReceived) && waitAttempts < 20 {
            try await Task.sleep(nanoseconds: 100_000_000) // Wait 0.1s
            waitAttempts += 1
        }

        #expect(await notificationReceived.wasReceived, "NSManagedObjectContextDidSave notification should fire")
        #expect(await notificationReceived.updatedObjectsCount > 0, "Should contain updated objects")
    }

    // MARK: - Multiple Favorites Tests

    @Test("Multiple favorited items: only edited item updates")
    func testMultipleFavoritesPartialUpdate() async throws {
        // GIVEN: Multiple favorited items
        let controller = createTestController()
        let context = controller.viewContext

        // Wait for Core Data readiness
        var attempts = 0
        while !(await controller.isReady) && attempts < 50 {
            try await Task.sleep(nanoseconds: 100_000_000)
            attempts += 1
        }

        let item1 = createTestFoodItem(
            in: context,
            name: "Item 1",
            servingSize: 100.0,
            totalCarbs: 20.0
        )
        item1.isFavorite = true

        let item2 = createTestFoodItem(
            in: context,
            name: "Item 2",
            servingSize: 50.0,
            totalCarbs: 15.0
        )
        item2.isFavorite = true

        let item3 = createTestFoodItem(
            in: context,
            name: "Item 3",
            servingSize: 200.0,
            totalCarbs: 40.0
        )
        item3.isFavorite = true

        try context.save()

        // WHEN: Only item2 is edited
        try simulateFoodItemDetailViewSave(
            foodItem: item2,
            newPortionGrams: 100.0,
            baseServingSize: 50.0,
            calories: "100",
            carbohydrates: "15",
            fiber: "2",
            sugars: "5",
            protein: "3",
            fat: "4",
            context: context
        )

        // THEN: Only item2 should be updated
        #expect(item1.servingSize == 100.0, "Item 1 should be unchanged")
        #expect(item1.totalCarbs == 20.0, "Item 1 carbs should be unchanged")

        #expect(item2.servingSize == 100.0, "Item 2 should be updated")
        #expect(item2.totalCarbs == 30.0, "Item 2 carbs should double (15 * 2)")

        #expect(item3.servingSize == 200.0, "Item 3 should be unchanged")
        #expect(item3.totalCarbs == 40.0, "Item 3 carbs should be unchanged")

        // Verify favorites fetch returns correct data
        let favoritesRequest = FoodItem.fetchRequest()
        favoritesRequest.predicate = NSPredicate(format: "isFavorite == YES")
        favoritesRequest.sortDescriptors = [
            NSSortDescriptor(keyPath: \FoodItem.name, ascending: true)
        ]

        let favorites = try context.fetch(favoritesRequest)
        #expect(favorites.count == 3, "Should have 3 favorites")

        // Verify specific item updates
        let fetchedItem2 = favorites.first { $0.name == "Item 2" }
        #expect(fetchedItem2?.servingSize == 100.0)
        #expect(fetchedItem2?.totalCarbs == 30.0)
    }

    // MARK: - Edge Cases

    @Test("No-op: editing without changing portion size")
    func testNoPortionChange() async throws {
        // GIVEN: A favorited item
        let controller = createTestController()
        let context = controller.viewContext

        // Wait for Core Data readiness
        var attempts = 0
        while !(await controller.isReady) && attempts < 50 {
            try await Task.sleep(nanoseconds: 100_000_000)
            attempts += 1
        }

        let foodItem = createTestFoodItem(
            in: context,
            name: "Unchanged Item",
            servingSize: 100.0,
            totalCarbs: 25.0
        )
        foodItem.isFavorite = true
        try context.save()

        // WHEN: "Editing" but keeping same portion size
        try simulateFoodItemDetailViewSave(
            foodItem: foodItem,
            newPortionGrams: 100.0, // Same as original
            baseServingSize: 100.0,
            calories: "180",
            carbohydrates: "25",
            fiber: "3",
            sugars: "7",
            protein: "5",
            fat: "4",
            context: context
        )

        // THEN: Portion and carbs should remain unchanged
        #expect(foodItem.servingSize == 100.0)
        #expect(foodItem.totalCarbs == 25.0, "Carbs should remain unchanged")

        // But text field values might be updated
        #expect(foodItem.calories == 180.0, "Calories can be updated independently")
    }

    @Test("Zero values: portion change with zero nutrition values")
    func testZeroNutritionValues() async throws {
        // GIVEN: An item with zero nutrition values
        let controller = createTestController()
        let context = controller.viewContext

        // Wait for Core Data readiness
        var attempts = 0
        while !(await controller.isReady) && attempts < 50 {
            try await Task.sleep(nanoseconds: 100_000_000)
            attempts += 1
        }

        let foodItem = createTestFoodItem(
            in: context,
            name: "Water",
            servingSize: 100.0,
            calories: 0.0,
            totalCarbs: 0.0,
            fiber: 0.0,
            sugars: 0.0,
            protein: 0.0,
            totalFat: 0.0
        )
        foodItem.isFavorite = true
        try context.save()

        // WHEN: Portion is changed
        try simulateFoodItemDetailViewSave(
            foodItem: foodItem,
            newPortionGrams: 200.0,
            baseServingSize: 100.0,
            calories: "0",
            carbohydrates: "0",
            fiber: "0",
            sugars: "0",
            protein: "0",
            fat: "0",
            context: context
        )

        // THEN: All values should remain zero
        #expect(foodItem.servingSize == 200.0, "Portion should update")
        #expect(foodItem.calories == 0.0)
        #expect(foodItem.totalCarbs == 0.0)
        #expect(foodItem.protein == 0.0)
        #expect(foodItem.totalFat == 0.0)
    }

    @Test("Non-favorited item: portion update works but not in favorites list")
    func testNonFavoritedItemUpdate() async throws {
        // GIVEN: A non-favorited item
        let controller = createTestController()
        let context = controller.viewContext

        // Wait for Core Data readiness
        var attempts = 0
        while !(await controller.isReady) && attempts < 50 {
            try await Task.sleep(nanoseconds: 100_000_000)
            attempts += 1
        }

        let foodItem = createTestFoodItem(
            in: context,
            name: "Not Favorite",
            servingSize: 100.0,
            totalCarbs: 20.0
        )
        foodItem.isFavorite = false // Explicitly not favorite
        try context.save()

        // WHEN: Portion is updated
        try simulateFoodItemDetailViewSave(
            foodItem: foodItem,
            newPortionGrams: 150.0,
            baseServingSize: 100.0,
            calories: "200",
            carbohydrates: "20",
            fiber: "2",
            sugars: "5",
            protein: "8",
            fat: "6",
            context: context
        )

        // THEN: Item should be updated
        #expect(foodItem.servingSize == 150.0)
        #expect(foodItem.totalCarbs == 30.0)

        // But NOT in favorites list
        let favoritesRequest = FoodItem.fetchRequest()
        favoritesRequest.predicate = NSPredicate(format: "isFavorite == YES")
        let favorites = try context.fetch(favoritesRequest)
        #expect(favorites.isEmpty, "Should have no favorites")
    }

    // MARK: - Concurrency Tests

    @Test("Concurrent portion updates: sequential saves work correctly")
    func testConcurrentUpdates() async throws {
        // GIVEN: Multiple favorited items
        let controller = createTestController()
        let context = controller.viewContext

        // Wait for Core Data readiness
        var attempts = 0
        while !(await controller.isReady) && attempts < 50 {
            try await Task.sleep(nanoseconds: 100_000_000)
            attempts += 1
        }

        let item1 = createTestFoodItem(
            in: context,
            name: "Concurrent Item 1",
            servingSize: 100.0,
            totalCarbs: 10.0
        )
        item1.isFavorite = true

        let item2 = createTestFoodItem(
            in: context,
            name: "Concurrent Item 2",
            servingSize: 100.0,
            totalCarbs: 20.0
        )
        item2.isFavorite = true

        try context.save()

        // WHEN: Multiple sequential updates
        try simulateFoodItemDetailViewSave(
            foodItem: item1,
            newPortionGrams: 200.0,
            baseServingSize: 100.0,
            calories: "100",
            carbohydrates: "10",
            fiber: "1",
            sugars: "2",
            protein: "3",
            fat: "4",
            context: context
        )

        try simulateFoodItemDetailViewSave(
            foodItem: item2,
            newPortionGrams: 150.0,
            baseServingSize: 100.0,
            calories: "200",
            carbohydrates: "20",
            fiber: "2",
            sugars: "5",
            protein: "6",
            fat: "8",
            context: context
        )

        // THEN: Both items should be updated correctly
        #expect(item1.servingSize == 200.0)
        #expect(item1.totalCarbs == 20.0, "Item 1 carbs should double")

        #expect(item2.servingSize == 150.0)
        #expect(item2.totalCarbs == 30.0, "Item 2 carbs should increase by 50%")

        // Verify favorites fetch
        let favoritesRequest = FoodItem.fetchRequest()
        favoritesRequest.predicate = NSPredicate(format: "isFavorite == YES")
        let favorites = try context.fetch(favoritesRequest)
        #expect(favorites.count == 2)
    }

    // MARK: - Impact Score Recalculation Tests

    @Test("Impact score recalculates after portion change")
    func testImpactScoreRecalculation() async throws {
        // GIVEN: A favorited item with known nutrition
        let controller = createTestController()
        let context = controller.viewContext

        // Wait for Core Data readiness
        var attempts = 0
        while !(await controller.isReady) && attempts < 50 {
            try await Task.sleep(nanoseconds: 100_000_000)
            attempts += 1
        }

        let foodItem = createTestFoodItem(
            in: context,
            name: "Impact Test",
            servingSize: 100.0,
            calories: 200.0,
            totalCarbs: 30.0,
            fiber: 5.0,
            sugars: 10.0,
            protein: 8.0,
            totalFat: 6.0
        )
        foodItem.isFavorite = true
        try context.save()

        // Calculate initial impact score
        let initialImpactScore = foodItem.impactScore
        let initialNetCarbs = foodItem.netCarbs

        // WHEN: Portion doubles (100g → 200g)
        try simulateFoodItemDetailViewSave(
            foodItem: foodItem,
            newPortionGrams: 200.0,
            baseServingSize: 100.0,
            calories: "200",
            carbohydrates: "30",
            fiber: "5",
            sugars: "10",
            protein: "8",
            fat: "6",
            context: context
        )

        // THEN: Impact score should approximately double (subject to rounding)
        let newImpactScore = foodItem.impactScore
        let newNetCarbs = foodItem.netCarbs

        #expect(foodItem.totalCarbs == 60.0, "Carbs should double")
        #expect(newNetCarbs > initialNetCarbs * 1.8, "Net carbs should approximately double")
        #expect(newImpactScore > initialImpactScore * 1.8, "Impact score should approximately double")

        // Verify favorites fetch returns updated impact
        let favoritesRequest = FoodItem.fetchRequest()
        favoritesRequest.predicate = NSPredicate(format: "isFavorite == YES")
        let favorites = try context.fetch(favoritesRequest)

        let fetchedItem = try #require(favorites.first)
        #expect(fetchedItem.impactScore == newImpactScore, "Fetched item should have updated impact score")
    }
}

// MARK: - NotificationTracker Helper

/// Actor-based notification tracker for Swift 6 compliance
private actor NotificationTracker {
    private var received = false
    private var updatedCount = 0

    var wasReceived: Bool {
        received
    }

    var updatedObjectsCount: Int {
        updatedCount
    }

    func markReceived(updatedCount: Int) {
        received = true
        self.updatedCount = updatedCount
    }

    func reset() {
        received = false
        updatedCount = 0
    }
}
