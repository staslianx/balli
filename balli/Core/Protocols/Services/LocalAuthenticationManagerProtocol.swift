//
//  LocalAuthenticationManagerProtocol.swift
//  balli
//
//  Protocol definition for LocalAuthenticationManager
//  Enables dependency injection and testing
//

import Foundation

/// Protocol for local authentication management
@MainActor
protocol LocalAuthenticationManagerProtocol: AnyObject {

    // MARK: - Published Properties

    var isAuthenticated: Bool { get }
    var currentUser: LocalUser? { get }
    var isLoading: Bool { get }
    var errorMessage: String? { get }

    // MARK: - User Information

    var userId: String { get }
    var userEmail: String? { get }
    var isAnonymous: Bool { get }

    // MARK: - Authentication Methods

    /// Sign in with email and password
    /// - Parameters:
    ///   - email: User's email address
    ///   - password: User's password
    func signIn(email: String, password: String) async throws

    /// Create a new account
    /// - Parameters:
    ///   - email: User's email address
    ///   - password: User's password
    ///   - displayName: Optional display name
    func signUp(email: String, password: String, displayName: String?) async throws

    /// Sign in anonymously (for testing or first-time use)
    func signInAnonymously() async throws

    /// Quick sign-in for predefined users (simplified for family use)
    /// - Parameters:
    ///   - predefinedUser: The predefined user to sign in as
    ///   - password: User's password
    func quickSignIn(for predefinedUser: LocalAuthenticationManager.PredefinedUser, password: String) async throws

    /// Sign out current user
    func signOut() throws

    /// Delete account (GDPR compliance)
    func deleteAccount() async throws

    /// Reset password
    /// - Parameter email: Email address to send reset link to
    func resetPassword(email: String) async throws

    /// Convert anonymous account to permanent account
    /// - Parameters:
    ///   - email: New email address
    ///   - password: New password
    func convertAnonymousToPermanent(email: String, password: String) async throws

    // MARK: - Helper Methods

    /// Get ID token for backend authentication
    /// - Returns: Authentication token string
    func getIDToken() async throws -> String

    /// Check if email is already registered
    /// - Parameter email: Email address to check
    /// - Returns: Boolean indicating if email exists
    func checkEmailExists(_ email: String) async -> Bool
}
