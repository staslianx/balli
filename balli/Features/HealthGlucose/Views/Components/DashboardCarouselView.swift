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

    // Environment
    @Environment(\.colorScheme) private var colorScheme

    // Dark mode dissolved purple gradient (matching ProductCardView)
    private var dissolvedPurpleDark: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: AppTheme.primaryPurple.opacity(0.12), location: 0.0),
                .init(color: AppTheme.primaryPurple.opacity(0.08), location: 0.15),
                .init(color: AppTheme.primaryPurple.opacity(0.05), location: 0.25),
                .init(color: AppTheme.primaryPurple.opacity(0.03), location: 0.5),
                .init(color: AppTheme.primaryPurple.opacity(0.05), location: 0.75),
                .init(color: AppTheme.primaryPurple.opacity(0.08), location: 0.85),
                .init(color: AppTheme.primaryPurple.opacity(0.12), location: 1.0)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // Card background - dark mode keeps purple, light mode is colorless (matching ProductCardView)
    private var cardBackground: some ShapeStyle {
        if colorScheme == .dark {
            return AnyShapeStyle(dissolvedPurpleDark)
        } else {
            return AnyShapeStyle(Color.clear)
        }
    }

    // Glass effect style - always interactive
    private var glassEffectStyle: Glass {
        .regular.interactive()
    }

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
                            .background(
                                RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.card, style: .continuous)
                                    .fill(cardBackground)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.card, style: .continuous))
                            .glassEffect(
                                glassEffectStyle,
                                in: RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.card, style: .continuous)
                            )
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
                                .background(
                                    RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.card, style: .continuous)
                                        .fill(cardBackground)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.card, style: .continuous))
                                .glassEffect(
                                    glassEffectStyle,
                                    in: RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.card, style: .continuous)
                                )
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
