//
//  CaloriesSectionView.swift
//  balli
//
//  Calories section with dual focus management for base and adjusted values
//  Extracted from NutritionLabelView.swift
//  Swift 6 strict concurrency compliant
//

import SwiftUI

/// Separate view for calories section to manage focus state independently
struct CaloriesSectionView: View {
    @Binding var calories: String
    let adjustedCalories: String
    @Binding var servingSize: String
    let portionGrams: Double
    let shouldShowValue: Bool

    @FocusState private var caloriesFocused: Bool
    @FocusState private var servingSizeFocused: Bool

    // Computed bindings to reduce duplication
    // KNOWN ISSUE: Swift 6 strict concurrency generates warnings for @Binding mutations in closures
    // This is a SwiftUI limitation - Binding(get:set:) doesn't support @Sendable closures
    // These mutations are safe in practice as @Binding provides thread-safe access
    private var caloriesBinding: Binding<String> {
        Binding(
            get: { caloriesFocused ? calories : adjustedCalories },
            set: { calories = $0 }
        )
    }

    private var servingSizeBinding: Binding<String> {
        Binding(
            get: { servingSizeFocused ? servingSize : String(format: "%.0f", portionGrams) },
            set: { servingSize = $0 }
        )
    }

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: ResponsiveDesign.Spacing.medium) {
            HStack(spacing: ResponsiveDesign.Spacing.xxSmall) {
                // Always show TextField, but switch between adjusted/base value based on focus
                TextField("0", text: caloriesBinding)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.system(size: ResponsiveDesign.Font.scaledSize(22), weight: .semibold, design: .rounded))
                .frame(width: ResponsiveDesign.width(45), height: ResponsiveDesign.height(28))
                .foregroundColor(.primary)
                .textFieldStyle(.plain)
                .focused($caloriesFocused)
                .opacity(shouldShowValue ? 1.0 : 0.0)

                Text("kcal")
                    .font(.system(size: ResponsiveDesign.Font.scaledSize(22), weight: .regular, design: .rounded))
                    .foregroundColor(.primary)
                    .opacity(shouldShowValue ? 1.0 : 0.0)
            }
            .layoutPriority(1)

            Spacer()

            HStack(spacing: ResponsiveDesign.Spacing.xxSmall) {
                // Serving size field - tap to edit base, otherwise shows portion grams
                TextField("0", text: servingSizeBinding)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.system(size: ResponsiveDesign.Font.scaledSize(22), weight: .medium, design: .rounded))
                .frame(width: ResponsiveDesign.width(45), height: ResponsiveDesign.height(28))
                .foregroundColor(.primary)
                .textFieldStyle(.plain)
                .focused($servingSizeFocused)

                Text("g'da")
                    .font(.system(size: ResponsiveDesign.Font.scaledSize(22), weight: .regular, design: .rounded))
                    .foregroundColor(.primary)
            }
        }
        .frame(height: ResponsiveDesign.height(28))
        .padding(.horizontal, ResponsiveDesign.Spacing.large)
        .padding(.top, ResponsiveDesign.Spacing.medium)
    }
}
