//
//  NutritionalValuesView+Previews.swift
//  balli
//
//  Preview configurations for NutritionalValuesView
//  Extracted from NutritionalValuesView.swift
//  Swift 6 strict concurrency compliant
//

import SwiftUI
import CoreData

// MARK: - Preview: Low Warning

#Preview("With Both Values - Low Warning") {
    @Previewable @State var multiplier = 1.0

    let context = PersistenceController.previewFast.container.viewContext
    let recipe = Recipe(context: context)
    recipe.id = UUID()
    recipe.name = "Izgara Tavuk Salatası"
    recipe.totalRecipeWeight = 350
    recipe.caloriesPerServing = 578
    recipe.carbsPerServing = 28
    recipe.fiberPerServing = 10.5
    recipe.sugarsPerServing = 7
    recipe.proteinPerServing = 108.5
    recipe.fatPerServing = 12.6
    recipe.glycemicLoadPerServing = 14
    recipe.portionSize = 350

    return NutritionalValuesView(
        recipe: ObservableRecipeWrapper(recipe: recipe),
        recipeName: "Izgara Tavuk Salatası",
        // Per-100g
        calories: "165",
        carbohydrates: "8",
        fiber: "3",
        sugar: "2",
        protein: "31",
        fat: "3.6",
        glycemicLoad: "4",
        // Per-serving (assuming 350g total)
        caloriesPerServing: "578",
        carbohydratesPerServing: "28",
        fiberPerServing: "10.5",
        sugarPerServing: "7",
        proteinPerServing: "108.5",
        fatPerServing: "12.6",
        glycemicLoadPerServing: "14",
        totalRecipeWeight: "350",
        digestionTiming: nil,
        portionMultiplier: $multiplier
    )
    .environment(\.managedObjectContext, context)
}

// MARK: - Preview: Danger Warning

#Preview("High Fat Recipe - Danger Warning") {
    @Previewable @State var multiplier = 1.0

    let context = PersistenceController.previewFast.container.viewContext
    let recipe = Recipe(context: context)
    recipe.id = UUID()
    recipe.name = "Carbonara Makarna"
    recipe.totalRecipeWeight = 400
    recipe.caloriesPerServing = 720
    recipe.carbsPerServing = 48
    recipe.fiberPerServing = 8
    recipe.sugarsPerServing = 4
    recipe.proteinPerServing = 32
    recipe.fatPerServing = 35
    recipe.glycemicLoadPerServing = 20
    recipe.portionSize = 400

    return NutritionalValuesView(
        recipe: ObservableRecipeWrapper(recipe: recipe),
        recipeName: "Carbonara Makarna",
        // Per-100g
        calories: "180",
        carbohydrates: "12",
        fiber: "2",
        sugar: "1",
        protein: "8",
        fat: "12",
        glycemicLoad: "8",
        // Per-serving (high fat = danger warning)
        caloriesPerServing: "720",
        carbohydratesPerServing: "48",
        fiberPerServing: "8",
        sugarPerServing: "4",
        proteinPerServing: "32",
        fatPerServing: "35",  // High fat triggers danger warning
        glycemicLoadPerServing: "20",
        totalRecipeWeight: "400",
        digestionTiming: nil,
        portionMultiplier: $multiplier
    )
    .environment(\.managedObjectContext, context)
}

// MARK: - Preview: Empty Values

#Preview("Empty Values") {
    @Previewable @State var multiplier = 1.0

    let context = PersistenceController.previewFast.container.viewContext
    let recipe = Recipe(context: context)
    recipe.id = UUID()
    recipe.name = "Test Tarifi"
    recipe.totalRecipeWeight = 500
    recipe.portionSize = 0

    return NutritionalValuesView(
        recipe: ObservableRecipeWrapper(recipe: recipe),
        recipeName: "Test Tarifi",
        calories: "",
        carbohydrates: "",
        fiber: "",
        sugar: "",
        protein: "",
        fat: "",
        glycemicLoad: "",
        caloriesPerServing: "",
        carbohydratesPerServing: "",
        fiberPerServing: "",
        sugarPerServing: "",
        proteinPerServing: "",
        fatPerServing: "",
        glycemicLoadPerServing: "",
        totalRecipeWeight: "",
        digestionTiming: nil,
        portionMultiplier: $multiplier
    )
    .environment(\.managedObjectContext, context)
}
