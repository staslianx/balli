//
//  AnalysisNutritionLabelView.swift
//  balli
//
//  Nutrition label view shown during AI analysis with real-time data updates
//

import SwiftUI

/// Nutrition label view displayed during AI analysis with live data updates
struct AnalysisNutritionLabelView: View {
    // MARK: - Properties

    /// The captured image being analyzed
    let capturedImage: UIImage

    /// Current analysis stage
    let currentStage: AnalysisStage

    /// Visual progress (0.0 to 1.0)
    let visualProgress: Double

    /// Error message if any
    let errorMessage: String?

    /// Real nutrition data when available
    let nutritionResult: NutritionExtractionResult?

    /// Color scheme for dynamic colors
    @Environment(\.colorScheme) private var colorScheme

    /// Rotation state for logo animation
    @State private var isRotating = false

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerSection
            caloriesSection
            dividerLine
            nutritionSection
            progressSection
            Spacer()
        }
        .frame(width: ResponsiveDesign.Components.foodLabelWidth, height: ResponsiveDesign.Components.foodLabelHeight)
        .glassEffect(
            .regular.interactive(),
            in: RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.modal)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.modal)
                .stroke(
                    LinearGradient(
                        colors: [
                            AppTheme.primaryPurple.opacity(0.15),
                            AppTheme.primaryPurple.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
        .shadow(color: AppTheme.primaryPurple.opacity(0.08), radius: 8, x: 0, y: 3)
        .shadow(color: Color.black.opacity(0.03), radius: 3, x: 0, y: 1)
    }

    // MARK: - Private Views

    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: ResponsiveDesign.Spacing.small) {
                // Brand name with label
                if currentStage == .completed && nutritionResult?.brandName != nil {
                    Text(nutritionResult?.brandName ?? "")
                        .font(.system(size: ResponsiveDesign.Font.scaledSize(30), weight: .semibold, design: .rounded))
                        .foregroundColor(AppTheme.primaryPurple)
                        .frame(height: ResponsiveDesign.height(36), alignment: .leading)
                } else {
                    Text("Marka")
                        .font(.system(size: ResponsiveDesign.Font.scaledSize(30), weight: .semibold, design: .rounded))
                        .foregroundColor(.secondary)
                        .frame(height: ResponsiveDesign.height(36), alignment: .leading)
                }

                // Product name with label
                if currentStage == .completed && nutritionResult?.productName != nil {
                    Text(nutritionResult?.productName ?? "")
                        .font(.system(size: ResponsiveDesign.Font.scaledSize(26), weight: .medium, design: .rounded))
                        .foregroundColor(AppTheme.primaryPurple)
                        .frame(height: ResponsiveDesign.height(32), alignment: .leading)
                } else {
                    Text("Ürün Adı")
                        .font(.system(size: ResponsiveDesign.Font.scaledSize(26), weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                        .frame(height: ResponsiveDesign.height(32), alignment: .leading)
                }
            }

            Spacer()
        }
        .padding(.horizontal, ResponsiveDesign.Spacing.large)
        .padding(.top, ResponsiveDesign.height(50))
    }


    private var caloriesSection: some View {
        HStack(alignment: .lastTextBaseline) {
            HStack(spacing: ResponsiveDesign.Spacing.xxSmall) {
                // Calorie value
                if let calorieValue = realValue(for: "kalori") {
                    Text(calorieValue)
                        .font(.system(size: ResponsiveDesign.Font.scaledSize(22), weight: .medium, design: .rounded))
                        .foregroundColor(AppTheme.primaryPurple)
                        .frame(height: ResponsiveDesign.height(28))
                } else {
                    Text("0")
                        .font(.system(size: ResponsiveDesign.Font.scaledSize(22), weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                        .frame(height: ResponsiveDesign.height(28))
                }

                Text("kcal")
                    .font(.system(size: ResponsiveDesign.Font.scaledSize(22), weight: .regular, design: .rounded))
                    .foregroundColor(.primary)
            }
            .layoutPriority(1)

            Spacer(minLength: ResponsiveDesign.Spacing.large)

            HStack(spacing: ResponsiveDesign.Spacing.xxSmall) {
                if let nutritionResult = nutritionResult, currentStage == .completed {
                    Text("\(Int(nutritionResult.servingSize.value))")
                        .font(.system(size: ResponsiveDesign.Font.scaledSize(22), weight: .medium, design: .rounded))
                        .foregroundColor(AppTheme.primaryPurple)
                        .frame(height: ResponsiveDesign.height(28))
                } else {
                    Text("0")
                        .font(.system(size: ResponsiveDesign.Font.scaledSize(22), weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                        .frame(height: ResponsiveDesign.height(28))
                }

                Text("g'da")
                    .font(.system(size: ResponsiveDesign.Font.scaledSize(22), weight: .regular, design: .rounded))
                    .foregroundColor(.primary)
            }
        }
        .padding(.horizontal, ResponsiveDesign.Spacing.large)
        .padding(.top, ResponsiveDesign.Spacing.medium)
    }

    private var dividerLine: some View {
        Rectangle()
            .fill(Color(.separator))
            .frame(height: 1)
            .padding(.horizontal, ResponsiveDesign.Spacing.xSmall)
            .padding(.vertical, ResponsiveDesign.Spacing.large)
    }

    private var nutritionSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.Spacing.medium) {
            analysisNutritionRow(label: "Karbonhidrat", key: "carbs")
            analysisNutritionRow(label: "Lif", key: "fiber")
            analysisNutritionRow(label: "Şeker", key: "sugar")
            analysisNutritionRow(label: "Protein", key: "protein")
            analysisNutritionRow(label: "Yağ", key: "fat")
        }
        .padding(.horizontal, ResponsiveDesign.Spacing.large)
    }

    private var progressSection: some View {
        VStack(spacing: ResponsiveDesign.Spacing.medium) {
            // Status with rotating balli logo - Fixed height to prevent jumping
            HStack(spacing: ResponsiveDesign.Spacing.small) {
                Image("balli-logo")
                    .resizable()
                    .renderingMode(.template)
                    .foregroundColor(currentStage.iconColor)
                    .frame(width: ResponsiveDesign.Font.scaledSize(24), height: ResponsiveDesign.Font.scaledSize(24))
                    .aspectRatio(contentMode: .fit)
                    .rotationEffect(.degrees(isRotating ? 360 : 0))
                    .animation(
                        isRotating ?
                            .linear(duration: 1.0).repeatForever(autoreverses: false) :
                            .default,
                        value: isRotating
                    )

                Text(currentStage.message)
                    .font(.system(size: ResponsiveDesign.Font.scaledSize(16), weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            }
            .frame(height: ResponsiveDesign.height(24))
            .multilineTextAlignment(.center)
            .onAppear {
                // Start rotation when view appears (if not completed)
                if currentStage != .completed {
                    isRotating = true
                }
            }
            .onChange(of: currentStage) { oldValue, newValue in
                // Stop rotation when analysis completes
                if newValue == .completed {
                    isRotating = false
                } else if !isRotating {
                    isRotating = true
                }
            }

            // Clean progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: ResponsiveDesign.height(3))
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: ResponsiveDesign.height(6))

                    // Progress fill
                    RoundedRectangle(cornerRadius: ResponsiveDesign.height(3))
                        .fill(AppTheme.primaryPurple)
                        .frame(width: geometry.size.width * CGFloat(visualProgress), height: ResponsiveDesign.height(6))
                        .animation(.easeInOut(duration: 0.3), value: visualProgress)
                }
            }
            .frame(height: ResponsiveDesign.height(6))

            // Error message if any
            if let error = errorMessage {
                Text(error)
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, ResponsiveDesign.Spacing.large)
        .padding(.top, ResponsiveDesign.Spacing.large)
    }

    // MARK: - Helper Views

    private func analysisNutritionRow(label: String, key: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: ResponsiveDesign.Font.scaledSize(22), weight: .semibold, design: .rounded))
                .foregroundColor(.primary)

            Spacer()

            HStack(spacing: ResponsiveDesign.Spacing.xxSmall) {
                animatedValue(for: key)

                Text("g")
                    .font(.system(size: ResponsiveDesign.Font.scaledSize(22), weight: .regular, design: .rounded))
                    .foregroundColor(.primary)
            }
        }
        .frame(height: ResponsiveDesign.height(28))
    }

    private func animatedValue(for key: String) -> some View {
        Group {
            if let realValueStr = realValue(for: key) {
                // Real data available - force visible color
                Text(realValueStr)
                    .font(.system(size: ResponsiveDesign.Font.scaledSize(22), weight: .medium, design: .rounded))
                    .foregroundColor(AppTheme.primaryPurple)
            } else {
                // Show placeholder "0"
                Text("0")
                    .font(.system(size: ResponsiveDesign.Font.scaledSize(22), weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            }
        }
    }



    // MARK: - Helper Functions


    // MARK: - Helper Functions

    private func realValue(for key: String) -> String? {
        guard let nutrition = nutritionResult else { return nil }

        switch key {
        case "kalori": return String(format: "%.0f", nutrition.nutrients.calories.value)
        case "carbs": return String(format: "%.1f", nutrition.nutrients.totalCarbohydrates.value)
        case "fiber": return nutrition.nutrients.dietaryFiber.map { String(format: "%.1f", $0.value) }
        case "sugar": return nutrition.nutrients.sugars.map { String(format: "%.1f", $0.value) }
        case "protein": return String(format: "%.1f", nutrition.nutrients.protein.value)
        case "fat": return String(format: "%.1f", nutrition.nutrients.totalFat.value)
        default: return nil
        }
    }

}


// MARK: - Preview

#Preview("Analysis in Progress") {
    ZStack {
        Color(.systemGray6)
            .ignoresSafeArea()

        AnalysisNutritionLabelView(
            capturedImage: UIImage(systemName: "photo.fill") ?? UIImage(),
            currentStage: .processing,
            visualProgress: 0.65,
            errorMessage: nil,
            nutritionResult: nil
        )
    }
}

#Preview("Analysis Starting") {
    ZStack {
        Color(.systemGray6)
            .ignoresSafeArea()

        AnalysisNutritionLabelView(
            capturedImage: UIImage(systemName: "photo.fill") ?? UIImage(),
            currentStage: .analyzing,
            visualProgress: 0.25,
            errorMessage: nil,
            nutritionResult: nil
        )
    }
}