//
//  DashboardCarouselView.swift
//  balli
//
//  Carousel view displaying Activity and Glucose cards
//  Extracted from TodayView for single responsibility
//

import SwiftUI
import Charts

struct DashboardCarouselView: View {
    // ViewModels
    let activityMetricsViewModel: ActivityMetricsViewModel
    let glucoseChartViewModel: GlucoseChartViewModel

    // Dependencies
    let healthKitPermissions: HealthKitPermissionManager

    // Scroll state
    @Binding var currentCardIndex: Int?

    var body: some View {
        ZStack(alignment: .bottom) {
            // Carousel
            GeometryReader { geometry in
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: ResponsiveDesign.Spacing.medium) {
                            // Activities Card
                            ActivityMetricsCard(
                                viewModel: activityMetricsViewModel,
                                healthKitPermissions: healthKitPermissions
                            )
                            .padding(.vertical, 24)
                            .background(.clear)
                            .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.card, style: .continuous))
                            .clipShape(RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.card, style: .continuous))
                            .shadow(color: .black.opacity(0.06), radius: ResponsiveDesign.height(8), x: 0, y: ResponsiveDesign.height(4))
                            .frame(width: geometry.size.width - ResponsiveDesign.Spacing.medium * 2)
                            .id(0)
                            .onTapGesture {
                                withAnimation {
                                    currentCardIndex = 0
                                }
                            }

                            // Glucose Card
                            GlucoseChartCard(viewModel: glucoseChartViewModel)
                                .padding(.vertical, 24)
                                .background(.clear)
                                .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.card, style: .continuous))
                                .clipShape(RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.card, style: .continuous))
                                .shadow(color: .black.opacity(0.06), radius: ResponsiveDesign.height(8), x: 0, y: ResponsiveDesign.height(4))
                                .frame(width: geometry.size.width - ResponsiveDesign.Spacing.medium * 2)
                                .id(1)
                                .onTapGesture {
                                    withAnimation {
                                        currentCardIndex = 1
                                    }
                                }
                        }
                        .padding(.horizontal, ResponsiveDesign.Spacing.medium)
                        .padding(.bottom, 30)
                    }
                    .scrollClipDisabled()
                    .scrollTargetBehavior(.paging)
                    .scrollPosition(id: $currentCardIndex)
                }
            }
            .frame(height: ResponsiveDesign.Components.chartHeight + ResponsiveDesign.Spacing.medium * 4 + 180)
            .zIndex(1)

            // Page Indicators
            HStack(spacing: 8) {
                ForEach(0..<2) { index in
                    Circle()
                        .fill((currentCardIndex ?? 0) == index ? AppTheme.primaryPurple : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .animation(.spring(response: 0.3), value: currentCardIndex)
                        .onTapGesture {
                            withAnimation {
                                currentCardIndex = index
                            }
                        }
                }
            }
            .padding(.bottom, 120)
            .zIndex(0)
        }
        .frame(height: ResponsiveDesign.Components.chartHeight + ResponsiveDesign.Spacing.medium * 4 + 40)
    }
}
