//
//  NutritionalValuesView.swift
//  balli
//
//  Modal view displaying nutritional JSON values
//  Glass morphism design with copy functionality
//

import SwiftUI

/// Modal sheet displaying nutritional values in JSON format
struct NutritionalValuesView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    let recipeName: String
    let calories: String
    let carbohydrates: String
    let fiber: String
    let sugar: String
    let protein: String
    let fat: String
    let glycemicLoad: String

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Recipe Name Header
                    Text(recipeName)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .padding(.bottom, 8)

                    // Nutritional Values Cards
                    VStack(spacing: 12) {
                        nutritionRow(
                            label: "Kalori",
                            value: calories,
                            unit: "kcal"
                        )

                        nutritionRow(
                            label: "Karbonhidrat",
                            value: carbohydrates,
                            unit: "g"
                        )

                        nutritionRow(
                            label: "Lif",
                            value: fiber,
                            unit: "g"
                        )

                        nutritionRow(
                            label: "Şeker",
                            value: sugar,
                            unit: "g"
                        )

                        nutritionRow(
                            label: "Protein",
                            value: protein,
                            unit: "g"
                        )

                        nutritionRow(
                            label: "Yağ",
                            value: fat,
                            unit: "g"
                        )

                        nutritionRow(
                            label: "Glisemik Yük",
                            value: glycemicLoad,
                            unit: ""
                        )
                    }
                }
                .padding(20)
            }
            .background(Color(.systemBackground))
            .navigationTitle("Besin Değerleri")
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
        .balliTintedGlass(cornerRadius: 28)
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Preview

#Preview("With Values") {
    NutritionalValuesView(
        recipeName: "Izgara Tavuk Salatası",
        calories: "165",
        carbohydrates: "8",
        fiber: "3",
        sugar: "2",
        protein: "31",
        fat: "3.6",
        glycemicLoad: "4"
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
        glycemicLoad: ""
    )
}
