//
//  EditableInsulinRow.swift
//  balli
//
//  Editable insulin row with pill/stepper toggle
//  Extracted from MealPreviewEditor.swift
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
