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

    // Portion multiplier binding for persistence
    @Binding var portionMultiplier: Double

    @State private var selectedTab = 0  // 0 = Porsiyon, 1 = 100g

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ResponsiveDesign.Spacing.medium) {
                    // Segmented Picker
                    Picker("Nutrition Mode", selection: $selectedTab) {
                        Text("Porsiyon").tag(0)
                        Text("100g").tag(1)
                    }
                    .pickerStyle(.segmented)

                    // Portion Stepper (only show in Porsiyon tab)
                    if selectedTab == 0 {
                        portionStepperView
                    }

                    // Main Card Container - matching LoggedMealsView style
                    VStack(alignment: .leading, spacing: 0) {
                        // Info Text Header
                        infoText
                            .font(.system(size: ResponsiveDesign.Font.scaledSize(14), weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)
                            .padding(.horizontal, ResponsiveDesign.Spacing.medium)
                            .padding(.top, ResponsiveDesign.Spacing.medium)
                            .padding(.bottom, ResponsiveDesign.Spacing.small)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        // Divider below header
                        Rectangle()
                            .fill(Color.secondary.opacity(0.2))
                            .frame(height: 0.5)
                            .padding(.horizontal, ResponsiveDesign.Spacing.medium)

                        // Nutritional Values Rows
                        VStack(spacing: ResponsiveDesign.Spacing.xSmall) {
                            nutritionRow(
                                label: "Kalori",
                                value: displayedCalories,
                                unit: "kcal"
                            )

                            Rectangle()
                                .fill(Color.secondary.opacity(0.1))
                                .frame(height: 0.5)
                                .padding(.horizontal, ResponsiveDesign.Spacing.medium)

                            nutritionRow(
                                label: "Karbonhidrat",
                                value: displayedCarbohydrates,
                                unit: "g"
                            )

                            Rectangle()
                                .fill(Color.secondary.opacity(0.1))
                                .frame(height: 0.5)
                                .padding(.horizontal, ResponsiveDesign.Spacing.medium)

                            nutritionRow(
                                label: "Lif",
                                value: displayedFiber,
                                unit: "g"
                            )

                            Rectangle()
                                .fill(Color.secondary.opacity(0.1))
                                .frame(height: 0.5)
                                .padding(.horizontal, ResponsiveDesign.Spacing.medium)

                            nutritionRow(
                                label: "Şeker",
                                value: displayedSugar,
                                unit: "g"
                            )

                            Rectangle()
                                .fill(Color.secondary.opacity(0.1))
                                .frame(height: 0.5)
                                .padding(.horizontal, ResponsiveDesign.Spacing.medium)

                            nutritionRow(
                                label: "Protein",
                                value: displayedProtein,
                                unit: "g"
                            )

                            Rectangle()
                                .fill(Color.secondary.opacity(0.1))
                                .frame(height: 0.5)
                                .padding(.horizontal, ResponsiveDesign.Spacing.medium)

                            nutritionRow(
                                label: "Yağ",
                                value: displayedFat,
                                unit: "g"
                            )

                            // Only show Glycemic Load in Porsiyon tab (it's a per-portion metric)
                            if selectedTab == 0 {
                                Rectangle()
                                    .fill(Color.secondary.opacity(0.1))
                                    .frame(height: 0.5)
                                    .padding(.horizontal, ResponsiveDesign.Spacing.medium)

                                nutritionRow(
                                    label: "Glisemik Yük",
                                    value: displayedGlycemicLoad,
                                    unit: ""
                                )
                            }
                        }
                        .padding(.vertical, ResponsiveDesign.Spacing.small)
                    }
                    .background(.clear)
                    .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.card, style: .continuous))
                    .clipShape(RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.card, style: .continuous))
                    .shadow(color: .black.opacity(0.06), radius: ResponsiveDesign.height(8), x: 0, y: ResponsiveDesign.height(4))
                }
                .padding(ResponsiveDesign.Spacing.medium)
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
                let multipliedWeight = (Double(totalRecipeWeight) ?? 0) * portionMultiplier
                return Text("1 porsiyon: **\(String(format: "%.0f", multipliedWeight))g**")
            } else {
                return Text("1 porsiyon")
            }
        } else {
            // 100g tab
            return Text("Per 100g")
        }
    }

    private var displayedCalories: String {
        if selectedTab == 0 {
            let value = (Double(caloriesPerServing) ?? 0) * portionMultiplier
            return String(format: "%.0f", value)
        } else {
            return calories
        }
    }

    private var displayedCarbohydrates: String {
        if selectedTab == 0 {
            let value = (Double(carbohydratesPerServing) ?? 0) * portionMultiplier
            return String(format: "%.1f", value)
        } else {
            return carbohydrates
        }
    }

    private var displayedFiber: String {
        if selectedTab == 0 {
            let value = (Double(fiberPerServing) ?? 0) * portionMultiplier
            return String(format: "%.1f", value)
        } else {
            return fiber
        }
    }

    private var displayedSugar: String {
        if selectedTab == 0 {
            let value = (Double(sugarPerServing) ?? 0) * portionMultiplier
            return String(format: "%.1f", value)
        } else {
            return sugar
        }
    }

    private var displayedProtein: String {
        if selectedTab == 0 {
            let value = (Double(proteinPerServing) ?? 0) * portionMultiplier
            return String(format: "%.1f", value)
        } else {
            return protein
        }
    }

    private var displayedFat: String {
        if selectedTab == 0 {
            let value = (Double(fatPerServing) ?? 0) * portionMultiplier
            return String(format: "%.1f", value)
        } else {
            return fat
        }
    }

    private var displayedGlycemicLoad: String {
        if selectedTab == 0 {
            let value = (Double(glycemicLoadPerServing) ?? 0) * portionMultiplier
            return String(format: "%.0f", value)
        } else {
            return glycemicLoad
        }
    }

    // MARK: - Components

    private var portionStepperView: some View {
        HStack {
            Text("Porsiyon Miktarı")
                .font(.system(size: ResponsiveDesign.Font.scaledSize(16), weight: .semibold, design: .rounded))
                .foregroundColor(.primary)

            Spacer()

            HStack(spacing: 12) {
                Button {
                    if portionMultiplier > 0.5 {
                        portionMultiplier -= 0.5
                    }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(AppTheme.primaryPurple)
                }
                .disabled(portionMultiplier <= 0.5)

                Text(String(format: "%.1f", portionMultiplier) + "x")
                    .font(.system(size: ResponsiveDesign.Font.scaledSize(20), weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(AppTheme.primaryPurple)
                    .frame(minWidth: 60)

                Button {
                    portionMultiplier += 0.5
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(AppTheme.primaryPurple)
                }
            }
        }
        .padding(ResponsiveDesign.Spacing.medium)
        .background(.clear)
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.card, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.card, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: ResponsiveDesign.height(8), x: 0, y: ResponsiveDesign.height(4))
    }

    private func nutritionRow(
        label: String,
        value: String,
        unit: String
    ) -> some View {
        HStack(spacing: ResponsiveDesign.Spacing.small) {
            Text(label)
                .font(.system(size: ResponsiveDesign.Font.scaledSize(16), weight: .medium, design: .rounded))
                .foregroundStyle(.primary)

            Spacer()

            HStack(spacing: 4) {
                Text(value.isEmpty ? "0" : value)
                    .font(.system(size: ResponsiveDesign.Font.scaledSize(18), weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.primaryPurple)

                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: ResponsiveDesign.Font.scaledSize(13), weight: .regular, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, ResponsiveDesign.Spacing.small)
        .padding(.horizontal, ResponsiveDesign.Spacing.medium)
    }
}

// MARK: - Preview

#Preview("With Both Values - Low Warning") {
    @Previewable @State var multiplier = 1.0

    return NutritionalValuesView(
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
}

#Preview("High Fat Recipe - Danger Warning") {
    @Previewable @State var multiplier = 1.0

    return NutritionalValuesView(
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
}

#Preview("Empty Values") {
    @Previewable @State var multiplier = 1.0

    return NutritionalValuesView(
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
}
