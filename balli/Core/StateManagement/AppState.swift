//
//  AppState.swift
//  balli
//
//  Lightweight coordinator for domain-specific state objects
//  PERFORMANCE: Split from 22 @Published properties to 5 domain-specific state managers
//  This eliminates unnecessary re-renders when only one domain changes
//

import SwiftUI
import Combine

// MARK: - App State Coordinator
@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    // MARK: - Domain-Specific State Objects
    let userState: UserState
    let navigationState: NavigationState
    let dataState: DataState
    let networkState: NetworkState
    let cameraDataState: CameraDataState
    let settingsState: SettingsState

    private var cancellables = Set<AnyCancellable>()

    private init() {
        self.userState = UserState.shared
        self.navigationState = NavigationState.shared
        self.dataState = DataState.shared
        self.networkState = NetworkState.shared
        self.cameraDataState = CameraDataState.shared
        self.settingsState = SettingsState.shared

        setupCoordination()
    }

    // MARK: - Setup

    private func setupCoordination() {
        // Coordinate logout with navigation
        NotificationCenter.default.publisher(for: .balliUserLoggedOut)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.navigationState.popToRoot()
            }
            .store(in: &cancellables)
    }

    // MARK: - Convenience Properties (for backward compatibility)

    var currentUser: UserProfile? {
        get { userState.currentUser }
        set { userState.currentUser = newValue }
    }

    var isAuthenticated: Bool {
        get { userState.isAuthenticated }
        set { userState.isAuthenticated = newValue }
    }

    var selectedTab: TabItem {
        get { navigationState.selectedTab }
        set { navigationState.selectedTab = newValue }
    }

    var navigationPath: NavigationPath {
        get { navigationState.navigationPath }
        set { navigationState.navigationPath = newValue }
    }

    var isLoading: Bool {
        get { navigationState.isLoading }
        set { navigationState.isLoading = newValue }
    }

    var recentFoodItems: [FoodItem] {
        dataState.recentFoodItems
    }

    var todaysMeals: [MealEntry] {
        dataState.todaysMeals
    }

    var glucoseReadings: [GlucoseReading] {
        dataState.glucoseReadings
    }

    var isOnline: Bool {
        networkState.isOnline
    }

    var isOfflineMode: Bool {
        networkState.isOfflineMode
    }

    var pendingOperationsCount: Int {
        networkState.pendingOperationsCount
    }

    var lastCapturedImage: UIImage? {
        get { cameraDataState.lastCapturedImage }
        set { cameraDataState.lastCapturedImage = newValue }
    }

    var appSettings: AppSettings {
        get { settingsState.appSettings }
        set { settingsState.appSettings = newValue }
    }

    // MARK: - Convenience Methods (delegate to domain-specific states)

    func login(email: String, password: String) async throws {
        navigationState.isLoading = true
        defer { navigationState.isLoading = false }
        try await userState.login(email: email, password: password)
    }

    func logout() {
        userState.logout()
    }

    func navigate(to destination: NavigationDestination) {
        navigationState.navigate(to: destination)
    }

    func showSheet(_ sheet: SheetType) {
        navigationState.showSheet(sheet)
    }

    func dismissSheet() {
        navigationState.dismissSheet()
    }

    func showAlert(_ alert: AlertType) {
        navigationState.showAlert(alert)
    }

    func handleError(_ error: Error) {
        navigationState.handleError(error)
    }

    func showSuccess(_ message: String) {
        navigationState.showSuccess(message)
    }

    func refreshData() {
        dataState.refreshData()
    }

    func updateTheme(_ theme: AppThemeMode) {
        settingsState.updateTheme(theme)
    }

    func updateLanguage(_ language: AppLanguage) {
        settingsState.updateLanguage(language)
    }
}

// MARK: - Environment Key
private struct AppStateKey: EnvironmentKey {
    static let defaultValue: AppState? = nil
}

extension EnvironmentValues {
    var appState: AppState {
        get {
            if let state = self[AppStateKey.self] {
                return state
            }
            return MainActor.assumeIsolated {
                AppState.shared
            }
        }
        set { self[AppStateKey.self] = newValue }
    }
}

// MARK: - View Modifier
struct WithAppState: ViewModifier {
    @StateObject private var appState = AppState.shared
    @StateObject private var userState = UserState.shared
    @StateObject private var navigationState = NavigationState.shared
    @StateObject private var dataState = DataState.shared
    @StateObject private var networkState = NetworkState.shared
    @StateObject private var cameraDataState = CameraDataState.shared
    @StateObject private var settingsState = SettingsState.shared

    func body(content: Content) -> some View {
        content
            .environmentObject(appState)
            .environmentObject(userState)
            .environmentObject(navigationState)
            .environmentObject(dataState)
            .environmentObject(networkState)
            .environmentObject(cameraDataState)
            .environmentObject(settingsState)
            .environment(\.appState, appState)
            .environment(\.userState, userState)
            .environment(\.navigationState, navigationState)
            .environment(\.dataState, dataState)
            .environment(\.networkState, networkState)
            .environment(\.cameraDataState, cameraDataState)
            .environment(\.settingsState, settingsState)
    }
}

extension View {
    func withAppState() -> some View {
        modifier(WithAppState())
    }
}
