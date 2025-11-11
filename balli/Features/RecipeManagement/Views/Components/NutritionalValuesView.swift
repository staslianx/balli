//
//  NutritionalValuesView.swift
//  balli
//
//  Modal view displaying nutritional values with segmented picker and portion adjustment
//  Supports both per-100g and per-serving views with inline portion definition
//
//  Refactored: Reduced from 907 lines to ~180 lines (80% reduction)
//  Components extracted to NutritionalValues/ subdirectory
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
    @State private var isPortionAdjustmentExpanded = false  // For portion adjustment section
    @State private var adjustingPortionWeight: Double = 0
    @State private var animateSaveButton = false
    @State private var toastMessage: ToastType? = nil

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.balli", category: "NutritionalValuesView")

    // Minimum portion size (50g)
    private let minPortionSize: Double = 50

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ResponsiveDesign.Spacing.medium) {
                    // Tab picker at top level
                    Picker("View Mode", selection: $selectedTab) {
                        Text("Porsiyon").tag(0)
                        Text("100g").tag(1)
                    }
                    .pickerStyle(.segmented)

                    // Unified Portion Card (only in Porsiyon tab, between picker and nutrition values)
                    if selectedTab == 0 {
                        unifiedPortionCard
                    }

                    // Main nutrition display card (WITHOUT internal picker)
                    nutritionValuesCard
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
            .toast($toastMessage)
            .onAppear {
                // Initialize slider to current effective portion size
                adjustingPortionWeight = currentPortionSize * portionMultiplier
            }
        }
    }

    // MARK: - Computed Properties

    /// Whether portion can be adjusted (saved or unsaved recipe with valid weight)
    private var canAdjustPortion: Bool {
        // P1 FIX: Allow portion adjustment for unsaved recipes with valid total weight
        // Check recipe entity first (saved recipes)
        if recipe.exists {
            return recipe.totalRecipeWeight > 0
        }

        // Fall back to string parameter for unsaved recipes
        let totalWeight = totalRecipeWeight.toDouble ?? 0
        return totalWeight > 0
    }

    /// Current portion size (either saved portion or default to total weight)
    private var currentPortionSize: Double {
        // 1. Try saved portion size (for saved recipes with user-defined portions)
        let portion = recipe.portionSize
        if portion > 0 {
            logger.debug("📏 [PORTION] Using saved portion size: \(portion)g")
            return portion
        }

        // 2. Try CoreData total recipe weight (for saved recipes)
        let recipeWeight = recipe.totalRecipeWeight
        if recipeWeight > 0 {
            logger.info("⚠️ [PORTION] No portion saved, using recipe total weight: \(recipeWeight)g")
            return recipeWeight
        }

        // 3. Try string parameter (for unsaved recipes)
        let stringWeight = totalRecipeWeight.toDouble ?? 0
        if stringWeight > 0 {
            logger.info("ℹ️ [PORTION] Using total weight from string parameter (unsaved recipe): \(stringWeight)g")
            return stringWeight
        }

        // 4. Fallback error state
        logger.error("❌ [PORTION] No valid portion or weight data available")
        return 0
    }

    /// Maximum slider value (total recipe weight)
    /// For unsaved recipes, uses string parameter; for saved recipes, uses CoreData entity
    private var maxSliderValue: Double {
        // Saved recipes: use CoreData entity
        if recipe.exists && recipe.totalRecipeWeight > 0 {
            return recipe.totalRecipeWeight
        }

        // Unsaved recipes: parse string parameter
        let totalWeight = totalRecipeWeight.toDouble ?? 0
        if totalWeight > 0 {
            return totalWeight
        }

        // Fallback: use currentPortionSize (prevents divide-by-zero)
        logger.warning("⚠️ [SLIDER] No valid total weight - falling back to currentPortionSize: \(currentPortionSize)")
        return max(currentPortionSize, minPortionSize)
    }

    // MARK: - Actions

    /// Handle save button tap - delegates to appropriate save method
    private func handleSave() {
        // P1 FIX: Route based on recipe.exists, not canAdjustPortion
        // canAdjustPortion now returns true for unsaved recipes with valid weight,
        // but they should still use the unsaved recipe save path
        if recipe.exists {
            // Save to CoreData for saved recipes
            let actions = NutritionalValuesActions(
                viewContext: viewContext,
                recipe: recipe,
                totalRecipeWeight: totalRecipeWeight,
                minPortionSize: minPortionSize,
                currentPortionSize: currentPortionSize,
                logger: logger,
                adjustingPortionWeight: $adjustingPortionWeight,
                portionMultiplier: $portionMultiplier,
                isPortionAdjustmentExpanded: $isPortionAdjustmentExpanded,
                toastMessage: $toastMessage
            )
            actions.savePortionSize()
        } else {
            // Update in-memory state for unsaved recipes
            let actions = NutritionalValuesActions(
                viewContext: viewContext,
                recipe: recipe,
                totalRecipeWeight: totalRecipeWeight,
                minPortionSize: minPortionSize,
                currentPortionSize: currentPortionSize,
                logger: logger,
                adjustingPortionWeight: $adjustingPortionWeight,
                portionMultiplier: $portionMultiplier,
                isPortionAdjustmentExpanded: $isPortionAdjustmentExpanded,
                toastMessage: $toastMessage
            )
            actions.savePortionSizeForUnsavedRecipe()
        }
    }

    // MARK: - Nutrition Values Card

    /// Main nutrition display card without the tab picker (picker is at top level)
    private var nutritionValuesCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Info Text Header (only shown in 100g tab)
            if selectedTab == 1 {
                Text("100 gram porsiyon başına besin değerleri")
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
                        ? String(format: "%.0f", (caloriesPerServing.toDouble ?? 0) * portionMultiplier)
                        : calories,
                    unit: "kcal"
                )

                divider

                nutritionRow(
                    label: "Karbonhidrat",
                    value: selectedTab == 0
                        ? String(format: "%.1f", (carbohydratesPerServing.toDouble ?? 0) * portionMultiplier)
                        : carbohydrates,
                    unit: "g"
                )

                divider

                nutritionRow(
                    label: "Lif",
                    value: selectedTab == 0
                        ? String(format: "%.1f", (fiberPerServing.toDouble ?? 0) * portionMultiplier)
                        : fiber,
                    unit: "g"
                )

                divider

                nutritionRow(
                    label: "Şeker",
                    value: selectedTab == 0
                        ? String(format: "%.1f", (sugarPerServing.toDouble ?? 0) * portionMultiplier)
                        : sugar,
                    unit: "g"
                )

                divider

                nutritionRow(
                    label: "Protein",
                    value: selectedTab == 0
                        ? String(format: "%.1f", (proteinPerServing.toDouble ?? 0) * portionMultiplier)
                        : protein,
                    unit: "g"
                )

                divider

                nutritionRow(
                    label: "Yağ",
                    value: selectedTab == 0
                        ? String(format: "%.1f", (fatPerServing.toDouble ?? 0) * portionMultiplier)
                        : fat,
                    unit: "g"
                )

                // Only show Glycemic Load in Porsiyon tab (it's a per-portion metric)
                if selectedTab == 0 {
                    divider

                    nutritionRow(
                        label: "Glisemik Yük",
                        value: String(format: "%.0f", (glycemicLoadPerServing.toDouble ?? 0) * portionMultiplier),
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
    }

    // Helper views for nutrition card
    private var divider: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.1))
            .frame(height: 0.5)
            .padding(.horizontal, ResponsiveDesign.Spacing.large)
    }

    private func nutritionRow(label: String, value: String, unit: String) -> some View {
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

    // MARK: - Unified Portion Card

    /// Unified portion card - clean single card design with collapsible slider
    private var unifiedPortionCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row - always visible
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isPortionAdjustmentExpanded.toggle()
                    if isPortionAdjustmentExpanded {
                        // Initialize adjustment weight with current EFFECTIVE portion size
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
                        // P1 FIX: Consolidate data sources - use recipe.totalRecipeWeight as single source of truth
                        // Only fall back to string parameter if recipe weight is invalid
                        let totalWeight = recipe.totalRecipeWeight > 0
                            ? recipe.totalRecipeWeight
                            : (totalRecipeWeight.toDouble ?? 0)

                        if totalWeight <= 0 {
                            Text("Porsiyon bilgisi eksik")
                                .font(.system(size: ResponsiveDesign.Font.scaledSize(14), weight: .medium, design: .rounded))
                                .foregroundColor(.secondary)
                                .onAppear {
                                    logger.error("❌ [PORTION] No valid total recipe weight available (recipe.totalRecipeWeight: \(recipe.totalRecipeWeight), string param: \(totalRecipeWeight))")
                                }
                        } else {
                            let effectivePortionSize = currentPortionSize > 0 ? currentPortionSize : totalWeight

                            // P0 FIX: Zero check to prevent displaying 0g
                            if effectivePortionSize <= 0 {
                                // Error state: No valid portion data
                                Text("Porsiyon bilgisi eksik")
                                    .font(.system(size: ResponsiveDesign.Font.scaledSize(14), weight: .medium, design: .rounded))
                                    .foregroundColor(.secondary)
                                    .onAppear {
                                        logger.error("❌ [PORTION DISPLAY] effectivePortionSize is 0 - currentPortionSize: \(currentPortionSize), totalWeight: \(totalWeight)")
                                    }
                            } else {
                                // Valid portion - show display and stepper
                                HStack(alignment: .firstTextBaseline, spacing: 4) {
                                    Text("\(Int(effectivePortionSize * portionMultiplier))")
                                        .font(.system(size: ResponsiveDesign.Font.scaledSize(20), weight: .bold, design: .rounded))
                                        .foregroundStyle(AppTheme.primaryPurple)

                                    Text("g")
                                        .font(.system(size: ResponsiveDesign.Font.scaledSize(14), weight: .medium, design: .rounded))
                                        .foregroundStyle(.secondary)
                                }
                                .onAppear {
                                    logger.debug("📊 [PORTION DISPLAY] Showing \(Int(effectivePortionSize * portionMultiplier))g (base: \(effectivePortionSize)g × multiplier: \(portionMultiplier))")
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

                    // Slider (for saved and unsaved recipes with valid total weight)
                    if canAdjustPortion {
                        VStack(spacing: 8) {
                            Slider(
                                value: $adjustingPortionWeight,
                                in: minPortionSize...maxSliderValue,
                                step: 1.0
                            )
                            .tint(AppTheme.primaryPurple)
                            .onChange(of: adjustingPortionWeight) { _, newValue in
                                // Update portion multiplier to reflect slider changes
                                guard currentPortionSize > 0 else { return }
                                let ratio = newValue / currentPortionSize
                                portionMultiplier = ratio
                            }

                            // Min/Max labels
                            HStack {
                                Text("\(Int(minPortionSize))g")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                Spacer()

                                Text("\(Int(maxSliderValue))g")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal, ResponsiveDesign.Spacing.medium)
                    }

                    // Save button (pill-shaped with compact padding)
                    Button(action: handleSave) {
                        Text(canAdjustPortion ? "Porsiyonu Kaydet" : "Güncelle")
                            .font(.system(size: ResponsiveDesign.Font.scaledSize(15), weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(AppTheme.primaryPurple)
                            )
                            .shadow(color: AppTheme.primaryPurple.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, ResponsiveDesign.Spacing.medium)
                    .padding(.bottom, ResponsiveDesign.Spacing.medium)
                }
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.95)),
                    removal: .opacity
                ))
            }
        }
        .background(.clear)
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.card, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.card, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: ResponsiveDesign.height(8), x: 0, y: ResponsiveDesign.height(4))
        .overlay(
            RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.card, style: .continuous)
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
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isPortionAdjustmentExpanded)
    }
}
