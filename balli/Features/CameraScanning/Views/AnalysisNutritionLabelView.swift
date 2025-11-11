//
//  AnalysisNutritionLabelView.swift
//  balli
//
//  Nutrition label view shown during AI analysis with real-time data updates
//

import SwiftUI
import os.log

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

    // MARK: - Logger
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.balli", category: "AnalysisView")

    // MARK: - Body

    var body: some View {
        let _ = logger.debug("📱 VIEW BODY: currentStage=\(String(describing: currentStage))")
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
            // Status text CENTERED with rotating logo on left of TEXT
            HStack(spacing: ResponsiveDesign.Spacing.medium) {
                Spacer()

                // Rotating balli logo
                Image("balli-logo")
                    .resizable()
                    .renderingMode(.template)
                    .foregroundColor(currentStage.iconColor)
                    .frame(width: ResponsiveDesign.Font.scaledSize(28), height: ResponsiveDesign.Font.scaledSize(28))
                    .aspectRatio(contentMode: .fit)
                    .rotationEffect(.degrees(isRotating ? 360 : 0))
                    .animation(
                        isRotating ?
                            .linear(duration: 1.0).repeatForever(autoreverses: false) :
                            .default,
                        value: isRotating
                    )

                // Status text with shimmer animation (conditionally applied)
                Text(currentStage.message)
                    .font(.system(size: ResponsiveDesign.Font.scaledSize(20), weight: .medium, design: .rounded))
                    .foregroundColor(
                        currentStage == .completed
                            ? .secondary
                            : (colorScheme == .dark ? Color.white.opacity(0.7) : Color.black.opacity(0.7))
                    )
                    .modifier(
                        ConditionalShimmer(
                            isActive: currentStage != .completed,
                            duration: 2.5,
                            bounceBack: false
                        )
                    )
                    .id(currentStage) // Force text recreation on stage change

                Spacer()
            }
            .onAppearExcludingPreview {
                // Start rotation when view appears (if not completed)
                // Logging and animations only in real app, not previews
                logger.info("✅ VIEW APPEARED: currentStage=\(String(describing: self.currentStage))")
                if currentStage != .completed {
                    logger.info("🎬 STARTING ANIMATIONS")
                    isRotating = true
                }
            }
            .onChange(of: currentStage) { oldValue, newValue in
                // Skip logging in preview mode
                guard !ProcessInfo.processInfo.isPreviewMode else {
                    // Still handle animation state changes
                    if newValue == .completed {
                        isRotating = false
                    } else if !isRotating {
                        isRotating = true
                    }
                    return
                }

                logger.info("🔄 STAGE CHANGED: \(String(describing: oldValue)) → \(String(describing: newValue))")
                // Stop rotation when analysis completes
                if newValue == .completed {
                    logger.info("🛑 STOPPING ANIMATIONS")
                    isRotating = false
                } else if !isRotating {
                    logger.info("▶️ RESTARTING ANIMATIONS")
                    isRotating = true
                }
            }

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

        // Use locale-aware formatting (comma in Turkish, period in US)
        switch key {
        case "kalori": return nutrition.nutrients.calories.value.asLocalizedDecimal(decimalPlaces: 0)
        case "carbs": return nutrition.nutrients.totalCarbohydrates.value.asLocalizedDecimal(decimalPlaces: 1)
        case "fiber": return nutrition.nutrients.dietaryFiber.map { $0.value.asLocalizedDecimal(decimalPlaces: 1) }
        case "sugar": return nutrition.nutrients.sugars.map { $0.value.asLocalizedDecimal(decimalPlaces: 1) }
        case "protein": return nutrition.nutrients.protein.value.asLocalizedDecimal(decimalPlaces: 1)
        case "fat": return nutrition.nutrients.totalFat.value.asLocalizedDecimal(decimalPlaces: 1)
        default: return nil
        }
    }

}

// MARK: - Preview

#Preview("Stage 1: İnceliyorum") {
    ZStack {
        Color(.systemGray6)
            .ignoresSafeArea()

        AnalysisNutritionLabelView(
            capturedImage: PreviewMocks.sampleImage,
            currentStage: .preparing,
            visualProgress: 0.15,
            errorMessage: nil,
            nutritionResult: nil
        )
    }
}

#Preview("Stage 2: Analiz ediyorum") {
    ZStack {
        Color(.systemGray6)
            .ignoresSafeArea()

        AnalysisNutritionLabelView(
            capturedImage: PreviewMocks.sampleImage,
            currentStage: .analyzing,
            visualProgress: 0.33,
            errorMessage: nil,
            nutritionResult: nil
        )
    }
}

#Preview("Stage 3: Sadeleştiriyorum") {
    ZStack {
        Color(.systemGray6)
            .ignoresSafeArea()

        AnalysisNutritionLabelView(
            capturedImage: PreviewMocks.sampleImage,
            currentStage: .reading,
            visualProgress: 0.41,
            errorMessage: nil,
            nutritionResult: nil
        )
    }
}

#Preview("Stage 4: Etiketini oluşturuyorum") {
    ZStack {
        Color(.systemGray6)
            .ignoresSafeArea()

        AnalysisNutritionLabelView(
            capturedImage: PreviewMocks.sampleImage,
            currentStage: .sending,
            visualProgress: 0.64,
            errorMessage: nil,
            nutritionResult: nil
        )
    }
}

#Preview("Stage 5: Sağlamasını yapıyorum") {
    ZStack {
        Color(.systemGray6)
            .ignoresSafeArea()

        AnalysisNutritionLabelView(
            capturedImage: PreviewMocks.sampleImage,
            currentStage: .processing,
            visualProgress: 0.73,
            errorMessage: nil,
            nutritionResult: nil
        )
    }
}

#Preview("Stage 6: Son bi bakıyorum...") {
    ZStack {
        Color(.systemGray6)
            .ignoresSafeArea()

        AnalysisNutritionLabelView(
            capturedImage: PreviewMocks.sampleImage,
            currentStage: .validating,
            visualProgress: 0.92,
            errorMessage: nil,
            nutritionResult: nil
        )
    }
}

#Preview("Completed") {
    ZStack {
        Color(.systemGray6)
            .ignoresSafeArea()

        AnalysisNutritionLabelView(
            capturedImage: PreviewMocks.sampleImage,
            currentStage: .completed,
            visualProgress: 1.0,
            errorMessage: nil,
            nutritionResult: PreviewMocks.nutritionResult(
                productName: "Çikolatalı Gofret",
                brandName: "Ülker",
                calories: 542,
                carbs: 58.2,
                protein: 7.8,
                fat: 30.5,
                servingSize: 100
            )
        )
    }
}
