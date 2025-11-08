//
//  MealDetailView.swift
//  balli
//
//  Detailed view showing all ingredients and nutrition for a logged meal
//

import SwiftUI
import os.log

struct MealDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.managedObjectContext) private var viewContext

    let mealGroup: MealGroup

    @State private var showingEditSheet = false
    @State private var selectedMeal: MealEntry?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Meal header card
                    mealHeaderCard

                    // Nutrition summary card
                    nutritionSummaryCard

                    // Insulin card if present
                    let medications = mealGroup.fetchAssociatedMedications(from: viewContext)
                    if !medications.isEmpty {
                        insulinSection(medications: medications)
                    }

                    // Ingredients list - ALWAYS show ingredients
                    ingredientsSection
                }
                .padding()
            }
            .background(Color(.systemBackground))
            .navigationTitle("Öğün Detayı")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .sheet(isPresented: $showingEditSheet) {
                if let meal = selectedMeal {
                    MealEditSheet(meal: meal)
                }
            }
        }
    }

    // MARK: - Meal Header Card

    @ViewBuilder
    private var mealHeaderCard: some View {
        VStack(spacing: ResponsiveDesign.Spacing.medium) {
            // Meal type with icon
            HStack(spacing: ResponsiveDesign.Spacing.small) {
                Image(systemName: symbolForMealType(mealGroup.mealType))
                    .font(.system(size: ResponsiveDesign.Font.scaledSize(32), weight: .semibold))
                    .foregroundStyle(AppTheme.primaryPurple)

                VStack(alignment: .leading, spacing: ResponsiveDesign.Spacing.xxSmall) {
                    Text(mealGroup.mealType.capitalized)
                        .font(.system(size: ResponsiveDesign.Font.scaledSize(24), weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)

                    Text(mealGroup.timestamp, format: .dateTime.day().month().year().hour().minute())
                        .font(.system(size: ResponsiveDesign.Font.scaledSize(14), weight: .regular, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Edit button for meal type and timestamp
                Button {
                    // Edit the first meal (all meals in group share same timestamp and type)
                    if let firstMeal = mealGroup.meals.first {
                        selectedMeal = firstMeal
                        showingEditSheet = true
                    }
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: ResponsiveDesign.Font.scaledSize(16), weight: .semibold))
                        .foregroundStyle(AppTheme.primaryPurple)
                        .frame(width: 40, height: 40)
                        .background(Color(.systemGray6))
                        .clipShape(Circle())
                }
            }
        }
        .padding(ResponsiveDesign.Spacing.medium)
        .background(Color.white.opacity(0.05))
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 36, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: ResponsiveDesign.height(8), x: 0, y: ResponsiveDesign.height(4))
    }

    // MARK: - Nutrition Summary Card

    @ViewBuilder
    private var nutritionSummaryCard: some View {
        VStack(spacing: ResponsiveDesign.Spacing.medium) {
            Text("Besin Değerleri")
                .font(.system(size: ResponsiveDesign.Font.scaledSize(18), weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Large carbs display
            VStack(spacing: ResponsiveDesign.Spacing.xxSmall) {
                Text("\(Int(mealGroup.totalCarbs))")
                    .font(.system(size: ResponsiveDesign.Font.scaledSize(48), weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.primaryPurple)

                Text("gram karbonhidrat")
                    .font(.system(size: ResponsiveDesign.Font.scaledSize(14), weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, ResponsiveDesign.Spacing.small)
        }
        .padding(ResponsiveDesign.Spacing.medium)
        .background(Color.white.opacity(0.05))
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 36, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: ResponsiveDesign.height(8), x: 0, y: ResponsiveDesign.height(4))
    }

    // MARK: - Insulin Section

    @ViewBuilder
    private func insulinSection(medications: [MedicationEntry]) -> some View {
        VStack(spacing: ResponsiveDesign.Spacing.medium) {
            Text("İnsülin")
                .font(.system(size: ResponsiveDesign.Font.scaledSize(18), weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(medications) { medication in
                HStack(spacing: ResponsiveDesign.Spacing.medium) {
                    // microbe.fill icon
                    Image(systemName: "microbe.fill.fill")
                        .font(.system(size: ResponsiveDesign.Font.scaledSize(24), weight: .semibold))
                        .foregroundStyle(AppTheme.primaryPurple)
                        .frame(width: ResponsiveDesign.Font.scaledSize(40), alignment: .center)

                    // Medication details
                    VStack(alignment: .leading, spacing: ResponsiveDesign.Spacing.xxSmall) {
                        Text(medication.medicationName)
                            .font(.system(size: ResponsiveDesign.Font.scaledSize(16), weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)

                        HStack(spacing: 4) {
                            Text("\(medication.dosage, specifier: "%.1f") ünite")
                                .font(.system(size: ResponsiveDesign.Font.scaledSize(14), weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)

                            // Insulin type badge
                            if medication.medicationType == "bolus_insulin" {
                                Text("Hızlı Etkili")
                                    .font(.system(size: ResponsiveDesign.Font.scaledSize(11), weight: .medium, design: .rounded))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(AppTheme.primaryPurple)
                                    .cornerRadius(4)
                            } else if medication.medicationType == "basal_insulin" {
                                Text("Uzun Etkili")
                                    .font(.system(size: ResponsiveDesign.Font.scaledSize(11), weight: .medium, design: .rounded))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.blue)
                                    .cornerRadius(4)
                            }
                        }
                    }

                    Spacer()
                }
                .padding(ResponsiveDesign.Spacing.medium)
                .background(.clear)
                .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: .black.opacity(0.04), radius: ResponsiveDesign.height(4), x: 0, y: ResponsiveDesign.height(2))
            }
        }
        .padding(ResponsiveDesign.Spacing.medium)
        .background(Color.white.opacity(0.05))
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 36, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: ResponsiveDesign.height(8), x: 0, y: ResponsiveDesign.height(4))
    }

    // MARK: - Ingredients Section

    @ViewBuilder
    private var ingredientsSection: some View {
        VStack(spacing: ResponsiveDesign.Spacing.small) {
            Text("Malzemeler (\(mealGroup.meals.count))")
                .font(.system(size: ResponsiveDesign.Font.scaledSize(18), weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(mealGroup.meals) { meal in
                ingredientRow(meal)
            }
        }
        .padding(ResponsiveDesign.Spacing.medium)
        .background(Color.white.opacity(0.05))
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 36, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: ResponsiveDesign.height(8), x: 0, y: ResponsiveDesign.height(4))
    }

    @ViewBuilder
    private func ingredientRow(_ meal: MealEntry) -> some View {
        HStack(spacing: ResponsiveDesign.Spacing.small) {
            // Food name
            VStack(alignment: .leading, spacing: ResponsiveDesign.Spacing.xxSmall) {
                if let foodName = meal.foodItem?.name {
                    Text(foodName)
                        .font(.system(size: ResponsiveDesign.Font.scaledSize(16), weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                } else {
                    Text("Bilinmeyen yiyecek")
                        .font(.system(size: ResponsiveDesign.Font.scaledSize(16), weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                // Portion info
                Text(meal.portionDescription)
                    .font(.system(size: ResponsiveDesign.Font.scaledSize(13), weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Carbs badge - ONLY show if this meal has individual carbs specified
            // Don't show if the user provided a collective carb amount
            if shouldShowIndividualCarbBadge(for: meal) {
                Text("\(Int(meal.consumedCarbs))g")
                    .font(.system(size: ResponsiveDesign.Font.scaledSize(14), weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.primaryPurple)
            }

            // Edit button
            Button {
                selectedMeal = meal
                showingEditSheet = true
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: ResponsiveDesign.Font.scaledSize(14), weight: .semibold))
                    .foregroundStyle(AppTheme.primaryPurple)
                    .frame(width: 32, height: 32)
                    .background(Color(.systemGray6))
                    .clipShape(Circle())
            }
        }
        .padding(ResponsiveDesign.Spacing.medium)
        .background(.clear)
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: ResponsiveDesign.height(4), x: 0, y: ResponsiveDesign.height(2))
    }

    // MARK: - Helper Functions

    /// Determines if individual carb badge should be shown for a meal
    /// Logic: Only show if user provided individual carb amounts (detailed format)
    /// Don't show if user provided only a collective carb total (simple format)
    private func shouldShowIndividualCarbBadge(for meal: MealEntry) -> Bool {
        // Must have carbs to show badge
        guard meal.consumedCarbs > 0 else { return false }

        // If there's only one meal in the group, always show the badge
        // (it represents the total anyway)
        if mealGroup.meals.count == 1 {
            return true
        }

        // If multiple meals exist:
        // - If ALL meals have the SAME carb value, it's likely a collective amount
        //   incorrectly distributed (user said "40g total" but system put 40g on each item)
        // - If meals have DIFFERENT carb values, user specified individual amounts
        let allCarbs = mealGroup.meals.map { $0.consumedCarbs }
        let uniqueCarbs = Set(allCarbs)

        // If all carbs are the same AND equal to the total, it's collective (don't show)
        if uniqueCarbs.count == 1, let firstCarb = allCarbs.first {
            // Check if this value equals the total (indicating incorrect distribution)
            if firstCarb == mealGroup.totalCarbs {
                return false // Collective amount - don't show individual badges
            }
        }

        // Otherwise, show the badge (user provided individual amounts)
        return true
    }

    private func symbolForMealType(_ mealType: String) -> String {
        let normalizedType = mealType.lowercased()

        switch normalizedType {
        case "kahvaltı":
            return "sun.max"
        case "ara öğün", "atıştırmalık":
            return "circle.badge.plus"
        case "akşam yemeği":
            return "fork.knife"
        default:
            return "fork.knife"
        }
    }

    // Logger
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.balli", category: "MealDetailView")
}

#Preview("Single Meal") {
    let context = PersistenceController.previewFast.container.viewContext

    // Create preview meal
    let meal = MealEntry(context: context)
    meal.id = UUID()
    meal.timestamp = Date()
    meal.mealType = "kahvaltı"
    meal.consumedCarbs = 30
    meal.consumedProtein = 15
    meal.consumedFat = 10
    meal.consumedCalories = 250
    meal.quantity = 1.0
    meal.unit = "porsiyon"

    let foodItem = FoodItem(context: context)
    foodItem.name = "Yumurta ve ekmek"
    meal.foodItem = foodItem

    let mealGroup = MealGroup(meals: [meal])

    return MealDetailView(mealGroup: mealGroup)
        .environment(\.managedObjectContext, context)
}

#Preview("Multiple Ingredients") {
    let context = PersistenceController.previewFast.container.viewContext

    // Create multiple preview meals
    var meals: [MealEntry] = []

    let ingredients = [
        ("Yumurta", 5.0),
        ("Ekmek", 20.0),
        ("Peynir", 5.0)
    ]

    for (name, carbs) in ingredients {
        let meal = MealEntry(context: context)
        meal.id = UUID()
        meal.timestamp = Date()
        meal.mealType = "kahvaltı"
        meal.consumedCarbs = carbs
        meal.consumedProtein = 10
        meal.consumedFat = 5
        meal.consumedCalories = 100
        meal.quantity = 1.0
        meal.unit = "porsiyon"

        let foodItem = FoodItem(context: context)
        foodItem.name = name
        meal.foodItem = foodItem

        meals.append(meal)
    }

    let mealGroup = MealGroup(meals: meals)

    return MealDetailView(mealGroup: mealGroup)
        .environment(\.managedObjectContext, context)
}
