//
//  LoggedMealsView.swift
//  balli
//
//  Voice‑logged meals history grouped by date
//

import SwiftUI
import CoreData
import os.log

// View mode filter for switching between meals and insulin history
enum HistoryViewMode {
    case meals
    case insulin
}

@MainActor
struct LoggedMealsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dependencies) private var dependencies

    @State private var selectedMealGroup: MealGroup?
    @State private var showMealDetail = false
    @State private var errorMessage: String?
    @State private var showErrorAlert = false
    @State private var selectedView: HistoryViewMode = .meals

    // Access sync coordinator via dependency injection
    private var syncCoordinator: any MealSyncCoordinatorProtocol {
        dependencies.mealSyncCoordinator
    }

    // Dark mode dissolved purple gradient (matching RecipeCardView and ProductCardView)
    private var dissolvedPurpleDark: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: AppTheme.primaryPurple.opacity(0.12), location: 0.0),
                .init(color: AppTheme.primaryPurple.opacity(0.08), location: 0.15),
                .init(color: AppTheme.primaryPurple.opacity(0.05), location: 0.25),
                .init(color: AppTheme.primaryPurple.opacity(0.03), location: 0.5),
                .init(color: AppTheme.primaryPurple.opacity(0.05), location: 0.75),
                .init(color: AppTheme.primaryPurple.opacity(0.08), location: 0.85),
                .init(color: AppTheme.primaryPurple.opacity(0.12), location: 1.0)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // Card background - LIGHT MODE: clear, DARK MODE: dissolved purple
    private var cardBackground: some ShapeStyle {
        if colorScheme == .dark {
            return AnyShapeStyle(dissolvedPurpleDark)
        } else {
            return AnyShapeStyle(Color.clear)
        }
    }

    // Glass effect - LIGHT MODE: interactive, DARK MODE: interactive
    private var glassEffectStyle: Glass {
        return .regular.interactive()
    }

    // Fetch all meal entries sorted by timestamp (newest first)
    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \MealEntry.timestamp, ascending: false)
        ],
        animation: .default
    )
    private var mealEntries: FetchedResults<MealEntry>

    // Group entries by date (calendar day), then by meal timestamp
    private var groupedEntries: [(date: Date, mealGroups: [MealGroup])] {
        let byDay = Dictionary(grouping: mealEntries) { entry in
            Calendar.current.startOfDay(for: entry.timestamp)
        }

        return byDay
            .map { (date: $0.key, mealGroups: groupMealsByTimestamp($0.value)) }
            .sorted { $0.date > $1.date }
    }

    /// Groups meal entries that were logged together (within 5 seconds of each other)
    private func groupMealsByTimestamp(_ meals: [MealEntry]) -> [MealGroup] {
        var groups: [MealGroup] = []
        var processedIDs = Set<UUID>()

        for meal in meals.sorted(by: { $0.timestamp > $1.timestamp }) {
            guard !processedIDs.contains(meal.id) else { continue }

            // Find all meals within 5 seconds of this meal
            let relatedMeals = meals.filter { otherMeal in
                !processedIDs.contains(otherMeal.id) &&
                abs(otherMeal.timestamp.timeIntervalSince(meal.timestamp)) <= 5
            }

            // Mark all related meals as processed
            relatedMeals.forEach { processedIDs.insert($0.id) }

            // Create meal group
            groups.append(MealGroup(meals: relatedMeals))
        }

        return groups.sorted { $0.timestamp > $1.timestamp }
    }

    // MARK: - Helper Functions

    /// Returns appropriate SF symbol for meal type
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

    /// Formats date header in Turkish format (e.g., "24 Ekim Cuma 2025")
    private func formatDateForHeader(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.dateFormat = "d MMMM EEEE yyyy"
        return formatter.string(from: date)
    }

    var body: some View {
        NavigationStack {
            Group {
                if selectedView == .meals {
                    // Meals view
                    if groupedEntries.isEmpty {
                        ContentUnavailableView(
                            "Henüz kayıtlı öğün yok",
                            systemImage: "calendar.day.timeline.left",
                            description: Text("Sesle kaydettiğin öğünler burada görünecek.")
                        )
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(AppTheme.primaryPurple)
                        .frame(maxHeight: .infinity)
                    } else {
                        List {
                            ForEach(groupedEntries, id: \.date) { dateGroup in
                                dayCard(for: dateGroup)
                                    .listRowInsets(EdgeInsets(
                                        top: ResponsiveDesign.Spacing.small,
                                        leading: ResponsiveDesign.Spacing.medium,
                                        bottom: ResponsiveDesign.Spacing.small,
                                        trailing: ResponsiveDesign.Spacing.medium
                                    ))
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(Color.clear)
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                } else {
                    // Insulin history view
                    InsulinHistoryContentView()
                        .environment(\.managedObjectContext, viewContext)
                }
            }
            .background(Color(.systemBackground))
            .navigationTitle(selectedView == .meals ? "Günlük Kayıtlar" : "İnsülin Geçmişi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        withAnimation {
                            selectedView = selectedView == .meals ? .insulin : .meals
                        }
                    }) {
                        Image(systemName: selectedView == .meals ? "carrot.fill" : "microbe.fill")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(AppTheme.primaryPurple)
                    }
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    Task {
                        await syncCoordinator.syncOnAppActivation()
                    }
                }
            }
            .sheet(isPresented: $showMealDetail) {
                if let mealGroup = selectedMealGroup {
                    MealDetailView(mealGroup: mealGroup)
                        .environment(\.managedObjectContext, viewContext)
                }
            }
            .alert("Hata", isPresented: $showErrorAlert) {
                Button("Tamam", role: .cancel) { }
            } message: {
                if let errorMessage {
                    Text(errorMessage)
                }
            }
        }
    }

    // MARK: - Helper Methods

    /// Deletes a meal group (all related meal entries) from Core Data
    private func deleteMealGroup(_ mealGroup: MealGroup) {
        // Delete all meals in the group (with their associated food items)
        mealGroup.meals.forEach { meal in
            // CRITICAL: Verify meal is in the correct context before deleting
            guard meal.managedObjectContext == viewContext else {
                logger.error("❌ Meal is not in viewContext - cannot delete")
                return
            }

            // Delete associated food item if it exists
            if let foodItem = meal.foodItem {
                // CRITICAL: Verify foodItem is in the correct context
                guard foodItem.managedObjectContext == viewContext else {
                    logger.error("❌ FoodItem is not in viewContext - cannot delete")
                    return
                }
                viewContext.delete(foodItem)
            }

            // Delete the meal entry
            viewContext.delete(meal)
        }

        do {
            try viewContext.save()
            logger.info("✅ Deleted meal group with \(mealGroup.meals.count) entries")
        } catch {
            // Show error to user
            errorMessage = "Öğün silinemedi: \(error.localizedDescription)"
            showErrorAlert = true
            logger.error("❌ Failed to delete meal group: \(error.localizedDescription)")

            // Rollback changes
            viewContext.rollback()
        }
    }

    // Logger
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.balli", category: "LoggedMealsView")

    // MARK: - Day Card View

    @ViewBuilder
    private func dayCard(for dateGroup: (date: Date, mealGroups: [MealGroup])) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Date header at top left inside card
            Text(formatDateForHeader(dateGroup.date))
                .font(.system(size: ResponsiveDesign.Font.scaledSize(14), weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
                .padding(.horizontal, ResponsiveDesign.Spacing.medium)
                .padding(.top, ResponsiveDesign.Spacing.medium)
                .padding(.bottom, ResponsiveDesign.Spacing.small)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Divider below date
            Rectangle()
                .fill(Color.secondary.opacity(0.2))
                .frame(height: 0.5)
                .padding(.horizontal, ResponsiveDesign.Spacing.medium)

            // All meals for this day
            VStack(spacing: ResponsiveDesign.Spacing.xSmall) {
                ForEach(dateGroup.mealGroups) { mealGroup in
                    mealGroupRow(mealGroup)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedMealGroup = mealGroup
                            showMealDetail = true
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                deleteMealGroup(mealGroup)
                            } label: {
                                Label("Sil", systemImage: "trash")
                            }
                        }

                    // Divider between meals (except last one)
                    if mealGroup.id != dateGroup.mealGroups.last?.id {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.1))
                            .frame(height: 0.5)
                            .padding(.horizontal, ResponsiveDesign.Spacing.medium)
                    }
                }
            }
            .padding(.vertical, ResponsiveDesign.Spacing.small)
        }
        .background(
            RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.card, style: .continuous)
                .fill(cardBackground)
        )
        .clipShape(RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.card, style: .continuous))
        .glassEffect(
            glassEffectStyle,
            in: RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.card, style: .continuous)
        )
        .shadow(color: .black.opacity(0.06), radius: ResponsiveDesign.height(8), x: 0, y: ResponsiveDesign.height(4))
    }

    // MARK: - Meal Group Row

    private func mealGroupRow(_ mealGroup: MealGroup) -> some View {
        let medications = mealGroup.fetchAssociatedMedications(from: viewContext)
        let hasInsulin = !medications.isEmpty

        return HStack(spacing: ResponsiveDesign.Spacing.small) {
            // Meal type icon
            Image(systemName: symbolForMealType(mealGroup.mealType))
                .font(.system(size: ResponsiveDesign.Font.scaledSize(20), weight: .semibold))
                .foregroundStyle(AppTheme.primaryPurple)
                .frame(width: ResponsiveDesign.Font.scaledSize(32), alignment: .center)

            // Meal details
            VStack(alignment: .leading, spacing: ResponsiveDesign.Spacing.xxSmall) {
                Text(mealGroup.mealType.capitalized)
                    .font(.system(size: ResponsiveDesign.Font.scaledSize(16), weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)

                // Time only (date is shown in card header)
                Text(mealGroup.timestamp, format: .dateTime.hour().minute())
                    .font(.system(size: ResponsiveDesign.Font.scaledSize(13), weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Right-aligned metrics (insulin + carbs)
            HStack(spacing: ResponsiveDesign.Spacing.small) {
                // Insulin info inline with carbs
                if hasInsulin, let firstMedication = medications.first {
                    HStack(spacing: 4) {
                        Image(systemName: "microbe.fill")
                            .font(.system(size: ResponsiveDesign.Font.scaledSize(18), weight: .medium))
                            .foregroundStyle(AppTheme.primaryPurple)

                        Text("\(Int(firstMedication.dosage))")
                            .font(.system(size: ResponsiveDesign.Font.scaledSize(18), weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(AppTheme.primaryPurple)
                    }

                    // Divider between insulin and carbs (only shown when both exist)
                    if mealGroup.totalCarbs > 0 {
                        Text("|")
                            .font(.system(size: ResponsiveDesign.Font.scaledSize(18), weight: .medium))
                            .foregroundStyle(.secondary.opacity(0.5))
                    }
                }

                // Carbohydrate amount
                if mealGroup.totalCarbs > 0 {
                    Text("\(Int(mealGroup.totalCarbs))gr")
                        .font(.system(size: ResponsiveDesign.Font.scaledSize(18), weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(AppTheme.primaryPurple)
                }
            }
        }
        .padding(.vertical, ResponsiveDesign.Spacing.small)
        .padding(.horizontal, ResponsiveDesign.Spacing.medium)
    }
}

// MARK: - MealGroup Model

/// Represents a group of meal entries logged together
struct MealGroup: Identifiable {
    let id = UUID()
    let meals: [MealEntry]

    var timestamp: Date {
        meals.first?.timestamp ?? Date()
    }

    var mealType: String {
        meals.first?.mealType ?? "atıştırmalık"
    }

    var totalCarbs: Double {
        meals.reduce(0) { $0 + $1.consumedCarbs }
    }

    var totalProtein: Double {
        meals.reduce(0) { $0 + $1.consumedProtein }
    }

    var totalFat: Double {
        meals.reduce(0) { $0 + $1.consumedFat }
    }

    var totalCalories: Double {
        meals.reduce(0) { $0 + $1.consumedCalories }
    }

    var totalFiber: Double {
        meals.reduce(0) { $0 + $1.consumedFiber }
    }

    /// Fetches associated medication entries for this meal group
    /// Returns medications logged within 5 seconds of the meal timestamp
    func fetchAssociatedMedications(from context: NSManagedObjectContext) -> [MedicationEntry] {
        let fetchRequest = MedicationEntry.fetchRequest()

        // Find medications within 5 seconds of the meal timestamp
        let startDate = timestamp.addingTimeInterval(-5)
        let endDate = timestamp.addingTimeInterval(5)

        fetchRequest.predicate = NSPredicate(
            format: "timestamp >= %@ AND timestamp <= %@ AND (medicationType == %@ OR medicationType == %@)",
            startDate as NSDate,
            endDate as NSDate,
            "bolus_insulin",
            "basal_insulin"
        )
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \MedicationEntry.timestamp, ascending: false)]

        do {
            return try context.fetch(fetchRequest)
        } catch {
            return []
        }
    }
}

// MARK: - Insulin History Content View

/// Content view for insulin history (without NavigationStack wrapper)
/// Extracted from InsulinHistoryView for embedding in LoggedMealsView
struct InsulinHistoryContentView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.managedObjectContext) private var viewContext

    @State private var selectedEntry: MedicationEntry?
    @State private var showDetailSheet = false

    // Fetch all medication entries (insulin) sorted by timestamp (newest first)
    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \MedicationEntry.timestamp, ascending: false)
        ],
        animation: .default
    )
    private var medicationEntries: FetchedResults<MedicationEntry>

    // Group entries by date (calendar day)
    private var groupedEntries: [(date: Date, entries: [MedicationEntry])] {
        let byDay = Dictionary(grouping: medicationEntries) { entry in
            Calendar.current.startOfDay(for: entry.timestamp)
        }

        return byDay
            .map { (date: $0.key, entries: $0.value.sorted { $0.timestamp > $1.timestamp }) }
            .sorted { $0.date > $1.date }
    }

    // Dark mode dissolved purple gradient
    private var dissolvedPurpleDark: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: AppTheme.primaryPurple.opacity(0.12), location: 0.0),
                .init(color: AppTheme.primaryPurple.opacity(0.08), location: 0.15),
                .init(color: AppTheme.primaryPurple.opacity(0.05), location: 0.25),
                .init(color: AppTheme.primaryPurple.opacity(0.03), location: 0.5),
                .init(color: AppTheme.primaryPurple.opacity(0.05), location: 0.75),
                .init(color: AppTheme.primaryPurple.opacity(0.08), location: 0.85),
                .init(color: AppTheme.primaryPurple.opacity(0.12), location: 1.0)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // Card background
    private var cardBackground: some ShapeStyle {
        if colorScheme == .dark {
            return AnyShapeStyle(dissolvedPurpleDark)
        } else {
            return AnyShapeStyle(Color.clear)
        }
    }

    var body: some View {
        Group {
            if groupedEntries.isEmpty {
                ContentUnavailableView(
                    "Henüz insülin kaydı yok",
                    systemImage: "syringe",
                    description: Text("Sesle kaydettiğin insülin dozları burada görünecek.")
                )
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(AppTheme.primaryPurple)
                .frame(maxHeight: .infinity)
            } else {
                List {
                    ForEach(groupedEntries, id: \.date) { dateGroup in
                        dayCard(for: dateGroup)
                            .listRowInsets(EdgeInsets(
                                top: ResponsiveDesign.Spacing.small,
                                leading: ResponsiveDesign.Spacing.medium,
                                bottom: ResponsiveDesign.Spacing.small,
                                trailing: ResponsiveDesign.Spacing.medium
                            ))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .sheet(isPresented: $showDetailSheet) {
            if let entry = selectedEntry {
                InsulinEditSheet(medication: entry)
                    .environment(\.managedObjectContext, viewContext)
            }
        }
    }

    // MARK: - Day Card View

    @ViewBuilder
    private func dayCard(for dateGroup: (date: Date, entries: [MedicationEntry])) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Date header
            Text(formatDateForHeader(dateGroup.date))
                .font(.system(size: ResponsiveDesign.Font.scaledSize(14), weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
                .padding(.horizontal, ResponsiveDesign.Spacing.medium)
                .padding(.top, ResponsiveDesign.Spacing.medium)
                .padding(.bottom, ResponsiveDesign.Spacing.small)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Divider below date
            Rectangle()
                .fill(Color.secondary.opacity(0.2))
                .frame(height: 0.5)
                .padding(.horizontal, ResponsiveDesign.Spacing.medium)

            // All insulin entries for this day
            VStack(spacing: ResponsiveDesign.Spacing.xSmall) {
                ForEach(dateGroup.entries) { entry in
                    insulinEntryRow(entry)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedEntry = entry
                            showDetailSheet = true
                        }

                    // Divider between entries (except last one)
                    if entry.id != dateGroup.entries.last?.id {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.1))
                            .frame(height: 0.5)
                            .padding(.horizontal, ResponsiveDesign.Spacing.medium)
                    }
                }
            }
            .padding(.vertical, ResponsiveDesign.Spacing.small)
        }
        .background(
            RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.card, style: .continuous)
                .fill(cardBackground)
        )
        .clipShape(RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.card, style: .continuous))
        .glassEffect(
            .regular.interactive(),
            in: RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.card, style: .continuous)
        )
        .shadow(color: .black.opacity(0.06), radius: ResponsiveDesign.height(8), x: 0, y: ResponsiveDesign.height(4))
    }

    // MARK: - Insulin Entry Row

    private func insulinEntryRow(_ entry: MedicationEntry) -> some View {
        let insulinTypeIcon = entry.isBasalInsulin ? "slowmo" : "chevron.forward.dotted.chevron.forward"
        let insulinTypeColor = AppTheme.primaryPurple

        return HStack(spacing: ResponsiveDesign.Spacing.small) {
            // Insulin type icon
            Image(systemName: insulinTypeIcon)
                .font(.system(size: ResponsiveDesign.Font.scaledSize(20), weight: .semibold))
                .foregroundStyle(insulinTypeColor)
                .frame(width: ResponsiveDesign.Font.scaledSize(32), alignment: .center)

            // Insulin details
            VStack(alignment: .leading, spacing: ResponsiveDesign.Spacing.xxSmall) {
                Text(entry.medicationName)
                    .font(.system(size: ResponsiveDesign.Font.scaledSize(16), weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)

                // Time only (date is shown in card header)
                Text(entry.timestamp, format: .dateTime.hour().minute())
                    .font(.system(size: ResponsiveDesign.Font.scaledSize(13), weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Right-aligned metrics (insulin dosage only)
            HStack(spacing: 4) {
                Image(systemName: "microbe.fill")
                    .font(.system(size: ResponsiveDesign.Font.scaledSize(18), weight: .medium))
                    .foregroundStyle(AppTheme.primaryPurple)

                Text("\(Int(entry.dosage))")
                    .font(.system(size: ResponsiveDesign.Font.scaledSize(18), weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.primaryPurple)
            }
        }
        .padding(.horizontal, ResponsiveDesign.Spacing.medium)
        .padding(.vertical, ResponsiveDesign.Spacing.small)
    }

    // MARK: - Helper Functions

    /// Formats date header in Turkish format
    private func formatDateForHeader(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.dateFormat = "d MMMM EEEE yyyy"
        return formatter.string(from: date)
    }
}

#Preview {
    LoggedMealsView()
        .environment(\.managedObjectContext, PersistenceController.previewFast.container.viewContext)
}
