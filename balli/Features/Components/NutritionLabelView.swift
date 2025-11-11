//
//  NutritionLabelView.swift
//  balli
//
//  Reusable nutrition label component for consistent UI across all views
//

import SwiftUI
import OSLog

// Logger accessible to extensions (private to this file)
private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.anaxonic.balli",
    category: "NutritionLabel"
)

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
                // ALWAYS EDITABLE: Brand name - no pencil required
                TextField("Marka", text: $productBrand)
                    .font(.system(size: ResponsiveDesign.Font.scaledSize(30), weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                    .textFieldStyle(.plain)
                    .frame(height: ResponsiveDesign.height(36))

                // ALWAYS EDITABLE: Product name - no pencil required
                TextField("Ürün", text: $productName)
                    .font(.system(size: ResponsiveDesign.Font.scaledSize(26), weight: .medium, design: .rounded))
                    .foregroundColor(.primary)
                    .textFieldStyle(.plain)
                    .frame(height: ResponsiveDesign.height(32))
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
            .padding(.top, ResponsiveDesign.Spacing.xxSmall + ResponsiveDesign.Spacing.medium + ResponsiveDesign.height(24))
            .animation(.easeInOut(duration: 0.15), value: portionGrams)
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
