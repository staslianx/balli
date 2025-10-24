//
//  GlucoseChartCard.swift
//  balli
//
//  Glucose chart visualization card component
//

import SwiftUI
import Charts

struct GlucoseChartCard: View {
    @ObservedObject var viewModel: GlucoseChartViewModel
    @State private var selectedMeal: MealEntry?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // PERFORMANCE FIX: Show chart even while loading if we have data
            // This prevents the chart from disappearing during background refreshes
            if !viewModel.glucoseData.isEmpty {
                chartView
                    .overlay(alignment: .topTrailing) {
                        // Show subtle loading indicator while refreshing data
                        if viewModel.isLoading {
                            ProgressView()
                                .controlSize(.small)
                                .padding(8)
                                .background(.ultraThinMaterial, in: Circle())
                                .padding(8)
                        }
                    }
            } else if viewModel.isLoading {
                loadingView
            } else if let error = viewModel.errorMessage {
                errorView(message: error)
            } else {
                emptyStateView
            }
        }
        .frame(height: ResponsiveDesign.Components.chartHeight + 40)
        .clipped()
        .padding(.horizontal)
    }

    // MARK: - Subviews

    @ViewBuilder
    private var loadingView: some View {
        HStack {
            Spacer()
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
            Text("Yükleniyor...")
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(height: ResponsiveDesign.height(180))
    }

    @ViewBuilder
    private func errorView(message: String) -> some View {
        VStack(spacing: ResponsiveDesign.Spacing.small) {
            Image(systemName: viewModel.glucoseData.isEmpty ? "chart.line.uptrend.xyaxis" : "exclamationmark.triangle")
                .font(.system(size: 40, design: .rounded))
                .foregroundColor(.secondary)
            Text(message)
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(height: ResponsiveDesign.height(180))
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: ResponsiveDesign.Spacing.small) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 40, design: .rounded))
                .foregroundColor(.secondary)
            Text("Kan şekeri verisi bulunamadı")
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(height: ResponsiveDesign.height(180))
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var chartView: some View {
        if let timeRange = viewModel.calculateTimeRange() {
            let average = viewModel.calculateAverage()

            Chart {
                ForEach(viewModel.glucoseData) { reading in
                    // Area mark with purple gradient
                    AreaMark(
                        x: .value("Zaman", reading.time),
                        yStart: .value("Baseline", 70),
                        yEnd: .value("Değer", reading.value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                AppTheme.primaryPurple.opacity(0.3),
                                AppTheme.primaryPurple.opacity(0.05)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)

                    // Line mark on top of area
                    LineMark(
                        x: .value("Zaman", reading.time),
                        y: .value("Değer", reading.value)
                    )
                    .foregroundStyle(AppTheme.primaryPurple)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .interpolationMethod(.catmullRom)
                }

                // Meal log markers - vertical lines in international orange
                // Tap on lines to see carb values
                ForEach(viewModel.mealLogs, id: \.id) { meal in
                    RuleMark(x: .value("Öğün", meal.timestamp))
                        .foregroundStyle(Color(red: 1.0, green: 0.31, blue: 0.0)) // International Orange
                        .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                }

                // Average line - simple horizontal line without badge
                RuleMark(y: .value("Ortalama", average))
                    .foregroundStyle(AppTheme.primaryPurple.opacity(0.6))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [8, 4]))
            }
            .chartXScale(domain: timeRange.start...timeRange.end)
            .chartYScale(domain: 60...310)
            .chartXAxis {
                AxisMarks(values: .stride(by: .hour, count: 3)) { value in
                    AxisGridLine()
                        .foregroundStyle(Color.gray.opacity(0.2))
                    AxisTick()
                        .foregroundStyle(Color.gray.opacity(0.3))
                    AxisValueLabel(format: .dateTime.hour())
                        .font(.system(size: 10, weight: .regular, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing, values: [70, 100, 150, 200, 250, 300]) { value in
                    AxisGridLine()
                        .foregroundStyle(Color.gray.opacity(0.15))
                    AxisValueLabel()
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            .chartGesture { chartProxy in
                // Detect tap on chart
                SpatialTapGesture()
                    .onEnded { value in
                        handleChartTap(at: value.location, chartProxy: chartProxy)
                    }
            }
            .overlay(alignment: .top) {
                // Show carb tooltip when meal is selected
                if let selectedMeal = selectedMeal {
                    let carbValue = selectedMeal.consumedCarbs
                    if carbValue > 0 {
                        mealTooltip(meal: selectedMeal, carbs: carbValue)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .frame(height: ResponsiveDesign.Components.chartHeight)
            .padding(.vertical, 8)
        } else {
            Text("Grafik hatası")
                .foregroundStyle(.secondary)
                .frame(height: ResponsiveDesign.Components.chartHeight)
        }
    }

    // MARK: - Tap Handling

    private func handleChartTap(at location: CGPoint, chartProxy: ChartProxy) {
        // Get the x-axis value (time) from tap location
        guard let tappedDate: Date = chartProxy.value(atX: location.x) else {
            // Tap outside chart area - clear selection
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedMeal = nil
            }
            return
        }

        // Find the closest meal to the tapped time
        let closestMeal = viewModel.mealLogs.min { meal1, meal2 in
            abs(meal1.timestamp.timeIntervalSince(tappedDate)) <
            abs(meal2.timestamp.timeIntervalSince(tappedDate))
        }

        // Only select if tap is within 30 minutes of a meal
        if let meal = closestMeal,
           abs(meal.timestamp.timeIntervalSince(tappedDate)) < 1800 {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedMeal = meal
            }

            // Auto-dismiss after 3 seconds
            Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if selectedMeal?.id == meal.id {
                            selectedMeal = nil
                        }
                    }
                }
            }
        } else {
            // Tapped too far from any meal - clear selection
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedMeal = nil
            }
        }
    }

    // MARK: - Tooltip View

    @ViewBuilder
    private func mealTooltip(meal: MealEntry, carbs: Double) -> some View {
        VStack(spacing: 4) {
            Text("\(Int(carbs))g")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 1.0, green: 0.31, blue: 0.0))

            Text("Karbonhidrat")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)

            Text(mealTypeName(meal.mealType))
                .font(.system(size: 10, weight: .regular, design: .rounded))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        .padding(.top, 8)
    }

    // MARK: - Helpers

    private func mealTypeName(_ type: String) -> String {
        switch type.lowercased() {
        case "breakfast": return "Kahvaltı"
        case "lunch": return "Öğle Yemeği"
        case "dinner": return "Akşam Yemeği"
        case "snack": return "Atıştırmalık"
        default: return type.capitalized
        }
    }
}
