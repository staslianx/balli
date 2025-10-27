//
//  ImpactScoreValidationTests.swift
//  balliTests
//
//  Manual validation against spec examples from IMPACT_SCORE_UPDATED.md
//

import XCTest
import SwiftUI
@testable import balli

final class ImpactScoreValidationTests: XCTestCase {

    // MARK: - Chocolate Bar Validation (Spec lines 554-614)

    func testChocolateBarFullServing_DetailedValidation() {
        // Given: Chocolate bar nutrition from spec (line 558-564)
        let totalCarbs = 13.7
        let fiber = 1.9
        let sugar = 12.5
        let protein = 4.9
        let fat = 16.0
        let servingSize = 38.0

        // When: Calculate at 100% portion
        let result = ImpactScoreCalculator.calculate(
            totalCarbs: totalCarbs,
            fiber: fiber,
            sugar: sugar,
            protein: protein,
            fat: fat,
            servingSize: servingSize,
            portionGrams: servingSize
        )

        // Then: Verify step-by-step calculation matches spec (lines 569-581)

        // Step 1: Available carbs = 13.7 - 1.9 = 11.8g
        XCTAssertEqual(result.availableCarbs, 11.8, accuracy: 0.01, "Available carbs calculation")

        // Step 6: Impact score = 3.63
        XCTAssertEqual(result.score, 3.63, accuracy: 0.1, "Impact score matches spec")

        // Step 5: Effective GI ≈ 30.8
        XCTAssertEqual(result.effectiveGI, 30.8, accuracy: 1.0, "Effective GI matches spec")

        // Threshold checks (lines 583-588)
        // ✓ score: 3.63 < 5.0 (pass)
        XCTAssertLessThan(result.score, 5.0, "Score threshold passes")

        // ✗ fat: 16g >= 15.0 (FAIL - danger zone)
        XCTAssertGreaterThanOrEqual(fat, 15.0, "Fat in danger zone")

        // ✓ protein: 4.9g < 10.0 (pass)
        XCTAssertLessThan(protein, 10.0, "Protein threshold passes")

        // Result: RED (spec line 588)
        XCTAssertEqual(result.color, .red, "Color should be RED due to high fat")

        // Weight display
        XCTAssertEqual(result.weightGrams, 38, "Weight should be 38g")
        XCTAssertTrue(result.statusText.contains("38g"), "Status should show weight")
    }

    func testChocolateBar30Percent_DetailedValidation() {
        // Given: Chocolate bar at 30% portion (spec lines 592-614)
        let totalCarbs = 13.7
        let fiber = 1.9
        let sugar = 12.5
        let protein = 4.9
        let fat = 16.0
        let servingSize = 38.0
        let portionGrams = servingSize * 0.30  // 11.4g

        // When: Calculate at 30% portion
        let result = ImpactScoreCalculator.calculate(
            totalCarbs: totalCarbs,
            fiber: fiber,
            sugar: sugar,
            protein: protein,
            fat: fat,
            servingSize: servingSize,
            portionGrams: portionGrams
        )

        // Then: Verify scaled values (spec lines 594-599)
        // Scaled carbs: 4.11g
        let scaledCarbs = totalCarbs * 0.30
        XCTAssertEqual(scaledCarbs, 4.11, accuracy: 0.01, "Scaled carbs")

        // Scaled fiber: 0.57g
        let scaledFiber = fiber * 0.30
        XCTAssertEqual(scaledFiber, 0.57, accuracy: 0.01, "Scaled fiber")

        // Scaled sugar: 3.75g
        let scaledSugar = sugar * 0.30
        XCTAssertEqual(scaledSugar, 3.75, accuracy: 0.01, "Scaled sugar")

        // Scaled protein: 1.47g
        let scaledProtein = protein * 0.30
        XCTAssertEqual(scaledProtein, 1.47, accuracy: 0.01, "Scaled protein")

        // Scaled fat: 4.8g
        let scaledFat = fat * 0.30
        XCTAssertEqual(scaledFat, 4.8, accuracy: 0.01, "Scaled fat")

        // Verify impact score ≈ 1.09 (spec line 605)
        XCTAssertEqual(result.score, 1.09, accuracy: 0.1, "Impact score at 30%")

        // Threshold checks (lines 607-610)
        // ✓ score: 1.09 < 5.0
        XCTAssertLessThan(result.score, 5.0, "Score passes")

        // ✓ fat: 4.8g < 5.0
        XCTAssertLessThan(scaledFat, 5.0, "Fat passes")

        // ✓ protein: 1.47g < 10.0
        XCTAssertLessThan(scaledProtein, 10.0, "Protein passes")

        // Result: GREEN (spec line 612)
        // Note: This test validates the color determination
        let color = ImpactLevel.from(score: result.score, fat: scaledFat, protein: scaledProtein)
        XCTAssertEqual(color, .low, "Impact level should be low (green)")

        // Weight: 11g (spec line 613)
        XCTAssertEqual(result.weightGrams, 11, "Weight should be ~11g")
    }

    // MARK: - Fruit Bar Validation (Spec lines 618-654)

    func testFruitBarFullServing_DetailedValidation() {
        // Given: Fruit bar nutrition from spec (lines 622-628)
        let totalCarbs = 13.8
        let fiber = 3.3
        let sugar = 7.8
        let protein = 3.8
        let fat = 3.8
        let servingSize = 27.0

        // When: Calculate at 100% portion
        let result = ImpactScoreCalculator.calculate(
            totalCarbs: totalCarbs,
            fiber: fiber,
            sugar: sugar,
            protein: protein,
            fat: fat,
            servingSize: servingSize,
            portionGrams: servingSize
        )

        // Then: Verify step-by-step calculation matches spec (lines 633-645)

        // Available carbs = 10.5g (spec line 633)
        XCTAssertEqual(result.availableCarbs, 10.5, accuracy: 0.01, "Available carbs")

        // Effective GI ≈ 44.2 (spec line 644)
        XCTAssertEqual(result.effectiveGI, 44.2, accuracy: 1.0, "Effective GI")

        // Impact score = 4.64 (spec line 645)
        XCTAssertEqual(result.score, 4.64, accuracy: 0.1, "Impact score matches spec")

        // Threshold checks (lines 647-650)
        // ✓ score: 4.64 < 5.0
        XCTAssertLessThan(result.score, 5.0, "Score threshold passes")

        // ✓ fat: 3.8g < 5.0
        XCTAssertLessThan(fat, 5.0, "Fat threshold passes")

        // ✓ protein: 3.8g < 10.0
        XCTAssertLessThan(protein, 10.0, "Protein threshold passes")

        // Result: GREEN (spec line 652)
        XCTAssertEqual(result.color, .green, "Color should be GREEN (all thresholds pass)")

        // Weight: 27g (spec line 653)
        XCTAssertEqual(result.weightGrams, 27, "Weight should be 27g")
        XCTAssertTrue(result.statusText.contains("27g"), "Status should show weight")
        XCTAssertTrue(result.statusText.contains("🟢"), "Status should show green indicator")
    }

    // MARK: - Formula Step-by-Step Validation

    func testFormulaStepByStep_ChocolateExample() {
        // Given: Chocolate bar at 100%
        let totalCarbs = 13.7
        let fiber = 1.9
        let sugar = 12.5
        let protein = 4.9
        let fat = 16.0

        // Step 1: Available carbs (spec line 569)
        let availableCarbs = totalCarbs - fiber
        XCTAssertEqual(availableCarbs, 11.8, accuracy: 0.01, "Step 1: Available carbs")

        // Step 2: Sugar vs starch split (spec lines 570-571)
        let sugarCarbs = min(sugar, availableCarbs)
        let starchCarbs = availableCarbs - sugarCarbs
        XCTAssertEqual(sugarCarbs, 11.8, accuracy: 0.01, "Step 2: Sugar carbs")
        XCTAssertEqual(starchCarbs, 0.0, accuracy: 0.01, "Step 2: Starch carbs")

        // Step 3: Glycemic impact (spec line 573)
        let glycemicImpact = (sugarCarbs * 0.65) + (starchCarbs * 0.75)
        XCTAssertEqual(glycemicImpact, 7.67, accuracy: 0.01, "Step 3: Glycemic impact")

        // Step 4: GI-lowering effects (spec lines 575-577)
        let fiberEffect = fiber * 0.3
        let proteinEffect = protein * 0.6
        let fatEffect = fat * 0.6
        XCTAssertEqual(fiberEffect, 0.57, accuracy: 0.01, "Step 4: Fiber effect")
        XCTAssertEqual(proteinEffect, 2.94, accuracy: 0.01, "Step 4: Protein effect")
        XCTAssertEqual(fatEffect, 9.6, accuracy: 0.01, "Step 4: Fat effect")

        // Step 5: Effective GI (spec lines 579-580)
        let denominator = availableCarbs + fiberEffect + proteinEffect + fatEffect
        XCTAssertEqual(denominator, 24.91, accuracy: 0.01, "Step 5: Denominator")

        let effectiveGI = (glycemicImpact * 100) / denominator
        XCTAssertEqual(effectiveGI, 30.8, accuracy: 0.5, "Step 5: Effective GI")

        // Step 6: Final impact score (spec line 581)
        let impactScore = (effectiveGI * availableCarbs) / 100
        XCTAssertEqual(impactScore, 3.63, accuracy: 0.1, "Step 6: Impact score")

        // Verify using calculator
        let result = ImpactScoreCalculator.calculate(
            totalCarbs: totalCarbs,
            fiber: fiber,
            sugar: sugar,
            protein: protein,
            fat: fat,
            servingSize: 100.0,
            portionGrams: 100.0
        )

        XCTAssertEqual(result.score, impactScore, accuracy: 0.01, "Calculator matches manual calculation")
    }

    // MARK: - Three-Threshold Logic Validation

    func testThreeThresholdLogic_AllMustPassForGreen() {
        // Test 1: All pass → GREEN
        let greenResult = ImpactLevel.from(score: 4.9, fat: 4.9, protein: 9.9)
        XCTAssertEqual(greenResult, .low, "All thresholds pass → GREEN")

        // Test 2: Score fails → YELLOW/RED
        let scoreFailYellow = ImpactLevel.from(score: 7.0, fat: 4.9, protein: 9.9)
        XCTAssertEqual(scoreFailYellow, .medium, "Score in caution zone → YELLOW")

        let scoreFailRed = ImpactLevel.from(score: 12.0, fat: 4.9, protein: 9.9)
        XCTAssertEqual(scoreFailRed, .high, "Score in danger zone → RED")

        // Test 3: Fat fails → RED (spec example: chocolate at 100%)
        let fatFail = ImpactLevel.from(score: 3.63, fat: 16.0, protein: 4.9)
        XCTAssertEqual(fatFail, .high, "High fat → RED despite low score")

        // Test 4: Protein fails → RED
        let proteinFail = ImpactLevel.from(score: 3.0, fat: 4.0, protein: 22.0)
        XCTAssertEqual(proteinFail, .high, "High protein → RED despite low score/fat")
    }

    // MARK: - Portion Scaling Validation

    func testPortionScaling_MaintainsProportions() {
        // Given: Food at 100%
        let fullServing = ImpactScoreCalculator.calculate(
            totalCarbs: 20.0,
            fiber: 4.0,
            sugar: 10.0,
            protein: 8.0,
            fat: 6.0,
            servingSize: 100.0,
            portionGrams: 100.0
        )

        // When: Scale to 50%
        let halfServing = ImpactScoreCalculator.calculate(
            totalCarbs: 20.0,
            fiber: 4.0,
            sugar: 10.0,
            protein: 8.0,
            fat: 6.0,
            servingSize: 100.0,
            portionGrams: 50.0
        )

        // Then: Available carbs should scale proportionally
        XCTAssertEqual(halfServing.availableCarbs, fullServing.availableCarbs * 0.5, accuracy: 0.01,
                       "Available carbs scale proportionally")

        // Effective GI should remain constant (ratio-based, not absolute)
        XCTAssertEqual(halfServing.effectiveGI, fullServing.effectiveGI, accuracy: 1.0,
                       "Effective GI remains constant across portions")

        // Score should scale linearly (GL = GI × carbs / 100)
        let expectedScoreRatio = halfServing.score / fullServing.score
        XCTAssertEqual(expectedScoreRatio, 0.5, accuracy: 0.01,
                       "Score scales linearly with portion")
    }
}
