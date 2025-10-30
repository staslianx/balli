//
//  ImpactScoreZeroNutrientsTests.swift
//  balliTests
//
//  Created by Claude Code on 2025-10-30.
//  Tests to verify graceful handling of zero/missing nutritional values
//

import XCTest
import SwiftUI
@testable import balli

final class ImpactScoreZeroNutrientsTests: XCTestCase {

    // MARK: - Zero Fiber Tests

    func testZeroFiber_StillCalculatesImpactScore() {
        // Given: Product with zero fiber (real-world scenario reported by user)
        let totalCarbs = 30.0
        let fiber = 0.0       // Zero fiber
        let sugar = 5.0
        let protein = 2.0
        let fat = 1.0
        let servingSize = 100.0
        let portionGrams = 100.0

        // When
        let result = ImpactScoreCalculator.calculate(
            totalCarbs: totalCarbs,
            fiber: fiber,
            sugar: sugar,
            protein: protein,
            fat: fat,
            servingSize: servingSize,
            portionGrams: portionGrams
        )

        // Then: Should calculate valid impact score
        XCTAssertGreaterThan(result.score, 0, "Zero fiber should not prevent impact score calculation")
        XCTAssertNotNil(result.color, "Should return a valid color")
        XCTAssertFalse(result.statusText.isEmpty, "Should return valid status text")

        // Available carbs should equal total carbs when fiber is zero
        XCTAssertEqual(result.availableCarbs, totalCarbs, accuracy: 0.01)
    }

    func testZeroSugars_StillCalculatesImpactScore() {
        // Given: Product with zero sugars (e.g., pure starch product)
        let totalCarbs = 40.0
        let fiber = 2.0
        let sugar = 0.0       // Zero sugars
        let protein = 8.0
        let fat = 5.0
        let servingSize = 100.0
        let portionGrams = 100.0

        // When
        let result = ImpactScoreCalculator.calculate(
            totalCarbs: totalCarbs,
            fiber: fiber,
            sugar: sugar,
            protein: protein,
            fat: fat,
            servingSize: servingSize,
            portionGrams: portionGrams
        )

        // Then: Should calculate valid impact score based on starch only
        XCTAssertGreaterThan(result.score, 0, "Zero sugars should not prevent impact score calculation")
        XCTAssertNotNil(result.color, "Should return a valid color")
    }

    func testZeroProtein_StillCalculatesImpactScore() {
        // Given: Product with zero protein (e.g., pure sugar product)
        let totalCarbs = 25.0
        let fiber = 0.5
        let sugar = 24.0
        let protein = 0.0     // Zero protein
        let fat = 0.1
        let servingSize = 100.0
        let portionGrams = 100.0

        // When
        let result = ImpactScoreCalculator.calculate(
            totalCarbs: totalCarbs,
            fiber: fiber,
            sugar: sugar,
            protein: protein,
            fat: fat,
            servingSize: servingSize,
            portionGrams: portionGrams
        )

        // Then: Should calculate high impact (no protein dampening effect)
        XCTAssertGreaterThan(result.score, 0, "Zero protein should not prevent impact score calculation")
        XCTAssertEqual(result.color, .red, "High carb with no protein should be red")
    }

    func testZeroFat_StillCalculatesImpactScore() {
        // Given: Product with zero fat (e.g., fat-free product)
        let totalCarbs = 20.0
        let fiber = 1.0
        let sugar = 10.0
        let protein = 5.0
        let fat = 0.0         // Zero fat
        let servingSize = 100.0
        let portionGrams = 100.0

        // When
        let result = ImpactScoreCalculator.calculate(
            totalCarbs: totalCarbs,
            fiber: fiber,
            sugar: sugar,
            protein: protein,
            fat: fat,
            servingSize: servingSize,
            portionGrams: portionGrams
        )

        // Then: Should calculate valid impact (no fat dampening effect)
        XCTAssertGreaterThan(result.score, 0, "Zero fat should not prevent impact score calculation")
        XCTAssertNotNil(result.color, "Should return a valid color")
    }

    // MARK: - Multiple Zero Values

    func testMultipleZeroNutrients_StillCalculatesImpactScore() {
        // Given: Product with multiple zero values (e.g., simple carb product)
        let totalCarbs = 35.0
        let fiber = 0.0       // Zero fiber
        let sugar = 0.0       // Zero sugars
        let protein = 0.0     // Zero protein
        let fat = 0.0         // Zero fat
        let servingSize = 100.0
        let portionGrams = 100.0

        // When
        let result = ImpactScoreCalculator.calculate(
            totalCarbs: totalCarbs,
            fiber: fiber,
            sugar: sugar,
            protein: protein,
            fat: fat,
            servingSize: servingSize,
            portionGrams: portionGrams
        )

        // Then: Should calculate based on starch carbs only
        XCTAssertGreaterThan(result.score, 0, "Multiple zeros should not prevent calculation")
        XCTAssertEqual(result.color, .red, "Pure carbs with no nutrients should be red")
        XCTAssertEqual(result.availableCarbs, totalCarbs, accuracy: 0.01)
    }

    func testAllNutrientsZero_ReturnsZeroScore() {
        // Given: Edge case with all nutrients zero
        let totalCarbs = 0.0
        let fiber = 0.0
        let sugar = 0.0
        let protein = 0.0
        let fat = 0.0
        let servingSize = 100.0
        let portionGrams = 100.0

        // When
        let result = ImpactScoreCalculator.calculate(
            totalCarbs: totalCarbs,
            fiber: fiber,
            sugar: sugar,
            protein: protein,
            fat: fat,
            servingSize: servingSize,
            portionGrams: portionGrams
        )

        // Then: Should return zero score (no glycemic impact possible)
        XCTAssertEqual(result.score, 0.0, accuracy: 0.01, "All zeros should give zero score")
        XCTAssertEqual(result.color, .green, "Zero score should be green (safe)")
    }

    // MARK: - Real-World Product Simulations

    func testCelery_VeryLowCarbsZeroImpact() {
        // Given: Celery - high fiber, very low carbs
        let totalCarbs = 3.0
        let fiber = 1.6
        let sugar = 1.3
        let protein = 0.7
        let fat = 0.2
        let servingSize = 100.0
        let portionGrams = 100.0

        // When
        let result = ImpactScoreCalculator.calculate(
            totalCarbs: totalCarbs,
            fiber: fiber,
            sugar: sugar,
            protein: protein,
            fat: fat,
            servingSize: servingSize,
            portionGrams: portionGrams
        )

        // Then: Should calculate very low impact
        XCTAssertLessThan(result.score, 2.0, "Celery should have very low impact")
        XCTAssertEqual(result.color, .green, "Should be green (safe)")
    }

    func testWhiteBread_HighStarchZeroFiber() {
        // Given: White bread - high starch, minimal fiber
        let totalCarbs = 49.0
        let fiber = 0.0       // Essentially zero fiber
        let sugar = 5.0
        let protein = 8.0
        let fat = 3.0
        let servingSize = 100.0
        let portionGrams = 100.0

        // When
        let result = ImpactScoreCalculator.calculate(
            totalCarbs: totalCarbs,
            fiber: fiber,
            sugar: sugar,
            protein: protein,
            fat: fat,
            servingSize: servingSize,
            portionGrams: portionGrams
        )

        // Then: Should calculate high impact despite zero fiber
        XCTAssertGreaterThan(result.score, 10.0, "White bread should have high impact")
        XCTAssertEqual(result.color, .red, "Should be red (high risk)")
    }

    // MARK: - UI Layer Integration Tests

    func testNutritionFormState_HandlesZeroFiber() {
        // Given: Form state with zero fiber as string
        var formState = NutritionFormState()
        formState.servingSize = "100"
        formState.portionGrams = 100.0
        formState.carbohydrates = "30"
        formState.fiber = "0"        // Zero as string
        formState.sugars = "5"
        formState.protein = "2"
        formState.fat = "1"

        // When
        let score = formState.calculateImpactScore()

        // Then: Should calculate valid score
        XCTAssertGreaterThan(score, 0, "Should calculate impact even with zero fiber")
    }

    func testNutritionFormState_HandlesEmptyFiber() {
        // Given: Form state with empty fiber string (user's reported issue)
        var formState = NutritionFormState()
        formState.servingSize = "100"
        formState.portionGrams = 100.0
        formState.carbohydrates = "30"
        formState.fiber = ""         // Empty string
        formState.sugars = "5"
        formState.protein = "2"
        formState.fat = "1"

        // When
        let score = formState.calculateImpactScore()

        // Then: Should calculate valid score (treats empty as 0.0)
        XCTAssertGreaterThan(score, 0, "Should calculate impact even with empty fiber")
    }

    func testNutritionFormState_HandlesMultipleEmptyOptionalFields() {
        // Given: Form state with multiple empty optional fields
        var formState = NutritionFormState()
        formState.servingSize = "100"
        formState.portionGrams = 100.0
        formState.carbohydrates = "40"
        formState.fiber = ""         // Empty
        formState.sugars = ""        // Empty
        formState.protein = ""       // Empty
        formState.fat = ""           // Empty

        // When
        let score = formState.calculateImpactScore()

        // Then: Should calculate based on carbs alone
        XCTAssertGreaterThan(score, 0, "Should calculate impact with multiple empty fields")
    }

    // MARK: - Portion Scaling with Zero Values

    func testPortionScaling_WithZeroFiber() {
        // Given: Product with zero fiber, different portions
        let totalCarbs = 30.0
        let fiber = 0.0
        let sugar = 5.0
        let protein = 2.0
        let fat = 1.0
        let servingSize = 100.0

        // When: Calculate for different portions
        let result50g = ImpactScoreCalculator.calculate(
            totalCarbs: totalCarbs, fiber: fiber, sugar: sugar,
            protein: protein, fat: fat,
            servingSize: servingSize, portionGrams: 50.0
        )

        let result100g = ImpactScoreCalculator.calculate(
            totalCarbs: totalCarbs, fiber: fiber, sugar: sugar,
            protein: protein, fat: fat,
            servingSize: servingSize, portionGrams: 100.0
        )

        let result200g = ImpactScoreCalculator.calculate(
            totalCarbs: totalCarbs, fiber: fiber, sugar: sugar,
            protein: protein, fat: fat,
            servingSize: servingSize, portionGrams: 200.0
        )

        // Then: Scores should scale proportionally
        XCTAssertLessThan(result50g.score, result100g.score, "50g should have lower score than 100g")
        XCTAssertGreaterThan(result200g.score, result100g.score, "200g should have higher score than 100g")
        XCTAssertEqual(result100g.score, result50g.score * 2.0, accuracy: 0.1, "Should scale linearly")
    }
}
