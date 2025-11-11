//
//  InsulinEditSheet.swift
//  balli
//
//  iOS 26 Liquid Glass insulin editing sheet
//  Allows editing of insulin/medication entries with paired meal timestamp updates
//

import SwiftUI
import os.log

struct InsulinEditSheet: View {
    let medication: MedicationEntry

    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) private var colorScheme

    @State private var medicationName: String
    @State private var timestamp: Date
    @State private var dosage: String
    @State private var notes: String
    @State private var showSaveError = false
    @State private var errorMessage = ""
    @State private var isSaving = false

    init(medication: MedicationEntry) {
        self.medication = medication

        // Initialize state from medication
        _medicationName = State(initialValue: medication.medicationName)
        _timestamp = State(initialValue: medication.timestamp)
        _dosage = State(initialValue: medication.dosage.asLocalizedDecimal(decimalPlaces: 1))
        _notes = State(initialValue: medication.notes ?? "")
    }

    private var canSave: Bool {
        !medicationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        dosage.toDouble != nil &&
        (dosage.toDouble ?? 0) > 0
    }

    private var hasChanges: Bool {
        let trimmedName = medicationName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)

        return trimmedName != medication.medicationName ||
               timestamp != medication.timestamp ||
               dosage.toDouble != medication.dosage ||
               (trimmedNotes.isEmpty ? nil : trimmedNotes) != medication.notes
    }

    // Insulin name options
    private let insulinOptions = ["Lantus", "Tresiba", "NovoRapid", "Humalog", "Fiasp"]

    // Logger
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.balli", category: "InsulinEditSheet")

    var body: some View {
        NavigationStack {
            Form {
                // Basic Information Section
                basicInfoSection

                // Dosage Section
                dosageSection

                // Notes Section
                notesSection
            }
            .formStyle(.grouped)
            .scrollDismissesKeyboard(.interactively)
            .scrollContentBackground(.hidden)
            .background(Color(.systemBackground))
            .tint(AppTheme.primaryPurple)
            .navigationTitle("İnsülin Düzenle")
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
            // Medication Name Picker
            HStack(spacing: 12) {
                Image(systemName: "syringe.fill")
                    .foregroundStyle(AppTheme.primaryPurple)
                    .frame(width: 24)

                Picker("İnsülin Adı", selection: $medicationName) {
                    ForEach(insulinOptions, id: \.self) { name in
                        Text(name).tag(name)
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
            Text("İnsülin Bilgileri")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
        }
        .listRowSeparator(.hidden)
        .listSectionSpacing(20)
    }

    private var dosageSection: some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: "microbe.fill")
                    .foregroundStyle(AppTheme.primaryPurple)
                    .frame(width: 24)

                Text("Doz")
                    .foregroundStyle(.primary)

                Spacer()

                TextField("0", text: $dosage)
                    .textFieldStyle(.plain)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 60)

                Text("ünite")
                    .foregroundStyle(.secondary)
                    .frame(width: 40, alignment: .leading)
            }
            .padding(.vertical, 8)
        } header: {
            Text("Doz Bilgisi")
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
        guard let dosageValue = dosage.toDouble, dosageValue > 0 else {
            errorMessage = "Lütfen geçerli sayısal değerler girin."
            showSaveError = true
            return
        }

        isSaving = true
        defer { isSaving = false }

        let trimmedName = medicationName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)

        // CRITICAL: Check if timestamp changed - if so, update paired meal timestamps
        let timestampChanged = medication.timestamp != timestamp
        let originalTimestamp = medication.timestamp

        // Update medication properties
        medication.medicationName = trimmedName
        medication.timestamp = timestamp
        medication.dosage = dosageValue
        medication.notes = trimmedNotes.isEmpty ? nil : trimmedNotes
        medication.lastModified = Date()

        // Mark as pending sync
        medication.markAsPendingSync()

        // CRITICAL FIX: If timestamp changed, update paired meal entries
        // This keeps meal and insulin together as a pair (reverse of MealEditSheet logic)
        if timestampChanged {
            updatePairedMealTimestamps(from: originalTimestamp, to: timestamp)
        }

        do {
            try viewContext.save()
            logger.info("✅ Insulin edited successfully: \(medication.id)")
            if timestampChanged {
                logger.info("   - Updated paired meal timestamps from \(originalTimestamp) to \(timestamp)")
            }
            dismiss()
        } catch {
            errorMessage = "Değişiklikler kaydedilirken bir hata oluştu: \(error.localizedDescription)"
            showSaveError = true

            // Rollback to prevent invalid context state
            viewContext.rollback()
            logger.error("❌ Failed to save insulin edit: \(error.localizedDescription)")
        }
    }

    /// Update meal timestamps to keep them paired with the insulin
    /// Finds meal entries within 5 seconds of the original insulin timestamp and updates them
    private func updatePairedMealTimestamps(from originalTimestamp: Date, to newTimestamp: Date) {
        let fetchRequest = MealEntry.fetchRequest()

        // Find meals within 5 seconds of the ORIGINAL insulin timestamp
        let startDate = originalTimestamp.addingTimeInterval(-5)
        let endDate = originalTimestamp.addingTimeInterval(5)

        fetchRequest.predicate = NSPredicate(
            format: "timestamp >= %@ AND timestamp <= %@",
            startDate as NSDate,
            endDate as NSDate
        )

        do {
            let meals = try viewContext.fetch(fetchRequest)

            if !meals.isEmpty {
                logger.info("   - Found \(meals.count) paired meal entries to update")

                for meal in meals {
                    meal.timestamp = newTimestamp
                    meal.lastModified = Date()
                    meal.markAsPendingSync()
                }

                logger.info("   - Updated \(meals.count) meal timestamps to match insulin")
            }
        } catch {
            logger.error("❌ Failed to fetch paired meals for timestamp update: \(error.localizedDescription)")
        }
    }
}

// MARK: - Previews

#Preview("Default State") {
    let context = PersistenceController.previewFast.container.viewContext

    let medication = MedicationEntry(context: context)
    medication.id = UUID()
    medication.medicationName = "NovoRapid"
    medication.timestamp = Date()
    medication.dosage = 5.0
    medication.dosageUnit = "ünite"
    medication.medicationType = "bolus_insulin"
    medication.notes = nil

    return InsulinEditSheet(medication: medication)
        .environment(\.managedObjectContext, context)
}

#Preview("Filled State") {
    let context = PersistenceController.previewFast.container.viewContext

    let medication = MedicationEntry(context: context)
    medication.id = UUID()
    medication.medicationName = "Lantus"
    medication.timestamp = Date()
    medication.dosage = 20.0
    medication.dosageUnit = "ünite"
    medication.medicationType = "basal_insulin"
    medication.notes = "Sabah dozumu aldım"

    return InsulinEditSheet(medication: medication)
        .environment(\.managedObjectContext, context)
}
