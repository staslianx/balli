//
//  AbsorptionTimingChart.swift
//  balli
//
//  Visualizes insulin vs meal absorption timing based on macronutrient composition
//

import SwiftUI
import Charts

@MainActor
struct AbsorptionTimingChart: View {
    let fat: Double
    let protein: Double
    let carbs: Double

    @State private var absorptionProfile: AbsorptionProfile?

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.Spacing.medium) {
            if let profile = absorptionProfile {
                // Main chart
                Chart {
                    // Insulin curve (orange)
                    ForEach(profile.insulinCurve) { point in
                        LineMark(
                            x: .value("Saat", point.timeHours),
                            y: .value("Yoğunluk", point.intensity),
                            series: .value("Tip", "İnsülin")
                        )
                        .foregroundStyle(Color.orange)
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                        .interpolationMethod(.catmullRom)
                    }

                    // Meal curve (custom purple)
                    ForEach(profile.mealCurve) { point in
                        LineMark(
                            x: .value("Saat", point.timeHours),
                            y: .value("Yoğunluk", point.intensity),
                            series: .value("Tip", "Yemek")
                        )
                        .foregroundStyle(ThemeColors.primaryPurple)
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                        .interpolationMethod(.catmullRom)
                    }

                    // Peak difference line (only show if meaningful difference)
                    if profile.peakDifferenceHours > 0.5 {
                        RuleMark(x: .value("Fark", profile.mealPeakTime))
                            .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                            .foregroundStyle(Color.gray.opacity(0.5))
                            .annotation(position: .top, alignment: .center, spacing: 4) {
                                Text(String(format: "%.1f saat fark", profile.peakDifferenceHours))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color(uiColor: .systemBackground).opacity(0.9))
                                    .cornerRadius(6)
                                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                            }
                    }
                }
                .chartLegend(.hidden)
                .chartXAxis {
                    AxisMarks(values: [0, 1, 2, 3, 4, 5, 6]) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(Color.gray.opacity(0.2))
                        AxisTick()
                        AxisValueLabel {
                            if let hour = value.as(Double.self) {
                                Text("\(Int(hour))s")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(values: [0, 0.25, 0.5, 0.75, 1.0]) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(Color.gray.opacity(0.2))
                        AxisValueLabel {
                            if let val = value.as(Double.self) {
                                Text("\(Int(val * 100))%")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .chartYScale(domain: -0.05...1.1)
                .chartXScale(domain: 0...6)
                .frame(height: 220)

                // Legend
                HStack(spacing: 20) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 10, height: 10)
                        Text("İnsülin (Novorapid)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    HStack(spacing: 6) {
                        Circle()
                            .fill(ThemeColors.primaryPurple)
                            .frame(width: 10, height: 10)
                        Text("Yemek Emilimi")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 8)
            } else {
                // Loading state
                ProgressView()
                    .frame(height: 220)
            }
        }
        .padding(ResponsiveDesign.Spacing.medium)
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(ResponsiveDesign.CornerRadius.card)
        .onAppear {
            calculateAbsorptionProfile()
        }
        .onChange(of: fat) { _ in
            calculateAbsorptionProfile()
        }
        .onChange(of: protein) { _ in
            calculateAbsorptionProfile()
        }
        .onChange(of: carbs) { _ in
            calculateAbsorptionProfile()
        }
        .animation(.easeInOut, value: absorptionProfile?.mealPeakTime)
    }

    // MARK: - Profile Calculation

    private func calculateAbsorptionProfile() {
        let insulinCurve = generateInsulinCurve()
        let mealCurve = generateMealCurve(fat: fat, protein: protein, carbs: carbs)

        let peaks = calculatePeakDifference(
            insulinCurve: insulinCurve,
            mealCurve: mealCurve
        )

        absorptionProfile = AbsorptionProfile(
            insulinCurve: insulinCurve,
            mealCurve: mealCurve,
            peakDifferenceHours: peaks.timeDifference,
            insulinPeakTime: peaks.insulinPeakTime,
            mealPeakTime: peaks.mealPeakTime
        )
    }

    // MARK: - Curve Generation

    /// Generates the insulin absorption curve for Novorapid
    /// Novorapid pharmacokinetics (clinically established):
    /// - Onset: 10-15 min (0.17-0.25h)
    /// - Peak: 1-1.5 hours
    /// - Duration: 3-5 hours
    /// - Action profile: Rapid rise, sharp peak, gradual decline
    private func generateInsulinCurve() -> [TimePoint] {
        let dataPoints: [(time: Double, intensity: Double)] = [
            (0.0, 0.0),      // Injection time
            (0.25, 0.35),    // Rapid onset (15 min)
            (0.5, 0.65),     // Rising
            (1.0, 1.0),      // Peak at 1h
            (1.5, 0.85),     // Just past peak
            (2.0, 0.60),     // Declining
            (2.5, 0.40),
            (3.0, 0.25),     // Tail
            (3.5, 0.15),
            (4.0, 0.08),
            (4.5, 0.04),
            (5.0, 0.02),
            (6.0, 0.0)       // End of action
        ]

        return dataPoints.map { TimePoint(timeHours: $0.time, intensity: $0.intensity) }
    }

    /// Generates the meal absorption curve based on macronutrient composition
    /// - Parameters:
    ///   - fat: Grams of fat
    ///   - protein: Grams of protein
    ///   - carbs: Grams of carbohydrates
    /// - Returns: Array of TimePoint representing the meal absorption curve
    private func generateMealCurve(fat: Double, protein: Double, carbs: Double) -> [TimePoint] {
        // Calculate macronutrient ratios
        let safeDivisor = max(carbs, 1.0)  // Prevent division by zero
        let fatRatio = fat / safeDivisor
        let proteinRatio = protein / safeDivisor

        // Calculate peak timing
        // Base peak for low-fat meal: 1.0 hour
        // Fat delays peak: Each 1.0 fat ratio adds ~1.5h delay
        // Protein delays peak: Each 1.0 protein ratio adds ~0.5h delay
        let basePeakTime = 1.0
        let fatDelay = fatRatio * 1.5
        let proteinDelay = proteinRatio * 0.5
        var peakTime = basePeakTime + fatDelay + proteinDelay
        peakTime = min(peakTime, 4.0)  // Cap at 4 hours

        // Calculate absorption duration
        // Base duration: 3 hours
        // Fat extends duration: Each 1.0 fat ratio adds 2h
        let baseDuration = 3.0
        var duration = baseDuration + (fatRatio * 2.0)
        duration = min(duration, 6.0)  // Cap at 6 hours
        duration = max(duration, peakTime + 1.0)  // Must be at least 1h past peak

        // Generate smooth curve
        var points: [TimePoint] = []

        // Create 25 points for smooth curve (every 0.25h)
        for i in 0...24 {
            let t = Double(i) * 0.25  // 0.0, 0.25, 0.5, ... 6.0
            let intensity: Double

            if t <= peakTime {
                // Rising phase: Use sine curve for smooth rise
                // Progress from 0 to π/2 (0° to 90°)
                let progress = t / peakTime
                intensity = sin(progress * .pi / 2)
            } else if t <= duration {
                // Falling phase: Use cosine curve for smooth decline
                // Progress from 0 to π/2 (0° to 90°)
                let progress = (t - peakTime) / (duration - peakTime)
                intensity = cos(progress * .pi / 2)
            } else {
                // Tail phase: Exponential decay
                let tailProgress = t - duration
                intensity = max(0.0, 0.1 * exp(-tailProgress * 0.8))
            }

            points.append(TimePoint(timeHours: t, intensity: intensity))
        }

        return points
    }

    /// Calculates the timing difference between insulin and meal absorption peaks
    private func calculatePeakDifference(
        insulinCurve: [TimePoint],
        mealCurve: [TimePoint]
    ) -> (timeDifference: Double, insulinPeakTime: Double, mealPeakTime: Double) {
        // Find peak points
        guard let insulinPeak = insulinCurve.max(by: { $0.intensity < $1.intensity }),
              let mealPeak = mealCurve.max(by: { $0.intensity < $1.intensity }) else {
            return (0, 0, 0)
        }

        let timeDifference = abs(mealPeak.timeHours - insulinPeak.timeHours)

        return (
            timeDifference: timeDifference,
            insulinPeakTime: insulinPeak.timeHours,
            mealPeakTime: mealPeak.timeHours
        )
    }
}

// MARK: - Previews

#Preview("Low-Fat Meal (Aligned)") {
    VStack {
        Text("Low-Fat Meal Example")
            .font(.title2)
            .padding()

        AbsorptionTimingChart(
            fat: 15,
            protein: 25,
            carbs: 50
        )
        .padding()

        Text("Expected: ~0.3h difference, curves mostly aligned")
            .font(.caption)
            .foregroundColor(.secondary)
            .padding()
    }
}

#Preview("Moderate-Fat Meal") {
    VStack {
        Text("Moderate-Fat Meal Example")
            .font(.title2)
            .padding()

        AbsorptionTimingChart(
            fat: 25,
            protein: 30,
            carbs: 45
        )
        .padding()

        Text("Expected: ~1.2h difference, dashed line shown")
            .font(.caption)
            .foregroundColor(.secondary)
            .padding()
    }
}

#Preview("High-Fat Meal (Dana Sote)") {
    VStack {
        Text("High-Fat Meal Example (Dana Sote)")
            .font(.title2)
            .padding()

        AbsorptionTimingChart(
            fat: 42,
            protein: 49,
            carbs: 48
        )
        .padding()

        Text("Expected: ~2.0h difference, significant timing mismatch")
            .font(.caption)
            .foregroundColor(.secondary)
            .padding()
    }
}

#Preview("All States") {
    ScrollView {
        VStack(spacing: 20) {
            Group {
                Text("Low-Fat (Aligned)")
                    .font(.headline)
                AbsorptionTimingChart(fat: 10, protein: 20, carbs: 50)
            }

            Divider()

            Group {
                Text("Moderate-Fat")
                    .font(.headline)
                AbsorptionTimingChart(fat: 30, protein: 25, carbs: 45)
            }

            Divider()

            Group {
                Text("High-Fat")
                    .font(.headline)
                AbsorptionTimingChart(fat: 50, protein: 40, carbs: 40)
            }
        }
        .padding()
    }
}
