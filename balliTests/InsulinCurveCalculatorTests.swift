//
//  InsulinCurveCalculatorTests.swift
//  balliTests
//
//  Unit tests for insulin-glucose curve calculations
//  Validates formulas from dual-curve.md specification
//

import XCTest
@testable import balli

final class InsulinCurveCalculatorTests: XCTestCase {

    var calculator: InsulinCurveCalculator!

    override func setUp() async throws {
        calculator = InsulinCurveCalculator.shared
    }

    // MARK: - Glucose Peak Time Tests

    func testGlucosePeakTime_LowFatHighSugar_FastPeak() async throws {
        // Arrange: Fruit - fast absorption
        let nutrition = InsulinCurveCalculator.RecipeNutrition(
            carbohydrates: 25,
            fat: 0,
            protein: 1,
            sugar: 20,  // 80% sugar ratio
            fiber: 2,
            glycemicLoad: 15
        )

        // Act
        let peakTime = calculator.calculateGlucosePeakTime(nutrition: nutrition)

        // Assert: Should peak around 60 minutes (base 60 + no delays)
        XCTAssertEqual(peakTime, 60, accuracy: 10, "Low fat, high sugar should peak ~60 minutes")
    }

    func testGlucosePeakTime_HighFatLowSugar_DelayedPeak() async throws {
        // Arrange: High-fat meal - delayed absorption
        let nutrition = InsulinCurveCalculator.RecipeNutrition(
            carbohydrates: 50,
            fat: 35,  // High fat = 120 min delay
            protein: 25,  // High protein = 30 min delay
            sugar: 10,  // 20% sugar ratio
            fiber: 3,
            glycemicLoad: 20
        )

        // Act
        let peakTime = calculator.calculateGlucosePeakTime(nutrition: nutrition)

        // Assert: Base 120 + fat 90 + protein 30 + fiber 0 = 240 (capped at 300)
        XCTAssertEqual(peakTime, 240, accuracy: 20, "High fat should delay peak to ~240 minutes")
    }

    func testGlucosePeakTime_BalancedMeal_MediumPeak() async throws {
        // Arrange: Balanced meal
        let nutrition = InsulinCurveCalculator.RecipeNutrition(
            carbohydrates: 40,
            fat: 12,  // Moderate fat = 30 min delay
            protein: 20,  // Moderate protein = 15 min delay
            sugar: 18,  // 45% sugar ratio
            fiber: 5,  // Moderate fiber = 10 min delay
            glycemicLoad: 15
        )

        // Act
        let peakTime = calculator.calculateGlucosePeakTime(nutrition: nutrition)

        // Assert: Base 90 + fat 30 + protein 15 + fiber 10 = 145
        XCTAssertEqual(peakTime, 145, accuracy: 15, "Balanced meal should peak ~105-145 minutes")
    }

    // MARK: - Warning Level Tests

    func testWarningLevel_HighFat_AlwaysDanger() async throws {
        // Arrange: Very high fat (>30g)
        let nutrition = InsulinCurveCalculator.RecipeNutrition(
            carbohydrates: 50,
            fat: 35,
            protein: 20,
            sugar: 10,
            fiber: 3,
            glycemicLoad: 15
        )

        // Act
        let warning = calculator.determineWarning(nutrition: nutrition)

        // Assert
        XCTAssertEqual(warning.level, .danger, "High fat (>30g) should always trigger danger warning")
    }

    func testWarningLevel_LowFatSmallMismatch_NoWarning() async throws {
        // Arrange: Low fat, good alignment
        let nutrition = InsulinCurveCalculator.RecipeNutrition(
            carbohydrates: 30,
            fat: 5,
            protein: 10,
            sugar: 20,  // High sugar = fast peak (~60 min)
            fiber: 2,
            glycemicLoad: 12
        )

        // Act
        let warning = calculator.determineWarning(nutrition: nutrition)

        // Assert: Peak ~60min, mismatch ~15min (75-60) = no warning
        XCTAssertEqual(warning.level, .none, "Low fat with small mismatch should show no warning")
    }

    func testWarningLevel_ModerateFatModerateGL_Warning() async throws {
        // Arrange: Moderate fat + moderate mismatch + high GL
        let nutrition = InsulinCurveCalculator.RecipeNutrition(
            carbohydrates: 45,
            fat: 22,  // Moderate-high fat
            protein: 18,
            sugar: 15,  // 33% sugar
            fiber: 4,
            glycemicLoad: 18  // High GL
        )

        // Act
        let warning = calculator.determineWarning(nutrition: nutrition)

        // Assert: Should trigger warning (moderate mismatch + high GL)
        XCTAssertTrue(warning.level == .warning || warning.level == .danger,
                     "Moderate fat with high GL should trigger warning or danger")
    }

    // MARK: - Real-World Validation Tests

    func testRealWorld_ChocolateBar() async throws {
        // Arrange: Chocolate bar (known food from spec)
        let nutrition = InsulinCurveCalculator.RecipeNutrition(
            carbohydrates: 30,
            fat: 12,
            protein: 5,
            sugar: 25,  // High sugar
            fiber: 1,
            glycemicLoad: 20
        )

        // Act
        let peakTime = calculator.calculateGlucosePeakTime(nutrition: nutrition)

        // Assert: Expected ~90 min peak
        XCTAssertEqual(peakTime, 90, accuracy: 20, "Chocolate bar should peak around 90 minutes")
    }

    func testRealWorld_PizzaSlice() async throws {
        // Arrange: Pizza slice (known food from spec)
        let nutrition = InsulinCurveCalculator.RecipeNutrition(
            carbohydrates: 40,
            fat: 18,
            protein: 12,
            sugar: 5,  // Low sugar ratio
            fiber: 2,
            glycemicLoad: 22
        )

        // Act
        let peakTime = calculator.calculateGlucosePeakTime(nutrition: nutrition)

        // Assert: Expected ~150 min peak
        XCTAssertEqual(peakTime, 150, accuracy: 30, "Pizza should peak around 150 minutes")
    }

    func testRealWorld_Fruit() async throws {
        // Arrange: Fruit (known food from spec)
        let nutrition = InsulinCurveCalculator.RecipeNutrition(
            carbohydrates: 25,
            fat: 0,
            protein: 1,
            sugar: 20,  // Very high sugar
            fiber: 3,
            glycemicLoad: 12
        )

        // Act
        let peakTime = calculator.calculateGlucosePeakTime(nutrition: nutrition)

        // Assert: Expected ~60 min peak (fast absorption)
        XCTAssertEqual(peakTime, 60, accuracy: 15, "Fruit should peak around 60 minutes")
    }

    func testRealWorld_Nuts() async throws {
        // Arrange: Nuts (known food from spec)
        let nutrition = InsulinCurveCalculator.RecipeNutrition(
            carbohydrates: 10,
            fat: 45,  // Very high fat
            protein: 15,
            sugar: 2,
            fiber: 5,
            glycemicLoad: 3
        )

        // Act
        let peakTime = calculator.calculateGlucosePeakTime(nutrition: nutrition)

        // Assert: Expected ~240 min peak (very delayed)
        XCTAssertEqual(peakTime, 240, accuracy: 30, "Nuts should peak around 240 minutes")
    }

    // MARK: - Edge Case Tests

    func testEdgeCase_VeryLowCarb() async throws {
        // Arrange: Very low carb (<5g)
        let carbsGrams = 3.0

        // Act
        let isVeryLowCarb = calculator.isVeryLowCarb(carbsGrams: carbsGrams)

        // Assert
        XCTAssertTrue(isVeryLowCarb, "Should detect very low carb (<5g)")
    }

    func testEdgeCase_ExtremeMismatch() async throws {
        // Arrange: >4 hours mismatch
        let mismatchMinutes = 250

        // Act
        let isExtreme = calculator.isExtremeMismatch(mismatchMinutes: mismatchMinutes)

        // Assert
        XCTAssertTrue(isExtreme, "Should detect extreme mismatch (>240 min)")
    }

    func testEdgeCase_HighProteinLowCarb() async throws {
        // Arrange: High protein + low carb
        let proteinGrams = 35.0
        let carbsGrams = 15.0

        // Act
        let isHighProteinLowCarb = calculator.isHighProteinLowCarb(
            proteinGrams: proteinGrams,
            carbsGrams: carbsGrams
        )

        // Assert
        XCTAssertTrue(isHighProteinLowCarb, "Should detect high protein + low carb combination")
    }

    // MARK: - Glucose Curve Generation Tests

    func testGenerateGlucoseCurve_ReturnsValidPoints() async throws {
        // Arrange
        let nutrition = InsulinCurveCalculator.RecipeNutrition(
            carbohydrates: 40,
            fat: 15,
            protein: 20,
            sugar: 18,
            fiber: 5,
            glycemicLoad: 16
        )

        // Act
        let curve = calculator.generateGlucoseCurve(nutrition: nutrition)

        // Assert
        XCTAssertGreaterThan(curve.count, 5, "Curve should have multiple points")
        XCTAssertEqual(curve.first?.timeMinutes, 0, "Curve should start at 0 minutes")
        XCTAssertEqual(curve.first?.intensity, 0.0, "Curve should start at 0 intensity")
        XCTAssertEqual(curve.last?.intensity, 0.0, "Curve should end at 0 intensity")

        // Find peak
        let maxIntensity = curve.max(by: { $0.intensity < $1.intensity })?.intensity ?? 0
        XCTAssertGreaterThan(maxIntensity, 0, "Curve should have a peak")
        XCTAssertLessThanOrEqual(maxIntensity, 1.0, "Peak should not exceed 1.0")
    }

    // MARK: - Duration Calculation Tests

    func testGlucoseDuration_HighFat_Extended() async throws {
        // Arrange: High fat extends duration
        let nutrition = InsulinCurveCalculator.RecipeNutrition(
            carbohydrates: 50,
            fat: 35,  // High fat = +180 min extension
            protein: 20,
            sugar: 15,
            fiber: 3,
            glycemicLoad: 20
        )

        let peakTime = calculator.calculateGlucosePeakTime(nutrition: nutrition)

        // Act
        let duration = calculator.calculateGlucoseDuration(nutrition: nutrition, peakTime: peakTime)

        // Assert: Should be significantly extended (300 base + 180 fat = 480)
        XCTAssertGreaterThan(duration, 400, "High fat should extend duration beyond 400 minutes")
    }

    func testGlucoseDuration_LowFatLowGL_Shorter() async throws {
        // Arrange: Low fat, low GL = shorter duration
        let nutrition = InsulinCurveCalculator.RecipeNutrition(
            carbohydrates: 25,
            fat: 5,
            protein: 10,
            sugar: 18,
            fiber: 2,
            glycemicLoad: 8  // Low GL
        )

        let peakTime = calculator.calculateGlucosePeakTime(nutrition: nutrition)

        // Act
        let duration = calculator.calculateGlucoseDuration(nutrition: nutrition, peakTime: peakTime)

        // Assert: Should be shorter (180 base + 0 fat = 180)
        XCTAssertLessThan(duration, 250, "Low fat and low GL should result in shorter duration")
    }
}
