//
//  NutritionLabelView+Preview.swift
//  balli
//
//  Preview configuration for NutritionLabelView
//  Extracted from NutritionLabelView.swift
//  Swift 6 strict concurrency compliant
//

import SwiftUI

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State private var productBrand = "Ülker"
        @State private var productName = "Çikolatalı Gofret"
        @State private var calories = "240"
        @State private var servingSize = "100"
        @State private var carbohydrates = "20"
        @State private var fiber = "6"
        @State private var sugars = "8"
        @State private var protein = "12"
        @State private var fat = "8"
        @State private var portionGrams: Double = 100
        @State private var isEditing = false

        var body: some View {
            ZStack {
                Color(.systemGray6)
                    .ignoresSafeArea()

                VStack {
                    NutritionLabelView(
                        productBrand: $productBrand,
                        productName: $productName,
                        calories: $calories,
                        servingSize: $servingSize,
                        carbohydrates: $carbohydrates,
                        fiber: $fiber,
                        sugars: $sugars,
                        protein: $protein,
                        fat: $fat,
                        portionGrams: $portionGrams,
                        isEditing: isEditing,
                        showIcon: true,
                        iconName: "laser.burst",
                        iconColor: AppTheme.primaryPurple,
                        showingValues: true,
                        valuesAnimationProgress: [:]
                    )

                    Button(action: { isEditing.toggle() }) {
                        Text(isEditing ? "Kaydet" : "Düzenle")
                            .font(.system(size: ResponsiveDesign.Font.scaledSize(18), weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(width: ResponsiveDesign.width(180))
                            .frame(height: ResponsiveDesign.height(56))
                            .background(AppTheme.primaryPurple)
                            .clipShape(Capsule())
                    }
                    .padding(.top, ResponsiveDesign.height(30))
                }
            }
        }
    }

    return PreviewWrapper()
}
