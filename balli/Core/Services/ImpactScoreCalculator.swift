//
//  ImpactScoreCalculator.swift
//  balli
//
//  Created by Claude Code on 2025-10-27.
//

import Foundation
import SwiftUI

/// Result of impact score calculation using Nestlé glycemic load formula
struct ImpactScoreResult: Sendable {
    let score: Double           // Glycemic load impact score
    let color: Color            // Safety color (green/yellow/red)
    let statusText: String      // Turkish status message with weight
    let weightGrams: Int        // Current portion weight

    /// Debug information (not shown to users by default)
    let effectiveGI: Double     // Calculated effective glycemic index
    let availableCarbs: Double  // Net carbs after fiber
}

/// Calculator implementing Nestlé Research validated glycemic load formula
/// Source: Nestlé Research (2019) - "Predicting Glycemic Index and Glycemic Load from Macronutrients"
/// Validation: r=0.90 correlation with in-vivo GI testing across 60 products
enum ImpactScoreCalculator {

    // MARK: - Main Calculation Entry Point

    /// Calculate impact score for a given portion of food
    /// - Parameters:
    ///   - totalCarbs: Total carbohydrates (grams)
    ///   - fiber: Dietary fiber (grams)
    ///   - sugar: Sugars (grams)
    ///   - protein: Protein (grams)
    ///   - fat: Fat (grams)
    ///   - servingSize: Base serving size (grams)
    ///   - portionGrams: Current portion weight (grams)
    /// - Returns: Complete impact score result with color and status
    static func calculate(
        totalCarbs: Double,
        fiber: Double,
        sugar: Double,
        protein: Double,
        fat: Double,
        servingSize: Double,
        portionGrams: Double
    ) -> ImpactScoreResult {

        // Calculate adjustment ratio for this portion
        let adjustmentRatio = portionGrams / servingSize

        // Scale all nutrients proportionally
        let scaledCarbs = totalCarbs * adjustmentRatio
        let scaledFiber = fiber * adjustmentRatio
        let scaledSugar = sugar * adjustmentRatio
        let scaledProtein = protein * adjustmentRatio
        let scaledFat = fat * adjustmentRatio

        // Calculate impact score using Nestlé formula
        let (score, effectiveGI, availableCarbs) = calculateNestleScore(
            totalCarbs: scaledCarbs,
            fiber: scaledFiber,
            sugar: scaledSugar,
            protein: scaledProtein,
            fat: scaledFat
        )

        // Determine safety color based on three thresholds
        let color = determineColor(
            score: score,
            fat: scaledFat,
            protein: scaledProtein
        )

        // Generate Turkish status text
        let weightGrams = Int(round(portionGrams))
        let statusText = generateStatusText(
            color: color,
            weightGrams: weightGrams
        )

        return ImpactScoreResult(
            score: score,
            color: color,
            statusText: statusText,
            weightGrams: weightGrams,
            effectiveGI: effectiveGI,
            availableCarbs: availableCarbs
        )
    }

    // MARK: - Nestlé Formula Implementation

    /// Calculate glycemic load using Nestlé Research validated formula
    /// - Returns: Tuple of (impactScore, effectiveGI, availableCarbs)
    private static func calculateNestleScore(
        totalCarbs: Double,
        fiber: Double,
        sugar: Double,
        protein: Double,
        fat: Double
    ) -> (score: Double, effectiveGI: Double, availableCarbs: Double) {

        // Step 1: Calculate available carbohydrates (net carbs)
        let availableCarbs = totalCarbs - fiber

        // Edge case: Zero or negative carbs = no glycemic impact
        guard availableCarbs > 0 else {
            return (score: 0.0, effectiveGI: 0.0, availableCarbs: 0.0)
        }

        // Step 2: Split into sugar vs starch
        // Cap sugar at available carbs to handle nutrition label errors
        let sugarCarbs = min(sugar, availableCarbs)
        let starchCarbs = availableCarbs - sugarCarbs

        // Step 3: Calculate glycemic impact (weighted by typical GI values)
        // 0.65 coefficient for sugar: Average GI of sucrose ≈ 65
        // 0.75 coefficient for starch: Average GI of rapidly digestible starch ≈ 75
        let glycemicImpact = (sugarCarbs * 0.65) + (starchCarbs * 0.75)

        // Step 4: Calculate GI-lowering effects (Nestlé empirical coefficients)
        // 0.3 for fiber: Creates viscosity, slows absorption
        // 0.6 for protein: Slows gastric emptying via GLP-1 hormone
        // 0.6 for fat: Slows gastric emptying via CCK hormone
        let fiberEffect = fiber * 0.3
        let proteinEffect = protein * 0.6
        let fatEffect = fat * 0.6

        // Step 5: Calculate effective GI
        let denominator = availableCarbs + fiberEffect + proteinEffect + fatEffect

        // Safety check: Avoid division by zero
        guard denominator > 0 else {
            return (score: 0.0, effectiveGI: 0.0, availableCarbs: availableCarbs)
        }

        let effectiveGI = (glycemicImpact * 100) / denominator

        // Step 6: Calculate final impact score (Glycemic Load)
        // GL = (GI × available carbs) / 100
        let impactScore = (effectiveGI * availableCarbs) / 100

        return (score: impactScore, effectiveGI: effectiveGI, availableCarbs: availableCarbs)
    }

    // MARK: - Three-Threshold Safety Evaluation

    /// Determine safety color based on three independent thresholds
    /// ALL THREE must pass for GREEN status
    /// - Parameters:
    ///   - score: Glycemic load impact score
    ///   - fat: Fat content (grams)
    ///   - protein: Protein content (grams)
    /// - Returns: Safety color (green/yellow/red)
    private static func determineColor(
        score: Double,
        fat: Double,
        protein: Double
    ) -> Color {

        // Define threshold checks
        let scoreGreen = score < 5.0        // Very low glycemic load
        let fatGreen = fat < 5.0            // Minimal gastric delay (< 30 min)
        let proteinGreen = protein < 10.0   // Minimal gluconeogenesis

        // GREEN: All three thresholds pass (safest)
        if scoreGreen && fatGreen && proteinGreen {
            return .green
        }

        // RED: Any single threshold in danger zone
        // - Score ≥ 10.0: High glycemic load
        // - Fat ≥ 15.0g: Major gastric delay (90-120+ min)
        // - Protein ≥ 20.0g: Significant late rise (4-5 hours)
        if score >= 10.0 || fat >= 15.0 || protein >= 20.0 {
            return .red
        }

        // YELLOW: In between (caution zone)
        // - Score 5.0-10.0: Moderate glycemic load
        // - Fat 5.0-15.0g: Moderate delay (30-90 min)
        // - Protein 10.0-20.0g: Moderate late rise (3-4 hours)
        return .yellow
    }

    // MARK: - Status Text Generation

    /// Generate Turkish status message with emoji indicator
    /// - Parameters:
    ///   - color: Safety color
    ///   - weightGrams: Current portion weight
    /// - Returns: Formatted status text in Turkish
    private static func generateStatusText(
        color: Color,
        weightGrams: Int
    ) -> String {
        switch color {
        case .green:
            return "🟢 \(weightGrams)g güvenli"
        case .yellow:
            return "🟡 \(weightGrams)g dikkatli ol"
        case .red:
            return "🔴 \(weightGrams)g çok fazla"
        default:
            return "\(weightGrams)g"
        }
    }
}

// MARK: - Convenience Methods for Existing FoodItem Model

extension ImpactScoreCalculator {

    /// Calculate impact score for full serving size (100% portion)
    static func calculateForFullServing(
        totalCarbs: Double,
        fiber: Double,
        sugar: Double,
        protein: Double,
        fat: Double
    ) -> Double {
        let (score, _, _) = calculateNestleScore(
            totalCarbs: totalCarbs,
            fiber: fiber,
            sugar: sugar,
            protein: protein,
            fat: fat
        )
        return score
    }
}
