
import Foundation
import SwiftUI
import Combine
import OSLog

// Local User Model
public struct LocalUser: Codable {
    let uid: String
    let email: String?
    let displayName: String?
    let isAnonymous: Bool
    
    init(uid: String = UUID().uuidString, 
         email: String? = nil, 
         displayName: String? = nil, 
         isAnonymous: Bool = false) {
        self.uid = uid
        self.email = email
        self.displayName = displayName
        self.isAnonymous = isAnonymous
    }
}

/// Manages Local Authentication for Balli
/// Simple setup for personal use - Dilara as main user, Serhat for testing
@MainActor
public class LocalAuthenticationManager: ObservableObject, LocalAuthenticationManagerProtocol {
    public static let shared = LocalAuthenticationManager()

    private enum Constants {
        static let signInDelayNanoseconds: UInt64 = 500_000_000         // 0.5 seconds
        static let signUpDelayNanoseconds: UInt64 = 500_000_000         // 0.5 seconds
        static let anonymousSignInDelayNanoseconds: UInt64 = 300_000_000 // 0.3 seconds
        static let passwordResetDelayNanoseconds: UInt64 = 1_000_000_000 // 1.0 seconds
        static let accountConversionDelayNanoseconds: UInt64 = 500_000_000 // 0.5 seconds
    }

    // MARK: - Published Properties
    @Published public private(set) var isAuthenticated = false
    @Published public private(set) var currentUser: LocalUser?
    @Published public private(set) var isLoading = false
    @Published public private(set) var errorMessage: String?
    
    // MARK: - User Information
    public var userId: String {
        // Test mode removed - use regular user ID
        return currentUser?.uid ?? "anonymous_\(UUID().uuidString)"
    }
    
    public var userEmail: String? {
        currentUser?.email
    }
    
    public var isAnonymous: Bool {
        currentUser?.isAnonymous ?? true
    }
    
    // MARK: - Predefined Users (for easy setup)
    public struct PredefinedUser {
        let email: String
        let displayName: String
        let isTestUser: Bool
    }
    
    public let predefinedUsers = [
        PredefinedUser(email: "dilara@balli.app", displayName: "Dilara", isTestUser: false),
        PredefinedUser(email: "serhat@balli.app", displayName: "Serhat (Test)", isTestUser: true)
    ]
    
    // UserDefaults keys
    private let userKey = "balli_local_user"
    private let authStateKey = "balli_auth_state"
    
    private init() {
        loadSavedUser()
    }
    
    // MARK: - Authentication Methods
    
    /// Load saved user from UserDefaults
    private func loadSavedUser() {
        if let userData = UserDefaults.standard.data(forKey: userKey),
           let user = try? JSONDecoder().decode(LocalUser.self, from: userData) {
            self.currentUser = user
            self.isAuthenticated = true
            
            // Test mode functionality removed
        }
    }
    
    /// Save user to UserDefaults
    private func saveUser(_ user: LocalUser) {
        if let userData = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(userData, forKey: userKey)
            UserDefaults.standard.set(true, forKey: authStateKey)
        }
    }
    
    /// Clear saved user
    private func clearUser() {
        UserDefaults.standard.removeObject(forKey: userKey)
        UserDefaults.standard.removeObject(forKey: authStateKey)
    }
    
    /// Sign in with email and password
    public func signIn(email: String, password: String) async throws {
        isLoading = true
        errorMessage = nil

        await debugDelay(Constants.signInDelayNanoseconds)
        
        // Check predefined users (simple local validation)
        let validUsers = [
            ("dilara@balli.app", "dilara123", "Dilara"),
            ("serhat@balli.app", "serhat123", "Serhat (Test)")
        ]
        
        if let validUser = validUsers.first(where: { $0.0 == email && $0.1 == password }) {
            let user = LocalUser(
                uid: "user_\(email.replacingOccurrences(of: "@", with: "_").replacingOccurrences(of: ".", with: "_"))",
                email: email,
                displayName: validUser.2,
                isAnonymous: false
            )
            
            currentUser = user
            isAuthenticated = true
            saveUser(user)

            // Test mode functionality removed

            AppLoggers.Auth.main.info("Signed in successfully: \(user.uid, privacy: .private)")
            isLoading = false
        } else {
            errorMessage = "Geçersiz email veya şifre"
            isLoading = false
            throw NSError(domain: "LocalAuth", code: 401, userInfo: [NSLocalizedDescriptionKey: "Invalid credentials"])
        }
    }
    
    /// Create a new account
    public func signUp(email: String, password: String, displayName: String? = nil) async throws {
        isLoading = true
        errorMessage = nil

        await debugDelay(Constants.signUpDelayNanoseconds)
        
        // Create local user
        let user = LocalUser(
            uid: "user_\(UUID().uuidString)",
            email: email,
            displayName: displayName ?? email.components(separatedBy: "@").first,
            isAnonymous: false
        )
        
        currentUser = user
        isAuthenticated = true
        saveUser(user)

        AppLoggers.Auth.main.info("Account created: \(user.uid, privacy: .private)")
        isLoading = false
    }
    
    /// Sign in anonymously (for testing or first-time use)
    public func signInAnonymously() async throws {
        isLoading = true
        errorMessage = nil

        await debugDelay(Constants.anonymousSignInDelayNanoseconds)
        
        let user = LocalUser(
            uid: "anon_\(UUID().uuidString)",
            email: nil,
            displayName: "Misafir Kullanıcı",
            isAnonymous: true
        )
        
        currentUser = user
        isAuthenticated = true
        saveUser(user)

        AppLoggers.Auth.main.info("Signed in anonymously: \(user.uid, privacy: .private)")
        isLoading = false
    }
    
    /// Quick sign-in for predefined users (simplified for family use)
    public func quickSignIn(for predefinedUser: PredefinedUser, password: String) async throws {
        // Test mode functionality removed
        try await signIn(email: predefinedUser.email, password: password)
    }
    
    /// Sign out
    public func signOut() throws {
        currentUser = nil
        isAuthenticated = false
        clearUser()
        // Test mode functionality removed
        AppLoggers.Auth.main.info("Signed out successfully")
    }
    
    /// Delete account (GDPR compliance)
    public func deleteAccount() async throws {
        guard currentUser != nil else {
            throw AuthError.notAuthenticated
        }

        isLoading = true
        errorMessage = nil

        await debugDelay(Constants.signInDelayNanoseconds)
        
        currentUser = nil
        isAuthenticated = false
        clearUser()

        AppLoggers.Auth.main.notice("Account deleted successfully")
        isLoading = false
    }
    
    /// Reset password
    public func resetPassword(email: String) async throws {
        await debugDelay(Constants.passwordResetDelayNanoseconds)

        AppLoggers.Auth.main.info("Password reset email sent to \(email, privacy: .private) (mock)")
    }
    
    /// Convert anonymous account to permanent account
    public func convertAnonymousToPermanent(email: String, password: String) async throws {
        guard let user = currentUser, user.isAnonymous else {
            throw AuthError.notAnonymous
        }

        isLoading = true
        errorMessage = nil

        await debugDelay(Constants.accountConversionDelayNanoseconds)
        
        // Create permanent user from anonymous
        let permanentUser = LocalUser(
            uid: user.uid,
            email: email,
            displayName: email.components(separatedBy: "@").first,
            isAnonymous: false
        )
        
        currentUser = permanentUser
        saveUser(permanentUser)

        AppLoggers.Auth.main.info("Converted to permanent account")
        isLoading = false
    }

    // MARK: - Helper Methods

    private func debugDelay(_ nanoseconds: UInt64) async {
#if DEBUG
        try? await Task.sleep(nanoseconds: nanoseconds)
#endif
    }

    /// Get ID token for backend authentication
    public func getIDToken() async throws -> String {
        guard let user = currentUser else {
            throw AuthError.notAuthenticated
        }
        // Return mock token based on user ID
        return "mock_token_\(user.uid)"
    }
    
    /// Check if email is already registered
    public func checkEmailExists(_ email: String) async -> Bool {
        // Check against predefined users
        return predefinedUsers.contains { $0.email == email }
    }
}

// MARK: - Auth Errors
public enum AuthError: LocalizedError {
    case notAuthenticated
    case notAnonymous
    case invalidEmail
    case weakPassword
    
    public var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Kullanıcı girişi yapılmamış"
        case .notAnonymous:
            return "Bu işlem sadece anonim hesaplar için geçerli"
        case .invalidEmail:
            return "Geçersiz email adresi"
        case .weakPassword:
            return "Şifre en az 6 karakter olmalı"
        }
    }
}

// MARK: - Auth State View Modifier
struct AuthenticatedViewModifier: ViewModifier {
    @ObservedObject var authManager = LocalAuthenticationManager.shared
    let unauthenticatedView: AnyView
    
    func body(content: Content) -> some View {
        if authManager.isAuthenticated {
            content
        } else {
            unauthenticatedView
        }
    }
}

extension View {
    func requiresAuthentication<V: View>(otherwise unauthenticatedView: V) -> some View {
        modifier(AuthenticatedViewModifier(unauthenticatedView: AnyView(unauthenticatedView)))
    }
}

// MARK: - Simple Login View
public struct SimpleLoginView: View {
    @ObservedObject private var authManager = LocalAuthenticationManager.shared
    @State private var selectedUser: LocalAuthenticationManager.PredefinedUser?
    @State private var password = ""
    @State private var showingCustomLogin = false
    @State private var customEmail = ""
    @State private var isSignUp = false
    
    public var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // App Logo/Header
                VStack(spacing: 10) {
                    Image(systemName: "heart.text.square.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Balli")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Diyabet Destek Asistanı")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 40)
                
                Spacer()
                
                // Quick Login for Family Members
                VStack(spacing: 15) {
                    Text("Hızlı Giriş")
                        .font(.headline)
                    
                    ForEach(authManager.predefinedUsers, id: \.email) { user in
                        Button(action: {
                            selectedUser = user
                        }) {
                            HStack {
                                Image(systemName: user.isTestUser ? "flask.fill" : "person.fill")
                                Text(user.displayName)
                                Spacer()
                                if user.isTestUser {
                                    Text("TEST")
                                        .font(.caption)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.orange.opacity(0.2))
                                        .foregroundColor(.orange)
                                        .cornerRadius(4)
                                }
                            }
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(10)
                        }
                    }
                    
                    // Password field for selected user
                    if let user = selectedUser {
                        VStack(spacing: 10) {
                            SecureField("Şifre (\(user.displayName))", text: $password)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            
                            Button(action: {
                                Task {
                                    do {
                                        try await authManager.quickSignIn(for: user, password: password)
                                    } catch {
                                        AppLoggers.Auth.main.error("Login failed: \(error.localizedDescription)")
                                    }
                                }
                            }) {
                                Text("Giriş Yap")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                            .disabled(password.isEmpty)
                        }
                        .padding(.top, 10)
                    }
                }
                .padding(.horizontal)
                
                Divider()
                    .padding(.vertical)
                
                // Other options
                VStack(spacing: 15) {
                    Button(action: {
                        Task {
                            try await authManager.signInAnonymously()
                        }
                    }) {
                        Text("Anonim Olarak Devam Et")
                            .foregroundColor(.gray)
                    }
                    
                    Button(action: {
                        showingCustomLogin = true
                    }) {
                        Text("Farklı Email ile Giriş")
                            .foregroundColor(.blue)
                    }
                }
                
                Spacer()
                
                // Loading indicator
                if authManager.isLoading {
                    ProgressView()
                        .padding()
                }
                
                // Error message
                if let error = authManager.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding()
                }
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingCustomLogin) {
            CustomLoginView()
        }
    }
}

// MARK: - Custom Login View
public struct CustomLoginView: View {
    @ObservedObject private var authManager = LocalAuthenticationManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var isSignUp = false
    
    public var body: some View {
        NavigationView {
            Form {
                Section(header: Text(isSignUp ? "Yeni Hesap Oluştur" : "Giriş Yap")) {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                    
                    SecureField("Şifre", text: $password)
                        .textContentType(isSignUp ? .newPassword : .password)
                    
                    if isSignUp {
                        TextField("İsim (opsiyonel)", text: $displayName)
                            .textContentType(.name)
                    }
                }
                
                Section {
                    Button(action: {
                        Task {
                            do {
                                if isSignUp {
                                    try await authManager.signUp(
                                        email: email,
                                        password: password,
                                        displayName: displayName.isEmpty ? nil : displayName
                                    )
                                } else {
                                    try await authManager.signIn(email: email, password: password)
                                }
                                dismiss()
                            } catch {
                                AppLoggers.Auth.main.error("Auth failed: \(error.localizedDescription)")
                            }
                        }
                    }) {
                        Text(isSignUp ? "Hesap Oluştur" : "Giriş Yap")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(email.isEmpty || password.count < 6)
                    
                    Button(action: {
                        isSignUp.toggle()
                    }) {
                        Text(isSignUp ? "Zaten hesabım var" : "Yeni hesap oluştur")
                            .foregroundColor(.blue)
                    }
                }
                
                if !isSignUp {
                    Section {
                        Button(action: {
                            Task {
                                try await authManager.resetPassword(email: email)
                            }
                        }) {
                            Text("Şifremi Unuttum")
                                .foregroundColor(.orange)
                        }
                        .disabled(email.isEmpty)
                    }
                }
            }
            .navigationTitle(isSignUp ? "Kayıt Ol" : "Giriş")
            .navigationBarItems(trailing: Button("İptal") { dismiss() })
        }
    }
}
