//
//  EditableFoodRow.swift
//  balli
//
//  Editable food row with inline editing and focus management
//  Extracted from MealPreviewEditor.swift
//  Swift 6 strict concurrency compliant
//

import SwiftUI

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
