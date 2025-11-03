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
                        .presentationDetents([.medium, .large])
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
        DashboardCarouselView(
            activityMetricsViewModel: viewModel.activityMetricsViewModel,
            glucoseChartViewModel: viewModel.glucoseChartViewModel,
            healthKitPermissions: healthKitPermissions,
            currentCardIndex: $viewModel.currentCardIndex
        )
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
