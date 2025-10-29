//
//  InsulinGlucoseCurveWarningView.swift
//  balli
//
//  Warning card for insulin-glucose curve mismatch
//  Shows when recipe's glucose absorption doesn't align with insulin action
//

import SwiftUI

/// Main warning view with expandable dual-curve chart
struct InsulinGlucoseCurveWarningView: View {
    // Nutrition data (per-serving values)
    let fatPerServing: Double
    let proteinPerServing: Double
    let carbsPerServing: Double
    let sugarPerServing: Double
    let fiberPerServing: Double
    let glycemicLoadPerServing: Double

    @State private var isExpanded = false

    // Calculator
    private let calculator = InsulinCurveCalculator.shared

    // Computed nutrition data
    private var nutrition: InsulinCurveCalculator.RecipeNutrition {
        InsulinCurveCalculator.RecipeNutrition(
            carbohydrates: carbsPerServing,
            fat: fatPerServing,
            protein: proteinPerServing,
            sugar: sugarPerServing,
            fiber: fiberPerServing,
            glycemicLoad: glycemicLoadPerServing
        )
    }

    // Curve calculations
    private var glucosePeakTime: Int {
        calculator.calculateGlucosePeakTime(nutrition: nutrition)
    }

    private var mismatchMinutes: Int {
        calculator.calculateMismatch(glucosePeakTime: glucosePeakTime)
    }

    private var warningLevel: CurveWarningLevel {
        calculator.determineWarning(nutrition: nutrition).level
    }

    private var shouldShow: Bool {
        warningLevel != .none
    }

    var body: some View {
        if shouldShow {
            VStack(alignment: .leading, spacing: 12) {
                // Header with expand/collapse indicator
                warningHeader

                // Collapsed: Just message
                if !isExpanded {
                    Text(warningLevel.getMessage(
                        mismatchMinutes: mismatchMinutes,
                        fatGrams: fatPerServing,
                        proteinGrams: proteinPerServing
                    ))
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                }

                // Expanded: Chart + recommendations
                if isExpanded {
                    expandedContent
                }

                // Expand/collapse button
                Button(action: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        isExpanded.toggle()
                    }
                }) {
                    HStack {
                        Spacer()
                        Text(isExpanded ? "Gizle" : "Detaylı Eğriyi Gör")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(warningLevel.borderColor)
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(warningLevel.borderColor)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(warningLevel.backgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(warningLevel.borderColor, lineWidth: 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Header

    private var warningHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: warningLevel.iconName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(warningLevel.borderColor)

            Text(warningLevel.title)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(warningLevel.borderColor)

            Spacer()
        }
    }

    // MARK: - Expanded Content

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Warning message
            Text(warningLevel.getMessage(
                mismatchMinutes: mismatchMinutes,
                fatGrams: fatPerServing,
                proteinGrams: proteinPerServing
            ))
            .font(.system(size: 15, weight: .medium, design: .rounded))
            .foregroundColor(.primary)
            .fixedSize(horizontal: false, vertical: true)

            Divider()

            // Dual curve chart
            DualCurveChartView(
                insulinCurve: InsulinCurveData.novorapidCurve,
                glucoseCurve: calculator.generateGlucoseCurve(nutrition: nutrition),
                insulinPeakTime: InsulinCurveData.novorapidPeakTime,
                glucosePeakTime: glucosePeakTime,
                mismatchMinutes: mismatchMinutes
            )
            .frame(maxWidth: .infinity)

            Divider()

            // Recommendations
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "list.clipboard.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(warningLevel.borderColor)
                    Text("Öneriler")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(warningLevel.borderColor)
                }

                ForEach(Array(warningLevel.getRecommendations(
                    mismatchMinutes: mismatchMinutes,
                    fatGrams: fatPerServing
                ).enumerated()), id: \.offset) { index, recommendation in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                        Text(recommendation)
                            .font(.system(size: 14, weight: .regular, design: .rounded))
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Danger Level - High Fat") {
    ScrollView {
        VStack(spacing: 20) {
            InsulinGlucoseCurveWarningView(
                fatPerServing: 35,
                proteinPerServing: 25,
                carbsPerServing: 50,
                sugarPerServing: 10,
                fiberPerServing: 3,
                glycemicLoadPerServing: 20
            )
        }
        .padding()
        .background(Color(.secondarySystemBackground))
    }
}

#Preview("Warning Level - Moderate Fat") {
    ScrollView {
        VStack(spacing: 20) {
            InsulinGlucoseCurveWarningView(
                fatPerServing: 22,
                proteinPerServing: 20,
                carbsPerServing: 45,
                sugarPerServing: 15,
                fiberPerServing: 5,
                glycemicLoadPerServing: 18
            )
        }
        .padding()
        .background(Color(.secondarySystemBackground))
    }
}

#Preview("Info Level - Slight Mismatch") {
    ScrollView {
        VStack(spacing: 20) {
            InsulinGlucoseCurveWarningView(
                fatPerServing: 12,
                proteinPerServing: 15,
                carbsPerServing: 40,
                sugarPerServing: 25,
                fiberPerServing: 4,
                glycemicLoadPerServing: 12
            )
        }
        .padding()
        .background(Color(.secondarySystemBackground))
    }
}

#Preview("No Warning - Good Alignment") {
    ScrollView {
        VStack(spacing: 20) {
            InsulinGlucoseCurveWarningView(
                fatPerServing: 5,
                proteinPerServing: 10,
                carbsPerServing: 30,
                sugarPerServing: 20,
                fiberPerServing: 2,
                glycemicLoadPerServing: 15
            )

            Text("⬆️ No warning shown (good alignment)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
    }
}
