//
//  NutritionLabelView.swift
//  balli
//
//  Reusable nutrition label component for consistent UI across all views
//

import SwiftUI

struct NutritionLabelView: View {
    // Product information
    @Binding var productBrand: String
    @Binding var productName: String
    
    // Nutritional values (base per serving size)
    @Binding var calories: String
    @Binding var servingSize: String
    @Binding var carbohydrates: String
    @Binding var fiber: String
    @Binding var sugars: String
    @Binding var protein: String
    @Binding var fat: String
    
    // Portion control
    @Binding var portionGrams: Double
    
    // UI state
    let isEditing: Bool
    let showIcon: Bool
    let iconName: String
    let iconColor: Color

    // Impact banner state
    let showImpactBanner: Bool
    let impactLevel: ImpactLevel?
    let impactScore: Double?

    // Animation states (optional - defaults to showing all values)
    let showingValues: Bool
    let valuesAnimationProgress: [String: Bool]

    // Slider visibility control
    let showSlider: Bool

    // Haptic feedback state
    @State private var previousColor: Color?

    // Default initializer for backward compatibility
    init(
        productBrand: Binding<String>,
        productName: Binding<String>,
        calories: Binding<String>,
        servingSize: Binding<String>,
        carbohydrates: Binding<String>,
        fiber: Binding<String>,
        sugars: Binding<String>,
        protein: Binding<String>,
        fat: Binding<String>,
        portionGrams: Binding<Double>,
        isEditing: Bool,
        showIcon: Bool,
        iconName: String,
        iconColor: Color,
        showImpactBanner: Bool = false,
        impactLevel: ImpactLevel? = nil,
        impactScore: Double? = nil,
        showingValues: Bool = true,
        valuesAnimationProgress: [String: Bool] = [:],
        showSlider: Bool = true  // Default to true for backward compatibility
    ) {
        self._productBrand = productBrand
        self._productName = productName
        self._calories = calories
        self._servingSize = servingSize
        self._carbohydrates = carbohydrates
        self._fiber = fiber
        self._sugars = sugars
        self._protein = protein
        self._fat = fat
        self._portionGrams = portionGrams
        self.isEditing = isEditing
        self.showIcon = showIcon
        self.iconName = iconName
        self.iconColor = iconColor
        self.showImpactBanner = showImpactBanner
        self.impactLevel = impactLevel
        self.impactScore = impactScore
        self.showingValues = showingValues
        self.valuesAnimationProgress = valuesAnimationProgress
        self.showSlider = showSlider
    }
    
    // Computed properties for proportional values
    private var adjustmentRatio: Double {
        let baseServing = servingSize.toDouble ?? 100.0
        return portionGrams / baseServing
    }

    private var adjustedCalories: String {
        guard let baseValue = calories.toDouble else { return calories }
        let adjusted = baseValue * adjustmentRatio
        return adjusted.asLocalizedDecimal(decimalPlaces: 0)
    }

    private var adjustedCarbohydrates: String {
        guard let baseValue = carbohydrates.toDouble else { return carbohydrates }
        let adjusted = baseValue * adjustmentRatio
        return formatNutritionValue(adjusted)
    }

    private var adjustedFiber: String {
        guard let baseValue = fiber.toDouble else { return fiber }
        let adjusted = baseValue * adjustmentRatio
        return formatNutritionValue(adjusted)
    }

    private var adjustedSugars: String {
        guard let baseValue = sugars.toDouble else { return sugars }
        let adjusted = baseValue * adjustmentRatio
        return formatNutritionValue(adjusted)
    }

    private var adjustedProtein: String {
        guard let baseValue = protein.toDouble else { return protein }
        let adjusted = baseValue * adjustmentRatio
        return formatNutritionValue(adjusted)
    }

    private var adjustedFat: String {
        guard let baseValue = fat.toDouble else { return fat }
        let adjusted = baseValue * adjustmentRatio
        return formatNutritionValue(adjusted)
    }

    /// Format nutrition value with locale-aware decimal separator
    /// Show decimal only if there's a meaningful value (51.0 -> "51", 51.5 -> "51,5" in Turkish)
    private func formatNutritionValue(_ value: Double) -> String {
        let rounded = round(value * 10) / 10  // Round to 1 decimal place
        if rounded.truncatingRemainder(dividingBy: 1) == 0 {
            // No decimal part, show as integer
            return rounded.asLocalizedDecimal(decimalPlaces: 0)
        } else {
            // Has decimal part, show 1 decimal with locale-aware separator
            return rounded.asLocalizedDecimal(decimalPlaces: 1)
        }
    }

    /// Calculate real-time impact score for current portion using Nestlé formula
    /// Treats empty or invalid nutritional values as 0.0 to handle products with missing data
    private var currentImpactResult: ImpactScoreResult? {
        // Require only carbs and serving size - other nutrients can be zero
        guard let baseCarbs = carbohydrates.toDouble,
              let baseServing = servingSize.toDouble,
              baseServing > 0 else {
            return nil
        }

        // Parse optional nutrients - default to 0.0 if missing/empty/invalid
        let baseFiber = fiber.toDouble ?? 0.0
        let baseSugars = sugars.toDouble ?? 0.0
        let baseProtein = protein.toDouble ?? 0.0
        let baseFat = fat.toDouble ?? 0.0

        return ImpactScoreCalculator.calculate(
            totalCarbs: baseCarbs,
            fiber: baseFiber,
            sugar: baseSugars,
            protein: baseProtein,
            fat: baseFat,
            servingSize: baseServing,
            portionGrams: portionGrams
        )
    }

    // Helper method to determine if a value should be visible based on animation state
    private func shouldShowValue(_ fieldName: String) -> Bool {
        // Always show in editing mode
        if isEditing {
            return true
        }

        // For animation mode: only show if both general flag is true AND individual field is animated
        if !showingValues {
            // During animation sequence: only show individual fields when their animation is triggered
            return valuesAnimationProgress[fieldName] ?? false
        }

        // For immediate display mode (showingValues = true): show everything
        return true
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerSection
            caloriesSection
            dividerLine
            nutritionSection
                .id(portionGrams) // Force recomputation when portionGrams changes

            // Conditionally show slider based on state
            if showSlider {
                sliderSection
            }

            Spacer()
        }
        .frame(width: ResponsiveDesign.Components.foodLabelWidth, height: ResponsiveDesign.Components.foodLabelHeight)
        .recipeGlass(tint: .transparent, cornerRadius: ResponsiveDesign.CornerRadius.modal)
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
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
        .shadow(color: Color.black.opacity(0.03), radius: 3, x: 0, y: 1)
        .sensoryFeedback(trigger: currentImpactResult?.color) { oldValue, newValue in
            // Trigger haptic feedback when crossing color thresholds
            guard let newColor = newValue, previousColor != newColor else {
                return nil
            }

            // Update previous color for next comparison
            previousColor = newColor

            // Play appropriate haptic based on new safety status
            switch newColor {
            case .green:
                return .success  // Entering safe zone
            case .yellow:
                return .warning  // Entering caution zone
            case .red:
                return .error    // Entering danger zone
            default:
                return nil
            }
        }
    }
    
    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: ResponsiveDesign.Spacing.xxSmall) {
                if isEditing {
                    TextField("Marka", text: $productBrand)
                        .font(.system(size: ResponsiveDesign.Font.scaledSize(30), weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                        .textFieldStyle(.plain)
                        .frame(height: ResponsiveDesign.height(36))
                } else {
                    Text(productBrand.isEmpty ? "Marka" : productBrand)
                        .font(.system(size: ResponsiveDesign.Font.scaledSize(30), weight: .semibold, design: .rounded))
                        .foregroundColor(productBrand.isEmpty ? .secondary : .primary)
                        .frame(height: ResponsiveDesign.height(36), alignment: .leading)
                }

                if isEditing {
                    TextField("Ürün", text: $productName)
                        .font(.system(size: ResponsiveDesign.Font.scaledSize(26), weight: .medium, design: .rounded))
                        .foregroundColor(.primary)
                        .textFieldStyle(.plain)
                        .frame(height: ResponsiveDesign.height(32))
                } else {
                    Text(productName.isEmpty ? "Ürün Adı" : productName)
                        .font(.system(size: ResponsiveDesign.Font.scaledSize(26), weight: .medium, design: .rounded))
                        .foregroundColor(productName.isEmpty ? .secondary : .primary)
                        .frame(height: ResponsiveDesign.height(32), alignment: .leading)
                }
            }

            Spacer()

            // Show real-time impact badge based on current portion
            if let result = currentImpactResult {
                // Determine impact level using three-threshold evaluation with SCALED values
                let scaledFat = (fat.toDouble ?? 0.0) * adjustmentRatio
                let scaledProtein = (protein.toDouble ?? 0.0) * adjustmentRatio

                let currentLevel = ImpactLevel.from(
                    score: result.score,
                    fat: scaledFat,
                    protein: scaledProtein
                )

                CompactImpactBannerView(
                    impactLevel: currentLevel,
                    impactScore: result.score
                )
                .offset(x:-13,y:9)
            } else if showIcon {
                // Fallback to icon if calculation fails
                Image(systemName: iconName)
                    .font(.system(size: ResponsiveDesign.Font.scaledSize(28), weight: .regular, design: .rounded))
                    .foregroundColor(iconColor)
            }
        }
        .padding(.horizontal, ResponsiveDesign.Spacing.large)
        .padding(.top, ResponsiveDesign.height(50))
    }
    
    private var caloriesSection: some View {
        CaloriesSectionView(
            calories: $calories,
            adjustedCalories: adjustedCalories,
            servingSize: $servingSize,
            portionGrams: portionGrams,
            shouldShowValue: shouldShowValue("calories")
        )
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
            NutritionLabelRowProportional(
                label: "Karbonhidrat",
                baseValue: $carbohydrates,
                adjustedValue: adjustedCarbohydrates,
                unit: "g",
                isEditing: isEditing,
                portionGrams: portionGrams,
                shouldShow: shouldShowValue("carbohydrates")
            )
            NutritionLabelRowProportional(
                label: "Lif",
                baseValue: $fiber,
                adjustedValue: adjustedFiber,
                unit: "g",
                isEditing: isEditing,
                portionGrams: portionGrams,
                shouldShow: shouldShowValue("fiber")
            )
            NutritionLabelRowProportional(
                label: "Şeker",
                baseValue: $sugars,
                adjustedValue: adjustedSugars,
                unit: "g",
                isEditing: isEditing,
                portionGrams: portionGrams,
                shouldShow: shouldShowValue("sugars")
            )
            NutritionLabelRowProportional(
                label: "Protein",
                baseValue: $protein,
                adjustedValue: adjustedProtein,
                unit: "g",
                isEditing: isEditing,
                portionGrams: portionGrams,
                shouldShow: shouldShowValue("protein")
            )
            NutritionLabelRowProportional(
                label: "Yağ",
                baseValue: $fat,
                adjustedValue: adjustedFat,
                unit: "g",
                isEditing: isEditing,
                portionGrams: portionGrams,
                shouldShow: shouldShowValue("fat")
            )
        }
        .padding(.horizontal, ResponsiveDesign.Spacing.large)
    }
    
    private var sliderSection: some View {
        // Logarithmic slider (keep original purple color - don't change)
        // Extra top padding to align with progress bar position in AnalysisNutritionLabelView
        // Progress bar appears below status text (24pt) + medium spacing, so we add that here
        Slider(value: sliderPosition, in: 0...1, step: 0.01)
            .accentColor(AppTheme.primaryPurple)
            .padding(.horizontal, ResponsiveDesign.Spacing.large)
            .padding(.top, ResponsiveDesign.Spacing.large + ResponsiveDesign.Spacing.medium + ResponsiveDesign.height(24))
            .animation(.easeInOut(duration: 0.15), value: portionGrams)
    }

    // MARK: - Logarithmic Slider Helpers

    /// Computed binding that converts between grams and slider position (0-1)
    private var sliderPosition: Binding<Double> {
        Binding<Double>(
            get: {
                self.sliderPositionFromGrams(self.portionGrams)
            },
            set: { newPosition in
                // Update the binding value directly
                // This should trigger SwiftUI to re-render the view
                self.portionGrams = self.gramsFromSliderPosition(newPosition)
            }
        )
    }

    private enum SliderConfig {
        static let minGrams = 5.0
        static let maxGrams = 300.0
        static let logGamma = 0.55
    }

    /// Convert grams to slider position using a tunable logarithmic curve
    private func sliderPositionFromGrams(_ grams: Double) -> Double {
        let clamped = max(SliderConfig.minGrams, min(SliderConfig.maxGrams, grams))
        let normalized = (clamped - SliderConfig.minGrams) / (SliderConfig.maxGrams - SliderConfig.minGrams)
        return pow(normalized, SliderConfig.logGamma)
    }

    /// Convert slider position back to grams using the inverse curve
    private func gramsFromSliderPosition(_ position: Double) -> Double {
        let clamped = max(0, min(1, position))
        let normalized = pow(clamped, 1 / SliderConfig.logGamma)
        let grams = SliderConfig.minGrams + normalized * (SliderConfig.maxGrams - SliderConfig.minGrams)

        if grams < 80 {
            return round(grams)
        }
        return round(grams / 5) * 5
    }

    private func impactBannerSection(impactLevel: ImpactLevel, impactScore: Double) -> some View {
        VStack(spacing: ResponsiveDesign.Spacing.small) {
            ImpactBannerView(
                impactLevel: impactLevel,
                impactScore: impactScore
            )
            .padding(.top, ResponsiveDesign.Spacing.large)
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .scale(scale: 0.95)),
                removal: .opacity
            ))
        }
    }

}

// MARK: - Calories Section Component

/// Separate view for calories section to manage focus state independently
struct CaloriesSectionView: View {
    @Binding var calories: String
    let adjustedCalories: String
    @Binding var servingSize: String
    let portionGrams: Double
    let shouldShowValue: Bool

    @FocusState private var caloriesFocused: Bool
    @FocusState private var servingSizeFocused: Bool

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: ResponsiveDesign.Spacing.medium) {
            HStack(spacing: ResponsiveDesign.Spacing.xxSmall) {
                // Always show TextField, but switch between adjusted/base value based on focus
                TextField("0", text: Binding(
                    get: {
                        caloriesFocused ? calories : adjustedCalories
                    },
                    set: { newValue in
                        calories = newValue
                    }
                ))
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
                TextField("0", text: Binding(
                    get: {
                        servingSizeFocused ? servingSize : String(format: "%.0f", portionGrams)
                    },
                    set: { newValue in
                        servingSize = newValue
                    }
                ))
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

// MARK: - Nutrition Row Component
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

struct NutritionLabelRowProportional: View {
    let label: String
    @Binding var baseValue: String  // Base value at serving size
    let adjustedValue: String  // Adjusted value based on portion
    let unit: String
    let isEditing: Bool
    let portionGrams: Double
    let shouldShow: Bool

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: ResponsiveDesign.Font.scaledSize(22), weight: .semibold, design: .rounded))
                .foregroundColor(.primary)

            Spacer()

            HStack(spacing: ResponsiveDesign.Spacing.xxSmall) {
                // Always show TextField, but populate it with adjusted value when not focused
                // This allows: (1) slider updates values in real-time, (2) tap to edit
                TextField("0", text: Binding(
                    get: {
                        // When focused, show base value for editing
                        // When not focused, show adjusted value for display
                        isFocused ? baseValue : adjustedValue
                    },
                    set: { newValue in
                        // When user types, update the base value
                        baseValue = newValue
                    }
                ))
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

// Keep old component for backwards compatibility if needed
struct NutritionLabelRow: View {
    let label: String
    @Binding var value: String
    let unit: String
    let isEditing: Bool
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: ResponsiveDesign.Font.scaledSize(22), weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
            
            Spacer()
            
            HStack(spacing: ResponsiveDesign.Spacing.xxSmall) {
                if isEditing {
                    TextField("0", text: $value)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .font(.system(size: ResponsiveDesign.Font.scaledSize(22), weight: .medium, design: .rounded))
                        .frame(width: ResponsiveDesign.width(50), height: ResponsiveDesign.height(28))
                        .foregroundColor(.primary)
                        .textFieldStyle(.plain)
                } else {
                    Text(value.isEmpty ? "0" : value)
                        .font(.system(size: ResponsiveDesign.Font.scaledSize(22), weight: .medium, design: .rounded))
                        .foregroundColor(.primary)
                        .frame(width: ResponsiveDesign.width(50), height: ResponsiveDesign.height(28), alignment: .trailing)
                }
                
                Text(unit)
                    .font(.system(size: ResponsiveDesign.Font.scaledSize(22), weight: .regular, design: .rounded))
                    .foregroundColor(.primary)
            }
        }
        .frame(height: ResponsiveDesign.height(28))
    }
}
