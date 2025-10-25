//
//  MealEditSheet.swift
//  balli
//
//  Sheet for editing meal entries
//

import SwiftUI
import os.log

struct MealEditSheet: View {
    let meal: MealEntry

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.managedObjectContext) private var viewContext

    @State private var mealType: String
    @State private var timestamp: Date
    @State private var quantity: String
    @State private var unit: String
    @State private var consumedCarbs: String
    @State private var consumedProtein: String
    @State private var consumedFat: String
    @State private var consumedCalories: String
    @State private var notes: String
    @State private var showSaveError = false
    @State private var errorMessage = ""

    init(meal: MealEntry) {
        self.meal = meal

        // Initialize state from meal
        _mealType = State(initialValue: meal.mealType)
        _timestamp = State(initialValue: meal.timestamp)
        _quantity = State(initialValue: String(format: "%.1f", meal.quantity))
        _unit = State(initialValue: meal.unit)
        _consumedCarbs = State(initialValue: String(format: "%.1f", meal.consumedCarbs))
        _consumedProtein = State(initialValue: String(format: "%.1f", meal.consumedProtein))
        _consumedFat = State(initialValue: String(format: "%.1f", meal.consumedFat))
        _consumedCalories = State(initialValue: String(format: "%.0f", meal.consumedCalories))
        _notes = State(initialValue: meal.notes ?? "")
    }

    private var canSave: Bool {
        !mealType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        Double(quantity) != nil &&
        Double(consumedCarbs) != nil
    }

    private var hasChanges: Bool {
        let trimmedMealType = mealType.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUnit = unit.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)

        return trimmedMealType != meal.mealType ||
               timestamp != meal.timestamp ||
               Double(quantity) != meal.quantity ||
               trimmedUnit != meal.unit ||
               Double(consumedCarbs) != meal.consumedCarbs ||
               Double(consumedProtein) != meal.consumedProtein ||
               Double(consumedFat) != meal.consumedFat ||
               Double(consumedCalories) != meal.consumedCalories ||
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
                Section("Öğün Bilgileri") {
                    // Meal Type Picker
                    Picker("Öğün Türü", selection: $mealType) {
                        ForEach(mealTypeOptions, id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }
                    .pickerStyle(.menu)

                    // Timestamp
                    DatePicker(
                        "Tarih ve Saat",
                        selection: $timestamp,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.compact)
                }

                // Portion Information
                Section("Porsiyon") {
                    HStack {
                        Image(systemName: "chart.bar.fill")
                            .foregroundColor(AppTheme.primaryPurple)
                            .frame(width: 24)

                        TextField("Miktar", text: $quantity)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 17, weight: .regular, design: .rounded))
                    }

                    HStack {
                        Image(systemName: "scalemass")
                            .foregroundColor(AppTheme.primaryPurple)
                            .frame(width: 24)

                        TextField("Birim (porsiyon, gr, ml)", text: $unit)
                            .font(.system(size: 17, weight: .regular, design: .rounded))
                    }
                }

                // Nutrition Information
                Section("Besin Değerleri") {
                    HStack {
                        Image(systemName: "leaf.fill")
                            .foregroundColor(AppTheme.primaryPurple)
                            .frame(width: 24)

                        Text("Karbonhidrat")
                            .font(.system(size: 17, weight: .regular, design: .rounded))

                        Spacer()

                        TextField("0", text: $consumedCarbs)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 17, weight: .regular, design: .rounded))
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)

                        Text("gr")
                            .foregroundColor(.secondary)
                            .font(.system(size: 17, weight: .regular, design: .rounded))
                    }

                    HStack {
                        Image(systemName: "figure.walk")
                            .foregroundColor(AppTheme.primaryPurple)
                            .frame(width: 24)

                        Text("Protein")
                            .font(.system(size: 17, weight: .regular, design: .rounded))

                        Spacer()

                        TextField("0", text: $consumedProtein)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 17, weight: .regular, design: .rounded))
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)

                        Text("gr")
                            .foregroundColor(.secondary)
                            .font(.system(size: 17, weight: .regular, design: .rounded))
                    }

                    HStack {
                        Image(systemName: "drop.fill")
                            .foregroundColor(AppTheme.primaryPurple)
                            .frame(width: 24)

                        Text("Yağ")
                            .font(.system(size: 17, weight: .regular, design: .rounded))

                        Spacer()

                        TextField("0", text: $consumedFat)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 17, weight: .regular, design: .rounded))
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)

                        Text("gr")
                            .foregroundColor(.secondary)
                            .font(.system(size: 17, weight: .regular, design: .rounded))
                    }

                    HStack {
                        Image(systemName: "flame.fill")
                            .foregroundColor(AppTheme.primaryPurple)
                            .frame(width: 24)

                        Text("Kalori")
                            .font(.system(size: 17, weight: .regular, design: .rounded))

                        Spacer()

                        TextField("0", text: $consumedCalories)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 17, weight: .regular, design: .rounded))
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)

                        Text("kcal")
                            .foregroundColor(.secondary)
                            .font(.system(size: 17, weight: .regular, design: .rounded))
                    }
                }

                // Notes Section
                Section("Notlar") {
                    HStack(alignment: .top) {
                        Image(systemName: "note.text")
                            .foregroundColor(AppTheme.primaryPurple)
                            .frame(width: 24)
                            .padding(.top, 4)

                        TextField(
                            "Ek notlar (isteğe bağlı)",
                            text: $notes,
                            axis: .vertical
                        )
                        .font(.system(size: 17, weight: .regular, design: .rounded))
                        .lineLimit(3...6)
                    }
                }
            }
            .navigationTitle("Öğünü Düzenle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("İptal") {
                        dismiss()
                    }
                    .font(.system(size: 17, weight: .regular, design: .rounded))
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kaydet") {
                        saveChanges()
                    }
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .disabled(!canSave || !hasChanges)
                }
            }
            .alert("Kaydetme Hatası", isPresented: $showSaveError) {
                Button("Tamam", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func saveChanges() {
        guard let carbsValue = Double(consumedCarbs),
              let quantityValue = Double(quantity) else {
            errorMessage = "Lütfen geçerli sayısal değerler girin."
            showSaveError = true
            return
        }

        let trimmedMealType = mealType.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUnit = unit.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)

        // Update meal properties
        meal.mealType = trimmedMealType
        meal.timestamp = timestamp
        meal.quantity = quantityValue
        meal.unit = trimmedUnit
        meal.consumedCarbs = carbsValue
        meal.consumedProtein = Double(consumedProtein) ?? 0
        meal.consumedFat = Double(consumedFat) ?? 0
        meal.consumedCalories = Double(consumedCalories) ?? 0
        meal.notes = trimmedNotes.isEmpty ? nil : trimmedNotes

        do {
            try viewContext.save()
            dismiss()
        } catch {
            errorMessage = "Değişiklikler kaydedilirken bir hata oluştu: \(error.localizedDescription)"
            showSaveError = true

            // Rollback to prevent invalid context state
            viewContext.rollback()
            logger.error("Failed to save meal edit: \(error.localizedDescription)")
        }
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext

    // Create a sample meal entry
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
    meal.notes = "Test öğünü"

    return MealEditSheet(meal: meal)
        .environment(\.managedObjectContext, context)
}
