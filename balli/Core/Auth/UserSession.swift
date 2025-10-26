//
//  UserSession.swift
//  balli
//
//  User session management for authentication and user context
//  Swift 6 strict concurrency compliant
//

import Foundation
import OSLog

/// Manages current user session and authentication state
@MainActor
final class UserSession: ObservableObject {

    // MARK: - Singleton

    static let shared = UserSession()

    // MARK: - Published State

    @Published private(set) var currentUser: User?
    @Published private(set) var isAuthenticated: Bool = false

    // MARK: - Properties

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.balli", category: "Auth")
    private let userDefaults = UserDefaults.standard

    // MARK: - User Model

    struct User: Codable, Sendable {
        let id: String
        let email: String
        let displayName: String

        var firestoreUserId: String {
            // Use email as Firestore user ID path component
            email
        }
    }

    // MARK: - Predefined Users

    static let serhat = User(
        id: "serhat",
        email: "serhat@balli",
        displayName: "Serhat"
    )

    static let dilara = User(
        id: "dilara",
        email: "dilara@balli",
        displayName: "Dilara"
    )

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let currentUserId = "balli.currentUserId"
    }

    // MARK: - Initialization

    private init() {
        // Restore session from UserDefaults
        restoreSession()
    }

    // MARK: - Session Management

    /// Set the current user (login)
    func setUser(_ user: User) {
        currentUser = user
        isAuthenticated = true

        // Persist to UserDefaults
        userDefaults.set(user.id, forKey: Keys.currentUserId)

        logger.info("User session started: \(user.displayName) (\(user.email))")

        // Post notification for session change
        NotificationCenter.default.post(name: .userSessionDidChange, object: user)
    }

    /// Clear current user (logout)
    func clearUser() {
        logger.info("User session ended: \(self.currentUser?.displayName ?? "unknown")")

        currentUser = nil
        isAuthenticated = false

        // Clear from UserDefaults
        userDefaults.removeObject(forKey: Keys.currentUserId)

        // Post notification for session change
        NotificationCenter.default.post(name: .userSessionDidChange, object: nil)
    }

    /// Switch between predefined users
    func switchUser() {
        guard let current = currentUser else {
            // No user set, default to Serhat
            setUser(Self.serhat)
            return
        }

        // Toggle between serhat and dilara
        if current.id == Self.serhat.id {
            setUser(Self.dilara)
        } else {
            setUser(Self.serhat)
        }

        logger.info("Switched user to: \(self.currentUser?.displayName ?? "unknown")")
    }

    /// Restore session from UserDefaults
    private func restoreSession() {
        guard let savedUserId = userDefaults.string(forKey: Keys.currentUserId) else {
            // No saved session, default to Serhat
            setUser(Self.serhat)
            return
        }

        // Restore user based on saved ID
        switch savedUserId {
        case Self.serhat.id:
            setUser(Self.serhat)
        case Self.dilara.id:
            setUser(Self.dilara)
        default:
            // Unknown user ID, default to Serhat
            logger.warning("Unknown saved user ID: \(savedUserId), defaulting to Serhat")
            setUser(Self.serhat)
        }

        logger.info("Restored user session: \(self.currentUser?.displayName ?? "unknown")")
    }

    // MARK: - Convenience Accessors

    /// Current user's Firestore ID for path construction
    var firestoreUserId: String {
        currentUser?.firestoreUserId ?? Self.serhat.firestoreUserId
    }

    /// Current user's display name
    var displayName: String {
        currentUser?.displayName ?? "Unknown"
    }

    /// Current user's email
    var email: String {
        currentUser?.email ?? "unknown@balli"
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let userSessionDidChange = Notification.Name("userSessionDidChange")
}

// MARK: - Preview Support

#if DEBUG
extension UserSession {
    static var preview: UserSession {
        let session = UserSession()
        session.currentUser = serhat
        session.isAuthenticated = true
        return session
    }

    static var previewDilara: UserSession {
        let session = UserSession()
        session.currentUser = dilara
        session.isAuthenticated = true
        return session
    }
}
#endif
