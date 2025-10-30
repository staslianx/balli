//
//  ActivityMetricsCard.swift
//  balli
//
//  Activity metrics (steps and calories) card component
//

import SwiftUI

struct ActivityMetricsCard: View {
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
        .frame(height: ResponsiveDesign.Components.chartHeight + ResponsiveDesign.Spacing.xSmall + 40)
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
                        .foregroundStyle(.white)
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
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .offset(y: 1)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)

                    Text("adım")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: true, vertical: false)

                    Image(systemName: "figure.walk")
                        .font(.system(size: 32))
                        .foregroundStyle(AppTheme.primaryPurple)
                        .alignmentGuide(.firstTextBaseline) { d in d[.bottom] }
                        .offset(y: 3)
                }
                .layoutPriority(1)

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Düne göre değişim")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(AppTheme.primaryPurple)

                    Text("\(viewModel.stepsChangePercent >= 0 ? "+" : "")\(viewModel.stepsChangePercent)%")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.primaryPurple)
                }
                .frame(minWidth: 80)
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
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .offset(y: 1)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)

                    Text("kcal")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: true, vertical: false)

                    Image(systemName: "flame.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(AppTheme.primaryPurple)
                        .offset(y: 4)
                        .alignmentGuide(.firstTextBaseline) { d in d[.bottom] }
                }
                .layoutPriority(1)

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Düne göre değişim")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(AppTheme.primaryPurple)

                    Text("\(viewModel.caloriesChangePercent >= 0 ? "+" : "")\(viewModel.caloriesChangePercent)%")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.primaryPurple)
                }
                .frame(minWidth: 80)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Spacer()
        }
        .frame(height: ResponsiveDesign.Components.chartHeight)
    }
}
