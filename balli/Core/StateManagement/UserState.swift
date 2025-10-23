//
//  UserState.swift
//  balli
//
//  User authentication and profile state management
//

import SwiftUI
import Combine
import OSLog

// MARK: - User State Manager
@MainActor
final class UserState: ObservableObject {
    static let shared = UserState()

    // MARK: - Published Properties
    @Published var currentUser: UserProfile?
    @Published var isAuthenticated = false
    @Published var isOnboardingComplete = UserDefaults.standard.bool(forKey: "isOnboardingComplete") {
        didSet {
            UserDefaults.standard.set(isOnboardingComplete, forKey: "isOnboardingComplete")
        }
    }

    private var cancellables = Set<AnyCancellable>()

    private init() {}

    // MARK: - User Methods

    func login(email: String, password: String) async throws {
        await debugDelay(nanoseconds: 1_000_000_000)

        currentUser = UserProfile(
            id: UUID(),
            name: "Dilara",
            email: email,
            diabetesType: .type1,
            diagnosisDate: Date(),
            targetGlucoseRange: 80...180
        )

        isAuthenticated = true
        NotificationCenter.default.post(name: .balliUserLoggedIn, object: nil)
    }

    func logout() {
        currentUser = nil
        isAuthenticated = false
        NotificationCenter.default.post(name: .balliUserLoggedOut, object: nil)
    }

    private func debugDelay(nanoseconds: UInt64) async {
#if DEBUG
        try? await Task.sleep(nanoseconds: nanoseconds)
#endif
    }
}

// MARK: - User Profile
struct UserProfile: Codable, Identifiable {
    let id: UUID
    var name: String
    var email: String
    var diabetesType: DiabetesType
    var diagnosisDate: Date
    var targetGlucoseRange: ClosedRange<Double>
    var profileImageUrl: String?

    enum DiabetesType: String, Codable, CaseIterable {
        case type1 = "Type 1"
        case type2 = "Type 2"
        case lada = "LADA"
        case gestational = "Gestational"
    }
}

// MARK: - Environment Key
private struct UserStateKey: EnvironmentKey {
    static let defaultValue: UserState? = nil
}

extension EnvironmentValues {
    var userState: UserState {
        get {
            if let state = self[UserStateKey.self] {
                return state
            }
            return MainActor.assumeIsolated {
                UserState.shared
            }
        }
        set { self[UserStateKey.self] = newValue }
    }
}
