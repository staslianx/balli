//
//  ContentView.swift
//  balli
//
//  Created by Serhat on 4.08.2025.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var userManager = UserProfileSelector.shared
    @State private var selectedTab = 1 // Start with Hoşgeldin tab
    @State private var calendarIcon = "calendar" // Dynamic calendar icon
    @State private var hasConfiguredTabBar = false

    // Search state for Ardiye view
    @State private var ardiyeSearchText = ""
    @State private var isArdiyeSearchPresented = false

    init() {
        // NOTE: Sync happens in balliApp.swift BEFORE ContentView is created
        // By the time we get here, all critical services should be ready
    }

    private func configureTabBarIfNeeded() {
        guard !hasConfiguredTabBar else { return }
        hasConfiguredTabBar = true

        // Configure tab bar with iOS 26 native Liquid Glass
        let appearance = UITabBarAppearance()

        // Use native material system (iOS 26 Liquid Glass compliant)
        appearance.configureWithDefaultBackground()

        // Configure the tab bar item appearance
        let itemAppearance = UITabBarItemAppearance()
        itemAppearance.normal.iconColor = UIColor.secondaryLabel
        itemAppearance.selected.iconColor = UIColor(AppTheme.primaryPurple)

        appearance.stackedLayoutAppearance = itemAppearance
        appearance.inlineLayoutAppearance = itemAppearance
        appearance.compactInlineLayoutAppearance = itemAppearance

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance

        // Native translucency for Liquid Glass integration
        UITabBar.appearance().isTranslucent = true
    }
    
    var body: some View {
        ZStack {
            // Main UI - sync already completed in balliApp.swift
            if userManager.currentUser != nil {
                mainTabView
            } else {
                Color.clear // Invisible placeholder while user selection modal loads
            }
        }
        .sheet(isPresented: $userManager.showUserSelection) {
            UserSelectionView()
                .interactiveDismissDisabled()
        }
        .onAppear {
            // Configure tab bar (cosmetic, doesn't affect sync)
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                configureTabBarIfNeeded()
            }
            // Update calendar icon
            updateCalendarIcon()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            updateCalendarIcon()
        }
    }

    private func updateCalendarIcon() {
        let calendar = Calendar.current
        let day = calendar.component(.day, from: Date())
        calendarIcon = "\(day).calendar"
    }

    private var mainTabView: some View {
        TabView(selection: $selectedTab) {
            // Ardiye Tab
            Tab("Ardiye", systemImage: "archivebox.fill", value: 0) {
                NavigationStack {
                    ArdiyeView(searchText: .constant(""))
                }
            }

            // Main balli Tab
            Tab("Bugün", systemImage: calendarIcon, value: 1) {
                NavigationStack {
                    UnifiedDashboardView(variant: .today, viewContext: viewContext)
                        .environment(\.selectedTab, $selectedTab)
                }
            }

            // Research/Balli Tab
            Tab("Araştır", systemImage: "gyroscope", value: 2) {
                NavigationStack {
                    InformationRetrievalView()
                }
            }

            // Search Tab - appears in tab bar
            Tab(value: 3, role: .search) {
                NavigationStack {
                    ArdiyeSearchView(searchText: $ardiyeSearchText)
                        .navigationBarTitleDisplayMode(.inline)
                        .searchable(
                            text: $ardiyeSearchText,
                            placement: .navigationBarDrawer(displayMode: .always),
                            prompt: "Tarif veya ürün ara..."
                        )
                }
            }
        }
        .tint(AppTheme.primaryPurple)
        .environmentObject(userManager)
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(HealthKitPermissionManager.shared)
        .injectDependencies()
}
