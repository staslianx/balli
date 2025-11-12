//
//  MealFormComponents.swift
//  balli
//
//  Reusable form components for meal editing
//  Extracted from MealPreviewEditor.swift
//  Swift 6 strict concurrency compliant
//

import SwiftUI

// MARK: - Meal Type Picker Component

struct MealTypePicker: View {
    @Binding var mealType: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Öğün Türü")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)

            Picker("Öğün", selection: $mealType) {
                Text("Kahvaltı").tag("kahvaltı")
                Text("Ara Öğün").tag("ara öğün")
                Text("Akşam Yemeği").tag("akşam yemeği")
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Carb Stepper Component

struct CarbStepperView: View {
    @Binding var totalCarbs: String
    let onAdjustCarbs: (Int) -> Void

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            Text("Karbonhidrat")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                // Decrease button
                Button {
                    onAdjustCarbs(-5)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(AppTheme.primaryPurple)
                }
                .buttonStyle(.plain)

                // Carb value
                TextField("0", text: $totalCarbs)
                    .keyboardType(.numberPad)
                    .font(.system(size: 24, weight: .bold, design: .rounded).monospacedDigit())
                    .glassTextField()
                    .frame(width: 70)
                    .multilineTextAlignment(.center)

                Text("g")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)

                // Increase button
                Button {
                    onAdjustCarbs(5)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(AppTheme.primaryPurple)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Add Item Buttons Component

struct AddItemButtonsView: View {
    @Binding var editableFoods: [EditableFoodItem]

    var body: some View {
        Button {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                editableFoods.append(EditableFoodItem(name: "", amount: nil, carbs: nil))
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "carrot.fill")
                    .font(.system(size: 16, weight: .medium))
                    .frame(width: 20, height: 20)
                Text("Yiyecek Ekle")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
            }
            .frame(width: 140, height: 44)
        }
        .buttonStyle(.bordered)
        .frame(maxWidth: .infinity)
    }
}
