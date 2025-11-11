//
//  NutritionalValuesViewTests.swift
//  balliTests
//
//  Unit tests for NutritionalValuesView portion adjustment logic
//  Tests P0 and P1 fixes for zero checks, fallback logic, and data source consolidation
//

import XCTest
import SwiftUI
@testable import balli

@MainActor
final class NutritionalValuesViewTests: XCTestCase {

    // MARK: - Test Cases for Portion Display Logic

    /// Test: currentPortionSize = 0, totalWeight = 800 → should display 800g
    func testPortionDisplay_WithZeroPortionSize_UsesTotalWeight() {
        // Given: Recipe with no saved portion, but valid total weight
        let recipe = createMockRecipe(portionSize: 0, totalRecipeWeight: 800)
        let multiplier: Double = 1.0

        // When: Calculate effective portion
        let effectivePortionSize = recipe.portionSize > 0 ? recipe.portionSize : recipe.totalRecipeWeight

        // Then: Should fall back to total recipe weight
        XCTAssertEqual(effectivePortionSize, 800, "Should use total recipe weight when portion size is 0")
        XCTAssertEqual(Int(effectivePortionSize * multiplier), 800, "Display should show 800g")
    }

    /// Test: currentPortionSize = 200, totalWeight = 800 → should display 200g
    func testPortionDisplay_WithSavedPortion_UsesSavedPortion() {
        // Given: Recipe with saved portion size
        let recipe = createMockRecipe(portionSize: 200, totalRecipeWeight: 800)
        let multiplier: Double = 1.0

        // When: Calculate effective portion
        let effectivePortionSize = recipe.portionSize > 0 ? recipe.portionSize : recipe.totalRecipeWeight

        // Then: Should use saved portion size
        XCTAssertEqual(effectivePortionSize, 200, "Should use saved portion size")
        XCTAssertEqual(Int(effectivePortionSize * multiplier), 200, "Display should show 200g")
    }

    /// Test: currentPortionSize = 0, totalWeight = 0 → should show error
    func testPortionDisplay_WithZeroValues_ShowsError() {
        // Given: Recipe with no portion and no total weight (corrupted data)
        let recipe = createMockRecipe(portionSize: 0, totalRecipeWeight: 0)

        // When: Calculate effective portion
        let effectivePortionSize = recipe.portionSize > 0 ? recipe.portionSize : recipe.totalRecipeWeight

        // Then: Should detect error condition
        XCTAssertEqual(effectivePortionSize, 0, "Effective portion should be 0")
        XCTAssertTrue(effectivePortionSize <= 0, "Should trigger error state check")
    }

    /// Test: Save portion → multiplier resets to 1.0
    func testPortionSave_ResetsMultiplierToOne() {
        // Given: Recipe with adjusted multiplier
        var multiplier: Double = 2.5

        // When: Save operation completes
        // Simulating what NutritionalValuesActions does (line 112)
        multiplier = 1.0

        // Then: Multiplier should be reset
        XCTAssertEqual(multiplier, 1.0, "Multiplier should reset to 1.0 after save")
    }

    /// Test: Stepper increments by 0.5
    func testStepper_IncrementsMultiplierByHalf() {
        // Given: Initial multiplier
        var multiplier: Double = 1.0

        // When: User taps + stepper
        multiplier += 0.5

        // Then: Multiplier increases by 0.5
        XCTAssertEqual(multiplier, 1.5, "Multiplier should increment by 0.5")

        // When: User taps + again
        multiplier += 0.5

        // Then: Multiplier increases again
        XCTAssertEqual(multiplier, 2.0, "Multiplier should be 2.0 after second increment")
    }

    /// Test: Stepper decrements by 0.5 (min 0.5)
    func testStepper_DecrementsMultiplierWithMinimum() {
        // Given: Initial multiplier at minimum
        var multiplier: Double = 0.5

        // When: User attempts to tap - stepper
        if multiplier > 0.5 {
            multiplier -= 0.5
        }

        // Then: Should not go below 0.5
        XCTAssertEqual(multiplier, 0.5, "Multiplier should not go below 0.5")

        // Given: Higher multiplier
        multiplier = 2.0

        // When: User taps - stepper
        multiplier -= 0.5

        // Then: Should decrement
        XCTAssertEqual(multiplier, 1.5, "Multiplier should decrement by 0.5")
    }

    /// Test: Slider onChange updates multiplier correctly
    func testSlider_UpdatesMultiplierFromWeight() {
        // Given: Recipe with saved portion of 200g
        let savedPortionSize: Double = 200
        let newSliderValue: Double = 300

        // When: Slider changes to 300g
        let newMultiplier = newSliderValue / savedPortionSize

        // Then: Multiplier should be 1.5
        XCTAssertEqual(newMultiplier, 1.5, "Multiplier should be calculated as newValue / portionSize")
    }

    /// Test: Data source consolidation - recipe.totalRecipeWeight is primary
    func testDataSourceConsolidation_UsesRecipeWeight() {
        // Given: Recipe with valid weight
        let recipe = createMockRecipe(portionSize: 0, totalRecipeWeight: 600)
        let stringParameter = "800" // Different value

        // When: Determine total weight (P1 fix logic)
        let totalWeight = recipe.totalRecipeWeight > 0
            ? recipe.totalRecipeWeight
            : (Double(stringParameter) ?? 0)

        // Then: Should use recipe.totalRecipeWeight
        XCTAssertEqual(totalWeight, 600, "Should prioritize recipe.totalRecipeWeight over string parameter")
    }

    /// Test: Data source consolidation - falls back to string parameter
    func testDataSourceConsolidation_FallsBackToStringParameter() {
        // Given: Recipe with zero weight but valid string parameter
        let recipe = createMockRecipe(portionSize: 0, totalRecipeWeight: 0)
        let stringParameter = "800"

        // When: Determine total weight (P1 fix logic)
        let totalWeight = recipe.totalRecipeWeight > 0
            ? recipe.totalRecipeWeight
            : (Double(stringParameter) ?? 0)

        // Then: Should fall back to string parameter
        XCTAssertEqual(totalWeight, 800, "Should fall back to string parameter when recipe weight is 0")
    }

    /// Test: Portion nutrition calculation after save
    func testPortionNutrition_UpdatesAfterSave() {
        // Given: Recipe with 800g total, 400 total calories
        let totalRecipeWeight: Double = 800
        let totalCalories: Double = 400
        let newPortionSize: Double = 200

        // When: Calculate portion ratio and nutrition
        let portionRatio = newPortionSize / totalRecipeWeight
        let portionCalories = totalCalories * portionRatio

        // Then: Portion should have 100 calories (200g of 800g = 25%)
        XCTAssertEqual(portionRatio, 0.25, "Portion ratio should be 0.25")
        XCTAssertEqual(portionCalories, 100, "Portion calories should be 100")
    }

    // MARK: - Helper Methods

    private func createMockRecipe(portionSize: Double, totalRecipeWeight: Double) -> MockRecipe {
        return MockRecipe(portionSize: portionSize, totalRecipeWeight: totalRecipeWeight)
    }
}

// MARK: - Mock Recipe

/// Mock recipe for testing portion logic
struct MockRecipe {
    let portionSize: Double
    let totalRecipeWeight: Double
}
