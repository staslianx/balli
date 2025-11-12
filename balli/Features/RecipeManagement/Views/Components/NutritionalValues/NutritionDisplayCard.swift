//
//  NutritionDisplayCard.swift
//  balli
//
//  Main nutrition facts display with tab switching (Per Serving / Per 100g)
//  Extracted from NutritionalValuesView.swift
//  Swift 6 strict concurrency compliant
//

import SwiftUI

/// Main nutrition display card showing facts in either per-serving or per-100g mode
@MainActor
struct NutritionDisplayCard: View {
    // Tab selection
    @Binding var selectedTab: Int

    // Per-100g values (base nutrition)
    let calories: String
    let carbohydrates: String
    let fiber: String
    let sugar: String
    let protein: String
    let fat: String

    // Per-serving values
    let caloriesPerServing: String
    let carbohydratesPerServing: String
    let fiberPerServing: String
    let sugarPerServing: String
    let proteinPerServing: String
    let fatPerServing: String
    let glycemicLoadPerServing: String

    // Portion multiplier for dynamic calculation
    let portionMultiplier: Double

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.Spacing.medium) {
            // Tab Picker
            Picker("Nutrition Mode", selection: $selectedTab) {
                Text("Porsiyon").tag(0)
                Text("100g").tag(1)
            }
            .pickerStyle(.segmented)

            // Main Card Container
            VStack(alignment: .leading, spacing: 0) {
                // Info Text Header (only shown in 100g tab)
                if selectedTab == 1 {
                    infoText
                        .font(.system(size: ResponsiveDesign.Font.scaledSize(14), weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, ResponsiveDesign.Spacing.large)
                        .padding(.top, ResponsiveDesign.Spacing.large)
                        .padding(.bottom, ResponsiveDesign.Spacing.medium)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // Divider below header
                    Rectangle()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 0.5)
                        .padding(.horizontal, ResponsiveDesign.Spacing.large)
                }

                // Nutritional Values Rows
                VStack(spacing: ResponsiveDesign.Spacing.small) {
                    nutritionRow(
                        label: "Kalori",
                        value: selectedTab == 0
                            ? String(format: "%.0f", (caloriesPerServing.toDouble ?? 0) * portionMultiplier)
                            : calories,
                        unit: "kcal"
                    )

                    divider

                    nutritionRow(
                        label: "Karbonhidrat",
                        value: selectedTab == 0
                            ? String(format: "%.1f", (carbohydratesPerServing.toDouble ?? 0) * portionMultiplier)
                            : carbohydrates,
                        unit: "g"
                    )

                    divider

                    nutritionRow(
                        label: "Lif",
                        value: selectedTab == 0
                            ? String(format: "%.1f", (fiberPerServing.toDouble ?? 0) * portionMultiplier)
                            : fiber,
                        unit: "g"
                    )

                    divider

                    nutritionRow(
                        label: "Şeker",
                        value: selectedTab == 0
                            ? String(format: "%.1f", (sugarPerServing.toDouble ?? 0) * portionMultiplier)
                            : sugar,
                        unit: "g"
                    )

                    divider

                    nutritionRow(
                        label: "Protein",
                        value: selectedTab == 0
                            ? String(format: "%.1f", (proteinPerServing.toDouble ?? 0) * portionMultiplier)
                            : protein,
                        unit: "g"
                    )

                    divider

                    nutritionRow(
                        label: "Yağ",
                        value: selectedTab == 0
                            ? String(format: "%.1f", (fatPerServing.toDouble ?? 0) * portionMultiplier)
                            : fat,
                        unit: "g"
                    )

                    // Only show Glycemic Load in Porsiyon tab (it's a per-portion metric)
                    if selectedTab == 0 {
                        divider

                        nutritionRow(
                            label: "Glisemik Yük",
                            value: String(format: "%.0f", (glycemicLoadPerServing.toDouble ?? 0) * portionMultiplier),
                            unit: ""
                        )
                    }
                }
                .padding(.vertical, ResponsiveDesign.Spacing.medium)
            }
            .background(.clear)
            .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.card, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.card, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: ResponsiveDesign.height(8), x: 0, y: ResponsiveDesign.height(4))
        }
    }

    // MARK: - Info Text

    private var infoText: some View {
        Text("100gr")
    }

    // MARK: - Divider

    private var divider: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.1))
            .frame(height: 0.5)
            .padding(.horizontal, ResponsiveDesign.Spacing.large)
    }

    // MARK: - Nutrition Row

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
        .padding(.vertical, ResponsiveDesign.Spacing.medium)
        .padding(.horizontal, ResponsiveDesign.Spacing.large)
    }
}
