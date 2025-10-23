//
//  NavigationState.swift
//  balli
//
//  Navigation, sheets, and alerts state management
//

import SwiftUI
import Combine

// MARK: - Navigation State Manager
@MainActor
final class NavigationState: ObservableObject {
    static let shared = NavigationState()

    // MARK: - Published Properties
    @Published var selectedTab: TabItem = .hosgeldin
    @Published var navigationPath = NavigationPath()
    @Published var presentedSheet: SheetType?
    @Published var presentedAlert: AlertType?

    // MARK: - App-level State
    @Published var isLoading = false
    @Published var globalError: Error?
    @Published var successMessage: String?

    private var cancellables = Set<AnyCancellable>()

    private init() {}

    // MARK: - Navigation Methods

    func navigate(to destination: NavigationDestination) {
        navigationPath.append(destination)
    }

    func popNavigation() {
        if !navigationPath.isEmpty {
            navigationPath.removeLast()
        }
    }

    func popToRoot() {
        navigationPath = NavigationPath()
    }

    func showSheet(_ sheet: SheetType) {
        presentedSheet = sheet
    }

    func dismissSheet() {
        presentedSheet = nil
    }

    func showAlert(_ alert: AlertType) {
        presentedAlert = alert
    }

    func dismissAlert() {
        presentedAlert = nil
    }

    // MARK: - Error Handling

    func handleError(_ error: Error) {
        globalError = error
        showAlert(.error(error))
    }

    func showSuccess(_ message: String) {
        successMessage = message
        showAlert(.success(message))
    }
}

// MARK: - Environment Key
private struct NavigationStateKey: EnvironmentKey {
    static let defaultValue: NavigationState? = nil
}

extension EnvironmentValues {
    var navigationState: NavigationState {
        get {
            if let state = self[NavigationStateKey.self] {
                return state
            }
            return MainActor.assumeIsolated {
                NavigationState.shared
            }
        }
        set { self[NavigationStateKey.self] = newValue }
    }
}
