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

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.Spacing.xSmall) {
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
        .frame(height: ResponsiveDesign.Components.chartHeight + ResponsiveDesign.Spacing.xSmall + 40)
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
                    // Line mark only - no data points
                    LineMark(
                        x: .value("Zaman", reading.time),
                        y: .value("Değer", reading.value)
                    )
                    .foregroundStyle(AppTheme.primaryPurple)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                    .interpolationMethod(.catmullRom)
                }

                // Average line
                RuleMark(y: .value("Ortalama", average))
                    .foregroundStyle(.purple)
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [8, 4]))
                    .annotation(position: .top, alignment: .trailing) {
                        Text("Ort: \(String(format: "%.0f", average))")
                            .font(.caption2)
                            .foregroundStyle(.purple)
                            .padding(4)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 4))
                    }
            }
            .chartXScale(domain: timeRange.start...timeRange.end)
            .chartYScale(domain: 70...300)
            .clipped()
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
                AxisMarks(position: .trailing) { _ in
                    AxisValueLabel()
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                }
            }
            .frame(height: ResponsiveDesign.Components.chartHeight)
        } else {
            Text("Grafik hatası")
                .foregroundStyle(.secondary)
                .frame(height: ResponsiveDesign.Components.chartHeight)
        }
    }
}
