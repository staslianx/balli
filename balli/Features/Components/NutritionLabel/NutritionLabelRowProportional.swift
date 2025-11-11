//
//  NutritionLabelRowProportional.swift
//  balli
//
//  Reusable nutrition row component with proportional value adjustment
//  Extracted from NutritionLabelView.swift
//  Swift 6 strict concurrency compliant
//

import SwiftUI

struct NutritionLabelRowProportional: View {
    let label: String
    @Binding var baseValue: String  // Base value at serving size
    let adjustedValue: String  // Adjusted value based on portion
    let unit: String
    let isEditing: Bool
    let portionGrams: Double
    let shouldShow: Bool

    @FocusState private var isFocused: Bool

    // Computed binding to reduce duplication
    // KNOWN ISSUE: Swift 6 strict concurrency generates warning for @Binding mutation in closure
    // This is a SwiftUI limitation - Binding(get:set:) doesn't support @Sendable closures
    // This mutation is safe in practice as @Binding provides thread-safe access
    private var valueBinding: Binding<String> {
        Binding(
            get: { isFocused ? baseValue : adjustedValue },
            set: { baseValue = $0 }
        )
    }

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: ResponsiveDesign.Font.scaledSize(22), weight: .semibold, design: .rounded))
                .foregroundColor(.primary)

            Spacer()

            HStack(spacing: ResponsiveDesign.Spacing.xxSmall) {
                // Always show TextField, but populate it with adjusted value when not focused
                // This allows: (1) slider updates values in real-time, (2) tap to edit
                TextField("0", text: valueBinding)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.system(size: ResponsiveDesign.Font.scaledSize(22), weight: .medium, design: .rounded))
                .frame(width: ResponsiveDesign.width(55), height: ResponsiveDesign.height(28))
                .foregroundColor(.primary)
                .textFieldStyle(.plain)
                .focused($isFocused)
                .opacity(shouldShow ? 1.0 : 0.0)

                Text(unit)
                    .font(.system(size: ResponsiveDesign.Font.scaledSize(22), weight: .regular, design: .rounded))
                    .foregroundColor(.primary)
                    .opacity(shouldShow ? 1.0 : 0.0)
            }
        }
        .frame(height: ResponsiveDesign.height(28))
    }
}
