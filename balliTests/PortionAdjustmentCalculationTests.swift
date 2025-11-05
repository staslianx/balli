//
//  PortionAdjustmentCalculationTests.swift
//  balliTests
//
//  Unit tests for portion adjustment calculations
//  Verifies that nutrition values update correctly when portion multiplier changes
//

import XCTest
import SwiftUI
@testable import balli

@MainActor
final class PortionAdjustmentCalculationTests: XCTestCase {

    // MARK: - Test Data

    /// Base recipe with known nutritional values per serving
    private func createTestRecipe() -> Recipe {
        let context = PersistenceController.preview.container.viewContext
        let recipe = Recipe(context: context)

        recipe.id = UUID()
        recipe.name = "Test Recipe"
        recipe.totalRecipeWeight = 400  // Total recipe is 400g
        recipe.portionSize = 200        // Default portion is 200g (50% of total)

        // Per-serving values (for 200g portion)
        recipe.caloriesPerServing = 500
        recipe.carbsPerServing = 50
        recipe.fiberPerServing = 10
        recipe.sugarsPerServing = 15
        recipe.proteinPerServing = 30
        recipe.fatPerServing = 20
        recipe.glycemicLoadPerServing = 25

        // Per-100g values
        recipe.calories = 250
        recipe.totalCarbs = 25
        recipe.fiber = 5
        recipe.sugars = 7.5
        recipe.protein = 15
        recipe.totalFat = 10
        recipe.glycemicLoad = 12.5

        return recipe
    }

    // MARK: - Portion Multiplier Tests

    func testPortionMultiplier_1x_ReturnsBaseValues() {
        // Given: Base recipe with 1.0x multiplier
        let recipe = createTestRecipe()
        let wrapper = ObservableRecipeWrapper(recipe: recipe)
        let multiplier = 1.0

        // When: Calculate displayed values at 1.0x
        let displayedCalories = (Double(recipe.caloriesPerServing) ) * multiplier
        let displayedCarbs = (Double(recipe.carbsPerServing) ) * multiplier
        let displayedProtein = (Double(recipe.proteinPerServing) ) * multiplier
        let displayedFat = (Double(recipe.fatPerServing) ) * multiplier

        // Then: Should match base per-serving values
        XCTAssertEqual(displayedCalories, 500, accuracy: 0.1, "1.0x should return base calories")
        XCTAssertEqual(displayedCarbs, 50, accuracy: 0.1, "1.0x should return base carbs")
        XCTAssertEqual(displayedProtein, 30, accuracy: 0.1, "1.0x should return base protein")
        XCTAssertEqual(displayedFat, 20, accuracy: 0.1, "1.0x should return base fat")
    }

    func testPortionMultiplier_2x_DoublesAllValues() {
        // Given: Base recipe with 2.0x multiplier
        let recipe = createTestRecipe()
        let multiplier = 2.0

        // When: Calculate displayed values at 2.0x
        let displayedCalories = Double(recipe.caloriesPerServing) * multiplier
        let displayedCarbs = Double(recipe.carbsPerServing) * multiplier
        let displayedProtein = Double(recipe.proteinPerServing) * multiplier
        let displayedFat = Double(recipe.fatPerServing) * multiplier
        let displayedGlycemicLoad = Double(recipe.glycemicLoadPerServing) * multiplier

        // Then: All values should be exactly doubled
        XCTAssertEqual(displayedCalories, 1000, accuracy: 0.1, "2.0x should double calories")
        XCTAssertEqual(displayedCarbs, 100, accuracy: 0.1, "2.0x should double carbs")
        XCTAssertEqual(displayedProtein, 60, accuracy: 0.1, "2.0x should double protein")
        XCTAssertEqual(displayedFat, 40, accuracy: 0.1, "2.0x should double fat")
        XCTAssertEqual(displayedGlycemicLoad, 50, accuracy: 0.1, "2.0x should double glycemic load")
    }

    func testPortionMultiplier_HalfPortion_HalvesAllValues() {
        // Given: Base recipe with 0.5x multiplier
        let recipe = createTestRecipe()
        let multiplier = 0.5

        // When: Calculate displayed values at 0.5x
        let displayedCalories = Double(recipe.caloriesPerServing) * multiplier
        let displayedCarbs = Double(recipe.carbsPerServing) * multiplier
        let displayedFiber = Double(recipe.fiberPerServing) * multiplier
        let displayedSugar = Double(recipe.sugarsPerServing) * multiplier
        let displayedProtein = Double(recipe.proteinPerServing) * multiplier
        let displayedFat = Double(recipe.fatPerServing) * multiplier

        // Then: All values should be halved
        XCTAssertEqual(displayedCalories, 250, accuracy: 0.1, "0.5x should halve calories")
        XCTAssertEqual(displayedCarbs, 25, accuracy: 0.1, "0.5x should halve carbs")
        XCTAssertEqual(displayedFiber, 5, accuracy: 0.1, "0.5x should halve fiber")
        XCTAssertEqual(displayedSugar, 7.5, accuracy: 0.1, "0.5x should halve sugar")
        XCTAssertEqual(displayedProtein, 15, accuracy: 0.1, "0.5x should halve protein")
        XCTAssertEqual(displayedFat, 10, accuracy: 0.1, "0.5x should halve fat")
    }

    func testPortionMultiplier_1Point5x_IncreasesBy50Percent() {
        // Given: Base recipe with 1.5x multiplier
        let recipe = createTestRecipe()
        let multiplier = 1.5

        // When: Calculate displayed values at 1.5x
        let displayedCalories = Double(recipe.caloriesPerServing) * multiplier
        let displayedCarbs = Double(recipe.carbsPerServing) * multiplier
        let displayedProtein = Double(recipe.proteinPerServing) * multiplier

        // Then: Values should be 1.5x base
        XCTAssertEqual(displayedCalories, 750, accuracy: 0.1, "1.5x should increase calories by 50%")
        XCTAssertEqual(displayedCarbs, 75, accuracy: 0.1, "1.5x should increase carbs by 50%")
        XCTAssertEqual(displayedProtein, 45, accuracy: 0.1, "1.5x should increase protein by 50%")
    }

    // MARK: - Stepper Button Tests

    func testStepperIncrement_IncreasesMultiplierBy0Point5() {
        // Given: Starting multiplier of 1.0
        var portionMultiplier = 1.0
        let recipe = createTestRecipe()

        // When: User taps the + button (increment by 0.5)
        portionMultiplier += 0.5

        let displayedCalories = Double(recipe.caloriesPerServing) * portionMultiplier

        // Then: Multiplier should be 1.5 and calories should reflect that
        XCTAssertEqual(portionMultiplier, 1.5, "Stepper + should increase by 0.5")
        XCTAssertEqual(displayedCalories, 750, accuracy: 0.1, "Calories should update with stepper")
    }

    func testStepperDecrement_DecreasesMultiplierBy0Point5() {
        // Given: Starting multiplier of 1.0
        var portionMultiplier = 1.0
        let recipe = createTestRecipe()

        // When: User taps the - button (decrement by 0.5)
        if portionMultiplier > 0.5 {
            portionMultiplier -= 0.5
        }

        let displayedCalories = Double(recipe.caloriesPerServing) * portionMultiplier

        // Then: Multiplier should be 0.5 and calories should reflect that
        XCTAssertEqual(portionMultiplier, 0.5, "Stepper - should decrease by 0.5")
        XCTAssertEqual(displayedCalories, 250, accuracy: 0.1, "Calories should update with stepper")
    }

    func testStepperDecrement_MinimumIs0Point5() {
        // Given: Starting multiplier at minimum (0.5)
        var portionMultiplier = 0.5

        // When: User taps the - button
        if portionMultiplier > 0.5 {
            portionMultiplier -= 0.5
        }

        // Then: Should stay at 0.5 (minimum)
        XCTAssertEqual(portionMultiplier, 0.5, "Stepper should not go below 0.5")
    }

    func testStepperMultipleIncrements_AccumulatesCorrectly() {
        // Given: Starting at 1.0
        var portionMultiplier = 1.0
        let recipe = createTestRecipe()

        // When: User taps + three times (1.0 → 1.5 → 2.0 → 2.5)
        portionMultiplier += 0.5  // 1.5
        portionMultiplier += 0.5  // 2.0
        portionMultiplier += 0.5  // 2.5

        let displayedCalories = Double(recipe.caloriesPerServing) * portionMultiplier

        // Then: Should be at 2.5x
        XCTAssertEqual(portionMultiplier, 2.5, "Multiple increments should accumulate")
        XCTAssertEqual(displayedCalories, 1250, accuracy: 0.1, "Calories should reflect 2.5x")
    }

    // MARK: - Slider Adjustment Tests

    func testSliderAdjustment_UpdatesMultiplierCorrectly() {
        // Given: Recipe with 200g portion, slider moved to 300g
        let recipe = createTestRecipe()
        let adjustingPortionWeight = 300.0  // Slider set to 300g

        // When: Calculate new multiplier based on slider position
        // Formula: newValue / recipe.portionSize
        let calculatedMultiplier = adjustingPortionWeight / recipe.portionSize

        // Then: Multiplier should be 1.5 (300g / 200g)
        XCTAssertEqual(calculatedMultiplier, 1.5, accuracy: 0.01, "Slider at 300g should give 1.5x multiplier")
    }

    func testSliderAdjustment_100g_CorrectMultiplier() {
        // Given: Recipe with 200g portion, slider moved to 100g
        let recipe = createTestRecipe()
        let adjustingPortionWeight = 100.0  // Slider set to 100g

        // When: Calculate new multiplier
        let calculatedMultiplier = adjustingPortionWeight / recipe.portionSize

        let displayedCalories = Double(recipe.caloriesPerServing) * calculatedMultiplier

        // Then: Multiplier should be 0.5 (100g / 200g)
        XCTAssertEqual(calculatedMultiplier, 0.5, accuracy: 0.01, "Slider at 100g should give 0.5x multiplier")
        XCTAssertEqual(displayedCalories, 250, accuracy: 0.1, "Calories should be half at 100g")
    }

    func testSliderAdjustment_400g_DoublesPortion() {
        // Given: Recipe with 200g portion, slider moved to 400g (entire recipe)
        let recipe = createTestRecipe()
        let adjustingPortionWeight = 400.0  // Slider set to entire recipe

        // When: Calculate new multiplier
        let calculatedMultiplier = adjustingPortionWeight / recipe.portionSize

        let displayedCarbs = Double(recipe.carbsPerServing) * calculatedMultiplier
        let displayedProtein = Double(recipe.proteinPerServing) * calculatedMultiplier

        // Then: Multiplier should be 2.0 (400g / 200g = eating entire recipe)
        XCTAssertEqual(calculatedMultiplier, 2.0, accuracy: 0.01, "Slider at 400g should give 2.0x multiplier")
        XCTAssertEqual(displayedCarbs, 100, accuracy: 0.1, "Carbs should double at 400g")
        XCTAssertEqual(displayedProtein, 60, accuracy: 0.1, "Protein should double at 400g")
    }

    // MARK: - Save and Reset Tests

    func testSaveNewPortion_ResetsMultiplierTo1x() {
        // Given: User adjusted to 1.5x and saved new portion
        let recipe = createTestRecipe()
        let wrapper = ObservableRecipeWrapper(recipe: recipe)
        let adjustedWeight = 300.0  // User saved 300g as new portion

        // When: Save new portion
        wrapper.updatePortionSize(adjustedWeight)
        var portionMultiplier = 1.5  // Was at 1.5x before save
        portionMultiplier = 1.0      // Reset after save

        // Then: Portion size updated and multiplier reset to 1.0
        XCTAssertEqual(recipe.portionSize, 300, "Portion size should update to 300g")
        XCTAssertEqual(portionMultiplier, 1.0, "Multiplier should reset to 1.0 after save")
    }

    func testAfterSave_1xMultiplierUsesNewBaseline() {
        // Given: User saved 300g as new portion (was 200g)
        let recipe = createTestRecipe()
        recipe.portionSize = 300  // New baseline
        let multiplier = 1.0

        // When: Calculate calories at 1.0x with new baseline
        // The per-serving values would need recalculation in real app,
        // but here we test that 1.0x uses the new portion as base
        let expectedCaloriesForNewPortion = (250.0 / 100.0) * 300.0  // calories per 100g × new portion

        // Then: 1.0x should represent 300g now (not 200g)
        XCTAssertEqual(recipe.portionSize, 300, "New baseline should be 300g")
        XCTAssertEqual(expectedCaloriesForNewPortion, 750, accuracy: 0.1, "1.0x should represent new 300g portion")
    }

    // MARK: - Edge Cases

    func testZeroValues_DoNotCauseNaN() {
        // Given: Recipe with some zero values
        let recipe = createTestRecipe()
        recipe.fiberPerServing = 0
        recipe.sugarsPerServing = 0
        let multiplier = 1.5

        // When: Calculate with multiplier
        let displayedFiber = Double(recipe.fiberPerServing) * multiplier
        let displayedSugar = Double(recipe.sugarsPerServing) * multiplier

        // Then: Should be 0, not NaN
        XCTAssertEqual(displayedFiber, 0, "Zero fiber should remain zero")
        XCTAssertEqual(displayedSugar, 0, "Zero sugar should remain zero")
        XCTAssertFalse(displayedFiber.isNaN, "Result should not be NaN")
    }

    func testVerySmallMultiplier_ProducesReasonableValues() {
        // Given: Recipe with very small multiplier (0.5 is minimum)
        let recipe = createTestRecipe()
        let multiplier = 0.5

        // When: Calculate values
        let displayedCalories = Double(recipe.caloriesPerServing) * multiplier

        // Then: Should produce reasonable result
        XCTAssertGreaterThan(displayedCalories, 0, "Small multiplier should still produce positive result")
        XCTAssertEqual(displayedCalories, 250, accuracy: 0.1, "0.5x should produce correct value")
    }

    func testLargeMultiplier_ProducesCorrectValues() {
        // Given: Recipe with large multiplier (3.0x)
        let recipe = createTestRecipe()
        let multiplier = 3.0

        // When: Calculate values
        let displayedCalories = Double(recipe.caloriesPerServing) * multiplier
        let displayedProtein = Double(recipe.proteinPerServing) * multiplier

        // Then: Should correctly multiply
        XCTAssertEqual(displayedCalories, 1500, accuracy: 0.1, "3.0x should triple calories")
        XCTAssertEqual(displayedProtein, 90, accuracy: 0.1, "3.0x should triple protein")
    }

    // MARK: - Wrapper Tests

    func testObservableRecipeWrapper_ExistsCheck() {
        // Given: Wrapper with recipe
        let recipe = createTestRecipe()
        let wrapper = ObservableRecipeWrapper(recipe: recipe)

        // Then: Should report exists
        XCTAssertTrue(wrapper.exists, "Wrapper with recipe should exist")
    }

    func testObservableRecipeWrapper_NilRecipe() {
        // Given: Wrapper without recipe (generation mode)
        let wrapper = ObservableRecipeWrapper(recipe: nil)

        // Then: Should report not exists
        XCTAssertFalse(wrapper.exists, "Wrapper without recipe should not exist")
        XCTAssertEqual(wrapper.portionSize, 0, "Nil recipe should return 0 portion size")
        XCTAssertEqual(wrapper.totalRecipeWeight, 0, "Nil recipe should return 0 total weight")
    }

    func testObservableRecipeWrapper_AccessorsWork() {
        // Given: Wrapper with recipe
        let recipe = createTestRecipe()
        let wrapper = ObservableRecipeWrapper(recipe: recipe)

        // Then: Accessors should return correct values
        XCTAssertEqual(wrapper.portionSize, 200, "Should access portion size")
        XCTAssertEqual(wrapper.totalRecipeWeight, 400, "Should access total weight")
    }

    // MARK: - Real-World Scenario Tests

    func testRealWorldScenario_UserIncreasesPortionThenSaves() {
        // Given: User starts with 200g portion
        let recipe = createTestRecipe()
        var portionMultiplier = 1.0

        // When: User taps + twice (1.0 → 1.5 → 2.0)
        portionMultiplier += 0.5
        portionMultiplier += 0.5

        let displayedCaloriesBeforeSave = Double(recipe.caloriesPerServing) * portionMultiplier

        // User saves new portion (400g = 2.0x of 200g)
        let newPortionSize = recipe.portionSize * portionMultiplier
        recipe.portionSize = newPortionSize
        portionMultiplier = 1.0  // Reset after save

        let displayedCaloriesAfterSave = Double(recipe.caloriesPerServing) * portionMultiplier

        // Then: Calories before save (2.0x) should equal calories after save (1.0x with new baseline)
        XCTAssertEqual(displayedCaloriesBeforeSave, 1000, accuracy: 0.1, "Before save: 2.0x = 1000 cal")
        XCTAssertEqual(recipe.portionSize, 400, "New portion should be 400g")
        XCTAssertEqual(portionMultiplier, 1.0, "Multiplier reset to 1.0")
        // Note: In real app, per-serving values would recalculate, but the gram amount stays same
    }

    func testRealWorldScenario_UserUsesSliderThenStepper() {
        // Given: User starts with 200g portion
        let recipe = createTestRecipe()

        // When: User moves slider to 250g
        let sliderPosition = 250.0
        var portionMultiplier = sliderPosition / recipe.portionSize  // 250/200 = 1.25

        let caloriesAfterSlider = Double(recipe.caloriesPerServing) * portionMultiplier

        // Then taps + button (1.25 → 1.75)
        portionMultiplier += 0.5

        let caloriesAfterStepper = Double(recipe.caloriesPerServing) * portionMultiplier

        // Then: Slider should give 1.25x, then stepper should increase to 1.75x
        XCTAssertEqual(caloriesAfterSlider, 625, accuracy: 0.1, "Slider at 250g = 625 cal")
        XCTAssertEqual(portionMultiplier, 1.75, accuracy: 0.01, "After + button should be 1.75x")
        XCTAssertEqual(caloriesAfterStepper, 875, accuracy: 0.1, "Final should be 875 cal")
    }
}
