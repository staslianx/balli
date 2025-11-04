//
//  MockLocalAuthenticationManager.swift
//  balliTests
//
//  Mock implementation of LocalAuthenticationManagerProtocol for testing
//

import Foundation
@testable import balli

@MainActor
final class MockLocalAuthenticationManager: LocalAuthenticationManagerProtocol {

    // MARK: - Published Properties

    var isAuthenticated = false
    var currentUser: LocalUser?
    var isLoading = false
    var errorMessage: String?

    // MARK: - User Information

    var userId: String {
        currentUser?.uid ?? "anonymous_test"
    }

    var userEmail: String? {
        currentUser?.email
    }

    var isAnonymous: Bool {
        currentUser?.isAnonymous ?? true
    }

    // MARK: - Mock Configuration

    var shouldSucceedSignIn = true
    var shouldSucceedSignUp = true
    var shouldSucceedAnonymousSignIn = true
    var mockError: Error?

    // MARK: - Call Tracking

    var signInCallCount = 0
    var signUpCallCount = 0
    var signInAnonymouslyCallCount = 0
    var quickSignInCallCount = 0
    var signOutCallCount = 0
    var deleteAccountCallCount = 0
    var resetPasswordCallCount = 0
    var convertAnonymousToPermanentCallCount = 0
    var getIDTokenCallCount = 0
    var checkEmailExistsCallCount = 0

    var lastSignInEmail: String?
    var lastSignInPassword: String?

    // MARK: - Authentication Methods

    func signIn(email: String, password: String) async throws {
        signInCallCount += 1
        lastSignInEmail = email
        lastSignInPassword = password
        isLoading = true

        if let error = mockError {
            isLoading = false
            throw error
        }

        guard shouldSucceedSignIn else {
            errorMessage = "Sign in failed"
            isLoading = false
            throw NSError(domain: "MockAuth", code: 401, userInfo: [NSLocalizedDescriptionKey: "Mock sign in failure"])
        }

        currentUser = LocalUser(
            uid: "mock_\(UUID().uuidString)",
            email: email,
            displayName: "Test User",
            isAnonymous: false
        )
        isAuthenticated = true
        isLoading = false
    }

    func signUp(email: String, password: String, displayName: String?) async throws {
        signUpCallCount += 1
        isLoading = true

        if let error = mockError {
            isLoading = false
            throw error
        }

        guard shouldSucceedSignUp else {
            errorMessage = "Sign up failed"
            isLoading = false
            throw NSError(domain: "MockAuth", code: 400, userInfo: [NSLocalizedDescriptionKey: "Mock sign up failure"])
        }

        currentUser = LocalUser(
            uid: "mock_\(UUID().uuidString)",
            email: email,
            displayName: displayName,
            isAnonymous: false
        )
        isAuthenticated = true
        isLoading = false
    }

    func signInAnonymously() async throws {
        signInAnonymouslyCallCount += 1
        isLoading = true

        if let error = mockError {
            isLoading = false
            throw error
        }

        guard shouldSucceedAnonymousSignIn else {
            errorMessage = "Anonymous sign in failed"
            isLoading = false
            throw NSError(domain: "MockAuth", code: 400, userInfo: [NSLocalizedDescriptionKey: "Mock anonymous sign in failure"])
        }

        currentUser = LocalUser(
            uid: "anon_\(UUID().uuidString)",
            email: nil,
            displayName: "Anonymous",
            isAnonymous: true
        )
        isAuthenticated = true
        isLoading = false
    }

    func quickSignIn(for predefinedUser: LocalAuthenticationManager.PredefinedUser, password: String) async throws {
        quickSignInCallCount += 1
        try await signIn(email: predefinedUser.email, password: password)
    }

    func signOut() throws {
        signOutCallCount += 1
        currentUser = nil
        isAuthenticated = false
        errorMessage = nil
    }

    func deleteAccount() async throws {
        deleteAccountCallCount += 1
        isLoading = true

        if let error = mockError {
            isLoading = false
            throw error
        }

        currentUser = nil
        isAuthenticated = false
        isLoading = false
    }

    func resetPassword(email: String) async throws {
        resetPasswordCallCount += 1

        if let error = mockError {
            throw error
        }
    }

    func convertAnonymousToPermanent(email: String, password: String) async throws {
        convertAnonymousToPermanentCallCount += 1
        isLoading = true

        if let error = mockError {
            isLoading = false
            throw error
        }

        guard let user = currentUser, user.isAnonymous else {
            throw NSError(domain: "MockAuth", code: 400, userInfo: [NSLocalizedDescriptionKey: "Not anonymous"])
        }

        currentUser = LocalUser(
            uid: user.uid,
            email: email,
            displayName: email.components(separatedBy: "@").first,
            isAnonymous: false
        )
        isLoading = false
    }

    // MARK: - Helper Methods

    func getIDToken() async throws -> String {
        getIDTokenCallCount += 1

        if let error = mockError {
            throw error
        }

        guard let user = currentUser else {
            throw NSError(domain: "MockAuth", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }

        return "mock_token_\(user.uid)"
    }

    func checkEmailExists(_ email: String) async -> Bool {
        checkEmailExistsCallCount += 1
        return email == "existing@test.com"
    }

    // MARK: - Reset

    func reset() {
        isAuthenticated = false
        currentUser = nil
        isLoading = false
        errorMessage = nil
        shouldSucceedSignIn = true
        shouldSucceedSignUp = true
        shouldSucceedAnonymousSignIn = true
        mockError = nil
        signInCallCount = 0
        signUpCallCount = 0
        signInAnonymouslyCallCount = 0
        quickSignInCallCount = 0
        signOutCallCount = 0
        deleteAccountCallCount = 0
        resetPasswordCallCount = 0
        convertAnonymousToPermanentCallCount = 0
        getIDTokenCallCount = 0
        checkEmailExistsCallCount = 0
        lastSignInEmail = nil
        lastSignInPassword = nil
    }
}
