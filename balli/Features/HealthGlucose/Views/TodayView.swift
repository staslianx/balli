//
//  TodayView.swift
//  balli
//
//  Welcome dashboard with glucose chart and quick actions
//

import SwiftUI
import Charts
import CoreData
import HealthKit

struct TodayView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dependencies) private var dependencies
    @EnvironmentObject private var healthKitPermissions: HealthKitPermissionManager

    // Main ViewModel
    @StateObject private var viewModel: HosgeldinViewModel

    // Dependencies
    @StateObject private var dexcomService = DexcomService()
    @ObservedObject private var dexcomShareService = DexcomShareService.shared

    // Sheet state
    @State private var showingMealHistory = false
    @State private var showingSettings = false

    // MARK: - Initialization

    init(viewContext: NSManagedObjectContext) {
        // Initialize ViewModel with shared dependencies
        // Note: healthKitService comes from DependencyContainer (singleton)
        let dependencies = DependencyContainer.shared
        let dexcomService = DexcomService()

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
                // Note: Removed duplicate .onReceive for .glucoseDataUpdated
                // The ViewModel already handles this notification, having it here causes rapid polling loops
                .onChange(of: dexcomService.isConnected) { _, isConnected in
                    viewModel.onDexcomConnectionChange(isConnected)
                }
                .onChange(of: dexcomShareService.isConnected) { _, isConnected in
                    if isConnected {
                        // SHARE connected - reload glucose data
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
                        .presentationDetents([.height(ResponsiveDesign.safeScreenHeight() * 0.45)])
                        .presentationDragIndicator(.visible)
                        .presentationBackgroundInteraction(.enabled)
                }
                .sheet(isPresented: $showingMealHistory) {
                    LoggedMealsView()
                }
                .sheet(isPresented: $showingSettings) {
                    AppSettingsView()
                }
                .toolbar {
                    // Logo with long-press gesture for settings
                    ToolbarItem(placement: .principal) {
                        Image("balli-text-logo")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 28)
                            .onLongPressGesture(minimumDuration: 0.5) {
                                showingSettings = true
                            }
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

    // MARK: - Carousel View

    @ViewBuilder
    private var carouselView: some View {
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
                            .background(.clear)
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
                                .background(.clear)
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

// MARK: - Preview

#Preview {
    TodayView(viewContext: PersistenceController.preview.container.viewContext)
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(HealthKitPermissionManager.shared)
}
