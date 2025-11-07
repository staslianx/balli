//
//  NutritionalValuesView.swift
//  balli
//
//  Modal view displaying nutritional values with segmented picker and portion adjustment
//  Supports both per-100g and per-serving views with inline portion definition
//

import SwiftUI
import CoreData
import OSLog

/// Modal sheet displaying nutritional values with integrated portion adjustment
struct NutritionalValuesView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.managedObjectContext) private var viewContext

    @ObservedObject var recipe: ObservableRecipeWrapper
    let recipeName: String

    // Per-100g values
    let calories: String
    let carbohydrates: String
    let fiber: String
    let sugar: String
    let protein: String
    let fat: String
    let glycemicLoad: String

    // Per-serving values
    let caloriesPerServing: String
    let carbohydratesPerServing: String
    let fiberPerServing: String
    let sugarPerServing: String
    let proteinPerServing: String
    let fatPerServing: String
    let glycemicLoadPerServing: String
    let totalRecipeWeight: String

    // API insights (optional - from nutrition calculation)
    let digestionTiming: DigestionTiming?

    // Portion multiplier binding for persistence
    @Binding var portionMultiplier: Double

    @State private var selectedTab = 0  // 0 = Porsiyon, 1 = 100g
    @State private var isChartExpanded = false  // For collapsible chart section
    @State private var isPortionAdjustmentExpanded = false  // For portion adjustment section
    @State private var adjustingPortionWeight: Double = 0
    @State private var showSuccessBanner = false

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.balli", category: "NutritionalValuesView")

    // Minimum portion size (50g)
    private let minPortionSize: Double = 50
    // Slider step size (5g)
    private let sliderStep: Double = 5

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ResponsiveDesign.Spacing.medium) {
                    // Segmented Picker
                    Picker("Nutrition Mode", selection: $selectedTab) {
                        Text("Porsiyon").tag(0)
                        Text("100g").tag(1)
                    }
                    .pickerStyle(.segmented)

                    // Portion Controls (always shown in Porsiyon tab)
                    if selectedTab == 0 {
                        if canAdjustPortion {
                            // Full portion card with base adjustment for saved recipes
                            unifiedPortionCard
                        } else {
                            // Multiplier-only card for unsaved recipes (during generation)
                            multiplierOnlyCard
                        }
                    }

                    // Main Card Container - matching LoggedMealsView style
                    VStack(alignment: .leading, spacing: 0) {
                        // Info Text Header (only shown in 100g tab)
                        if selectedTab == 1 {
                            infoText
                                .font(.system(size: ResponsiveDesign.Font.scaledSize(14), weight: .semibold, design: .rounded))
                                .foregroundStyle(.primary)
                                .padding(.horizontal, ResponsiveDesign.Spacing.large)
                                .padding(.top, ResponsiveDesign.Spacing.large)
                                .padding(.bottom, ResponsiveDesign.Spacing.medium)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            // Divider below header
                            Rectangle()
                                .fill(Color.secondary.opacity(0.2))
                                .frame(height: 0.5)
                                .padding(.horizontal, ResponsiveDesign.Spacing.large)
                        }

                        // Nutritional Values Rows
                        VStack(spacing: ResponsiveDesign.Spacing.small) {
                            nutritionRow(
                                label: "Kalori",
                                value: selectedTab == 0
                                    ? String(format: "%.0f", (Double(caloriesPerServing) ?? 0) * portionMultiplier)
                                    : calories,
                                unit: "kcal"
                            )

                            Rectangle()
                                .fill(Color.secondary.opacity(0.1))
                                .frame(height: 0.5)
                                .padding(.horizontal, ResponsiveDesign.Spacing.large)

                            nutritionRow(
                                label: "Karbonhidrat",
                                value: selectedTab == 0
                                    ? String(format: "%.1f", (Double(carbohydratesPerServing) ?? 0) * portionMultiplier)
                                    : carbohydrates,
                                unit: "g"
                            )

                            Rectangle()
                                .fill(Color.secondary.opacity(0.1))
                                .frame(height: 0.5)
                                .padding(.horizontal, ResponsiveDesign.Spacing.large)

                            nutritionRow(
                                label: "Lif",
                                value: selectedTab == 0
                                    ? String(format: "%.1f", (Double(fiberPerServing) ?? 0) * portionMultiplier)
                                    : fiber,
                                unit: "g"
                            )

                            Rectangle()
                                .fill(Color.secondary.opacity(0.1))
                                .frame(height: 0.5)
                                .padding(.horizontal, ResponsiveDesign.Spacing.large)

                            nutritionRow(
                                label: "Şeker",
                                value: selectedTab == 0
                                    ? String(format: "%.1f", (Double(sugarPerServing) ?? 0) * portionMultiplier)
                                    : sugar,
                                unit: "g"
                            )

                            Rectangle()
                                .fill(Color.secondary.opacity(0.1))
                                .frame(height: 0.5)
                                .padding(.horizontal, ResponsiveDesign.Spacing.large)

                            nutritionRow(
                                label: "Protein",
                                value: selectedTab == 0
                                    ? String(format: "%.1f", (Double(proteinPerServing) ?? 0) * portionMultiplier)
                                    : protein,
                                unit: "g"
                            )

                            Rectangle()
                                .fill(Color.secondary.opacity(0.1))
                                .frame(height: 0.5)
                                .padding(.horizontal, ResponsiveDesign.Spacing.large)

                            nutritionRow(
                                label: "Yağ",
                                value: selectedTab == 0
                                    ? String(format: "%.1f", (Double(fatPerServing) ?? 0) * portionMultiplier)
                                    : fat,
                                unit: "g"
                            )

                            // Only show Glycemic Load in Porsiyon tab (it's a per-portion metric)
                            if selectedTab == 0 {
                                Rectangle()
                                    .fill(Color.secondary.opacity(0.1))
                                    .frame(height: 0.5)
                                    .padding(.horizontal, ResponsiveDesign.Spacing.large)

                                nutritionRow(
                                    label: "Glisemik Yük",
                                    value: String(format: "%.0f", (Double(glycemicLoadPerServing) ?? 0) * portionMultiplier),
                                    unit: ""
                                )
                            }
                        }
                        .padding(.vertical, ResponsiveDesign.Spacing.medium)
                    }
                    .background(.clear)
                    .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.card, style: .continuous))
                    .clipShape(RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.card, style: .continuous))
                    .shadow(color: .black.opacity(0.06), radius: ResponsiveDesign.height(8), x: 0, y: ResponsiveDesign.height(4))

                    // Absorption Timing Chart (Porsiyon tab only)
                    if selectedTab == 0 && shouldShowChart {
                        absorptionTimingSection
                    }
                }
                .padding(ResponsiveDesign.Spacing.medium)
            }
            .background(Color(.systemBackground))
            .navigationTitle(recipeName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kapat") {
                        dismiss()
                    }
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                }
            }
            .overlay(alignment: .top) {
                if showSuccessBanner {
                    successBanner
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .onAppear {
                // Initialize slider to current effective portion size
                adjustingPortionWeight = currentPortionSize * portionMultiplier
            }
        }
    }

    // MARK: - Actions

    /// Saves the adjusted portion size to the recipe
    private func savePortionSize() {
        // Ensure recipe exists
        guard recipe.exists else {
            logger.warning("⚠️ Cannot save portion - recipe not available")
            return
        }

        // Validate portion size
        guard adjustingPortionWeight >= minPortionSize else {
            logger.warning("Attempted to save portion below minimum: \(self.adjustingPortionWeight)g")
            return
        }

        guard adjustingPortionWeight <= recipe.totalRecipeWeight else {
            logger.warning("Attempted to save portion above maximum: \(self.adjustingPortionWeight)g")
            return
        }

        // Update recipe
        recipe.updatePortionSize(adjustingPortionWeight)

        // Reset multiplier to 1.0 after saving new portion
        portionMultiplier = 1.0

        // Save to Core Data
        do {
            try viewContext.save()
            logger.info("✅ Saved portion size: \(self.adjustingPortionWeight)g")

            // Show success feedback
            withAnimation(.spring()) {
                showSuccessBanner = true
            }

            // Collapse section after brief delay (Swift 6 concurrency compliance)
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.0))
                withAnimation {
                    showSuccessBanner = false
                }

                try? await Task.sleep(for: .seconds(0.3))
                withAnimation(.easeInOut(duration: 0.3)) {
                    isPortionAdjustmentExpanded = false
                }
            }

        } catch {
            logger.error("❌ Failed to save portion size: \(error.localizedDescription)")
        }
    }

    /// Save portion size for unsaved recipes (updates in-memory state, not CoreData)
    private func savePortionSizeForUnsavedRecipe() {
        logger.info("💾 [PORTION] Saving portion size for unsaved recipe")
        logger.info("   Adjusted weight: \(adjustingPortionWeight)g")
        logger.info("   Current multiplier: \(portionMultiplier)")

        // Validate portion size
        guard adjustingPortionWeight >= minPortionSize else {
            logger.error("❌ [PORTION] Portion size too small: \(adjustingPortionWeight)g")
            return
        }

        let totalWeight = Double(totalRecipeWeight) ?? 0
        guard adjustingPortionWeight <= totalWeight else {
            logger.error("❌ [PORTION] Portion size exceeds total weight: \(adjustingPortionWeight)g > \(totalWeight)g")
            return
        }

        // Update portion multiplier binding
        // This will update the formState in RecipeViewModel
        let newMultiplier = adjustingPortionWeight / currentPortionSize
        portionMultiplier = newMultiplier
        logger.info("✅ [PORTION] Updated multiplier to \(newMultiplier)")

        // Show success banner
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            showSuccessBanner = true
        }

        // Hide banner and collapse section after delay
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                showSuccessBanner = false
            }

            try? await Task.sleep(for: .seconds(0.3))
            withAnimation(.easeInOut(duration: 0.3)) {
                isPortionAdjustmentExpanded = false
            }
        }
    }

    /// Success banner shown after saving
    private var successBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundColor(.white)

            Text("Porsiyon kaydedildi!")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)

            Spacer()
        }
        .padding()
        .background(Color.green)
        .cornerRadius(12)
        .shadow(radius: 8)
        .padding()
    }

    // MARK: - Computed Properties

    /// Whether portion adjustment is available (recipe must be saved)
    private var canAdjustPortion: Bool {
        recipe.exists
    }

    /// Current portion size from recipe
    private var currentPortionSize: Double {
        if recipe.exists {
            let portionSize = recipe.portionSize
            let totalWeight = recipe.totalRecipeWeight
            return portionSize > 0 ? portionSize : totalWeight
        } else {
            // For unsaved recipes, use the string parameter passed to the view
            return Double(totalRecipeWeight) ?? 0
        }
    }

    /// Number of portions the recipe makes based on current adjustment
    private var adjustedPortionCount: Double {
        guard recipe.exists, adjustingPortionWeight > 0 else { return 1.0 }
        return recipe.totalRecipeWeight / adjustingPortionWeight
    }

    /// Nutrition for the adjusted portion size
    private var adjustedPortionNutrition: NutritionValues {
        recipe.calculatePortionNutrition(for: adjustingPortionWeight)
    }

    /// Whether portion is defined in recipe
    private var isPortionDefined: Bool {
        recipe.recipe?.isPortionDefined ?? false
    }

    /// Determines whether the absorption timing chart should be displayed
    /// Chart is hidden if any macronutrient value is zero, negative, or invalid
    private var shouldShowChart: Bool {
        guard let fat = Double(fatPerServing),
              let protein = Double(proteinPerServing),
              let carbs = Double(carbohydratesPerServing) else {
            return false
        }

        // Hide if any value is zero or negative
        return fat > 0 && protein > 0 && carbs > 0
    }

    /// Calculates portion-adjusted macronutrient values for the chart
    private var chartMacros: (fat: Double, protein: Double, carbs: Double) {
        let fat = (Double(fatPerServing) ?? 0) * portionMultiplier
        let protein = (Double(proteinPerServing) ?? 0) * portionMultiplier
        let carbs = (Double(carbohydratesPerServing) ?? 0) * portionMultiplier

        return (fat: fat, protein: protein, carbs: carbs)
    }

    private var infoText: Text {
        if selectedTab == 0 {
            // Porsiyon tab - no longer showing portion weight since it's in the card above
            return Text("")
        } else {
            // 100g tab
            return Text("100g için")
        }
    }

    // MARK: - Components

    /// Unified portion card - clean single card design
    private var unifiedPortionCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isPortionAdjustmentExpanded.toggle()
                    if isPortionAdjustmentExpanded {
                        // Initialize adjustment weight with current EFFECTIVE portion size
                        // This accounts for both the base portion and any multiplier adjustments
                        adjustingPortionWeight = currentPortionSize * portionMultiplier
                    }
                }
            } label: {
                HStack(spacing: ResponsiveDesign.Spacing.medium) {
                    // Left: "Porsiyon" label
                    Text("Porsiyon")
                        .font(.system(size: ResponsiveDesign.Font.scaledSize(16), weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)

                    Spacer()

                    // Center-Right: Current portion or stepper
                    if !isPortionAdjustmentExpanded {
                        // Show current portion value (base portion × multiplier)
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(Int(currentPortionSize * portionMultiplier))")
                                .font(.system(size: ResponsiveDesign.Font.scaledSize(20), weight: .bold, design: .rounded))
                                .foregroundStyle(AppTheme.primaryPurple)

                            Text("g")
                                .font(.system(size: ResponsiveDesign.Font.scaledSize(14), weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                        }

                        // Portion multiplier stepper
                        HStack(spacing: 8) {
                            Button {
                                if portionMultiplier > 0.5 {
                                    portionMultiplier -= 0.5
                                }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundStyle(AppTheme.primaryPurple)
                            }
                            .disabled(portionMultiplier <= 0.5)

                            Text(String(format: "%.1f", portionMultiplier) + "x")
                                .font(.system(size: ResponsiveDesign.Font.scaledSize(16), weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundColor(AppTheme.primaryPurple)
                                .frame(minWidth: 50)

                            Button {
                                portionMultiplier += 0.5
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundStyle(AppTheme.primaryPurple)
                            }
                        }
                    }

                    // Right: Chevron
                    Image(systemName: isPortionAdjustmentExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryPurple)
                }
                .padding(ResponsiveDesign.Spacing.medium)
            }
            .buttonStyle(.plain)

            // Expanded slider content
            if isPortionAdjustmentExpanded {
                VStack(spacing: ResponsiveDesign.Spacing.medium) {
                    Divider()
                        .padding(.horizontal, ResponsiveDesign.Spacing.medium)

                    // Gram display
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(Int(adjustingPortionWeight))")
                            .font(.system(size: ResponsiveDesign.Font.scaledSize(48), weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.primaryPurple)

                        Text("g")
                            .font(.system(size: ResponsiveDesign.Font.scaledSize(20), weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)

                    // Slider
                    if recipe.exists {
                        VStack(spacing: 8) {
                            Slider(
                                value: $adjustingPortionWeight,
                                in: minPortionSize...recipe.totalRecipeWeight,
                                step: sliderStep
                            )
                            .tint(AppTheme.primaryPurple)
                            .onChange(of: adjustingPortionWeight) { _, newValue in
                                // Update portion multiplier to reflect slider changes in main nutrition card
                                // The ratio is: new slider value / recipe's defined portion size
                                guard recipe.portionSize > 0 else { return }
                                let ratio = newValue / recipe.portionSize
                                portionMultiplier = ratio
                            }

                            // Min/Max labels
                            HStack {
                                Text("\(Int(minPortionSize))g")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                Spacer()

                                Text("\(Int(recipe.totalRecipeWeight))g")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal, ResponsiveDesign.Spacing.medium)
                    }

                    // Save button
                    Button(action: savePortionSize) {
                        Text("Porsiyonu Kaydet")
                            .font(.system(size: ResponsiveDesign.Font.scaledSize(16), weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(AppTheme.primaryPurple)
                            .cornerRadius(24)
                    }
                    .padding(.horizontal, ResponsiveDesign.Spacing.medium)
                    .padding(.bottom, ResponsiveDesign.Spacing.medium)
                    .shadow(color: AppTheme.primaryPurple.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .background(.clear)
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.card, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.card, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: ResponsiveDesign.height(8), x: 0, y: ResponsiveDesign.height(4))
    }


    /// Collapsible section containing the absorption timing chart
    private var absorptionTimingSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header (tap to expand/collapse)
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isChartExpanded.toggle()
                }
            } label: {
                HStack {
                    Text("Emilim Zamanlaması")
                        .font(.system(size: ResponsiveDesign.Font.scaledSize(16), weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)

                    Spacer()

                    Image(systemName: isChartExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(AppTheme.primaryPurple)
                }
                .padding(ResponsiveDesign.Spacing.medium)
            }
            .buttonStyle(.plain)

            // Chart content (only when expanded)
            if isChartExpanded {
                let macros = chartMacros

                VStack(spacing: 0) {
                    Divider()
                        .padding(.horizontal, ResponsiveDesign.Spacing.medium)

                    AbsorptionTimingChart(
                        fat: macros.fat,
                        protein: macros.protein,
                        carbs: macros.carbs
                    )
                    .padding(.top, ResponsiveDesign.Spacing.small)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .background(.clear)
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.card, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.card, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: ResponsiveDesign.height(8), x: 0, y: ResponsiveDesign.height(4))
    }

    /// Full portion card for unsaved recipes - includes slider and save button
    private var multiplierOnlyCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isPortionAdjustmentExpanded.toggle()
                    if isPortionAdjustmentExpanded {
                        // Initialize adjustment weight with current portion size
                        adjustingPortionWeight = currentPortionSize * portionMultiplier
                    }
                }
            } label: {
                HStack(spacing: ResponsiveDesign.Spacing.medium) {
                    // Left: "Porsiyon" label
                    Text("Porsiyon")
                        .font(.system(size: ResponsiveDesign.Font.scaledSize(16), weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)

                    Spacer()

                    // Center-Right: Current portion or stepper
                    if !isPortionAdjustmentExpanded {
                        // Show current portion value
                        if let weightValue = Double(totalRecipeWeight), weightValue > 0 {
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text("\(Int(weightValue * portionMultiplier))")
                                    .font(.system(size: ResponsiveDesign.Font.scaledSize(20), weight: .bold, design: .rounded))
                                    .foregroundStyle(AppTheme.primaryPurple)

                                Text("g")
                                    .font(.system(size: ResponsiveDesign.Font.scaledSize(14), weight: .medium, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                        }

                        // Portion multiplier stepper
                        HStack(spacing: 8) {
                            Button {
                                if portionMultiplier > 0.5 {
                                    portionMultiplier -= 0.5
                                }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundStyle(AppTheme.primaryPurple)
                            }
                            .disabled(portionMultiplier <= 0.5)

                            Text(String(format: "%.1f", portionMultiplier) + "x")
                                .font(.system(size: ResponsiveDesign.Font.scaledSize(16), weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundColor(AppTheme.primaryPurple)
                                .frame(minWidth: 50)

                            Button {
                                portionMultiplier += 0.5
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundStyle(AppTheme.primaryPurple)
                            }
                        }
                    }

                    // Right: Chevron
                    Image(systemName: isPortionAdjustmentExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryPurple)
                }
                .padding(ResponsiveDesign.Spacing.medium)
            }
            .buttonStyle(.plain)

            // Expanded slider content
            if isPortionAdjustmentExpanded {
                VStack(spacing: ResponsiveDesign.Spacing.medium) {
                    Divider()
                        .padding(.horizontal, ResponsiveDesign.Spacing.medium)

                    // Gram display
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(Int(adjustingPortionWeight))")
                            .font(.system(size: ResponsiveDesign.Font.scaledSize(48), weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.primaryPurple)

                        Text("g")
                            .font(.system(size: ResponsiveDesign.Font.scaledSize(20), weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)

                    // Slider for unsaved recipe
                    if let maxWeight = Double(totalRecipeWeight), maxWeight > 0 {
                        VStack(spacing: 8) {
                            Slider(
                                value: $adjustingPortionWeight,
                                in: minPortionSize...maxWeight,
                                step: sliderStep
                            )
                            .tint(AppTheme.primaryPurple)
                            .onChange(of: adjustingPortionWeight) { _, newValue in
                                // Update portion multiplier to reflect slider changes
                                guard let baseWeight = Double(totalRecipeWeight), baseWeight > 0 else { return }
                                let ratio = newValue / baseWeight
                                portionMultiplier = ratio
                            }

                            // Min/Max labels
                            HStack {
                                Text("\(Int(minPortionSize))g")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                Spacer()

                                Text("\(Int(maxWeight))g")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal, ResponsiveDesign.Spacing.medium)
                    }

                    // Save button
                    Button(action: savePortionSizeForUnsavedRecipe) {
                        Text("Porsiyonu Kaydet")
                            .font(.system(size: ResponsiveDesign.Font.scaledSize(16), weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(AppTheme.primaryPurple)
                            .cornerRadius(24)
                    }
                    .padding(.horizontal, ResponsiveDesign.Spacing.medium)
                    .padding(.bottom, ResponsiveDesign.Spacing.medium)
                    .shadow(color: AppTheme.primaryPurple.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .background(.clear)
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.card, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.card, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: ResponsiveDesign.height(8), x: 0, y: ResponsiveDesign.height(4))
    }

    private func nutritionRow(
        label: String,
        value: String,
        unit: String
    ) -> some View {
        HStack(spacing: ResponsiveDesign.Spacing.small) {
            Text(label)
                .font(.system(size: ResponsiveDesign.Font.scaledSize(16), weight: .medium, design: .rounded))
                .foregroundStyle(.primary)

            Spacer()

            HStack(spacing: 4) {
                Text(value.isEmpty ? "0" : value)
                    .font(.system(size: ResponsiveDesign.Font.scaledSize(18), weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.primaryPurple)

                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: ResponsiveDesign.Font.scaledSize(13), weight: .regular, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, ResponsiveDesign.Spacing.medium)
        .padding(.horizontal, ResponsiveDesign.Spacing.large)
    }
}

// MARK: - Observable Recipe Wrapper

/// Wrapper to make optional Recipe observable for SwiftUI reactivity
@MainActor
final class ObservableRecipeWrapper: ObservableObject {
    let recipe: Recipe?

    init(recipe: Recipe?) {
        self.recipe = recipe
    }

    /// Convenience accessor for portion size
    var portionSize: Double {
        recipe?.portionSize ?? 0
    }

    /// Convenience accessor for total recipe weight
    var totalRecipeWeight: Double {
        recipe?.totalRecipeWeight ?? 0
    }

    /// Convenience accessor for portion multiplier
    var portionMultiplier: Double {
        get { recipe?.portionMultiplier ?? 1.0 }
        set {
            recipe?.portionMultiplier = newValue
            objectWillChange.send()
        }
    }

    /// Update portion size
    func updatePortionSize(_ size: Double) {
        recipe?.updatePortionSize(size)
        objectWillChange.send()
    }

    /// Calculate nutrition for portion
    func calculatePortionNutrition(for portionWeight: Double) -> NutritionValues {
        guard let recipe = recipe else {
            return NutritionValues(
                calories: 0, carbohydrates: 0, fiber: 0,
                sugar: 0, protein: 0, fat: 0, glycemicLoad: 0
            )
        }
        return recipe.calculatePortionNutrition(for: portionWeight)
    }

    /// Whether recipe exists
    var exists: Bool {
        recipe != nil
    }
}

// MARK: - Preview

#Preview("With Both Values - Low Warning") {
    @Previewable @State var multiplier = 1.0

    let context = PersistenceController.preview.container.viewContext
    let recipe = Recipe(context: context)
    recipe.id = UUID()
    recipe.name = "Izgara Tavuk Salatası"
    recipe.totalRecipeWeight = 350
    recipe.caloriesPerServing = 578
    recipe.carbsPerServing = 28
    recipe.fiberPerServing = 10.5
    recipe.sugarsPerServing = 7
    recipe.proteinPerServing = 108.5
    recipe.fatPerServing = 12.6
    recipe.glycemicLoadPerServing = 14
    recipe.portionSize = 350

    return NutritionalValuesView(
        recipe: ObservableRecipeWrapper(recipe: recipe),
        recipeName: "Izgara Tavuk Salatası",
        // Per-100g
        calories: "165",
        carbohydrates: "8",
        fiber: "3",
        sugar: "2",
        protein: "31",
        fat: "3.6",
        glycemicLoad: "4",
        // Per-serving (assuming 350g total)
        caloriesPerServing: "578",
        carbohydratesPerServing: "28",
        fiberPerServing: "10.5",
        sugarPerServing: "7",
        proteinPerServing: "108.5",
        fatPerServing: "12.6",
        glycemicLoadPerServing: "14",
        totalRecipeWeight: "350",
        digestionTiming: nil,
        portionMultiplier: $multiplier
    )
    .environment(\.managedObjectContext, context)
}

#Preview("High Fat Recipe - Danger Warning") {
    @Previewable @State var multiplier = 1.0

    let context = PersistenceController.preview.container.viewContext
    let recipe = Recipe(context: context)
    recipe.id = UUID()
    recipe.name = "Carbonara Makarna"
    recipe.totalRecipeWeight = 400
    recipe.caloriesPerServing = 720
    recipe.carbsPerServing = 48
    recipe.fiberPerServing = 8
    recipe.sugarsPerServing = 4
    recipe.proteinPerServing = 32
    recipe.fatPerServing = 35
    recipe.glycemicLoadPerServing = 20
    recipe.portionSize = 400

    return NutritionalValuesView(
        recipe: ObservableRecipeWrapper(recipe: recipe),
        recipeName: "Carbonara Makarna",
        // Per-100g
        calories: "180",
        carbohydrates: "12",
        fiber: "2",
        sugar: "1",
        protein: "8",
        fat: "12",
        glycemicLoad: "8",
        // Per-serving (high fat = danger warning)
        caloriesPerServing: "720",
        carbohydratesPerServing: "48",
        fiberPerServing: "8",
        sugarPerServing: "4",
        proteinPerServing: "32",
        fatPerServing: "35",  // High fat triggers danger warning
        glycemicLoadPerServing: "20",
        totalRecipeWeight: "400",
        digestionTiming: nil,
        portionMultiplier: $multiplier
    )
    .environment(\.managedObjectContext, context)
}

#Preview("Empty Values") {
    @Previewable @State var multiplier = 1.0

    let context = PersistenceController.preview.container.viewContext
    let recipe = Recipe(context: context)
    recipe.id = UUID()
    recipe.name = "Test Tarifi"
    recipe.totalRecipeWeight = 500
    recipe.portionSize = 0

    return NutritionalValuesView(
        recipe: ObservableRecipeWrapper(recipe: recipe),
        recipeName: "Test Tarifi",
        calories: "",
        carbohydrates: "",
        fiber: "",
        sugar: "",
        protein: "",
        fat: "",
        glycemicLoad: "",
        caloriesPerServing: "",
        carbohydratesPerServing: "",
        fiberPerServing: "",
        sugarPerServing: "",
        proteinPerServing: "",
        fatPerServing: "",
        glycemicLoadPerServing: "",
        totalRecipeWeight: "",
        digestionTiming: nil,
        portionMultiplier: $multiplier
    )
    .environment(\.managedObjectContext, context)
}
