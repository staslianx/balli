//
//  NutritionalValuesView.swift
//  balli
//
//  Modal view displaying nutritional values with segmented picker
//  Supports both per-100g and per-serving views
//

import SwiftUI

/// Modal sheet displaying nutritional values with tab switching
struct NutritionalValuesView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    let recipeName: String

    // Per-100g values
    let calories: String
    let carbohydrates: String
    let fiber: String
    let sugar: String
    let protein: String
    let fat: String
    let glycemicLoad: String

    // Per-serving values
    let caloriesPerServing: String
    let carbohydratesPerServing: String
    let fiberPerServing: String
    let sugarPerServing: String
    let proteinPerServing: String
    let fatPerServing: String
    let glycemicLoadPerServing: String
    let totalRecipeWeight: String

    // API insights (optional - from nutrition calculation)
    let digestionTiming: DigestionTiming?

    @State private var selectedTab = 0  // 0 = Porsiyon, 1 = 100g

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Segmented Picker
                    Picker("Nutrition Mode", selection: $selectedTab) {
                        Text("Porsiyon").tag(0)
                        Text("100g").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding(.bottom, 8)

                    // Info Text
                    infoText
                        .font(.system(size: 15, weight: .regular, design: .rounded))
                        .foregroundColor(.secondary)
                        .padding(.bottom, 8)

                    // Nutritional Values Cards
                    VStack(spacing: 12) {
                        nutritionRow(
                            label: "Kalori",
                            value: displayedCalories,
                            unit: "kcal"
                        )

                        nutritionRow(
                            label: "Karbonhidrat",
                            value: displayedCarbohydrates,
                            unit: "g"
                        )

                        nutritionRow(
                            label: "Lif",
                            value: displayedFiber,
                            unit: "g"
                        )

                        nutritionRow(
                            label: "Şeker",
                            value: displayedSugar,
                            unit: "g"
                        )

                        nutritionRow(
                            label: "Protein",
                            value: displayedProtein,
                            unit: "g"
                        )

                        nutritionRow(
                            label: "Yağ",
                            value: displayedFat,
                            unit: "g"
                        )

                        // Only show Glycemic Load in Porsiyon tab (it's a per-portion metric)
                        if selectedTab == 0 {
                            nutritionRow(
                                label: "Glisemik Yük",
                                value: displayedGlycemicLoad,
                                unit: ""
                            )
                        }
                    }
                }
                .padding(20)
            }
            .background(Color(.systemBackground))
            .navigationTitle(recipeName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kapat") {
                        dismiss()
                    }
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                }
            }
        }
    }

    // MARK: - Computed Properties

    private var infoText: Text {
        if selectedTab == 0 {
            // Porsiyon tab
            if !totalRecipeWeight.isEmpty && totalRecipeWeight != "0" {
                return Text("1 porsiyon: ") + Text("\(totalRecipeWeight)g").fontWeight(.semibold)
            } else {
                return Text("1 porsiyon")
            }
        } else {
            // 100g tab
            return Text("Per 100g")
        }
    }

    private var displayedCalories: String {
        selectedTab == 0 ? caloriesPerServing : calories
    }

    private var displayedCarbohydrates: String {
        selectedTab == 0 ? carbohydratesPerServing : carbohydrates
    }

    private var displayedFiber: String {
        selectedTab == 0 ? fiberPerServing : fiber
    }

    private var displayedSugar: String {
        selectedTab == 0 ? sugarPerServing : sugar
    }

    private var displayedProtein: String {
        selectedTab == 0 ? proteinPerServing : protein
    }

    private var displayedFat: String {
        selectedTab == 0 ? fatPerServing : fat
    }

    private var displayedGlycemicLoad: String {
        selectedTab == 0 ? glycemicLoadPerServing : glycemicLoad
    }

    // MARK: - Components

    private func nutritionRow(
        label: String,
        value: String,
        unit: String
    ) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .foregroundColor(.primary)

            Spacer()

            HStack(spacing: 4) {
                Text(value.isEmpty ? "0" : value)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 15, weight: .regular, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(16)
        .recipeGlass(tint: .warm, cornerRadius: 30)
        .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
    }
}

// MARK: - Preview

#Preview("With Both Values - Low Warning") {
    NutritionalValuesView(
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
        digestionTiming: nil
    )
}

#Preview("High Fat Recipe - Danger Warning") {
    NutritionalValuesView(
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
        digestionTiming: nil
    )
}

#Preview("Empty Values") {
    NutritionalValuesView(
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
        digestionTiming: nil
    )
}
