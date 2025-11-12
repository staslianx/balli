//
//  ActivityMetricsCard.swift
//  balli
//
//  Activity metrics (steps and calories) card component
//

import SwiftUI

struct ActivityMetricsCard: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var viewModel: ActivityMetricsViewModel
    let healthKitPermissions: HealthKitPermissionManager
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.Spacing.xSmall) {
            if let error = viewModel.errorMessage {
                errorView(message: error)
            } else {
                metricsView
            }
        }
        .frame(height: ResponsiveDesign.Components.chartHeight + 40)  // Match GlucoseChartCard height
        .padding(.horizontal)
        .onChange(of: scenePhase) { _, newPhase in
            // When app becomes active (user returning from Settings), refresh permissions
            if newPhase == .active {
                viewModel.refreshPermissionsAndData()
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private func errorView(message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 24, design: .rounded))
                .foregroundStyle(.orange)

            Text(message)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if healthKitPermissions.shouldShowSettingsButton {
                Button {
                    healthKitPermissions.openHealthKitSettings()
                } label: {
                    Text("Ayarları Aç")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppTheme.foregroundOnColor(for: colorScheme))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(AppTheme.primaryPurple)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    @ViewBuilder
    private var metricsView: some View {
        VStack(spacing: 32) {
            Spacer()

            // Steps Card
            HStack(spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(String(format: "%.0f", viewModel.todaySteps))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .offset(y: 1)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Text("adım")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .offset(y:1.5)

                    Image(systemName: "figure.walk")
                        .font(.system(size: 28))
                        .foregroundStyle(AppTheme.primaryPurple)
                        .alignmentGuide(.firstTextBaseline) { d in d[.bottom] }
                        .offset(y: 5.5)
                }
                .layoutPriority(1)

                Spacer(minLength: 12)

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Düne kıyasla")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(AppTheme.primaryPurple)
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)

                    Text("\(viewModel.stepsChangePercent >= 0 ? "+" : "")\(viewModel.stepsChangePercent)%")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.primaryPurple)
                }
                .frame(minWidth: 90)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            // Divider
            Rectangle()
                .fill(AppTheme.primaryPurple.opacity(0.2))
                .frame(height: 0.5)
                .padding(.horizontal)

            // Calories Card
            HStack(spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(String(format: "%.0f", viewModel.todayCalories))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .offset(y: 0)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Text("kcal")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .offset(y: 0)

                    Image(systemName: "app.background.dotted")
                        .font(.system(size: 28))
                        .foregroundStyle(AppTheme.primaryPurple)
                        .offset(y: 4)
                        .alignmentGuide(.firstTextBaseline) { d in d[.bottom] }
                }
                .layoutPriority(1)

                Spacer(minLength: 12)

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Düne kıyasla")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(AppTheme.primaryPurple)
                        .offset(y:-1.4)
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)

                    Text("\(viewModel.caloriesChangePercent >= 0 ? "+" : "")\(viewModel.caloriesChangePercent)%")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.primaryPurple)
                        .offset(y:-1.4)
                }
                .frame(minWidth: 90)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Spacer()
        }
        .frame(height: ResponsiveDesign.Components.chartHeight)
    }
}

// MARK: - Previews

#Preview("Healthy Activity") {
    ActivityMetricsCard(
        viewModel: ActivityMetricsViewModel.preview,
        healthKitPermissions: HealthKitPermissionManager.preview
    )
    .previewWithPadding()
    .frame(height: ResponsiveDesign.Components.chartHeight + 100)
}

#Preview("High Activity") {
    ActivityMetricsCard(
        viewModel: ActivityMetricsViewModel.previewHighActivity,
        healthKitPermissions: HealthKitPermissionManager.preview
    )
    .previewWithPadding()
    .frame(height: ResponsiveDesign.Components.chartHeight + 100)
}

#Preview("Low Activity") {
    ActivityMetricsCard(
        viewModel: ActivityMetricsViewModel.previewLowActivity,
        healthKitPermissions: HealthKitPermissionManager.preview
    )
    .previewWithPadding()
    .frame(height: ResponsiveDesign.Components.chartHeight + 100)
}

#Preview("Error State") {
    ActivityMetricsCard(
        viewModel: ActivityMetricsViewModel.previewError,
        healthKitPermissions: HealthKitPermissionManager.previewDenied
    )
    .previewWithPadding()
    .frame(height: ResponsiveDesign.Components.chartHeight + 100)
}

#Preview("Loading State") {
    ActivityMetricsCard(
        viewModel: ActivityMetricsViewModel.previewLoading,
        healthKitPermissions: HealthKitPermissionManager.preview
    )
    .previewWithPadding()
    .frame(height: ResponsiveDesign.Components.chartHeight + 100)
}
