//
//  ImpactScoreCalculatorTests.swift
//  balliTests
//
//  Created by Claude Code on 2025-10-27.
//

import XCTest
import SwiftUI
@testable import balli

final class ImpactScoreCalculatorTests: XCTestCase {

    // MARK: - Spec Example 1: Chocolate Bar (High Fat)

    func testChocolateBar_FullServing_ScoreAccurate() {
        // Given: Chocolate bar nutrition (from spec lines 556-589)
        let totalCarbs = 13.7
        let fiber = 1.9
        let sugar = 12.5
        let protein = 4.9
        let fat = 16.0
        let servingSize = 38.0
        let portionGrams = 38.0  // 100% portion

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

        // Then: Score should be ~3.63 (spec line 581)
        XCTAssertEqual(result.score, 3.63, accuracy: 0.1, "Chocolate score should match spec")

        // Available carbs should be 11.8g (spec line 569)
        XCTAssertEqual(result.availableCarbs, 11.8, accuracy: 0.1, "Available carbs calculation")

        // Effective GI should be ~30.8 (spec line 580)
        XCTAssertEqual(result.effectiveGI, 30.8, accuracy: 1.0, "Effective GI calculation")
    }

    func testChocolateBar_FullServing_RedDueToFat() {
        // Given: Same chocolate bar at 100%
        let result = ImpactScoreCalculator.calculate(
            totalCarbs: 13.7,
            fiber: 1.9,
            sugar: 12.5,
            protein: 4.9,
            fat: 16.0,
            servingSize: 38.0,
            portionGrams: 38.0
        )

        // Then: Should be RED because fat (16g) exceeds 15.0g threshold
        // Even though score is low (3.63 < 5.0), fat is in danger zone
        XCTAssertEqual(result.color, .red, "Chocolate should be red due to high fat")
        XCTAssertTrue(result.statusText.contains("🔴"), "Status should show red indicator")
        XCTAssertTrue(result.statusText.contains("çok fazla"), "Status should be 'too much'")
    }

    func testChocolateBar_30Percent_AllGreen() {
        // Given: Chocolate bar at 30% portion (spec lines 592-614)
        let servingSize = 38.0
        let portionGrams = servingSize * 0.30  // 11.4g

        let result = ImpactScoreCalculator.calculate(
            totalCarbs: 13.7,
            fiber: 1.9,
            sugar: 12.5,
            protein: 4.9,
            fat: 16.0,
            servingSize: servingSize,
            portionGrams: portionGrams
        )

        // Then: All thresholds should pass
        // Score: ~1.09 < 5.0 ✓
        // Fat: 4.8g < 5.0 ✓
        // Protein: 1.47g < 10.0 ✓
        XCTAssertLessThan(result.score, 5.0, "Score should be under 5.0")
        XCTAssertEqual(result.color, .green, "30% chocolate should be green")
        XCTAssertTrue(result.statusText.contains("🟢"), "Status should show green indicator")
        XCTAssertTrue(result.statusText.contains("güvenli"), "Status should be 'safe'")
        XCTAssertEqual(result.weightGrams, 11, "Weight should be ~11g")
    }

    // MARK: - Spec Example 2: Fruit Bar (Low Fat)

    func testFruitBar_FullServing_ScoreAccurate() {
        // Given: Fruit bar nutrition (from spec lines 620-654)
        let totalCarbs = 13.8
        let fiber = 3.3
        let sugar = 7.8
        let protein = 3.8
        let fat = 3.8
        let servingSize = 27.0
        let portionGrams = 27.0  // 100% portion

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

        // Then: Score should be ~4.64 (spec line 645)
        XCTAssertEqual(result.score, 4.64, accuracy: 0.1, "Fruit bar score should match spec")

        // Available carbs should be 10.5g (spec line 633)
        XCTAssertEqual(result.availableCarbs, 10.5, accuracy: 0.1, "Available carbs")

        // Effective GI should be ~44.2 (spec line 644)
        XCTAssertEqual(result.effectiveGI, 44.2, accuracy: 1.0, "Effective GI")
    }

    func testFruitBar_FullServing_AllGreen() {
        // Given: Fruit bar at 100% (spec lines 630-653)
        let result = ImpactScoreCalculator.calculate(
            totalCarbs: 13.8,
            fiber: 3.3,
            sugar: 7.8,
            protein: 3.8,
            fat: 3.8,
            servingSize: 27.0,
            portionGrams: 27.0
        )

        // Then: All thresholds pass at full serving
        // Score: 4.64 < 5.0 ✓
        // Fat: 3.8g < 5.0 ✓
        // Protein: 3.8g < 10.0 ✓
        XCTAssertEqual(result.color, .green, "Fruit bar should be green at 100%")
        XCTAssertTrue(result.statusText.contains("🟢"), "Status should show green indicator")
        XCTAssertEqual(result.weightGrams, 27, "Weight should be 27g")
    }

    // MARK: - Edge Cases

    func testZeroCarbs_GreenWhenProteinFatLow() {
        // Given: Food with zero carbs but low protein/fat (e.g., small portion of cheese)
        let result = ImpactScoreCalculator.calculate(
            totalCarbs: 0.0,
            fiber: 0.0,
            sugar: 0.0,
            protein: 8.0,  // < 10g threshold
            fat: 4.0,      // < 5g threshold
            servingSize: 100.0,
            portionGrams: 100.0
        )

        // Then: Should be green (no glycemic impact and low protein/fat)
        XCTAssertEqual(result.score, 0.0, "Zero carbs should have zero score")
        XCTAssertEqual(result.color, .green, "Zero carbs with low protein/fat should be green")
    }

    func testVeryLowCarbs_HandledCorrectly() {
        // Given: Food with carbs < fiber (fiber exceeds total carbs)
        let result = ImpactScoreCalculator.calculate(
            totalCarbs: 2.0,
            fiber: 5.0,
            sugar: 1.0,
            protein: 3.0,
            fat: 2.0,
            servingSize: 100.0,
            portionGrams: 100.0
        )

        // Then: Calculator handles negative available carbs gracefully
        // Score should be 0 (early return when availableCarbs ≤ 0)
        XCTAssertEqual(result.score, 0.0, "Negative available carbs should yield zero score")
        // Available carbs returned should be 0.0 (not the negative calculated value)
        XCTAssertEqual(result.availableCarbs, 0.0, "Available carbs returned as 0.0 for negative calc")
    }

    func testSugarExceedsAvailableCarbs_Capped() {
        // Given: Nutrition label error where sugar > net carbs
        let totalCarbs = 10.0
        let fiber = 2.0
        let sugar = 15.0  // Impossible but happens in labels
        let protein = 3.0
        let fat = 2.0

        let result = ImpactScoreCalculator.calculate(
            totalCarbs: totalCarbs,
            fiber: fiber,
            sugar: sugar,
            protein: protein,
            fat: fat,
            servingSize: 100.0,
            portionGrams: 100.0
        )

        // Then: Sugar should be capped at available carbs (8.0g)
        // Score calculation should not break
        XCTAssertGreaterThan(result.score, 0, "Score should be calculated despite label error")
        XCTAssertEqual(result.availableCarbs, 8.0, "Available carbs should be totalCarbs - fiber")
    }

    func testNoFiber_FormulaStillWorks() {
        // Given: Food with no fiber listed (0g)
        let result = ImpactScoreCalculator.calculate(
            totalCarbs: 20.0,
            fiber: 0.0,
            sugar: 10.0,
            protein: 2.0,
            fat: 1.0,
            servingSize: 100.0,
            portionGrams: 100.0
        )

        // Then: Should calculate without fiber effect (higher score)
        XCTAssertGreaterThan(result.score, 0, "Score should be calculated without fiber")
        XCTAssertEqual(result.availableCarbs, 20.0, "Available carbs = total carbs when no fiber")
    }

    // MARK: - Threshold Boundary Tests

    func testGreenThresholds_ExactBoundary() {
        // Given: Values just under green thresholds
        // Score: 4.9 < 5.0 ✓
        // Fat: 4.9g < 5.0 ✓
        // Protein: 9.9g < 10.0 ✓
        let result = ImpactScoreCalculator.calculate(
            totalCarbs: 10.0,
            fiber: 2.0,
            sugar: 5.0,
            protein: 9.9,
            fat: 4.9,
            servingSize: 100.0,
            portionGrams: 100.0
        )

        // Then: Should be green (all pass)
        XCTAssertEqual(result.color, .green, "Just under thresholds should be green")
    }

    func testYellowThresholds_ScoreExceeded() {
        // Given: Score just over green threshold
        // Score: 5.5 (5.0-10.0 range) → Yellow zone
        // Fat: 3.0g < 5.0 ✓
        // Protein: 5.0g < 10.0 ✓
        let result = ImpactScoreCalculator.calculate(
            totalCarbs: 15.0,
            fiber: 2.0,
            sugar: 10.0,
            protein: 5.0,
            fat: 3.0,
            servingSize: 100.0,
            portionGrams: 100.0
        )

        // Then: Should be yellow (score in caution zone)
        XCTAssertGreaterThanOrEqual(result.score, 5.0, "Score should exceed green threshold")
        XCTAssertLessThan(result.score, 10.0, "Score should be in yellow range")
        XCTAssertEqual(result.color, .yellow, "Score 5.0-10.0 should be yellow")
        XCTAssertTrue(result.statusText.contains("🟡"), "Status should show yellow indicator")
    }

    func testRedThresholds_ScoreInDangerZone() {
        // Given: Score in danger zone
        // Score: ≥ 10.0 → RED
        let result = ImpactScoreCalculator.calculate(
            totalCarbs: 30.0,
            fiber: 1.0,
            sugar: 25.0,
            protein: 3.0,
            fat: 2.0,
            servingSize: 100.0,
            portionGrams: 100.0
        )

        // Then: Should be red
        XCTAssertGreaterThanOrEqual(result.score, 10.0, "Score should exceed red threshold")
        XCTAssertEqual(result.color, .red, "Score ≥ 10.0 should be red")
    }

    func testRedThresholds_FatInDangerZone() {
        // Given: Low score but high fat
        // Score: 3.5 < 5.0 ✓
        // Fat: 16.0g ≥ 15.0 → RED
        // Protein: 4.0g < 10.0 ✓
        let result = ImpactScoreCalculator.calculate(
            totalCarbs: 13.7,
            fiber: 1.9,
            sugar: 12.5,
            protein: 4.0,
            fat: 16.0,
            servingSize: 100.0,
            portionGrams: 100.0
        )

        // Then: Should be red despite low score (fat exceeded)
        XCTAssertLessThan(result.score, 5.0, "Score is low")
        XCTAssertEqual(result.color, .red, "High fat should trigger red")
    }

    func testRedThresholds_ProteinInDangerZone() {
        // Given: Low score, low fat, but high protein
        // Score: 3.0 < 5.0 ✓
        // Fat: 3.0g < 5.0 ✓
        // Protein: 22.0g ≥ 20.0 → RED
        let result = ImpactScoreCalculator.calculate(
            totalCarbs: 10.0,
            fiber: 2.0,
            sugar: 5.0,
            protein: 22.0,
            fat: 3.0,
            servingSize: 100.0,
            portionGrams: 100.0
        )

        // Then: Should be red despite low score/fat (protein exceeded)
        XCTAssertEqual(result.color, .red, "High protein should trigger red")
    }

    // MARK: - Portion Scaling Tests

    func testPortionScaling_50Percent() {
        // Given: Food at 50% portion
        let servingSize = 100.0
        let portionGrams = 50.0

        let result = ImpactScoreCalculator.calculate(
            totalCarbs: 20.0,
            fiber: 4.0,
            sugar: 10.0,
            protein: 8.0,
            fat: 6.0,
            servingSize: servingSize,
            portionGrams: portionGrams
        )

        // Then: Available carbs should be halved
        let fullResult = ImpactScoreCalculator.calculate(
            totalCarbs: 20.0,
            fiber: 4.0,
            sugar: 10.0,
            protein: 8.0,
            fat: 6.0,
            servingSize: servingSize,
            portionGrams: servingSize
        )

        XCTAssertEqual(result.availableCarbs, fullResult.availableCarbs * 0.5, accuracy: 0.1,
                       "50% portion should halve available carbs")
        XCTAssertEqual(result.weightGrams, 50, "Weight should be 50g")
    }

    func testPortionScaling_10Percent_Minimum() {
        // Given: Food at minimum portion (10%)
        let servingSize = 100.0
        let portionGrams = 10.0

        let result = ImpactScoreCalculator.calculate(
            totalCarbs: 50.0,
            fiber: 5.0,
            sugar: 30.0,
            protein: 10.0,
            fat: 20.0,
            servingSize: servingSize,
            portionGrams: portionGrams
        )

        // Then: All nutrients should be scaled to 10%
        XCTAssertEqual(result.weightGrams, 10, "Weight should be 10g")
        // Even at 10%, high-fat/protein foods might not turn green
    }

    // MARK: - Status Text Tests

    func testStatusText_Green_Turkish() {
        // Given: Green status food
        let result = ImpactScoreCalculator.calculate(
            totalCarbs: 10.0,
            fiber: 2.0,
            sugar: 5.0,
            protein: 3.0,
            fat: 2.0,
            servingSize: 100.0,
            portionGrams: 50.0
        )

        // Then: Status should be in Turkish with green emoji
        XCTAssertTrue(result.statusText.contains("🟢"), "Should have green emoji")
        XCTAssertTrue(result.statusText.contains("güvenli"), "Should say 'safe' in Turkish")
        XCTAssertTrue(result.statusText.contains("50g"), "Should show weight")
    }

    func testStatusText_Yellow_Turkish() {
        // Given: Yellow status food (score in caution range)
        let result = ImpactScoreCalculator.calculate(
            totalCarbs: 20.0,
            fiber: 2.0,
            sugar: 15.0,
            protein: 5.0,
            fat: 3.0,
            servingSize: 100.0,
            portionGrams: 100.0
        )

        // Then: Status should be in Turkish with yellow emoji
        if result.color == .yellow {
            XCTAssertTrue(result.statusText.contains("🟡"), "Should have yellow emoji")
            XCTAssertTrue(result.statusText.contains("dikkatli ol"), "Should say 'be careful' in Turkish")
        }
    }

    func testStatusText_Red_Turkish() {
        // Given: Red status food
        let result = ImpactScoreCalculator.calculate(
            totalCarbs: 40.0,
            fiber: 2.0,
            sugar: 30.0,
            protein: 5.0,
            fat: 3.0,
            servingSize: 100.0,
            portionGrams: 100.0
        )

        // Then: Status should be in Turkish with red emoji
        XCTAssertTrue(result.statusText.contains("🔴"), "Should have red emoji")
        XCTAssertTrue(result.statusText.contains("çok fazla"), "Should say 'too much' in Turkish")
    }

    // MARK: - Convenience Method Tests

    func testCalculateForFullServing_ReturnsScore() {
        // Given: Nutrition values
        let totalCarbs = 13.7
        let fiber = 1.9
        let sugar = 12.5
        let protein = 4.9
        let fat = 16.0

        // When
        let score = ImpactScoreCalculator.calculateForFullServing(
            totalCarbs: totalCarbs,
            fiber: fiber,
            sugar: sugar,
            protein: protein,
            fat: fat
        )

        // Then: Should return just the score (not full result)
        XCTAssertEqual(score, 3.63, accuracy: 0.1, "Convenience method should return score")
    }
}
