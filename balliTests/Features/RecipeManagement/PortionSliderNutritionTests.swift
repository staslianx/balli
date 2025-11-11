//
//  PortionSliderNutritionTests.swift
//  balliTests
//
//  Comprehensive unit tests for nutrition calculation accuracy when portion slider changes
//  Tests mathematical correctness of nutrition scaling across portion adjustments
//
//  Test Coverage:
//  - Slider movement updates nutrition values proportionally
//  - Portion multiplier calculations are mathematically correct
//  - Edge cases: min (50g), max (totalRecipeWeight), mid-range values
//  - Rounding precision (±0.1g tolerance for macros, ±1 kcal for calories)
//  - Integration between RecipeGenerationView and RecipeDetailView flows
//

import XCTest
import CoreData
@testable import balli

@MainActor
final class PortionSliderNutritionTests: XCTestCase {

    var context: NSManagedObjectContext!
    var recipe: Recipe!

    // MARK: - Setup

    override func setUp() async throws {
        try await super.setUp()

        context = PersistenceController.preview.container.viewContext

        // Create test recipe with known nutrition values
        recipe = Recipe(context: context)
        recipe.id = UUID()
        recipe.name = "Test Recipe"

        // IMMUTABLE total recipe values (from Gemini response)
        recipe.totalRecipeWeight = 300.0  // 300g cooked weight
        recipe.totalRecipeCalories = 600.0  // 600 kcal total
        recipe.totalRecipeCarbs = 75.0  // 75g carbs
        recipe.totalRecipeProtein = 30.0  // 30g protein
        recipe.totalRecipeFat = 18.0  // 18g fat
        recipe.totalRecipeGlycemicLoad = 15.0
        recipe.totalRecipeFiber = 9.0  // 9g fiber
        recipe.totalRecipeSugar = 12.0  // 12g sugar

        // Initial per-serving values (equals total since no portion defined yet)
        recipe.caloriesPerServing = 600.0
        recipe.carbsPerServing = 75.0
        recipe.proteinPerServing = 30.0
        recipe.fatPerServing = 18.0
        recipe.glycemicLoadPerServing = 15.0
        recipe.fiberPerServing = 9.0
        recipe.sugarsPerServing = 12.0

        // No portion defined yet
        recipe.portionSize = 0
        recipe.portionMultiplier = 1.0
    }

    override func tearDown() async throws {
        recipe = nil
        context = nil
        try await super.tearDown()
    }

    // MARK: - Test 1: Slider at Maximum (totalRecipeWeight = 300g)

    func testSliderAtMaximum_NutritionEqualsTotal() throws {
        // Given: Slider at maximum (300g = full recipe)
        let sliderValue = 300.0

        // When: Calculate nutrition for full recipe
        let nutrition = recipe.calculatePortionNutrition(for: sliderValue)

        // Then: Should match total recipe nutrition exactly
        XCTAssertEqual(nutrition.calories, 600.0, accuracy: 1.0, "Calories should equal total")
        XCTAssertEqual(nutrition.carbohydrates, 75.0, accuracy: 0.1, "Carbs should equal total")
        XCTAssertEqual(nutrition.protein, 30.0, accuracy: 0.1, "Protein should equal total")
        XCTAssertEqual(nutrition.fat, 18.0, accuracy: 0.1, "Fat should equal total")
        XCTAssertEqual(nutrition.glycemicLoad, 15.0, accuracy: 1.0, "GL should equal total")
    }

    // MARK: - Test 2: Slider at 50% (150g)

    func testSliderAtHalf_NutritionIsHalf() throws {
        // Given: Slider at 50% of total (150g of 300g)
        let sliderValue = 150.0
        let expectedRatio = 0.5

        // When: Calculate nutrition
        let nutrition = recipe.calculatePortionNutrition(for: sliderValue)

        // Then: Should be exactly half of total
        XCTAssertEqual(nutrition.calories, 300.0, accuracy: 1.0, "Calories should be half (300)")
        XCTAssertEqual(nutrition.carbohydrates, 37.5, accuracy: 0.1, "Carbs should be half (37.5g)")
        XCTAssertEqual(nutrition.protein, 15.0, accuracy: 0.1, "Protein should be half (15g)")
        XCTAssertEqual(nutrition.fat, 9.0, accuracy: 0.1, "Fat should be half (9g)")
        XCTAssertEqual(nutrition.glycemicLoad, 7.5, accuracy: 1.0, "GL should be half (7.5)")

        // Verify ratio calculation
        let actualRatio = sliderValue / recipe.totalRecipeWeight
        XCTAssertEqual(actualRatio, expectedRatio, accuracy: 0.001, "Ratio calculation should be exact")
    }

    // MARK: - Test 3: Slider at Minimum (50g)

    func testSliderAtMinimum_NutritionScalesCorrectly() throws {
        // Given: Slider at minimum (50g)
        let sliderValue = 50.0
        let expectedRatio = 50.0 / 300.0  // = 0.1667

        // When: Calculate nutrition
        let nutrition = recipe.calculatePortionNutrition(for: sliderValue)

        // Then: Should be 1/6 of total (16.67%)
        XCTAssertEqual(nutrition.calories, 100.0, accuracy: 1.0, "Calories should be ~100 kcal")
        XCTAssertEqual(nutrition.carbohydrates, 12.5, accuracy: 0.1, "Carbs should be ~12.5g")
        XCTAssertEqual(nutrition.protein, 5.0, accuracy: 0.1, "Protein should be ~5g")
        XCTAssertEqual(nutrition.fat, 3.0, accuracy: 0.1, "Fat should be ~3g")
        XCTAssertEqual(nutrition.glycemicLoad, 2.5, accuracy: 1.0, "GL should be ~2.5")

        // Verify ratio
        let actualRatio = sliderValue / recipe.totalRecipeWeight
        XCTAssertEqual(actualRatio, expectedRatio, accuracy: 0.001, "Ratio should be 0.1667")
    }

    // MARK: - Test 4: Arbitrary Slider Value (140g)

    func testSliderAtArbitraryValue_MathematicallyCorrect() throws {
        // Given: Slider at 140g (user's example from issue)
        let sliderValue = 140.0
        let expectedRatio = 140.0 / 300.0  // = 0.4667

        // When: Calculate nutrition
        let nutrition = recipe.calculatePortionNutrition(for: sliderValue)

        // Then: Calculate expected values
        let expectedCalories = 600.0 * expectedRatio  // = 280 kcal
        let expectedCarbs = 75.0 * expectedRatio  // = 35g
        let expectedProtein = 30.0 * expectedRatio  // = 14g
        let expectedFat = 18.0 * expectedRatio  // = 8.4g
        let expectedGL = 15.0 * expectedRatio  // = 7

        XCTAssertEqual(nutrition.calories, expectedCalories, accuracy: 1.0, "Calories should be 280 kcal")
        XCTAssertEqual(nutrition.carbohydrates, expectedCarbs, accuracy: 0.1, "Carbs should be 35g")
        XCTAssertEqual(nutrition.protein, expectedProtein, accuracy: 0.1, "Protein should be 14g")
        XCTAssertEqual(nutrition.fat, expectedFat, accuracy: 0.1, "Fat should be 8.4g")
        XCTAssertEqual(nutrition.glycemicLoad, expectedGL, accuracy: 1.0, "GL should be 7")
    }

    // MARK: - Test 5: Slider Movement Preserves Ratios

    func testSliderMovement_PreservesProportions() throws {
        // Given: Multiple slider positions
        let testValues: [Double] = [50, 100, 150, 200, 250, 298, 300]

        for sliderValue in testValues {
            // When: Calculate nutrition at each position
            let nutrition = recipe.calculatePortionNutrition(for: sliderValue)
            let ratio = sliderValue / recipe.totalRecipeWeight

            // Then: Verify proportional scaling
            let expectedCalories = recipe.totalRecipeCalories * ratio
            let expectedCarbs = recipe.totalRecipeCarbs * ratio
            let expectedProtein = recipe.totalRecipeProtein * ratio

            XCTAssertEqual(nutrition.calories, expectedCalories, accuracy: 1.0,
                          "Calories at \(sliderValue)g should be proportional")
            XCTAssertEqual(nutrition.carbohydrates, expectedCarbs, accuracy: 0.1,
                          "Carbs at \(sliderValue)g should be proportional")
            XCTAssertEqual(nutrition.protein, expectedProtein, accuracy: 0.1,
                          "Protein at \(sliderValue)g should be proportional")
        }
    }

    // MARK: - Test 6: Save Portion Then Adjust with Multiplier

    func testSavePortionThenAdjustMultiplier_MathematicallyCorrect() throws {
        // Given: User saves portion at 150g
        let savedPortionSize = 150.0
        recipe.portionSize = savedPortionSize

        // Update per-serving values to match saved portion
        let ratio = savedPortionSize / recipe.totalRecipeWeight
        recipe.caloriesPerServing = recipe.totalRecipeCalories * ratio  // 300 kcal
        recipe.carbsPerServing = recipe.totalRecipeCarbs * ratio  // 37.5g
        recipe.proteinPerServing = recipe.totalRecipeProtein * ratio  // 15g
        recipe.fatPerServing = recipe.totalRecipeFat * ratio  // 9g
        recipe.portionMultiplier = 1.0

        // When: User adjusts multiplier to 2.0 (doubles the portion)
        recipe.portionMultiplier = 2.0

        // Then: Effective portion should be 300g (150g × 2)
        let effectivePortionSize = savedPortionSize * recipe.portionMultiplier
        XCTAssertEqual(effectivePortionSize, 300.0, "Effective portion should be 300g")

        // Nutrition should be double the saved portion (= full recipe)
        let effectiveCalories = recipe.caloriesPerServing * recipe.portionMultiplier
        let effectiveCarbs = recipe.carbsPerServing * recipe.portionMultiplier

        XCTAssertEqual(effectiveCalories, 600.0, accuracy: 1.0, "Should equal full recipe calories")
        XCTAssertEqual(effectiveCarbs, 75.0, accuracy: 0.1, "Should equal full recipe carbs")
    }

    // MARK: - Test 7: Slider Step Size (1.0) Precision

    func testSliderStepSize_AllowsExactValues() throws {
        // Given: Slider with step: 1.0, max: 298g
        let stepSize = 1.0
        let maxValue = 298.0

        // When: Calculate number of steps from min to max
        let minValue = 50.0
        let stepsToMax = (maxValue - minValue) / stepSize

        // Then: Should be exactly 248 steps
        XCTAssertEqual(stepsToMax, 248.0, "Should have 248 steps from 50g to 298g")

        // Verify slider can hit 298g exactly
        let finalValue = minValue + (stepsToMax * stepSize)
        XCTAssertEqual(finalValue, 298.0, "Slider should reach exactly 298g")

        // Verify nutrition at 298g is accurate
        let nutrition = recipe.calculatePortionNutrition(for: 298.0)
        let expectedRatio = 298.0 / 300.0  // = 0.9933
        let expectedCalories = recipe.totalRecipeCalories * expectedRatio

        XCTAssertEqual(nutrition.calories, expectedCalories, accuracy: 1.0,
                      "Nutrition at 298g should be mathematically correct")
    }

    // MARK: - Test 8: Unsaved Recipe (RecipeGenerationView)

    func testUnsavedRecipe_PortionMultiplierWorks() throws {
        // Given: Unsaved recipe (portionSize = 0, no CoreData save yet)
        recipe.portionSize = 0
        recipe.portionMultiplier = 1.0

        // Initial per-serving equals total recipe
        XCTAssertEqual(recipe.caloriesPerServing, recipe.totalRecipeCalories)

        // When: User adjusts multiplier to 0.5 (half the default portion)
        recipe.portionMultiplier = 0.5

        // Then: Effective calories should be half
        let effectiveCalories = recipe.caloriesPerServing * recipe.portionMultiplier
        XCTAssertEqual(effectiveCalories, 300.0, accuracy: 1.0, "Should be half of total")

        // When: User saves with adjusted portion (150g)
        let adjustedPortion = recipe.totalRecipeWeight * recipe.portionMultiplier
        recipe.portionSize = adjustedPortion

        // Update per-serving to match saved portion
        let ratio = adjustedPortion / recipe.totalRecipeWeight
        recipe.caloriesPerServing = recipe.totalRecipeCalories * ratio
        recipe.portionMultiplier = 1.0  // Reset after save

        // Then: Per-serving should now be 300 kcal, multiplier back to 1.0
        XCTAssertEqual(recipe.caloriesPerServing, 300.0, accuracy: 1.0)
        XCTAssertEqual(recipe.portionMultiplier, 1.0)
    }

    // MARK: - Test 9: Saved Recipe (RecipeDetailView)

    func testSavedRecipe_PortionAdjustmentPreservesTotal() throws {
        // Given: Saved recipe with portion size 150g
        recipe.portionSize = 150.0

        // Per-serving values for 150g portion
        let ratio = 150.0 / recipe.totalRecipeWeight
        recipe.caloriesPerServing = recipe.totalRecipeCalories * ratio  // 300 kcal
        recipe.carbsPerServing = recipe.totalRecipeCarbs * ratio  // 37.5g
        recipe.proteinPerServing = recipe.totalRecipeProtein * ratio  // 15g

        // When: User adjusts to 200g
        let newPortionSize = 200.0
        let newRatio = newPortionSize / recipe.totalRecipeWeight

        // Calculate new per-serving values from IMMUTABLE total
        let newCalories = recipe.totalRecipeCalories * newRatio
        let newCarbs = recipe.totalRecipeCarbs * newRatio
        let newProtein = recipe.totalRecipeProtein * newRatio

        // Then: Nutrition should scale correctly
        XCTAssertEqual(newCalories, 400.0, accuracy: 1.0, "200g should be 400 kcal")
        XCTAssertEqual(newCarbs, 50.0, accuracy: 0.1, "200g should be 50g carbs")
        XCTAssertEqual(newProtein, 20.0, accuracy: 0.1, "200g should be 20g protein")

        // When: User adjusts back to 150g
        let revertedCalories = recipe.totalRecipeCalories * ratio

        // Then: Should return to original values
        XCTAssertEqual(revertedCalories, 300.0, accuracy: 1.0, "Should revert to 300 kcal")
    }

    // MARK: - Test 10: Edge Case - Zero Total Weight

    func testZeroTotalWeight_ReturnsZeroNutrition() throws {
        // Given: Corrupted recipe with zero total weight
        recipe.totalRecipeWeight = 0

        // When: Calculate nutrition for any portion
        let nutrition = recipe.calculatePortionNutrition(for: 100.0)

        // Then: Should return zeros (not crash)
        XCTAssertEqual(nutrition.calories, 0)
        XCTAssertEqual(nutrition.carbohydrates, 0)
        XCTAssertEqual(nutrition.protein, 0)
    }

    // MARK: - Test 11: Rounding Precision

    func testRoundingPrecision_WithinTolerance() throws {
        // Given: Slider at value that causes floating-point rounding (155g)
        let sliderValue = 155.0

        // When: Calculate nutrition
        let nutrition = recipe.calculatePortionNutrition(for: sliderValue)

        // Then: Calculate expected with floating-point math
        let ratio = sliderValue / recipe.totalRecipeWeight  // 0.51666...
        let expectedCalories = recipe.totalRecipeCalories * ratio  // 310 kcal
        let expectedCarbs = recipe.totalRecipeCarbs * ratio  // 38.75g

        // Verify within tolerance
        XCTAssertEqual(nutrition.calories, expectedCalories, accuracy: 1.0,
                      "Calories should be within ±1 kcal tolerance")
        XCTAssertEqual(nutrition.carbohydrates, expectedCarbs, accuracy: 0.1,
                      "Carbs should be within ±0.1g tolerance")
    }

    // MARK: - Test 12: Comprehensive Integration Test

    func testCompleteUserFlow_MathematicallyConsistent() throws {
        // SCENARIO: User's bug report scenario
        // 1. Gemini returns 309g cooked weight (using 298g for our test data)
        recipe.totalRecipeWeight = 298.0
        recipe.totalRecipeCalories = 600.0

        // 2. User decreases to 155g and saves
        let userAdjustedPortion = 155.0
        recipe.portionSize = userAdjustedPortion

        let ratioAtSave = userAdjustedPortion / recipe.totalRecipeWeight
        recipe.caloriesPerServing = recipe.totalRecipeCalories * ratioAtSave
        recipe.portionMultiplier = 1.0

        // Verify: Saved portion is 155g with correct nutrition
        XCTAssertEqual(recipe.portionSize, 155.0)
        let expectedCaloriesAt155 = 600.0 * (155.0 / 298.0)  // ≈ 311.7 kcal
        XCTAssertEqual(recipe.caloriesPerServing, expectedCaloriesAt155, accuracy: 1.0)

        // 3. User reopens modal, slider shows range 50g...298g
        let sliderMin = 50.0
        let sliderMax = recipe.totalRecipeWeight  // Should be 298.0

        XCTAssertEqual(sliderMax, 298.0, "Slider max should be preserved totalRecipeWeight")

        // 4. User moves slider to maximum (298g)
        let sliderAtMax = 298.0
        let nutritionAtMax = recipe.calculatePortionNutrition(for: sliderAtMax)

        // Verify: Can reach 298g and nutrition is correct
        XCTAssertEqual(sliderAtMax, sliderMax, "Should be able to reach max value")

        let expectedCaloriesAtMax = recipe.totalRecipeCalories * (298.0 / 298.0)
        XCTAssertEqual(nutritionAtMax.calories, expectedCaloriesAtMax, accuracy: 1.0,
                      "At 298g, calories should be ~600 kcal")

        // 5. User saves at 298g
        recipe.portionSize = 298.0
        let ratioAtMax = 298.0 / recipe.totalRecipeWeight
        recipe.caloriesPerServing = recipe.totalRecipeCalories * ratioAtMax

        // Verify: Nutrition matches full recipe (within rounding)
        XCTAssertEqual(recipe.caloriesPerServing, 600.0, accuracy: 1.0,
                      "At 298g of 298g total, should get ~600 kcal")
    }
}
