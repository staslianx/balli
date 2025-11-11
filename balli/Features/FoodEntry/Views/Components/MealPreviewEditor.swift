//
//  MealPreviewEditor.swift
//  balli
//
//  Editable meal preview form component
//  Swift 6 strict concurrency compliant
//

import SwiftUI

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
                    MealTypePicker(mealType: $editableMealType)

                    // EDITABLE Total Carbs with Stepper - RIGHT SIDE
                    CarbStepperView(
                        totalCarbs: $editableTotalCarbs,
                        onAdjustCarbs: onAdjustCarbs
                    )
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

                    // Add food and insulin buttons
                    AddItemButtonsView(
                        editableFoods: $editableFoods,
                        hasInsulin: $hasInsulin,
                        insulinDosage: $editableInsulinDosage,
                        insulinName: $editableInsulinName,
                        isInsulinFinalized: $isInsulinFinalized
                    )
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
