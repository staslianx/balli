//
//  RecipeMealSelectionView.swift
//  balli
//
//  Modal view for selecting recipe meal type and style
//  40% screen height with meal/style pickers
//

import SwiftUI

struct RecipeMealSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @Binding var selectedMealType: String
    @Binding var selectedStyleType: String

    let onGenerate: () -> Void

    // Meal types from recipe_chef_assistant.prompt
    private let mealTypes = [
        "Kahvaltı",
        "Akşam Yemeği",
        "Salatalar",
        "Tatlılar",
        "Atıştırmalıklar"
    ]

    // Style types mapped by meal type
    private var styleTypes: [String] {
        switch selectedMealType {
        case "Kahvaltı":
            return ["Geleneksel", "Protein Ağırlıklı", "Hızlı", "Vejeteryan"]
        case "Akşam Yemeği":
            return ["Karbohidrat ve Protein Uyumu", "Tam Buğday Makarna", "Geleneksel", "Hafif"]
        case "Salatalar":
            return ["Doyurucu Salata", "Hafif Salata"]
        case "Tatlılar":
            return ["Sana Özel Tatlılar", "Dondurma", "Meyve Salatası"]
        case "Atıştırmalıklar":
            return ["Geleneksel", "Protein Ağırlıklı", "Hafif"]
        default:
            return []
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Meal Type Picker
                VStack(alignment: .leading, spacing: 12) {
                    Text("Öğün Tipi")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)

                    Picker("Öğün Tipi", selection: $selectedMealType) {
                        ForEach(mealTypes, id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // Style Type Picker
                if !styleTypes.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Stil")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)

                        Picker("Stil", selection: $selectedStyleType) {
                            ForEach(styleTypes, id: \.self) { style in
                                Text(style).tag(style)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }

                Spacer()

                // Generate Button
                Button(action: {
                    onGenerate()
                    dismiss()
                }) {
                    Text("Tarif Oluştur")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(AppTheme.primaryPurple)
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.bottom, 20)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .navigationTitle("Tarif Seç")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("İptal") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            // Ensure selectedStyleType is valid for the current mealType
            if !styleTypes.contains(selectedStyleType) {
                selectedStyleType = styleTypes.first ?? ""
            }
        }
        .onChange(of: selectedMealType) { _, _ in
            // Reset style type when meal type changes
            selectedStyleType = styleTypes.first ?? ""
        }
    }
}

#Preview {
    RecipeMealSelectionView(
        selectedMealType: .constant("Kahvaltı"),
        selectedStyleType: .constant("Geleneksel"),
        onGenerate: {
            print("Generate tapped")
        }
    )
}
