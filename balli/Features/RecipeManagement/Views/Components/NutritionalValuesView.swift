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

    @State private var showingCopyConfirmation = false

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
                            icon: "flame.fill",
                            label: "Kalori",
                            value: calories,
                            unit: "kcal",
                            color: .orange
                        )

                        nutritionRow(
                            icon: "fork.knife",
                            label: "Karbonhidrat",
                            value: carbohydrates,
                            unit: "g",
                            color: .blue
                        )

                        nutritionRow(
                            icon: "leaf.fill",
                            label: "Lif",
                            value: fiber,
                            unit: "g",
                            color: .green
                        )

                        nutritionRow(
                            icon: "cube.fill",
                            label: "Şeker",
                            value: sugar,
                            unit: "g",
                            color: .pink
                        )

                        nutritionRow(
                            icon: "figure.run",
                            label: "Protein",
                            value: protein,
                            unit: "g",
                            color: .purple
                        )

                        nutritionRow(
                            icon: "drop.fill",
                            label: "Yağ",
                            value: fat,
                            unit: "g",
                            color: .yellow
                        )

                        nutritionRow(
                            icon: "chart.line.uptrend.xyaxis",
                            label: "Glisemik Yük",
                            value: glycemicLoad,
                            unit: "",
                            color: .red
                        )
                    }

                    // Copy JSON Button
                    Button(action: copyJSONToClipboard) {
                        HStack {
                            Image(systemName: "doc.on.doc.fill")
                                .font(.system(size: 16, weight: .semibold))

                            Text("JSON Kopyala")
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(AppTheme.primaryPurple)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8)

                    // Copy Confirmation
                    if showingCopyConfirmation {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("JSON kopyalandı!")
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                        .transition(.opacity)
                    }
                }
                .padding(20)
            }
            .background(Color.appBackground(for: colorScheme))
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
        icon: String,
        label: String,
        value: String,
        unit: String,
        color: Color
    ) -> some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 48, height: 48)

                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(color)
            }

            // Label and Value
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
        }
        .padding(16)
        .recipeGlass(tint: .warm, cornerRadius: 16)
    }

    // MARK: - Actions

    private func copyJSONToClipboard() {
        let jsonDict: [String: Any] = [
            "name": recipeName,
            "calories": Double(calories) ?? 0,
            "carbohydrates": Double(carbohydrates) ?? 0,
            "fiber": Double(fiber) ?? 0,
            "sugar": Double(sugar) ?? 0,
            "protein": Double(protein) ?? 0,
            "fat": Double(fat) ?? 0,
            "glycemicLoad": Double(glycemicLoad) ?? 0
        ]

        if let jsonData = try? JSONSerialization.data(withJSONObject: jsonDict, options: .prettyPrinted),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            UIPasteboard.general.string = jsonString

            // Show confirmation
            withAnimation {
                showingCopyConfirmation = true
            }

            // Hide confirmation after 2 seconds
            Task {
                try? await Task.sleep(for: .seconds(2))
                withAnimation {
                    showingCopyConfirmation = false
                }
            }
        }
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
