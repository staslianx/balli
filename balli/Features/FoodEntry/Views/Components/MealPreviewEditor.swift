//
//  MealPreviewEditor.swift
//  balli
//
//  Editable meal preview form component
//  Swift 6 strict concurrency compliant
//

import SwiftUI

// MARK: - Editable Insulin Row (Pill Style)

struct EditableInsulinRow: View {
    @Binding var dosage: Double
    @Binding var insulinName: String?
    @Binding var isFinalized: Bool

    var body: some View {
        HStack(spacing: ResponsiveDesign.Spacing.medium) {
            // Insulin type picker (left side, centered vertically)
            Picker("İnsülin Tipi", selection: $insulinName) {
                Text("NovoRapid").tag(Optional("NovoRapid"))
                Text("Lantus").tag(Optional("Lantus"))
            }
            .pickerStyle(.menu)
            .font(.system(size: 17, weight: .semibold, design: .rounded))
            .foregroundColor(.primary)

            Spacer()

            // Right side: Stepper (editing) or Pill (finalized)
            if !isFinalized {
                // State 1: Stepper mode - just shows: - 5 +
                HStack(spacing: 12) {
                    // Decrease button
                    Button {
                        dosage = max(0, dosage - 1)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(AppTheme.primaryPurple)
                    }
                    .buttonStyle(.plain)

                    // Dosage value (no "Ünite" text)
                    Text("\(Int(dosage))")
                        .font(.system(size: 24, weight: .bold, design: .rounded).monospacedDigit())
                        .frame(width: 50)

                    // Increase button
                    Button {
                        dosage += 1
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(AppTheme.primaryPurple)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                // State 2: Pill mode (read-only display)
                Text("\(Int(dosage)) Ünite")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(AppTheme.primaryPurple)
                    .padding(.horizontal, ResponsiveDesign.width(12))
                    .padding(.vertical, ResponsiveDesign.height(6))
                    .background(
                        Capsule()
                            .fill(AppTheme.primaryPurple.opacity(0.15))
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        // Tap pill to switch back to editing mode
                        isFinalized = false
                    }
            }
        }
        .padding(.vertical, ResponsiveDesign.Spacing.medium)
        .padding(.horizontal, ResponsiveDesign.Spacing.medium)
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.card, style: .continuous))
    }
}

// MARK: - Editable Food Row (Shopping List Style)

struct EditableFoodRow: View {
    @Binding var food: EditableFoodItem
    let isDetailedFormat: Bool

    @State private var isEditingName = false
    @State private var isEditingAmount = false
    @State private var isEditingCarbs = false
    @State private var editName = ""
    @State private var editAmount = ""
    @State private var editCarbs = ""
    @FocusState private var isNameFocused: Bool
    @FocusState private var isAmountFocused: Bool
    @FocusState private var isCarbsFocused: Bool

    var body: some View {
        VStack(spacing: 12) {
            // Main row: name + quantity on left, carbs pill on right
            HStack(spacing: ResponsiveDesign.Spacing.medium) {
                // Food name and quantity (inline editable)
                VStack(alignment: .leading, spacing: 4) {
                    // Food name
                    if isEditingName {
                        TextField("Yiyecek adı", text: $editName)
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)
                            .focused($isNameFocused)
                            .onSubmit {
                                saveNameAndStopEditing()
                            }
                            .onChange(of: isNameFocused) { _, focused in
                                if !focused {
                                    saveNameAndStopEditing()
                                }
                            }
                            .onAppear {
                                isNameFocused = true
                            }
                    } else {
                        Text(food.name.isEmpty ? "Yiyecek adı" : food.name)
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundColor(food.name.isEmpty ? .secondary : .primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                startEditingName()
                            }
                    }

                    // Quantity text below name (always shown if available)
                    if isEditingAmount {
                        HStack(spacing: 4) {
                            TextField("2 adet", text: $editAmount)
                                .font(.system(size: 12, weight: .regular, design: .rounded))
                                .foregroundColor(.secondary)
                                .focused($isAmountFocused)
                                .frame(width: 80)
                                .onSubmit {
                                    saveAmountAndStopEditing()
                                }
                                .onChange(of: isAmountFocused) { _, focused in
                                    if !focused {
                                        saveAmountAndStopEditing()
                                    }
                                }
                                .onAppear {
                                    isAmountFocused = true
                                }
                        }
                    } else if !food.amount.isEmpty {
                        Text(food.amount)
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundColor(.secondary)
                            .onTapGesture {
                                startEditingAmount()
                            }
                    } else {
                        Text("Miktar ekle")
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundColor(.secondary.opacity(0.7))
                            .onTapGesture {
                                startEditingAmount()
                            }
                    }
                }

                // Carbs pill (inline editable) - only shown if detailed format
                if isDetailedFormat {
                    if isEditingCarbs {
                        TextField("0", text: $editCarbs)
                            .keyboardType(.numberPad)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(AppTheme.primaryPurple)
                            .multilineTextAlignment(.center)
                            .focused($isCarbsFocused)
                            .padding(.horizontal, ResponsiveDesign.width(12))
                            .padding(.vertical, ResponsiveDesign.height(6))
                            .background(
                                Capsule()
                                    .fill(AppTheme.primaryPurple.opacity(0.15))
                            )
                            .frame(width: ResponsiveDesign.width(70))
                            .onSubmit {
                                saveCarbsAndStopEditing()
                            }
                            .onChange(of: isCarbsFocused) { _, focused in
                                if !focused {
                                    saveCarbsAndStopEditing()
                                }
                            }
                            .onAppear {
                                isCarbsFocused = true
                            }
                            .transition(.scale.combined(with: .opacity))
                    } else if !food.carbs.isEmpty {
                        Text("\(food.carbs)g")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(AppTheme.primaryPurple)
                            .padding(.horizontal, ResponsiveDesign.width(12))
                            .padding(.vertical, ResponsiveDesign.height(6))
                            .background(
                                Capsule()
                                    .fill(AppTheme.primaryPurple.opacity(0.15))
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.smooth(duration: 0.25)) {
                                    startEditingCarbs()
                                }
                            }
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        Text("0g")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(AppTheme.primaryPurple.opacity(0.5))
                            .padding(.horizontal, ResponsiveDesign.width(12))
                            .padding(.vertical, ResponsiveDesign.height(6))
                            .background(
                                Capsule()
                                    .fill(AppTheme.primaryPurple.opacity(0.08))
                            )
                            .onTapGesture {
                                withAnimation(.smooth(duration: 0.25)) {
                                    startEditingCarbs()
                                }
                            }
                    }
                }
            }
        }
        .padding(.vertical, ResponsiveDesign.Spacing.medium)
        .padding(.horizontal, ResponsiveDesign.Spacing.medium)
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.card, style: .continuous))
    }

    // MARK: - Editing Methods

    private func startEditingName() {
        editName = food.name
        isEditingName = true
    }

    private func saveNameAndStopEditing() {
        isEditingName = false
        isNameFocused = false
        let newName = editName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !newName.isEmpty {
            food.name = newName
        }
    }

    private func startEditingAmount() {
        editAmount = food.amount
        isEditingAmount = true
    }

    private func saveAmountAndStopEditing() {
        isEditingAmount = false
        isAmountFocused = false
        let newAmount = editAmount.trimmingCharacters(in: .whitespacesAndNewlines)
        food.amount = newAmount
    }

    private func startEditingCarbs() {
        editCarbs = food.carbs
        isEditingCarbs = true
    }

    private func saveCarbsAndStopEditing() {
        isEditingCarbs = false
        isCarbsFocused = false
        let newCarbs = editCarbs.trimmingCharacters(in: .whitespacesAndNewlines)
        food.carbs = newCarbs
    }
}

// MARK: - Meal Preview Editor

struct MealPreviewEditor: View {
    let parsedData: ParsedMealData
    let isDetailedFormat: Bool // TRUE = show per-item carbs, FALSE = show only total

    @Binding var editableFoods: [EditableFoodItem]
    @Binding var editableTotalCarbs: String
    @Binding var editableMealType: String
    @Binding var editableMealTime: String
    @Binding var editableTimestamp: Date
    @Binding var hasInsulin: Bool
    @Binding var editableInsulinDosage: Double
    @Binding var editableInsulinType: String?
    @Binding var editableInsulinName: String?

    let onAdjustCarbs: (Int) -> Void

    @State private var isInsulinFinalized = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // TOP ROW: Meal Type (left) and Carb Stepper (right)
                HStack(alignment: .top, spacing: 16) {
                    // EDITABLE Meal Type Picker - LEFT SIDE
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Öğün Türü")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)

                        Picker("Öğün", selection: $editableMealType) {
                            Text("Kahvaltı").tag("kahvaltı")
                            Text("Ara Öğün").tag("ara öğün")
                            Text("Akşam Yemeği").tag("akşam yemeği")
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // EDITABLE Total Carbs with Stepper - RIGHT SIDE
                    VStack(alignment: .trailing, spacing: 8) {
                        Text("Karbonhidrat")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)

                        HStack(spacing: 8) {
                            // Decrease button
                            Button {
                                onAdjustCarbs(-5)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundStyle(AppTheme.primaryPurple)
                            }
                            .buttonStyle(.plain)

                            // Carb value
                            TextField("0", text: $editableTotalCarbs)
                                .keyboardType(.numberPad)
                                .font(.system(size: 24, weight: .bold, design: .rounded).monospacedDigit())
                                .glassTextField()
                                .frame(width: 70)
                                .multilineTextAlignment(.center)

                            Text("g")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.secondary)

                            // Increase button
                            Button {
                                onAdjustCarbs(5)
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundStyle(AppTheme.primaryPurple)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal)

                Divider()
                    .padding(.horizontal)

                // EDITABLE Foods Array - inline style matching shopping list
                VStack(alignment: .leading, spacing: 16) {
                    Text("Yiyecekler")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                        .padding(.horizontal)

                    ForEach($editableFoods) { $food in
                        EditableFoodRow(
                            food: $food,
                            isDetailedFormat: isDetailedFormat
                        )
                        .padding(.horizontal)
                    }

                    // Add food and insulin buttons stacked vertically and centered
                    VStack(spacing: 12) {
                        Button {
                            var transaction = Transaction()
                            transaction.disablesAnimations = true
                            withTransaction(transaction) {
                                editableFoods.append(EditableFoodItem(name: "", amount: nil, carbs: nil))
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "carrot.fill")
                                    .font(.system(size: 16, weight: .medium))
                                    .frame(width: 20, height: 20)
                                Text("Yiyecek Ekle")
                                    .font(.system(size: 16, weight: .medium, design: .rounded))
                            }
                            .frame(width: 140, height: 44)
                        }
                        .buttonStyle(.bordered)

                        if !hasInsulin {
                            Button {
                                hasInsulin = true
                                editableInsulinDosage = 0 // Start at 0
                                editableInsulinName = "NovoRapid" // Default insulin type
                                isInsulinFinalized = false // Start in stepper mode
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "microbe.fill")
                                        .font(.system(size: 16, weight: .medium))
                                        .frame(width: 20, height: 20)
                                    Text("İnsülin Ekle")
                                        .font(.system(size: 16, weight: .medium, design: .rounded))
                                }
                                .frame(width: 140, height: 44)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal)
                }
                .animation(nil, value: editableFoods)

                // INSULIN SECTION (if insulin was detected or user wants to add)
                if hasInsulin {
                    Divider()
                        .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 16) {
                        Text("İnsülin")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)
                            .padding(.horizontal)

                        EditableInsulinRow(
                            dosage: $editableInsulinDosage,
                            insulinName: $editableInsulinName,
                            isFinalized: $isInsulinFinalized
                        )
                        .padding(.horizontal)

                        // Tamam button (only visible when editing)
                        if !isInsulinFinalized {
                            HStack {
                                Spacer()
                                Button {
                                    isInsulinFinalized = true
                                } label: {
                                    Text("Tamam")
                                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                                        .foregroundColor(.white)
                                        .frame(width: 120)
                                        .padding(.vertical, 12)
                                        .background(
                                            Capsule()
                                                .fill(AppTheme.primaryPurple)
                                        )
                                }
                                .buttonStyle(.plain)
                                Spacer()
                            }
                        }
                    }
                }

                // EDITABLE Timestamp
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tarih ve Saat")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)

                    DatePicker(
                        "Öğün zamanı",
                        selection: $editableTimestamp,
                        in: ...Date(),
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal)

                // Confidence warning
                if let confidence = parsedData.confidence, confidence != "high" {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("Bazı bilgileri tahmin ettim, lütfen kontrol et")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(.orange)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)

                    Divider()
                        .padding(.horizontal)
                }

                // Show transcription at the BOTTOM
                if let transcription = parsedData.transcription {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Duyduklarım")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)

                        Text(transcription)
                            .font(.system(size: 16, weight: .regular, design: .rounded))
                            .italic()
                            .foregroundStyle(.primary)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 32)
                }
            }
            .padding(.top, 32)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
    }
}

// MARK: - Previews

#Preview("Simple Meal - No Insulin") {
    @Previewable @State var editableFoods = [
        EditableFoodItem(name: "Ekmek", amount: "2 adet", carbs: 30),
        EditableFoodItem(name: "Peynir", amount: "1 dilim", carbs: 2)
    ]
    @Previewable @State var editableTotalCarbs = "32"
    @Previewable @State var editableMealType = "kahvaltı"
    @Previewable @State var editableMealTime = "08:30"
    @Previewable @State var editableTimestamp = Date()
    @Previewable @State var hasInsulin = false
    @Previewable @State var editableInsulinDosage = 0.0
    @Previewable @State var editableInsulinType: String? = nil
    @Previewable @State var editableInsulinName: String? = nil

    let parsedData = ParsedMealData(
        transcription: "İki adet ekmek ve bir dilim peynir yedim",
        foods: [
            ParsedFoodItem(name: "Ekmek", amount: "2 adet", carbs: 30),
            ParsedFoodItem(name: "Peynir", amount: "1 dilim", carbs: 2)
        ],
        totalCarbs: 32,
        mealType: "kahvaltı",
        mealTime: "08:30",
        confidence: "high"
    )

    MealPreviewEditor(
        parsedData: parsedData,
        isDetailedFormat: false, // Simple format - no per-item carbs
        editableFoods: $editableFoods,
        editableTotalCarbs: $editableTotalCarbs,
        editableMealType: $editableMealType,
        editableMealTime: $editableMealTime,
        editableTimestamp: $editableTimestamp,
        hasInsulin: $hasInsulin,
        editableInsulinDosage: $editableInsulinDosage,
        editableInsulinType: $editableInsulinType,
        editableInsulinName: $editableInsulinName,
        onAdjustCarbs: { delta in
            if let current = Int(editableTotalCarbs) {
                editableTotalCarbs = "\(max(0, current + delta))"
            }
        }
    )
}

#Preview("Detailed Meal with Insulin") {
    @Previewable @State var editableFoods = [
        EditableFoodItem(name: "Ekmek", amount: "2 adet", carbs: 30),
        EditableFoodItem(name: "Peynir", amount: "50 gram", carbs: 2),
        EditableFoodItem(name: "Domates", amount: "1 adet", carbs: 3)
    ]
    @Previewable @State var editableTotalCarbs = "35"
    @Previewable @State var editableMealType = "akşam yemeği"
    @Previewable @State var editableMealTime = "19:45"
    @Previewable @State var editableTimestamp = Date()
    @Previewable @State var hasInsulin = true
    @Previewable @State var editableInsulinDosage = 5.0
    @Previewable @State var editableInsulinType: String? = "bolus"
    @Previewable @State var editableInsulinName: String? = "NovoRapid"

    let parsedData = ParsedMealData(
        transcription: "Akşam yemeğinde iki adet ekmek, elli gram peynir, bir adet domates yedim. Beş ünite NovoRapid vurdum.",
        foods: [
            ParsedFoodItem(name: "Ekmek", amount: "2 adet", carbs: 30),
            ParsedFoodItem(name: "Peynir", amount: "50 gram", carbs: 2),
            ParsedFoodItem(name: "Domates", amount: "1 adet", carbs: 3)
        ],
        totalCarbs: 35,
        mealType: "akşam yemeği",
        mealTime: "19:45",
        confidence: "high",
        insulinDosage: 5.0,
        insulinType: "bolus",
        insulinName: "NovoRapid"
    )

    MealPreviewEditor(
        parsedData: parsedData,
        isDetailedFormat: true, // Detailed format - show per-item carbs
        editableFoods: $editableFoods,
        editableTotalCarbs: $editableTotalCarbs,
        editableMealType: $editableMealType,
        editableMealTime: $editableMealTime,
        editableTimestamp: $editableTimestamp,
        hasInsulin: $hasInsulin,
        editableInsulinDosage: $editableInsulinDosage,
        editableInsulinType: $editableInsulinType,
        editableInsulinName: $editableInsulinName,
        onAdjustCarbs: { delta in
            if let current = Int(editableTotalCarbs) {
                editableTotalCarbs = "\(max(0, current + delta))"
            }
        }
    )
}

#Preview("Low Confidence Warning") {
    @Previewable @State var editableFoods = [
        EditableFoodItem(name: "Ekmek", amount: "2 adet", carbs: nil)
    ]
    @Previewable @State var editableTotalCarbs = "30"
    @Previewable @State var editableMealType = "ara öğün"
    @Previewable @State var editableMealTime = "15:30"
    @Previewable @State var editableTimestamp = Date()
    @Previewable @State var hasInsulin = false
    @Previewable @State var editableInsulinDosage = 0.0
    @Previewable @State var editableInsulinType: String? = nil
    @Previewable @State var editableInsulinName: String? = nil

    let parsedData = ParsedMealData(
        transcription: "Bir şeyler yedim ama tam hatırlamıyorum",
        foods: [
            ParsedFoodItem(name: "Ekmek", amount: "2 adet", carbs: nil)
        ],
        totalCarbs: 30,
        mealType: "ara öğün",
        mealTime: "15:30",
        confidence: "medium"
    )

    MealPreviewEditor(
        parsedData: parsedData,
        isDetailedFormat: false, // Simple format with warning
        editableFoods: $editableFoods,
        editableTotalCarbs: $editableTotalCarbs,
        editableMealType: $editableMealType,
        editableMealTime: $editableMealTime,
        editableTimestamp: $editableTimestamp,
        hasInsulin: $hasInsulin,
        editableInsulinDosage: $editableInsulinDosage,
        editableInsulinType: $editableInsulinType,
        editableInsulinName: $editableInsulinName,
        onAdjustCarbs: { delta in
            if let current = Int(editableTotalCarbs) {
                editableTotalCarbs = "\(max(0, current + delta))"
            }
        }
    )
}
