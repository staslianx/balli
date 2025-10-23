//
//  UserProfileSelector.swift
//  balli
//
//  User profile selection for 2-user personal app
//  Handles profile switching between Dilara and Serhat
//

import Foundation
import SwiftUI
import OSLog

// MARK: - User Model
enum AppUser: String, CaseIterable, Codable, Sendable {
    case dilara = "dilara@balli.com"
    case serhat = "serhat@balli.com"

    var displayName: String {
        switch self {
        case .dilara: return "Dilara"
        case .serhat: return "Serhat"
        }
    }

    var emoji: String {
        switch self {
        case .dilara: return "🌺"
        case .serhat: return "🍐"
        }
    }

    var subtitle: String {
        switch self {
        case .dilara: return "Asıl Kullanıcı"
        case .serhat: return "Geliştirici"
        }
    }

    var isTestUser: Bool {
        self == .serhat
    }

    var themeColor: Color {
        switch self {
        case .dilara: return AppTheme.primaryPurple
        case .serhat: return .blue
        }
    }
}

// MARK: - User Profile Selector
@MainActor
class UserProfileSelector: ObservableObject {
    static let shared = UserProfileSelector()

    @AppStorage("selectedUserEmail") private var selectedUserEmail: String = ""
    @Published var currentUser: AppUser?
    @Published var showUserSelection: Bool = false

    private init() {
        loadCurrentUser()
    }

    // MARK: - Public Methods

    /// Load the current user from storage
    func loadCurrentUser() {
        if let user = AppUser(rawValue: selectedUserEmail) {
            currentUser = user
            showUserSelection = false
        } else {
            currentUser = nil
            showUserSelection = true
        }
    }

    /// Select a user and save to storage
    func selectUser(_ user: AppUser) {
        currentUser = user
        selectedUserEmail = user.rawValue
        showUserSelection = false

        AppLoggers.Auth.userManagement.info("User selected: \(user.displayName, privacy: .public) (\(user.rawValue, privacy: .private))")
    }

    /// Switch to a different user (for developer tools)
    func switchToUser(_ user: AppUser) {
        selectUser(user)
        AppLoggers.Auth.userManagement.info("Switched to user: \(user.displayName, privacy: .public)")
    }

    /// Clear user selection (for logout/reset)
    func clearUserSelection() {
        currentUser = nil
        selectedUserEmail = ""
        showUserSelection = true
    }

    /// Check if current user is developer/test user
    var isTestUser: Bool {
        currentUser?.isTestUser ?? false
    }

    /// Get current user email for API calls
    var currentUserEmail: String {
        currentUser?.rawValue ?? ""
    }

    /// Get display name for current user
    var currentUserDisplayName: String {
        currentUser?.displayName ?? "Unknown"
    }

    /// Force show user selection modal
    func showUserSelectionModal() {
        showUserSelection = true
    }
}

// MARK: - Environment Key for User Manager
struct UserProfileSelectorKey: @preconcurrency EnvironmentKey {
    @MainActor
    static var defaultValue: UserProfileSelector {
        return UserProfileSelector.shared
    }
}

extension EnvironmentValues {
    var userManager: UserProfileSelector {
        get { self[UserProfileSelectorKey.self] }
        set { self[UserProfileSelectorKey.self] = newValue }
    }
}

// MARK: - View Extension for User Manager
extension View {
    func userManager(_ manager: UserProfileSelector = UserProfileSelector.shared) -> some View {
        environment(\.userManager, manager)
    }
}
