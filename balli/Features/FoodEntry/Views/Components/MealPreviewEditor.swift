//
//  MealPreviewEditor.swift
//  balli
//
//  Editable meal preview form component
//  Swift 6 strict concurrency compliant
//

import SwiftUI

struct MealPreviewEditor: View {
    let parsedData: ParsedMealData

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

                // EDITABLE Foods Array
                VStack(alignment: .leading, spacing: 16) {
                    Text("Yiyecekler")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                        .padding(.horizontal)

                    ForEach($editableFoods) { $food in
                        VStack(spacing: 12) {
                            // Food name
                            TextField("Yiyecek adı", text: $food.name)
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .glassTextField()

                            // Amount
                            TextField("Örn: 2 adet, 1 dilim", text: $food.amount)
                                .font(.system(size: 14, design: .rounded))
                                .glassTextField()

                            // Per-item carbs (if detailed format)
                            if parsedData.isDetailedFormat {
                                HStack {
                                    Text("Karb:")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(.secondary)
                                        .frame(width: 60, alignment: .leading)

                                    TextField("0", text: $food.carbs)
                                        .keyboardType(.numberPad)
                                        .font(.system(size: 16, weight: .bold, design: .rounded).monospacedDigit())
                                        .glassTextField()
                                        .frame(width: 80)

                                    Text("gram")
                                        .font(.system(size: 14))
                                        .foregroundStyle(.secondary)

                                    Spacer()
                                }
                            }
                        }
                        .padding(16)
                        .background(AppTheme.primaryPurple.opacity(0.2))
                        .cornerRadius(24)
                        .padding(.horizontal)
                    }

                    // Add food button
                    Button {
                        editableFoods.append(EditableFoodItem(name: "", amount: nil, carbs: nil))
                    } label: {
                        Label("Yiyecek Ekle", systemImage: "plus.circle")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                    }
                    .buttonStyle(.bordered)
                    .padding(.horizontal)
                }

                // INSULIN SECTION (if insulin was detected or user wants to add)
                if hasInsulin {
                    Divider()
                        .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("İnsülin")
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                .foregroundStyle(.primary)

                            Spacer()

                            Button {
                                hasInsulin = false
                                editableInsulinDosage = 0
                            } label: {
                                Label("Sil", systemImage: "trash")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal)

                        VStack(spacing: 16) {
                            // Insulin dosage stepper
                            HStack {
                                Text("Doz:")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 60, alignment: .leading)

                                Spacer()

                                // Decrease button
                                Button {
                                    editableInsulinDosage = max(0, editableInsulinDosage - 1)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .font(.system(size: 28))
                                        .foregroundStyle(AppTheme.primaryPurple)
                                }
                                .buttonStyle(.plain)

                                // Dosage value
                                Text("\(Int(editableInsulinDosage))")
                                    .font(.system(size: 24, weight: .bold, design: .rounded).monospacedDigit())
                                    .frame(width: 70)

                                Text("ünite")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.secondary)

                                // Increase button
                                Button {
                                    editableInsulinDosage += 1
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 28))
                                        .foregroundStyle(AppTheme.primaryPurple)
                                }
                                .buttonStyle(.plain)
                            }

                            // Insulin type display (if detected)
                            if let insulinName = editableInsulinName {
                                HStack {
                                    Text("İsim:")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(.secondary)
                                        .frame(width: 60, alignment: .leading)

                                    Text(insulinName)
                                        .font(.system(size: 16, weight: .medium, design: .rounded))
                                        .foregroundStyle(.primary)

                                    Spacer()

                                    if let insulinType = editableInsulinType {
                                        Text(insulinType == "bolus" ? "Hızlı Etkili" : "Uzun Etkili")
                                            .font(.system(size: 12, weight: .medium, design: .rounded))
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(insulinType == "bolus" ? AppTheme.primaryPurple : .blue)
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                        }
                        .padding(16)
                        .background(AppTheme.primaryPurple.opacity(0.05))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                } else {
                    // Button to add insulin manually
                    Button {
                        hasInsulin = true
                        editableInsulinDosage = 5 // Default starting value
                    } label: {
                        Label("İnsülin Ekle", systemImage: "plus.circle")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                    }
                    .buttonStyle(.bordered)
                    .padding(.horizontal)
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
