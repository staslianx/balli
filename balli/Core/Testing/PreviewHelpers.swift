//
//  PreviewHelpers.swift
//  balli
//
//  Lightweight preview infrastructure for fast SwiftUI preview loading
//

import SwiftUI
import CoreData

// MARK: - Preview Mode Detection

extension ProcessInfo {
    /// Returns true if running in Xcode preview mode
    var isPreviewMode: Bool {
        environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
}

// MARK: - Lightweight Persistence Controller

extension PersistenceController {
    /// Lightweight preview persistence controller (loads once, reused across all previews)
    /// This eliminates 2-3 seconds of Core Data initialization per preview update
    static let previewFast: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        let viewContext = controller.container.viewContext

        // Pre-populate with minimal mock data for faster preview rendering
        // Add 1-2 sample recipes
        let sampleRecipe = Recipe(context: viewContext)
        sampleRecipe.id = UUID()
        sampleRecipe.name = "Preview Recipe"
        sampleRecipe.prepTime = 15
        sampleRecipe.cookTime = 30
        sampleRecipe.servings = 4
        sampleRecipe.lastModified = Date()
        sampleRecipe.dateCreated = Date()
        sampleRecipe.calories = 250
        sampleRecipe.totalCarbs = 30
        sampleRecipe.protein = 10
        sampleRecipe.totalFat = 8

        // Add 1-2 sample food items
        let sampleFood = FoodItem(context: viewContext)
        sampleFood.id = UUID()
        sampleFood.name = "Preview Food"
        sampleFood.calories = 250
        sampleFood.totalCarbs = 30
        sampleFood.protein = 10
        sampleFood.totalFat = 8
        sampleFood.servingSize = 100
        sampleFood.servingUnit = "g"
        sampleFood.gramWeight = 100
        sampleFood.source = "ai_scanned"
        sampleFood.dateAdded = Date()
        sampleFood.lastModified = Date()
        sampleFood.lastUsed = Date()

        // Save once
        try? viewContext.save()

        return controller
    }()
}

// MARK: - Preview Mock Data Factories

enum PreviewMocks {
    /// Creates a sample NutritionExtractionResult for previews
    static func nutritionResult(
        productName: String = "Preview Product",
        brandName: String = "Preview Brand",
        calories: Double = 250,
        carbs: Double = 30,
        protein: Double = 10,
        fat: Double = 8,
        servingSize: Double = 100
    ) -> NutritionExtractionResult {
        return NutritionExtractionResult(
            productName: productName,
            brandName: brandName,
            servingSize: NutritionServingSize(value: servingSize, unit: "g"),
            nutrients: ExtractedNutrients(
                calories: NutrientValue(value: calories, unit: "kcal"),
                totalCarbohydrates: NutrientValue(value: carbs, unit: "g"),
                dietaryFiber: NutrientValue(value: 2, unit: "g"),
                sugars: NutrientValue(value: 5, unit: "g"),
                protein: NutrientValue(value: protein, unit: "g"),
                totalFat: NutrientValue(value: fat, unit: "g"),
                saturatedFat: NutrientValue(value: 2, unit: "g"),
                sodium: NutrientValue(value: 150, unit: "mg")
            ),
            metadata: ExtractionMetadata(
                confidence: 85,
                processingTime: "1500ms",
                modelVersion: "preview-1.0"
            )
        )
    }

    /// Creates a sample UIImage for previews
    static var sampleImage: UIImage {
        UIImage(systemName: "photo.fill") ?? UIImage()
    }
}

// MARK: - Preview Animation Control

extension View {
    /// Disables animations when running in preview mode
    /// Use this to prevent continuous animations from slowing down preview updates
    @ViewBuilder
    func disableAnimationsInPreview() -> some View {
        if ProcessInfo.processInfo.isPreviewMode {
            self.animation(nil, value: UUID())
        } else {
            self
        }
    }

    /// Executes action only when NOT in preview mode
    /// Use this to skip expensive operations (network, analytics, etc.) in previews
    @ViewBuilder
    func onAppearExcludingPreview(perform action: @escaping () -> Void) -> some View {
        self.onAppear {
            if !ProcessInfo.processInfo.isPreviewMode {
                action()
            }
        }
    }
}
