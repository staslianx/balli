//
//  UnifiedDashboardView.swift
//  balli
//
//  Unified dashboard view supporting both welcome and today variants
//  Eliminates code duplication between HosgeldinView and TodayView
//  Swift 6 strict concurrency compliant
//

import SwiftUI
import Charts
import CoreData
import HealthKit

/// Dashboard variant configuration
enum DashboardVariant {
    case welcome  // Welcome screen with inline carousel
    case today    // Today tab with extracted carousel and settings
}

struct UnifiedDashboardView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dependencies) private var dependencies
    @EnvironmentObject private var healthKitPermissions: HealthKitPermissionManager

    // Configuration
    let variant: DashboardVariant

    // Main ViewModel
    @StateObject private var viewModel: HosgeldinViewModel

    // Dependencies
    @ObservedObject private var dexcomService = DexcomService.shared
    @ObservedObject private var dexcomShareService = DexcomShareService.shared

    // Sheet state
    @State private var showingMealHistory = false
    @State private var showingSettings = false  // Only used for .today variant

    // MARK: - Initialization

    init(variant: DashboardVariant, viewContext: NSManagedObjectContext) {
        self.variant = variant

        // Initialize ViewModel with shared dependencies
        let dependencies = DependencyContainer.shared
        let dexcomService = DexcomService.shared

        _viewModel = StateObject(wrappedValue: HosgeldinViewModel(
            healthKitService: dependencies.healthKitService,
            dexcomService: dexcomService,
            dexcomShareService: DexcomShareService.shared,
            healthKitPermissions: HealthKitPermissionManager.shared,
            viewContext: viewContext
        ))
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            NavigationStack {
                VStack(spacing: 0) {
                    // Main content
                    VStack(spacing: 0) {
                        carouselView
                            .padding(.top, ResponsiveDesign.Spacing.xxLarge + 66)

                        DashboardActionButtons(
                            showingCamera: $viewModel.showingCamera,
                            showingManualEntry: $viewModel.showingManualEntry,
                            showingRecipeEntry: $viewModel.showingRecipeEntry,
                            isLongPressing: $viewModel.isLongPressing
                        )
                        .padding(.top, -24)
                        .offset(y: -12)

                        FavoritesSection()
                            .padding(.top, -6)

                        Spacer()
                    }
                }
                .background(Color(.systemBackground))
                .navigationBarTitleDisplayMode(.inline)
                .onAppear {
                    viewModel.onAppear()
                }
                .onChange(of: dexcomService.isConnected) { _, isConnected in
                    viewModel.onDexcomConnectionChange(isConnected)
                }
                .onChange(of: dexcomShareService.isConnected) { _, isConnected in
                    if isConnected {
                        viewModel.glucoseChartViewModel.loadGlucoseData()
                    }
                }
                .onDisappear {
                    viewModel.onDisappear()
                }
                .fullScreenCover(isPresented: $viewModel.showingCamera) {
                    CameraView()
                }
                .fullScreenCover(isPresented: $viewModel.showingManualEntry) {
                    ManualEntryView()
                }
                .fullScreenCover(isPresented: $viewModel.showingRecipeEntry) {
                    NavigationStack {
                        RecipeGenerationView(viewContext: viewContext)
                    }
                }
                .sheet(isPresented: $viewModel.showingVoiceInput) {
                    VoiceInputView()
                        .presentationDetents([.medium, .large])
                        .presentationDragIndicator(.visible)
                        .presentationBackgroundInteraction(.enabled)
                }
                .sheet(isPresented: $showingMealHistory) {
                    LoggedMealsView()
                }
                .if(variant == .today) { view in
                    view.sheet(isPresented: $showingSettings) {
                        AppSettingsView()
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        logoView
                    }

                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            showingMealHistory = true
                        } label: {
                            Image(systemName: "calendar")
                                .font(.system(size: 18, weight: .medium, design: .rounded))
                                .foregroundColor(AppTheme.primaryPurple)
                        }
                        .accessibilityLabel("Günlük Kayıtlar")
                        .accessibilityHint("Sesle kaydedilen öğünleri gör")
                        .buttonStyle(.plain)
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            viewModel.showingVoiceInput = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 18, weight: .medium, design: .rounded))
                                .foregroundColor(AppTheme.primaryPurple)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Edge glow overlay
            edgeGlowOverlay
        }
    }

    // MARK: - Logo View

    @ViewBuilder
    private var logoView: some View {
        let logo = Image("balli-text-logo")
            .resizable()
            .scaledToFit()
            .frame(height: 28)

        switch variant {
        case .welcome:
            logo
        case .today:
            logo
                .onLongPressGesture(minimumDuration: 0.5) {
                    showingSettings = true
                }
        }
    }

    // MARK: - Carousel View

    @ViewBuilder
    private var carouselView: some View {
        switch variant {
        case .welcome:
            // Inline carousel implementation (from HosgeldinView)
            inlineCarouselView
        case .today:
            // Extracted carousel component (from TodayView)
            DashboardCarouselView(
                activityMetricsViewModel: viewModel.activityMetricsViewModel,
                glucoseChartViewModel: viewModel.glucoseChartViewModel,
                healthKitPermissions: healthKitPermissions,
                currentCardIndex: $viewModel.currentCardIndex
            )
        }
    }

    // MARK: - Inline Carousel (Welcome Variant)

    @ViewBuilder
    private var inlineCarouselView: some View {
        ZStack(alignment: .bottom) {
            // Carousel
            GeometryReader { geometry in
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: ResponsiveDesign.Spacing.medium) {
                            // Activities Card
                            ActivityMetricsCard(
                                viewModel: viewModel.activityMetricsViewModel,
                                healthKitPermissions: healthKitPermissions
                            )
                            .padding(.vertical, 24)
                            .background(Color(.systemBackground))
                            .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.card, style: .continuous))
                            .clipShape(RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.card, style: .continuous))
                            .shadow(color: .black.opacity(0.06), radius: ResponsiveDesign.height(8), x: 0, y: ResponsiveDesign.height(4))
                            .frame(width: geometry.size.width - ResponsiveDesign.Spacing.medium * 2)
                            .id(0)
                            .onTapGesture {
                                withAnimation {
                                    viewModel.currentCardIndex = 0
                                }
                            }

                            // Glucose Card
                            GlucoseChartCard(viewModel: viewModel.glucoseChartViewModel)
                                .padding(.vertical, 24)
                                .background(Color(.systemBackground))
                                .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.card, style: .continuous))
                                .clipShape(RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.card, style: .continuous))
                                .shadow(color: .black.opacity(0.06), radius: ResponsiveDesign.height(8), x: 0, y: ResponsiveDesign.height(4))
                                .frame(width: geometry.size.width - ResponsiveDesign.Spacing.medium * 2)
                                .id(1)
                                .onTapGesture {
                                    withAnimation {
                                        viewModel.currentCardIndex = 1
                                    }
                                }
                        }
                        .padding(.horizontal, ResponsiveDesign.Spacing.medium)
                        .padding(.bottom, 30)
                    }
                    .scrollClipDisabled()
                    .scrollTargetBehavior(.paging)
                    .scrollPosition(id: $viewModel.currentCardIndex)
                }
            }
            .frame(height: ResponsiveDesign.Components.chartHeight + ResponsiveDesign.Spacing.medium * 4 + 180)
            .zIndex(1)

            // Page Indicators
            HStack(spacing: 8) {
                ForEach(0..<2) { index in
                    Circle()
                        .fill((viewModel.currentCardIndex ?? 0) == index ? AppTheme.primaryPurple : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .animation(.spring(response: 0.3), value: viewModel.currentCardIndex)
                        .onTapGesture {
                            withAnimation {
                                viewModel.currentCardIndex = index
                            }
                        }
                }
            }
            .padding(.bottom, 120)
            .zIndex(0)
        }
        .frame(height: ResponsiveDesign.Components.chartHeight + ResponsiveDesign.Spacing.medium * 4 + 40)
    }

    // MARK: - Edge Glow Effect

    @ViewBuilder
    private var edgeGlowOverlay: some View {
        GeometryReader { geometry in
            RoundedRectangle(cornerRadius: 55, style: .continuous)
                .stroke(AppTheme.primaryPurple, lineWidth: 4)
                .shadow(color: AppTheme.primaryPurple.opacity(0.8), radius: 20, x: 0, y: 0)
                .shadow(color: AppTheme.primaryPurple.opacity(0.6), radius: 40, x: 0, y: 0)
                .shadow(color: AppTheme.primaryPurple.opacity(0.4), radius: 60, x: 0, y: 0)
                .shadow(color: AppTheme.primaryPurple.opacity(0.2), radius: 80, x: 0, y: 0)
                .opacity(0)
                .allowsHitTesting(false)
                .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .edgesIgnoringSafeArea(.all)
    }
}

// MARK: - Previews

#Preview("Welcome Variant") {
    UnifiedDashboardView(variant: .welcome, viewContext: PersistenceController.preview.container.viewContext)
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(HealthKitPermissionManager.shared)
}

#Preview("Today Variant") {
    UnifiedDashboardView(variant: .today, viewContext: PersistenceController.preview.container.viewContext)
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(HealthKitPermissionManager.shared)
}
