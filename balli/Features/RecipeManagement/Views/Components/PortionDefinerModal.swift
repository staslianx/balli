//
//  PortionDefinerModal.swift
//  balli
//
//  Created by Claude Code on 2025-11-04.
//  Critical for diabetes management - allows users to define what "1 portion" means
//

import SwiftUI
import CoreData

/// Unified modal for defining or adjusting recipe portion sizes
///
/// # Purpose
/// Allows users to define what "1 portion" means for a recipe by selecting
/// a weight in grams. Critical for accurate diabetes management calculations.
///
/// # Modes
/// - `.define`: First-time definition (manual recipes) - required, cannot dismiss
/// - `.adjust`: Editing existing portion (both recipe types) - optional, can dismiss
///
/// # Usage
/// ```swift
/// .sheet(isPresented: $showPortionDefiner) {
///     PortionDefinerModal(
///         recipe: recipe,
///         mode: recipe.isPortionDefined ? .adjust : .define,
///         isRequired: !recipe.isPortionDefined
///     )
/// }
/// ```
@MainActor
struct PortionDefinerModal: View {

    // MARK: - Mode

    enum Mode {
        case define   // First-time definition (manual recipes)
        case adjust   // Editing existing portion (both types)

        var title: String {
            switch self {
            case .define: return "Porsiyonu Tanımla"
            case .adjust: return "Porsiyonu Düzenle"
            }
        }

        var buttonText: String {
            switch self {
            case .define: return "Porsiyonu Kaydet"
            case .adjust: return "Güncelle"
            }
        }

        var description: String {
            switch self {
            case .define: return "Bir porsiyon senin için ne kadar olsun?"
            case .adjust: return "Porsiyon miktarını ayarla"
            }
        }
    }

    // MARK: - Properties

    /// Recipe to define/adjust portion for
    let recipe: Recipe

    /// Define or adjust mode
    let mode: Mode

    /// Whether dismissal is prevented (true for manual recipes in define mode)
    let isRequired: Bool

    /// Core Data context for saving
    @Environment(\.managedObjectContext) private var viewContext

    /// Dismiss action
    @Environment(\.dismiss) private var dismiss

    /// Current portion weight (5g steps)
    @State private var portionWeight: Double

    /// Show success feedback
    @State private var showSuccessFeedback = false

    // MARK: - Initialization

    init(recipe: Recipe, mode: Mode, isRequired: Bool = false) {
        self.recipe = recipe
        self.mode = mode
        self.isRequired = isRequired

        // Initialize slider with current or default value
        // Default to full recipe weight for define mode
        let initialValue = recipe.portionSize > 0 ? recipe.portionSize : recipe.totalRecipeWeight
        _portionWeight = State(initialValue: initialValue)
    }

    // MARK: - Computed Properties

    /// Number of portions the recipe makes
    private var portionCount: Double {
        guard portionWeight > 0 else { return 1.0 }
        return recipe.totalRecipeWeight / portionWeight
    }

    /// Ratio for scaling nutrition
    private var ratio: Double {
        guard recipe.totalRecipeWeight > 0 else { return 0 }
        return portionWeight / recipe.totalRecipeWeight
    }

    /// Nutrition values for current portion size
    private var portionNutrition: NutritionValues {
        return recipe.calculatePortionNutrition(for: portionWeight)
    }

    /// Total nutrition for entire recipe
    private var totalNutrition: NutritionValues {
        return recipe.totalNutrition
    }

    /// Minimum allowed portion size (50g)
    private let minPortionSize: Double = 50

    /// Slider step size (5g for balanced precision/UX)
    private let sliderStep: Double = 5

    // MARK: - Body

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header Section
                    headerSection

                    // Total Recipe Info
                    totalRecipeCard

                    Divider()
                        .padding(.vertical, 8)

                    // Portion Slider
                    portionSliderSection

                    // Live Nutrition Preview
                    nutritionPreviewSection

                    Spacer(minLength: 20)

                    // Action Buttons
                    actionButtons
                }
                .padding()
            }
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(isRequired)  // Prevent swipe-down if required
            .toolbar {
                if !isRequired {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("İptal") {
                            dismiss()
                        }
                        .foregroundColor(.secondary)
                    }
                }
            }
        }
        .overlay(alignment: .top) {
            if showSuccessFeedback {
                successBanner
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    // MARK: - View Components

    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: mode == .define ? "slider.horizontal.below.rectangle" : "slider.horizontal.3")
                .font(.system(size: 40))
                .foregroundColor(.blue)

            Text(mode.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    private var totalRecipeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "takeoutbag.and.cup.and.straw")
                    .foregroundColor(.secondary)
                Text("Toplam Tarif")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
            }

            HStack(alignment: .firstTextBaseline, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ağırlık")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(Int(recipe.totalRecipeWeight))")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("g")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Divider()
                    .frame(height: 40)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Kalori")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(Int(totalNutrition.calories))")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("kcal")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.08))
        .cornerRadius(16)
    }

    private var portionSliderSection: some View {
        VStack(spacing: 20) {
            // Portion Size Display
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Bir Porsiyon")
                        .font(.headline)
                        .foregroundColor(.primary)

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(Int(portionWeight))")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(.blue)
                        Text("g")
                            .font(.title3)
                            .foregroundColor(.secondary)
                            .padding(.bottom, 8)
                    }
                }

                Spacer()

                // Portion Count Badge
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Çıkan")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)

                    Text(String(format: "%.1f", portionCount))
                        .font(.system(size: 36, weight: .semibold, design: .rounded))
                        .foregroundColor(.blue)

                    Text(portionCount == 1.0 ? "porsiyon" : "porsiyon")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
            }

            // Slider
            VStack(spacing: 8) {
                Slider(
                    value: $portionWeight,
                    in: minPortionSize...recipe.totalRecipeWeight,
                    step: sliderStep
                )
                .tint(.blue)

                // Slider Labels
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Min")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("\(Int(minPortionSize))g")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Max")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("\(Int(recipe.totalRecipeWeight))g")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(16)
    }

    private var nutritionPreviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.green)
                Text("Porsiyon Başına Besin Değerleri")
                    .font(.headline)
            }

            // Nutrition Grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                NutritionItemView(
                    label: "Kalori",
                    value: "\(Int(portionNutrition.calories))",
                    unit: "kcal",
                    color: .orange
                )

                NutritionItemView(
                    label: "Protein",
                    value: String(format: "%.1f", portionNutrition.protein),
                    unit: "g",
                    color: .red
                )

                NutritionItemView(
                    label: "Karbonhidrat",
                    value: String(format: "%.1f", portionNutrition.carbohydrates),
                    unit: "g",
                    color: .blue
                )

                NutritionItemView(
                    label: "Yağ",
                    value: String(format: "%.1f", portionNutrition.fat),
                    unit: "g",
                    color: .yellow
                )

                NutritionItemView(
                    label: "Lif",
                    value: String(format: "%.1f", portionNutrition.fiber),
                    unit: "g",
                    color: .green
                )

                NutritionItemView(
                    label: "GL",
                    value: String(format: "%.0f", portionNutrition.glycemicLoad),
                    unit: "",
                    color: .purple
                )
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(16)
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Save Button
            Button(action: savePortionSize) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                    Text(mode.buttonText)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }

            // Cancel Button (only if not required)
            if !isRequired {
                Button(action: { dismiss() }) {
                    Text("İptal")
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundColor(.blue)
                }
            }
        }
    }

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

    // MARK: - Actions

    private func savePortionSize() {
        // Validate portion size
        guard portionWeight >= minPortionSize else {
            // Show error (could add alert here)
            return
        }

        guard portionWeight <= recipe.totalRecipeWeight else {
            // Show error (could add alert here)
            return
        }

        // Update recipe
        recipe.updatePortionSize(portionWeight)

        // Save to Core Data
        do {
            try viewContext.save()

            // Show success feedback
            withAnimation(.spring()) {
                showSuccessFeedback = true
            }

            // Dismiss after brief delay (Swift 6 concurrency compliance)
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.0))
                withAnimation {
                    showSuccessFeedback = false
                }

                try? await Task.sleep(for: .seconds(0.3))
                dismiss()
            }

        } catch {
            // Handle error (could add alert here)
        }
    }
}

// MARK: - Supporting Views

/// Individual nutrition item display
private struct NutritionItemView: View {
    let label: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)

                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                if !unit.isEmpty {
                    Text(unit)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: color.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Previews

#Preview("Define Mode - Manual Recipe") {
    let context = PersistenceController.preview.container.viewContext
    let recipe = Recipe(context: context)
    recipe.id = UUID()
    recipe.name = "Tavuklu Sebze Sote"
    recipe.totalRecipeWeight = 756
    recipe.caloriesPerServing = 1041
    recipe.carbsPerServing = 77.6
    recipe.fiberPerServing = 11.2
    recipe.sugarsPerServing = 11.9
    recipe.proteinPerServing = 107.9
    recipe.fatPerServing = 32.5
    recipe.glycemicLoadPerServing = 37
    recipe.portionSize = 0  // Not defined
    recipe.recipeType = "manual"

    return PortionDefinerModal(
        recipe: recipe,
        mode: .define,
        isRequired: true
    )
    .environment(\.managedObjectContext, context)
}

#Preview("Adjust Mode - AI Generated") {
    let context = PersistenceController.preview.container.viewContext
    let recipe = Recipe(context: context)
    recipe.id = UUID()
    recipe.name = "Mercimekli Bulgur Pilavı"
    recipe.totalRecipeWeight = 342
    recipe.caloriesPerServing = 480
    recipe.carbsPerServing = 70.4
    recipe.fiberPerServing = 12.1
    recipe.sugarsPerServing = 5.4
    recipe.proteinPerServing = 20.9
    recipe.fatPerServing = 15.2
    recipe.glycemicLoadPerServing = 23
    recipe.portionSize = 342  // Already defined (full recipe)
    recipe.recipeType = "aiGenerated"

    return PortionDefinerModal(
        recipe: recipe,
        mode: .adjust,
        isRequired: false
    )
    .environment(\.managedObjectContext, context)
}

#Preview("Small Portion - Many Servings") {
    let context = PersistenceController.preview.container.viewContext
    let recipe = Recipe(context: context)
    recipe.id = UUID()
    recipe.name = "Büyük Sebze Güveç"
    recipe.totalRecipeWeight = 1200  // 1.2kg
    recipe.caloriesPerServing = 1800
    recipe.carbsPerServing = 150
    recipe.fiberPerServing = 25
    recipe.sugarsPerServing = 20
    recipe.proteinPerServing = 80
    recipe.fatPerServing = 60
    recipe.glycemicLoadPerServing = 45
    recipe.portionSize = 200  // Small portion = 6 servings
    recipe.recipeType = "manual"

    return PortionDefinerModal(
        recipe: recipe,
        mode: .adjust,
        isRequired: false
    )
    .environment(\.managedObjectContext, context)
}
