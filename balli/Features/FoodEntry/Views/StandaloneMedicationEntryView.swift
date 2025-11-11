//
//  StandaloneMedicationEntryView.swift
//  balli
//
//  Standalone insulin/medication logging view
//  For basal insulin (Lantus) or other medications logged without a meal
//  Design matches MealPreviewEditor for consistency
//

import SwiftUI
import CoreData
import OSLog

struct StandaloneMedicationEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext

    // Passed from VoiceInputView
    let initialMedicationName: String?
    let initialDosage: Double
    let initialMedicationType: String? // "basal" or "bolus"
    let initialTimestamp: Date

    // Editable state
    @State private var medicationName: String
    @State private var dosage: String
    @State private var medicationType: String
    @State private var timestamp: Date
    @State private var notes: String = ""

    // UI state
    @State private var showingSaveConfirmation = false
    @State private var errorMessage: String?

    private let hapticManager = HapticManager()
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.anaxoniclabs.balli",
        category: "StandaloneMedicationEntry"
    )

    init(
        medicationName: String?,
        dosage: Double,
        medicationType: String?,
        timestamp: Date = Date()
    ) {
        self.initialMedicationName = medicationName
        self.initialDosage = dosage
        self.initialMedicationType = medicationType
        self.initialTimestamp = timestamp

        // Initialize state
        _medicationName = State(initialValue: medicationName ?? "")
        _dosage = State(initialValue: String(Int(dosage)))
        _medicationType = State(initialValue: medicationType ?? "basal")
        _timestamp = State(initialValue: timestamp)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Unified Card: Insulin Picker + Dosage Stepper + Date/Time
                    VStack(spacing: 20) {
                        // Row 1: Insulin Name Picker + Dosage Stepper
                        HStack(spacing: 16) {
                            // Insulin Name Picker
                            Picker("", selection: $medicationName) {
                                Text("Lantus").tag("Lantus")
                                Text("Tresiba").tag("Tresiba")
                                Text("NovoRapid").tag("NovoRapid")
                                Text("Humalog").tag("Humalog")
                                Text("Fiasp").tag("Fiasp")
                                Text("Diğer").tag("Diğer")
                            }
                            .pickerStyle(.menu)
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                            Spacer()

                            // Dosage Stepper
                            HStack(spacing: 8) {
                                // Decrease button
                                Button {
                                    if let current = Int(dosage), current > 0 {
                                        dosage = "\(current - 1)"
                                    }
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .font(.system(size: 28))
                                        .foregroundStyle(AppTheme.primaryPurple)
                                }
                                .buttonStyle(.plain)

                                // Dosage value
                                VStack(spacing: 0) {
                                    TextField("0", text: $dosage)
                                        .keyboardType(.numberPad)
                                        .font(.system(size: 22, weight: .bold, design: .rounded).monospacedDigit())
                                        .multilineTextAlignment(.center)
                                        .frame(width: 50)

                                    Text("Ünite")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(.secondary)
                                }

                                // Increase button
                                Button {
                                    if let current = Int(dosage) {
                                        dosage = "\(current + 1)"
                                    } else {
                                        dosage = "1"
                                    }
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 28))
                                        .foregroundStyle(AppTheme.primaryPurple)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        // Row 2: Date and Time Picker
                        DatePicker(
                            "",
                            selection: $timestamp,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.vertical, ResponsiveDesign.Spacing.medium)
                    .padding(.horizontal, ResponsiveDesign.Spacing.medium)
                    .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.card, style: .continuous))
                    .padding(.horizontal)

                    // Optional Notes Section (only if user starts typing)
                    if !notes.isEmpty || isEditingNotes {
                        Divider()
                            .padding(.horizontal)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Not (Opsiyonel)")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(.secondary)

                            TextField("Ek bilgi ekle...", text: $notes, axis: .vertical)
                                .font(.system(size: 16, weight: .regular, design: .rounded))
                                .lineLimit(2...4)
                                .padding(12)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(12)
                        }
                        .padding(.vertical, ResponsiveDesign.Spacing.small)
                        .padding(.horizontal, ResponsiveDesign.Spacing.medium)
                        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.card, style: .continuous))
                        .padding(.horizontal)
                    }

                    Spacer(minLength: 100)
                }
                .padding(.top, 32)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("İnsülin")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("İptal") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task {
                            await saveMedicationEntry()
                        }
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .buttonStyle(.balliBordered)
                }
            }
            .overlay {
                // Success confirmation toast (matching MealPreviewEditor style)
                if showingSaveConfirmation {
                    VStack {
                        Spacer()
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(AppTheme.primaryPurple)
                            Text("İnsülin kaydedildi ✓")
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                                .foregroundColor(.primary)
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .recipeGlass(tint: .warm, cornerRadius: 100)
                        .padding(.bottom, 100)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showingSaveConfirmation)
                }
            }
            .alert("Hata", isPresented: .constant(errorMessage != nil), presenting: errorMessage) { _ in
                Button("Tamam") {
                    errorMessage = nil
                }
            } message: { error in
                Text(error)
            }
        }
    }

    // MARK: - Computed Properties

    private var isEditingNotes: Bool {
        // Show notes field if user tapped to add notes
        false
    }

    // MARK: - Save Logic

    private func saveMedicationEntry() async {
        // Validation
        guard !medicationName.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Lütfen insülin adı seçin"
            return
        }

        guard let dosageValue = Double(dosage), dosageValue > 0 else {
            errorMessage = "Lütfen geçerli bir doz girin (0'dan büyük)"
            return
        }

        do {
            // Create MedicationEntry in CoreData
            let entry = MedicationEntry(context: viewContext)
            entry.id = UUID()
            entry.timestamp = timestamp
            entry.medicationName = medicationName.trimmingCharacters(in: .whitespaces)
            entry.medicationType = medicationType
            entry.dosage = dosageValue
            entry.dosageUnit = "units"
            entry.administrationRoute = "injection"
            entry.glucoseAtTime = 0 // Unknown at time of entry
            entry.notes = notes.isEmpty ? nil : notes
            entry.isScheduled = false
            entry.dateAdded = Date()
            entry.lastModified = Date()
            entry.source = "voice_transcription"

            // No meal connection
            entry.mealEntry = nil

            // Save context
            try viewContext.save()

            logger.info("✅ Saved standalone medication entry: \(medicationName) \(dosageValue) units")

            // Show success confirmation
            await MainActor.run {
                hapticManager.notification(.success)

                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    showingSaveConfirmation = true
                }

                // Auto-dismiss
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(1.5))
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        showingSaveConfirmation = false
                    }
                    try? await Task.sleep(for: .seconds(0.3))
                    dismiss()
                }
            }

        } catch {
            logger.error("❌ Failed to save medication entry: \(error.localizedDescription)")
            errorMessage = "Kayıt başarısız: \(error.localizedDescription)"
        }
    }
}

// MARK: - Preview

#Preview("Lantus - Basal") {
    StandaloneMedicationEntryView(
        medicationName: "Lantus",
        dosage: 20,
        medicationType: "basal"
    )
    .environment(\.managedObjectContext, PersistenceController.previewFast.container.viewContext)
}

#Preview("NovoRapid - Bolus") {
    StandaloneMedicationEntryView(
        medicationName: "NovoRapid",
        dosage: 5,
        medicationType: "bolus"
    )
    .environment(\.managedObjectContext, PersistenceController.previewFast.container.viewContext)
}
