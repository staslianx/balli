//
//  GlucoseDashboardView.swift
//  balli
//
//  Glucose data visualization dashboard with iOS 26 Liquid Glass design
//  Swift 6 strict concurrency compliant
//

import SwiftUI
import Charts
import OSLog

@MainActor
struct GlucoseDashboardView: View {

    // MARK: - Environment

    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Dependencies (Injected)

    @ObservedObject var dexcomService: DexcomService
    @ObservedObject var viewModel: GlucoseDashboardViewModel

    private let logger = AppLoggers.Health.glucose

    // MARK: - Initialization

    /// Initialize with dependency injection support
    /// - Parameters:
    ///   - dexcomService: Dexcom service (force cast in default is unavoidable due to @ObservedObject limitation)
    ///   - viewModel: Optional pre-configured view model
    init(
        dexcomService: DexcomService = DependencyContainer.shared.dexcomService as! DexcomService,
        viewModel: GlucoseDashboardViewModel? = nil
    ) {
        self.dexcomService = dexcomService
        self.viewModel = viewModel ?? GlucoseDashboardViewModel(dexcomService: dexcomService)
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                headerView

                // Latest Reading Card
                if let reading = viewModel.glucoseReadings.first {
                    latestReadingCard(reading)
                }

                // Tab Picker
                tabPicker

                // Content based on selected tab
                if viewModel.selectedTab == .activities {
                    activitiesView
                } else {
                    // Glucose Chart
                    if !viewModel.glucoseReadings.isEmpty {
                        glucoseChart
                    } else if viewModel.isLoading {
                        ProgressView("Loading glucose data...")
                    } else {
                        emptyStateView
                    }

                    // Statistics
                    if !viewModel.glucoseReadings.isEmpty {
                        statisticsView
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemBackground))
        .navigationTitle("Glucose")
        .navigationBarTitleDisplayMode(.large)
        .task {
            // Ensure connection status is fresh before loading data
            await dexcomService.checkConnectionStatus()
            await viewModel.loadData()
        }
        .refreshable {
            await viewModel.loadData()
        }
        .onChange(of: dexcomService.isConnected) { oldValue, newValue in
            logger.info("🔄 [VIEW] Connection status changed: \(oldValue) → \(newValue)")
            // Reload data when connection status changes from disconnected to connected
            if !oldValue && newValue {
                logger.info("✅ [VIEW] Connection established - reloading glucose data")
                Task {
                    await viewModel.loadData()
                }
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Dexcom CGM")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if dexcomService.isConnected {
                    Label("Connected", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else {
                    Label("Not Connected", systemImage: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Spacer()

            if let lastSync = dexcomService.lastSync {
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Last Sync")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Text(lastSync, format: .relative(presentation: .named))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Latest Reading Card

    private func latestReadingCard(_ reading: HealthGlucoseReading) -> some View {
        VStack(spacing: 16) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(String(format: "%.0f", reading.value))
                            .font(.system(size: 56, weight: .bold, design: .rounded))

                        Text("mg/dL")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .offset(y: -8)
                    }

                    Text(reading.timestamp, format: .relative(presentation: .named))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Trend Indicator
                if let metadata = reading.metadata,
                   let trend = metadata["trend"] {
                    VStack(spacing: 4) {
                        Image(systemName: viewModel.trendSymbol(for: trend))
                            .font(.largeTitle)
                            .foregroundStyle(viewModel.glucoseColor(for: reading.value))

                        Text(viewModel.trendDescription(for: trend))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Range Indicator
            rangeIndicator(for: reading.value)
        }
        .padding()
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Tab Picker

    private var tabPicker: some View {
        Picker("Dashboard Tab", selection: $viewModel.selectedTab) {
            ForEach(GlucoseDashboardViewModel.DashboardTab.allCases, id: \.self) { tab in
                Text(tab.rawValue).tag(tab)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Activities View

    private var activitiesView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Today's Activity")
                .font(.headline)
                .padding(.horizontal)

            VStack(spacing: 12) {
                // Steps Card
                HStack {
                    Image(systemName: "figure.walk")
                        .font(.system(size: 32))
                        .foregroundStyle(.blue.gradient)
                        .frame(width: 50)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Steps")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("8,543")
                                .font(.system(size: 36, weight: .bold, design: .rounded))

                            Text("steps")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Goal")
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        Text("10,000")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.blue)
                    }
                }
                .padding()
                .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 12))

                // Calories Card
                HStack {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.orange.gradient)
                        .frame(width: 50)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Calories")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("342")
                                .font(.system(size: 36, weight: .bold, design: .rounded))

                            Text("kcal")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Goal")
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        Text("500")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.orange)
                    }
                }
                .padding()
                .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
    }

    // MARK: - Glucose Chart

    private var glucoseChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Glucose Levels (6am - 6am)")
                .font(.headline)
                .padding(.horizontal)

            Chart {
                // Glucose line (curvy, no data points)
                ForEach(viewModel.filteredReadingsFor24Hours(), id: \.id) { reading in
                    LineMark(
                        x: .value("Time", reading.timestamp),
                        y: .value("Glucose", reading.value)
                    )
                    .foregroundStyle(.blue.gradient)
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }

                // Average line
                RuleMark(y: .value("Average", viewModel.calculateAverageGlucose()))
                    .foregroundStyle(.purple)
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [8, 4]))
                    .annotation(position: .top, alignment: .trailing) {
                        Text("Avg: \(String(format: "%.0f", viewModel.calculateAverageGlucose()))")
                            .font(.caption2)
                            .foregroundStyle(.purple)
                            .padding(4)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 4))
                    }

                // Target range indicator (70-180 mg/dL)
                RuleMark(y: .value("Low", 70))
                    .foregroundStyle(.orange.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))

                RuleMark(y: .value("High", 180))
                    .foregroundStyle(.orange.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
            }
            .frame(height: 200)
            .chartYScale(domain: 40...300)
            .chartXScale(domain: viewModel.chartXAxisRange)
            .clipped() // Prevent chart from rendering outside bounds
            .chartXAxis {
                AxisMarks(values: .stride(by: .hour, count: 3)) { value in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel(format: .dateTime.hour())
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: [70, 100, 140, 180, 240]) { value in
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
            .padding()
        }
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Statistics

    private var statisticsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Statistics")
                .font(.headline)

            HStack(spacing: 16) {
                statCard(title: "Average", value: String(format: "%.0f", viewModel.calculateAverageGlucose()), unit: "mg/dL", color: .blue)
                statCard(title: "Minimum", value: String(format: "%.0f", viewModel.calculateMinimumGlucose()), unit: "mg/dL", color: .orange)
                statCard(title: "Maximum", value: String(format: "%.0f", viewModel.calculateMaximumGlucose()), unit: "mg/dL", color: .red)
            }

            HStack(spacing: 16) {
                statCard(title: "In Range", value: String(format: "%.0f%%", viewModel.calculateTimeInRange()), unit: "70-180", color: .green)
                statCard(title: "Readings", value: "\(viewModel.glucoseReadings.count)", unit: "total", color: .purple)
            }
        }
        .padding()
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Helper Views

    private func statCard(title: String, value: String, unit: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(color)

            Text(unit)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
    }

    private func rangeIndicator(for value: Double) -> some View {
        HStack(spacing: 4) {
            ForEach(0..<5) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(viewModel.rangeColor(for: value, index: index))
                    .frame(height: 4)
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No Data Available")
                .font(.headline)

            if !dexcomService.isConnected {
                Text("Connect to Dexcom to view your glucose data")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Text("Glucose readings will appear here")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Preview

#Preview("Connected with Data") {
    NavigationStack {
        GlucoseDashboardView(
            dexcomService: .previewConnected,
            viewModel: .previewWithData
        )
    }
    .injectDependencies()
}

#Preview("Disconnected") {
    NavigationStack {
        GlucoseDashboardView(
            dexcomService: .previewDisconnected,
            viewModel: .previewEmpty
        )
    }
    .injectDependencies()
}

#Preview("Loading") {
    NavigationStack {
        GlucoseDashboardView(
            dexcomService: .previewConnected,
            viewModel: .previewLoading
        )
    }
    .injectDependencies()
}