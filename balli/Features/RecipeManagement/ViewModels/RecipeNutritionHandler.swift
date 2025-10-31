//
//  RecipeNutritionHandler.swift
//  balli
//
//  Handles nutrition calculation and caching for recipes
//  Swift 6 strict concurrency compliant
//

import SwiftUI
import Foundation
import OSLog

@MainActor
public class RecipeNutritionHandler: ObservableObject {
    // MARK: - Dependencies
    private let formState: RecipeFormState
    private let nutritionRepository = RecipeNutritionRepository()
    private let logger = AppLoggers.Recipe.generation

    // MARK: - Published State
    @Published public var isCalculatingNutrition = false
    @Published public var nutritionCalculationError: String?
    @Published public var nutritionCalculationProgress = 0  // Progress percentage (0-100)

    // MARK: - Nutrition Cache (Performance Optimization)
    private var nutritionCache: NutritionCache = NutritionCache()

    private struct NutritionCache {
        var lastPortionGrams: Double = 100.0
        var lastCalories: String = ""
        var lastCarbs: String = ""
        var lastFiber: String = ""
        var lastSugar: String = ""
        var lastProtein: String = ""
        var lastFat: String = ""
        var lastGlycemicLoad: String = ""

        var cachedAdjustedCalories: String = ""
        var cachedAdjustedCarbs: String = ""
        var cachedAdjustedFiber: String = ""
        var cachedAdjustedSugar: String = ""
        var cachedAdjustedProtein: String = ""
        var cachedAdjustedFat: String = ""
        var cachedAdjustedGlycemicLoad: String = ""

        mutating func shouldInvalidate(
            portionGrams: Double,
            calories: String,
            carbs: String,
            fiber: String,
            sugar: String,
            protein: String,
            fat: String,
            glycemicLoad: String
        ) -> Bool {
            portionGrams != lastPortionGrams ||
            calories != lastCalories ||
            carbs != lastCarbs ||
            fiber != lastFiber ||
            sugar != lastSugar ||
            protein != lastProtein ||
            fat != lastFat ||
            glycemicLoad != lastGlycemicLoad
        }
    }

    // MARK: - Initialization
    public init(formState: RecipeFormState) {
        self.formState = formState
    }

    // MARK: - Adjusted Nutrition Values (Performance Optimized with Caching)

    /// Adjustment ratio based on current portion grams vs 100g base
    public var adjustmentRatio: Double {
        // Nutrition values are per 100g, so ratio is portionGrams / 100
        return formState.portionGrams / 100.0
    }

    /// Adjusted calorie value based on serving size
    public var adjustedCalories: String {
        updateCacheIfNeeded()
        return nutritionCache.cachedAdjustedCalories
    }

    /// Adjusted carbohydrates value based on serving size
    public var adjustedCarbohydrates: String {
        updateCacheIfNeeded()
        return nutritionCache.cachedAdjustedCarbs
    }

    /// Adjusted fiber value based on serving size
    public var adjustedFiber: String {
        updateCacheIfNeeded()
        return nutritionCache.cachedAdjustedFiber
    }

    /// Adjusted sugar value based on serving size
    public var adjustedSugar: String {
        updateCacheIfNeeded()
        return nutritionCache.cachedAdjustedSugar
    }

    /// Adjusted protein value based on serving size
    public var adjustedProtein: String {
        updateCacheIfNeeded()
        return nutritionCache.cachedAdjustedProtein
    }

    /// Adjusted fat value based on serving size
    public var adjustedFat: String {
        updateCacheIfNeeded()
        return nutritionCache.cachedAdjustedFat
    }

    /// Adjusted glycemic load value based on serving size
    public var adjustedGlycemicLoad: String {
        updateCacheIfNeeded()
        return nutritionCache.cachedAdjustedGlycemicLoad
    }

    // MARK: - Private Cache Management

    /// Update nutrition cache if any values changed
    private func updateCacheIfNeeded() {
        if nutritionCache.shouldInvalidate(
            portionGrams: formState.portionGrams,
            calories: formState.calories,
            carbs: formState.carbohydrates,
            fiber: formState.fiber,
            sugar: formState.sugar,
            protein: formState.protein,
            fat: formState.fat,
            glycemicLoad: formState.glycemicLoad
        ) {
            // Recalculate all values
            let ratio = adjustmentRatio

            nutritionCache.cachedAdjustedCalories = calculateAdjusted(formState.calories, ratio: ratio, isCalories: true)
            nutritionCache.cachedAdjustedCarbs = calculateAdjusted(formState.carbohydrates, ratio: ratio)
            nutritionCache.cachedAdjustedFiber = calculateAdjusted(formState.fiber, ratio: ratio)
            nutritionCache.cachedAdjustedSugar = calculateAdjusted(formState.sugar, ratio: ratio)
            nutritionCache.cachedAdjustedProtein = calculateAdjusted(formState.protein, ratio: ratio)
            nutritionCache.cachedAdjustedFat = calculateAdjusted(formState.fat, ratio: ratio)
            nutritionCache.cachedAdjustedGlycemicLoad = calculateAdjusted(formState.glycemicLoad, ratio: ratio)

            // Update cache state
            nutritionCache.lastPortionGrams = formState.portionGrams
            nutritionCache.lastCalories = formState.calories
            nutritionCache.lastCarbs = formState.carbohydrates
            nutritionCache.lastFiber = formState.fiber
            nutritionCache.lastSugar = formState.sugar
            nutritionCache.lastProtein = formState.protein
            nutritionCache.lastFat = formState.fat
            nutritionCache.lastGlycemicLoad = formState.glycemicLoad
        }
    }

    /// Calculate adjusted value with caching
    private func calculateAdjusted(_ baseString: String, ratio: Double, isCalories: Bool = false) -> String {
        guard let baseValue = Double(baseString) else { return baseString }
        let adjusted = baseValue * ratio

        if isCalories {
            return String(format: "%.0f", adjusted)
        }
        return formatNutritionValue(adjusted)
    }

    /// Format nutrition value with appropriate precision
    private func formatNutritionValue(_ value: Double) -> String {
        if value < 10 {
            return String(format: "%.1f", value)
        } else {
            return String(format: "%.0f", value)
        }
    }

    // MARK: - Nutrition Calculation

    /// Calculate nutrition values on-demand using Gemini 2.5 Pro
    /// Called when user taps the nutrition values button
    public func calculateNutrition() {
        logger.info("🍽️ [NUTRITION] Starting on-demand nutrition calculation")

        // Validate we have recipe data
        guard !formState.recipeName.isEmpty else {
            logger.error("❌ [NUTRITION] Cannot calculate - no recipe name")
            nutritionCalculationError = "Recipe name is required"
            return
        }

        guard !formState.recipeContent.isEmpty else {
            logger.error("❌ [NUTRITION] Cannot calculate - no recipe content")
            nutritionCalculationError = "Recipe content is required"
            return
        }

        // Reset error state
        nutritionCalculationError = nil
        isCalculatingNutrition = true
        nutritionCalculationProgress = 1  // Start at 1%

        // Start progress animation
        startNutritionProgressAnimation()

        Task {
            do {
                logger.info("🍽️ [NUTRITION] Calling Cloud Function...")
                let nutritionData = try await nutritionRepository.calculateNutrition(
                    recipeName: formState.recipeName,
                    recipeContent: formState.recipeContent,
                    servings: 1  // Always 1 = entire recipe as one portion
                )

                // Update form state with calculated values
                await MainActor.run {
                    // Per-100g values
                    let formattedValues = nutritionData.toFormState()
                    formState.calories = formattedValues.calories
                    formState.carbohydrates = formattedValues.carbohydrates
                    formState.fiber = formattedValues.fiber
                    formState.sugar = formattedValues.sugar
                    formState.protein = formattedValues.protein
                    formState.fat = formattedValues.fat
                    formState.glycemicLoad = formattedValues.glycemicLoad

                    // Per-serving values (entire recipe = 1 serving)
                    let servingValues = nutritionData.toFormStatePerServing()
                    formState.caloriesPerServing = servingValues.calories
                    formState.carbohydratesPerServing = servingValues.carbohydrates
                    formState.fiberPerServing = servingValues.fiber
                    formState.sugarPerServing = servingValues.sugar
                    formState.proteinPerServing = servingValues.protein
                    formState.fatPerServing = servingValues.fat
                    formState.glycemicLoadPerServing = servingValues.glycemicLoad
                    formState.totalRecipeWeight = servingValues.totalRecipeWeight

                    // Store digestion timing insights
                    formState.digestionTiming = nutritionData.digestionTiming

                    isCalculatingNutrition = false
                    nutritionCalculationProgress = 100  // Set to 100% on completion

                    logger.info("✅ [NUTRITION] Calculation complete and form state updated")
                    logger.info("   Per-100g: \(formattedValues.calories) kcal, \(formattedValues.carbohydrates)g carbs")
                    logger.info("   Per-serving: \(servingValues.calories) kcal, \(servingValues.carbohydrates)g carbs, \(servingValues.totalRecipeWeight)g total")
                    if let insights = nutritionData.digestionTiming {
                        logger.info("   Digestion timing: \(insights.hasMismatch ? "mismatch detected" : "no mismatch"), peak at \(insights.glucosePeakTime)h")
                    }
                }

            } catch {
                await MainActor.run {
                    isCalculatingNutrition = false
                    nutritionCalculationProgress = 0  // Reset on error
                    nutritionCalculationError = error.localizedDescription
                    logger.error("❌ [NUTRITION] Calculation failed: \(error.localizedDescription)")
                }
            }
        }
    }

    /// Animate nutrition calculation progress from 1% to 100% over time
    private func startNutritionProgressAnimation() {
        Task { @MainActor in
            // Increment progress smoothly over ~66 seconds (typical API call duration: 60-70s)
            for i in 1...100 {
                guard isCalculatingNutrition else { break }  // Stop if calculation completes early

                nutritionCalculationProgress = i

                // Variable speed: faster at start (excitement), slower near end (anticipation)
                let delay: TimeInterval = if i < 30 {
                    0.4  // Fast (30% in 12s)
                } else if i < 70 {
                    0.6  // Medium (40% in 24s)
                } else {
                    1.0  // Slow (30% in 30s)
                }

                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
    }
}
