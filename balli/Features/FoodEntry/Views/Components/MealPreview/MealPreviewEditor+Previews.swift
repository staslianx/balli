//
//  MealPreviewEditor+Previews.swift
//  balli
//
//  Preview configurations for MealPreviewEditor
//  Extracted from MealPreviewEditor.swift
//  Swift 6 strict concurrency compliant
//

import SwiftUI

// MARK: - Previews

#Preview("Simple Meal - No Insulin") {
    @Previewable @State var editableFoods = [
        EditableFoodItem(name: "Ekmek", amount: "2 adet", carbs: 30),
        EditableFoodItem(name: "Peynir", amount: "1 dilim", carbs: 2)
    ]
    @Previewable @State var editableTotalCarbs = "32"
    @Previewable @State var editableMealType = "kahvaltı"
    @Previewable @State var editableMealTime = "08:30"
    @Previewable @State var editableTimestamp = Date()
    @Previewable @State var hasInsulin = false
    @Previewable @State var editableInsulinDosage = 0.0
    @Previewable @State var editableInsulinType: String? = nil
    @Previewable @State var editableInsulinName: String? = nil

    let parsedData = ParsedMealData(
        transcription: "İki adet ekmek ve bir dilim peynir yedim",
        foods: [
            ParsedFoodItem(name: "Ekmek", amount: "2 adet", carbs: 30),
            ParsedFoodItem(name: "Peynir", amount: "1 dilim", carbs: 2)
        ],
        totalCarbs: 32,
        mealType: "kahvaltı",
        mealTime: "08:30",
        confidence: "high"
    )

    MealPreviewEditor(
        parsedData: parsedData,
        isDetailedFormat: false, // Simple format - no per-item carbs
        editableFoods: $editableFoods,
        editableTotalCarbs: $editableTotalCarbs,
        editableMealType: $editableMealType,
        editableMealTime: $editableMealTime,
        editableTimestamp: $editableTimestamp,
        hasInsulin: $hasInsulin,
        editableInsulinDosage: $editableInsulinDosage,
        editableInsulinType: $editableInsulinType,
        editableInsulinName: $editableInsulinName,
        onAdjustCarbs: { delta in
            if let current = Int(editableTotalCarbs) {
                editableTotalCarbs = "\(max(0, current + delta))"
            }
        }
    )
}

#Preview("Detailed Meal with Insulin") {
    @Previewable @State var editableFoods = [
        EditableFoodItem(name: "Ekmek", amount: "2 adet", carbs: 30),
        EditableFoodItem(name: "Peynir", amount: "50 gram", carbs: 2),
        EditableFoodItem(name: "Domates", amount: "1 adet", carbs: 3)
    ]
    @Previewable @State var editableTotalCarbs = "35"
    @Previewable @State var editableMealType = "akşam yemeği"
    @Previewable @State var editableMealTime = "19:45"
    @Previewable @State var editableTimestamp = Date()
    @Previewable @State var hasInsulin = true
    @Previewable @State var editableInsulinDosage = 5.0
    @Previewable @State var editableInsulinType: String? = "bolus"
    @Previewable @State var editableInsulinName: String? = "NovoRapid"

    let parsedData = ParsedMealData(
        transcription: "Akşam yemeğinde iki adet ekmek, elli gram peynir, bir adet domates yedim. Beş ünite NovoRapid vurdum.",
        foods: [
            ParsedFoodItem(name: "Ekmek", amount: "2 adet", carbs: 30),
            ParsedFoodItem(name: "Peynir", amount: "50 gram", carbs: 2),
            ParsedFoodItem(name: "Domates", amount: "1 adet", carbs: 3)
        ],
        totalCarbs: 35,
        mealType: "akşam yemeği",
        mealTime: "19:45",
        confidence: "high",
        insulinDosage: 5.0,
        insulinType: "bolus",
        insulinName: "NovoRapid"
    )

    MealPreviewEditor(
        parsedData: parsedData,
        isDetailedFormat: true, // Detailed format - show per-item carbs
        editableFoods: $editableFoods,
        editableTotalCarbs: $editableTotalCarbs,
        editableMealType: $editableMealType,
        editableMealTime: $editableMealTime,
        editableTimestamp: $editableTimestamp,
        hasInsulin: $hasInsulin,
        editableInsulinDosage: $editableInsulinDosage,
        editableInsulinType: $editableInsulinType,
        editableInsulinName: $editableInsulinName,
        onAdjustCarbs: { delta in
            if let current = Int(editableTotalCarbs) {
                editableTotalCarbs = "\(max(0, current + delta))"
            }
        }
    )
}

#Preview("Low Confidence Warning") {
    @Previewable @State var editableFoods = [
        EditableFoodItem(name: "Ekmek", amount: "2 adet", carbs: nil)
    ]
    @Previewable @State var editableTotalCarbs = "30"
    @Previewable @State var editableMealType = "ara öğün"
    @Previewable @State var editableMealTime = "15:30"
    @Previewable @State var editableTimestamp = Date()
    @Previewable @State var hasInsulin = false
    @Previewable @State var editableInsulinDosage = 0.0
    @Previewable @State var editableInsulinType: String? = nil
    @Previewable @State var editableInsulinName: String? = nil

    let parsedData = ParsedMealData(
        transcription: "Bir şeyler yedim ama tam hatırlamıyorum",
        foods: [
            ParsedFoodItem(name: "Ekmek", amount: "2 adet", carbs: nil)
        ],
        totalCarbs: 30,
        mealType: "ara öğün",
        mealTime: "15:30",
        confidence: "medium"
    )

    MealPreviewEditor(
        parsedData: parsedData,
        isDetailedFormat: false, // Simple format with warning
        editableFoods: $editableFoods,
        editableTotalCarbs: $editableTotalCarbs,
        editableMealType: $editableMealType,
        editableMealTime: $editableMealTime,
        editableTimestamp: $editableTimestamp,
        hasInsulin: $hasInsulin,
        editableInsulinDosage: $editableInsulinDosage,
        editableInsulinType: $editableInsulinType,
        editableInsulinName: $editableInsulinName,
        onAdjustCarbs: { delta in
            if let current = Int(editableTotalCarbs) {
                editableTotalCarbs = "\(max(0, current + delta))"
            }
        }
    )
}
