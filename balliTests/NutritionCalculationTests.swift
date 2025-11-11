//
//  NutritionCalculationTests.swift
//  balliTests
//
//  Comprehensive unit tests for nutrition calculation logic
//  CRITICAL: These tests verify medical accuracy for diabetes management
//

import XCTest
import CoreData
@testable import balli

@MainActor
final class NutritionCalculationTests: XCTestCase {

    var context: NSManagedObjectContext!
    var persistence: PersistenceController!

    override func setUp() async throws {
        // Use in-memory store for tests
        persistence = PersistenceController(inMemory: true)
        context = persistence.viewContext
    }

    override func tearDown() {
        context = nil
        persistence = nil
    }

    // MARK: - Issue #2 Tests: Data Corruption Prevention

    /// CRITICAL TEST: Verify portion adjustments don't corrupt nutrition data
    /// This was the main bug - repeated adjustments would compound errors
    func testPortionAdjustmentPreservesOriginalNutrition() throws {
        // Given: A recipe with known total nutrition
        let recipe = Recipe(context: context)
        recipe.id = UUID()
        recipe.name = "Test Recipe"
        recipe.totalRecipeWeight = 600.0

        // Set IMMUTABLE total nutrition (full recipe)
        recipe.totalRecipeCalories = 1200.0
        recipe.totalRecipeCarbs = 150.0
        recipe.totalRecipeProtein = 80.0
        recipe.totalRecipeFat = 40.0

        // Set initial per-serving values (same as total for new recipe)
        recipe.caloriesPerServing = 1200.0
        recipe.carbsPerServing = 150.0
        recipe.proteinPerServing = 80.0
        recipe.fatPerServing = 40.0
        recipe.portionSize = 600.0  // Full recipe initially

        try context.save()

        // When: Adjust to half portion (300g)
        let halfPortion = recipe.calculatePortionNutrition(for: 300.0)
        recipe.caloriesPerServing = halfPortion.calories
        recipe.carbsPerServing = halfPortion.carbohydrates
        recipe.proteinPerServing = halfPortion.protein
        recipe.fatPerServing = halfPortion.fat
        recipe.portionSize = 300.0
        try context.save()

        // Then: Per-serving should be half of total
        XCTAssertEqual(recipe.caloriesPerServing, 600.0, accuracy: 1.0)
        XCTAssertEqual(recipe.carbsPerServing, 75.0, accuracy: 0.1)

        // When: Adjust again to quarter portion (150g)
        let quarterPortion = recipe.calculatePortionNutrition(for: 150.0)
        recipe.caloriesPerServing = quarterPortion.calories
        recipe.carbsPerServing = quarterPortion.carbohydrates
        recipe.portionSize = 150.0
        try context.save()

        // Then: Should be quarter of ORIGINAL, not half of half
        // CRITICAL: This verifies we're reading from immutable totalRecipe* fields
        XCTAssertEqual(recipe.caloriesPerServing, 300.0, accuracy: 1.0, "Should be 1/4 of original 1200")
        XCTAssertEqual(recipe.carbsPerServing, 37.5, accuracy: 0.1, "Should be 1/4 of original 150")

        // Verify immutable fields never changed
        XCTAssertEqual(recipe.totalRecipeCalories, 1200.0)
        XCTAssertEqual(recipe.totalRecipeCarbs, 150.0)
    }

    // MARK: - Issue #1 Tests: Zero-Weight Division Guards

    func testCalculatePortionNutrition_ZeroWeight_ReturnsNil() throws {
        // Given: Recipe with zero total weight
        let recipe = Recipe(context: context)
        recipe.id = UUID()
        recipe.totalRecipeWeight = 0.0
        recipe.totalRecipeCalories = 1200.0

        // When: Calculate portion nutrition
        let nutrition = recipe.calculatePortionNutrition(for: 100.0)

        // Then: Should return zeros, not crash
        XCTAssertEqual(nutrition.calories, 0.0)
    }

    func testTotalNutrition_WithZeroValues_ReturnsZeros() throws {
        // Given: Recipe with zero nutrition
        let recipe = Recipe(context: context)
        recipe.id = UUID()
        recipe.totalRecipeCalories = 0.0
        recipe.caloriesPerServing = 0.0

        // When: Access totalNutrition
        let nutrition = recipe.totalNutrition

        // Then: Should return zeros, not crash or NaN
        XCTAssertEqual(nutrition.calories, 0.0)
        XCTAssertFalse(nutrition.calories.isNaN)
    }

    // MARK: - Issue #5 Tests: Rounding Precision

    func testScaling_PreservesPrecision() {
        // Given: Nutrition values with precise decimals
        let original = NutritionValues(
            calories: 123.456,
            carbohydrates: 45.678,
            fiber: 3.210,
            sugar: 5.432,
            protein: 12.345,
            fat: 6.789,
            glycemicLoad: 15.5
        )

        // When: Scale down and back up
        let halfPortion = original.scaled(by: 0.5)
        let restored = halfPortion.scaled(by: 2.0)

        // Then: Should be very close to original (within floating point tolerance)
        XCTAssertEqual(restored.calories, original.calories, accuracy: 0.001)
        XCTAssertEqual(restored.carbohydrates, original.carbohydrates, accuracy: 0.001)
        XCTAssertEqual(restored.protein, original.protein, accuracy: 0.001)
    }

    func testMultipleScalings_DontCompoundErrors() {
        // Given: Original values
        let original = NutritionValues(calories: 1000.0, carbohydrates: 100.0, fiber: 10.0, sugar: 20.0, protein: 50.0, fat: 30.0, glycemicLoad: 25.0)

        // When: Apply multiple scalings
        var result = original
        for _ in 0..<10 {
            result = result.scaled(by: 0.9)  // Scale down 10 times
        }
        for _ in 0..<10 {
            result = result.scaled(by: 1.0 / 0.9)  // Scale back up 10 times
        }

        // Then: Should be close to original (within 1% tolerance for 20 operations)
        let tolerance = original.calories * 0.01
        XCTAssertEqual(result.calories, original.calories, accuracy: tolerance)
    }

    // MARK: - Issue #4 Tests: Missing Data Handling

    func testDisplayCalories_ZeroValue_ReturnsEmDash() {
        let nutrition = NutritionValues(calories: 0.0)
        XCTAssertEqual(nutrition.displayCalories, "—")
    }

    func testDisplayCarbohydrates_NegativeValue_ReturnsEmDash() {
        // Even if data is corrupt with negative values, display should show em dash
        let nutrition = NutritionValues(carbohydrates: -5.0)
        XCTAssertEqual(nutrition.displayCarbohydrates, "—")
    }

    func testDisplayProtein_ValidSmallValue_ShowsDecimal() {
        let nutrition = NutritionValues(protein: 5.7)
        XCTAssertEqual(nutrition.displayProtein, "5.7")
    }

    func testDisplayFat_ValidLargeValue_HidesDecimal() {
        let nutrition = NutritionValues(fat: 15.7)
        XCTAssertEqual(nutrition.displayFat, "16")  // Rounds to nearest integer
    }

    // MARK: - Integration Tests

    func testCompletePortionAdjustmentWorkflow() throws {
        // Given: A complete recipe from generation
        let recipe = Recipe(context: context)
        recipe.id = UUID()
        recipe.name = "Grilled Chicken Salad"
        recipe.totalRecipeWeight = 350.0
        recipe.servings = 1

        // Initial nutrition (represents full recipe)
        recipe.totalRecipeCalories = 578.0
        recipe.totalRecipeCarbs = 28.0
        recipe.totalRecipeFiber = 10.5
        recipe.totalRecipeProtein = 108.5
        recipe.totalRecipeFat = 12.6

        recipe.caloriesPerServing = 578.0
        recipe.carbsPerServing = 28.0
        recipe.fiberPerServing = 10.5
        recipe.proteinPerServing = 108.5
        recipe.fatPerServing = 12.6

        recipe.portionSize = 350.0  // Full recipe initially

        try context.save()

        // When: User adjusts to 175g (half portion)
        let halfNutrition = recipe.calculatePortionNutrition(for: 175.0)
        recipe.caloriesPerServing = halfNutrition.calories
        recipe.carbsPerServing = halfNutrition.carbohydrates
        recipe.portionSize = 175.0
        try context.save()

        // Then: Nutrition should be exactly half
        XCTAssertEqual(recipe.caloriesPerServing, 289.0, accuracy: 1.0)
        XCTAssertEqual(recipe.carbsPerServing, 14.0, accuracy: 0.1)

        // When: User adjusts to 262.5g (3/4 of original)
        let threeQuartersNutrition = recipe.calculatePortionNutrition(for: 262.5)
        recipe.caloriesPerServing = threeQuartersNutrition.calories
        recipe.carbsPerServing = threeQuartersNutrition.carbohydrates
        recipe.portionSize = 262.5
        try context.save()

        // Then: Should be 3/4 of ORIGINAL (not 3/4 of half!)
        XCTAssertEqual(recipe.caloriesPerServing, 433.5, accuracy: 1.0)
        XCTAssertEqual(recipe.carbsPerServing, 21.0, accuracy: 0.1)

        // Verify immutable values never changed
        XCTAssertEqual(recipe.totalRecipeCalories, 578.0)
        XCTAssertEqual(recipe.totalRecipeCarbs, 28.0)
    }

    // MARK: - Constants Tests

    func testNutritionConstants_MinPortionSize() {
        XCTAssertEqual(NutritionConstants.minPortionSize, 50.0)
        XCTAssertGreaterThan(NutritionConstants.minPortionSize, 0.0)
    }

    func testNutritionConstants_SliderStep() {
        XCTAssertEqual(NutritionConstants.sliderStep, 5.0)
    }
}
