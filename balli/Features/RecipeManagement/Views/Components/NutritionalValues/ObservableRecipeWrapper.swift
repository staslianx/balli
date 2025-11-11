//
//  ObservableRecipeWrapper.swift
//  balli
//
//  SwiftUI-friendly wrapper for CoreData Recipe entity
//  Extracted from NutritionalValuesView.swift
//  Swift 6 strict concurrency compliant
//

import SwiftUI
import CoreData

/// Observable wrapper providing SwiftUI-friendly access to CoreData Recipe
@MainActor
final class ObservableRecipeWrapper: ObservableObject {
    let recipe: Recipe?

    init(recipe: Recipe?) {
        self.recipe = recipe
    }

    /// Convenience accessor for portion size
    var portionSize: Double {
        recipe?.portionSize ?? 0
    }

    /// Convenience accessor for total recipe weight
    var totalRecipeWeight: Double {
        recipe?.totalRecipeWeight ?? 0
    }

    /// Convenience accessor for portion multiplier
    var portionMultiplier: Double {
        get { recipe?.portionMultiplier ?? 1.0 }
        set {
            recipe?.portionMultiplier = newValue
            objectWillChange.send()
        }
    }

    /// Update portion size
    func updatePortionSize(_ size: Double) {
        recipe?.updatePortionSize(size)
        objectWillChange.send()
    }

    /// Calculate nutrition for portion
    func calculatePortionNutrition(for portionWeight: Double) -> NutritionValues {
        guard let recipe = recipe else {
            return NutritionValues(
                calories: 0, carbohydrates: 0, fiber: 0,
                sugar: 0, protein: 0, fat: 0, glycemicLoad: 0
            )
        }
        return recipe.calculatePortionNutrition(for: portionWeight)
    }

    /// Whether recipe exists
    var exists: Bool {
        recipe != nil
    }
}
