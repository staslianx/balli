//
//  MealEditSheet.swift
//  balli
//
//  iOS 26 Liquid Glass meal editing sheet
//  Follows native design patterns with glass materials
//

import SwiftUI
import os.log

struct MealEditSheet: View {
    let meal: MealEntry

    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) private var colorScheme

    @State private var mealType: String
    @State private var timestamp: Date
    @State private var quantity: String
    @State private var unit: String
    @State private var consumedCarbs: String
    @State private var consumedProtein: String
    @State private var consumedFat: String
    @State private var consumedCalories: String
    @State private var consumedFiber: String
    @State private var notes: String
    @State private var showSaveError = false
    @State private var errorMessage = ""
    @State private var isSaving = false

    init(meal: MealEntry) {
        self.meal = meal

        // Initialize state from meal with locale-aware formatting (comma in Turkish, period in US)
        _mealType = State(initialValue: meal.mealType)
        _timestamp = State(initialValue: meal.timestamp)
        _quantity = State(initialValue: meal.quantity.asLocalizedDecimal(decimalPlaces: 1))
        _unit = State(initialValue: meal.unit)
        _consumedCarbs = State(initialValue: meal.consumedCarbs.asLocalizedDecimal(decimalPlaces: 1))
        _consumedProtein = State(initialValue: meal.consumedProtein.asLocalizedDecimal(decimalPlaces: 1))
        _consumedFat = State(initialValue: meal.consumedFat.asLocalizedDecimal(decimalPlaces: 1))
        _consumedCalories = State(initialValue: meal.consumedCalories.asLocalizedDecimal(decimalPlaces: 0))
        _consumedFiber = State(initialValue: meal.consumedFiber.asLocalizedDecimal(decimalPlaces: 1))
        _notes = State(initialValue: meal.notes ?? "")
    }

    private var canSave: Bool {
        !mealType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        quantity.toDouble != nil &&
        consumedCarbs.toDouble != nil
    }

    private var hasChanges: Bool {
        let trimmedMealType = mealType.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUnit = unit.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)

        return trimmedMealType != meal.mealType ||
               timestamp != meal.timestamp ||
               quantity.toDouble != meal.quantity ||
               trimmedUnit != meal.unit ||
               consumedCarbs.toDouble != meal.consumedCarbs ||
               consumedProtein.toDouble != meal.consumedProtein ||
               consumedFat.toDouble != meal.consumedFat ||
               consumedCalories.toDouble != meal.consumedCalories ||
               consumedFiber.toDouble != meal.consumedFiber ||
               (trimmedNotes.isEmpty ? nil : trimmedNotes) != meal.notes
    }

    // Meal type options
    private let mealTypeOptions = ["Kahvaltı", "Ara Öğün", "Akşam Yemeği"]

    // Logger
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.balli", category: "MealEditSheet")

    var body: some View {
        NavigationStack {
            Form {
                // Basic Information Section
                basicInfoSection

                // Nutrition Section
                nutritionSection

                // Notes Section
                notesSection
            }
            .formStyle(.grouped)
            .scrollDismissesKeyboard(.interactively)
            .scrollContentBackground(.hidden)
            .background(Color(.systemBackground))
            .tint(AppTheme.primaryPurple)
            .navigationTitle("Öğünü Düzenle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") {
                        dismiss()
                    }
                    .fontWeight(.regular)
                }

                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Button("Kaydet") {
                            Task { await saveChanges() }
                        }
                        .fontWeight(.semibold)
                        .disabled(!canSave || !hasChanges)
                    }
                }
            }
            .alert("Kaydetme Hatası", isPresented: $showSaveError) {
                Button("Tamam", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Section Views

    private var basicInfoSection: some View {
        Section {
            // Meal Type Picker
            HStack(spacing: 12) {
                Image(systemName: "fork.knife")
                    .foregroundStyle(AppTheme.primaryPurple)
                    .frame(width: 24)

                Picker("Öğün Türü", selection: $mealType) {
                    ForEach(mealTypeOptions, id: \.self) { type in
                        Text(type).tag(type)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }
            .padding(.vertical, 8)

            // Timestamp
            HStack(spacing: 12) {
                Image(systemName: "clock.fill")
                    .foregroundStyle(AppTheme.primaryPurple)
                    .frame(width: 24)

                DatePicker(
                    "Tarih ve Saat",
                    selection: $timestamp,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.compact)
                .labelsHidden()
            }
            .padding(.vertical, 8)
        } header: {
            Text("Öğün Bilgileri")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
        }
        .listRowSeparator(.hidden)
        .listSectionSpacing(20)
    }

    private var nutritionSection: some View {
        Section {
            // Carbohydrates only
            NutritionFieldRow(
                icon: "leaf.fill",
                label: "Karbonhidrat",
                value: $consumedCarbs,
                unit: "gr"
            )
        } header: {
            Text("Besin Değerleri")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
        }
        .listRowSeparator(.hidden)
        .listSectionSpacing(20)
    }

    private var notesSection: some View {
        Section {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "note.text")
                    .foregroundStyle(AppTheme.primaryPurple)
                    .frame(width: 24)
                    .padding(.top, 4)

                TextEditor(text: $notes)
                    .frame(minHeight: 80, maxHeight: 120)
                    .scrollContentBackground(.hidden)
                    .font(.body)
            }
            .padding(.vertical, 4)
        } header: {
            Text("Notlar")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
        }
        .listRowSeparator(.hidden)
        .listSectionSpacing(20)
    }

    // MARK: - Actions

    @MainActor
    private func saveChanges() async {
        guard let carbsValue = consumedCarbs.toDouble,
              let quantityValue = quantity.toDouble else {
            errorMessage = "Lütfen geçerli sayısal değerler girin."
            showSaveError = true
            return
        }

        isSaving = true
        defer { isSaving = false }

        let trimmedMealType = mealType.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUnit = unit.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)

        // Update meal properties
        meal.mealType = trimmedMealType
        meal.timestamp = timestamp
        meal.quantity = quantityValue
        meal.unit = trimmedUnit
        meal.consumedCarbs = carbsValue
        meal.consumedProtein = consumedProtein.toDouble ?? 0
        meal.consumedFat = consumedFat.toDouble ?? 0
        meal.consumedCalories = consumedCalories.toDouble ?? 0
        meal.consumedFiber = consumedFiber.toDouble ?? 0
        meal.notes = trimmedNotes.isEmpty ? nil : trimmedNotes
        meal.lastModified = Date()

        // Mark as pending sync
        meal.markAsPendingSync()

        do {
            try viewContext.save()
            logger.info("✅ Meal edited successfully: \(meal.id)")
            dismiss()
        } catch {
            errorMessage = "Değişiklikler kaydedilirken bir hata oluştu: \(error.localizedDescription)"
            showSaveError = true

            // Rollback to prevent invalid context state
            viewContext.rollback()
            logger.error("❌ Failed to save meal edit: \(error.localizedDescription)")
        }
    }
}

// MARK: - Nutrition Field Row

private struct NutritionFieldRow: View {
    let icon: String
    let label: String
    @Binding var value: String
    let unit: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(AppTheme.primaryPurple)
                .frame(width: 24)

            Text(label)
                .foregroundStyle(.primary)

            Spacer()

            TextField("0", text: $value)
                .textFieldStyle(.plain)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 60)

            Text(unit)
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .leading)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Previews

#Preview("Default State") {
    let context = PersistenceController.previewFast.container.viewContext

    let meal = MealEntry(context: context)
    meal.id = UUID()
    meal.mealType = "Kahvaltı"
    meal.timestamp = Date()
    meal.quantity = 1.0
    meal.unit = "porsiyon"
    meal.consumedCarbs = 45.0
    meal.consumedProtein = 12.0
    meal.consumedFat = 8.0
    meal.consumedCalories = 300.0
    meal.consumedFiber = 5.0
    meal.notes = nil

    return MealEditSheet(meal: meal)
        .environment(\.managedObjectContext, context)
}

#Preview("Filled State") {
    let context = PersistenceController.previewFast.container.viewContext

    let meal = MealEntry(context: context)
    meal.id = UUID()
    meal.mealType = "Akşam Yemeği"
    meal.timestamp = Date()
    meal.quantity = 2.5
    meal.unit = "porsiyon"
    meal.consumedCarbs = 65.5
    meal.consumedProtein = 28.3
    meal.consumedFat = 15.7
    meal.consumedCalories = 520.0
    meal.consumedFiber = 8.2
    meal.notes = "Izgara tavuk göğsü, pirinç pilavı ve salata ile birlikte. Çok doyurucu bir öğündü."

    return MealEditSheet(meal: meal)
        .environment(\.managedObjectContext, context)
}

#Preview("Dark Mode") {
    let context = PersistenceController.previewFast.container.viewContext

    let meal = MealEntry(context: context)
    meal.id = UUID()
    meal.mealType = "Ara Öğün"
    meal.timestamp = Date()
    meal.quantity = 1.0
    meal.unit = "adet"
    meal.consumedCarbs = 25.0
    meal.consumedProtein = 5.0
    meal.consumedFat = 3.0
    meal.consumedCalories = 150.0
    meal.consumedFiber = 3.0
    meal.notes = "Elma ve badem"

    return MealEditSheet(meal: meal)
        .environment(\.managedObjectContext, context)
        .preferredColorScheme(.dark)
}

#Preview("Long Notes") {
    let context = PersistenceController.previewFast.container.viewContext

    let meal = MealEntry(context: context)
    meal.id = UUID()
    meal.mealType = "Kahvaltı"
    meal.timestamp = Date()
    meal.quantity = 1.0
    meal.unit = "porsiyon"
    meal.consumedCarbs = 45.0
    meal.consumedProtein = 12.0
    meal.consumedFat = 8.0
    meal.consumedCalories = 300.0
    meal.consumedFiber = 5.0
    meal.notes = """
    Tam tahıllı ekmek, peynir, domates, salatalık ve yeşil zeytin ile \
    zengin bir kahvaltı yaptım. Yanında taze sıkılmış portakal suyu içtim. \
    Çok doyurucu ve besleyiciydi. Sabah enerjisini sağladı.
    """

    return MealEditSheet(meal: meal)
        .environment(\.managedObjectContext, context)
}

#Preview("Zero Values") {
    let context = PersistenceController.previewFast.container.viewContext

    let meal = MealEntry(context: context)
    meal.id = UUID()
    meal.mealType = "Kahvaltı"
    meal.timestamp = Date()
    meal.quantity = 0.0
    meal.unit = ""
    meal.consumedCarbs = 0.0
    meal.consumedProtein = 0.0
    meal.consumedFat = 0.0
    meal.consumedCalories = 0.0
    meal.consumedFiber = 0.0
    meal.notes = nil

    return MealEditSheet(meal: meal)
        .environment(\.managedObjectContext, context)
}
