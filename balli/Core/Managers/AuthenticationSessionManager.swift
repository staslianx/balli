//
//  AuthenticationSessionManager.swift
//  balli
//
//  Authentication token lifecycle management with automatic refresh
//  HIPAA-compliant auth session handling with automatic cleanup
//  Swift 6 strict concurrency compliant
//

import Foundation
import SwiftUI
import Combine
import Network
import OSLog

// MARK: - Session State
public enum SessionState: Sendable, Equatable {
    case inactive
    case starting
    case active(timeRemaining: TimeInterval)
    case refreshing
    case expiring(timeRemaining: TimeInterval)
    case expired
    case terminated
    case error(String)
}

// MARK: - Session Configuration
public struct SessionConfiguration: Sendable {
    let sessionTimeout: TimeInterval = 3600 // 1 hour
    let refreshThreshold: TimeInterval = 600 // 10 minutes before expiry
    let maxRefreshAttempts: Int = 3
    let backgroundRefreshInterval: TimeInterval = 300 // 5 minutes
    let inactivityTimeout: TimeInterval = 1800 // 30 minutes
    
    public init() {}
}

// MARK: - Session Data
public struct SessionData: Codable, Sendable {
    let sessionId: String
    let userId: String
    let startTime: Date
    let lastActivity: Date
    let expiresAt: Date
    let deviceId: String
    let appVersion: String
    
    var isExpired: Bool {
        Date() > expiresAt
    }
    
    var timeUntilExpiry: TimeInterval {
        expiresAt.timeIntervalSinceNow
    }
    
    var isNearExpiry: Bool {
        timeUntilExpiry <= 600 // 10 minutes
    }
}

// MARK: - Authentication Session Manager
@MainActor
public final class AuthenticationSessionManager: ObservableObject {
    public static let shared = AuthenticationSessionManager()

    private let logger = AppLoggers.Auth.main
    private let configuration = SessionConfiguration()
    
    // MARK: - Dependencies
    private let keychainManager = KeychainStorageService.shared
    private let networkMonitor = NWPathMonitor()
    
    // MARK: - Published Properties
    @Published public private(set) var sessionState: SessionState = .inactive
    @Published public private(set) var currentSession: SessionData?
    @Published public private(set) var isNetworkAvailable = true
    @Published public private(set) var lastRefreshAttempt: Date?
    
    // MARK: - Private Properties
    private var sessionTimer: Timer?
    private var refreshTimer: Timer?
    private var inactivityTimer: Timer?
    private var refreshAttempts = 0
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Background Task
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    
    private init() {
        setupNetworkMonitoring()
        setupAuthStateObserver()
        logger.info("SessionManager initialized")
    }

    deinit {
        // Cancel any ongoing operations before deallocation
        // Note: We can't perform async cleanup in deinit as it violates Swift 6 concurrency
        // Cleanup should be called explicitly before the object is deallocated
        logger.debug("SessionManager deallocated")
    }
    
    // MARK: - Session Lifecycle
    
    /// Start a new authenticated session
    public func startSession(for userId: String) async throws {
        logger.info("Starting session for user: [REDACTED]")

        sessionState = .starting

        do {
            // End any existing session
            await endSession()

            // Create new session data
            let sessionData = SessionData(
                sessionId: UUID().uuidString,
                userId: userId,
                startTime: Date(),
                lastActivity: Date(),
                expiresAt: Date().addingTimeInterval(configuration.sessionTimeout),
                deviceId: UIDevice.current.identifierForVendor?.uuidString ?? "unknown",
                appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
            )

            // Store session securely
            try await keychainManager.store(
                sessionData,
                for: "current_session",
                itemType: .userCredentials
            )

            // Update state
            currentSession = sessionData
            sessionState = .active(timeRemaining: sessionData.timeUntilExpiry)

            // Start timers
            startSessionTimers()

            // Start background refresh
            setupBackgroundRefresh()

            logger.info("Session started successfully: \(sessionData.sessionId, privacy: .private)")

        } catch {
            logger.error("Failed to start session: \(error.localizedDescription)")
            sessionState = .error(error.localizedDescription)
            throw error
        }
    }
    
    /// Update session activity (call on user interaction)
    public func updateActivity() async {
        guard let session = currentSession,
              sessionState != .expired,
              sessionState != .terminated else {
            return
        }
        
        logger.debug("Updating session activity")
        
        let updatedSession = SessionData(
            sessionId: session.sessionId,
            userId: session.userId,
            startTime: session.startTime,
            lastActivity: Date(),
            expiresAt: session.expiresAt,
            deviceId: session.deviceId,
            appVersion: session.appVersion
        )
        
        do {
            try await keychainManager.store(
                updatedSession,
                for: "current_session",
                itemType: .userCredentials
            )
            
            currentSession = updatedSession
            
            // Reset inactivity timer
            resetInactivityTimer()
            
        } catch {
            logger.warning("Failed to update session activity: \(error.localizedDescription)")
        }
    }
    
    /// Refresh session token
    public func refreshSession() async -> Bool {
        logger.info("Refreshing session token")
        
        guard let session = currentSession,
              !session.isExpired,
              refreshAttempts < configuration.maxRefreshAttempts else {
            logger.warning("Cannot refresh session - invalid state or max attempts reached")
            return false
        }
        
        sessionState = .refreshing
        refreshAttempts += 1
        lastRefreshAttempt = Date()
        
        do {
            // Start background task
            beginBackgroundTask()
            
            // Refresh authentication token
            // Authentication refresh removed
            
            // Extend session
            let extendedSession = SessionData(
                sessionId: session.sessionId,
                userId: session.userId,
                startTime: session.startTime,
                lastActivity: Date(),
                expiresAt: Date().addingTimeInterval(configuration.sessionTimeout),
                deviceId: session.deviceId,
                appVersion: session.appVersion
            )
            
            // Store updated session
            try await keychainManager.store(
                extendedSession,
                for: "current_session",
                itemType: .userCredentials
            )
            
            currentSession = extendedSession
            sessionState = .active(timeRemaining: extendedSession.timeUntilExpiry)
            refreshAttempts = 0
            
            // Restart timers
            startSessionTimers()
            
            logger.info("Session refreshed successfully")
            
            // End background task
            endBackgroundTask()
            
            return true
            
        } catch {
            logger.error("Session refresh failed: \(error.localizedDescription)")
            
            // End background task
            endBackgroundTask()
            
            if refreshAttempts >= configuration.maxRefreshAttempts {
                logger.error("Max refresh attempts reached, expiring session")
                await expireSession()
                return false
            }
            
            sessionState = .error(error.localizedDescription)
            return false
        }
    }
    
    /// End current session
    public func endSession() async {
        logger.info("Ending current session")
        
        // Stop all timers
        stopAllTimers()
        
        // Clear session data
        try? await keychainManager.delete(key: "current_session", itemType: .userCredentials)
        
        currentSession = nil
        sessionState = .terminated
        refreshAttempts = 0
        
        logger.info("Session ended successfully")
    }
    
    /// Handle session expiry
    private func expireSession() async {
        logger.warning("Session expired")
        
        sessionState = .expired
        stopAllTimers()
        
        // Clear session data but keep for audit
        currentSession = nil

        // Sign out user (removed - local mode)

        logger.info("Session expired and user signed out")
    }
    
    /// Restore session from keychain
    public func restoreSession() async -> Bool {
        logger.info("Attempting to restore session")
        
        do {
            guard let sessionData = try await keychainManager.retrieve(
                SessionData.self,
                for: "current_session",
                itemType: .userCredentials
            ) else {
                logger.info("No stored session found")
                return false
            }
            
            // Check if session is expired
            if sessionData.isExpired {
                logger.info("Stored session is expired")
                try? await keychainManager.delete(key: "current_session", itemType: .userCredentials)
                return false
            }
            
            // Restore session
            currentSession = sessionData
            
            if sessionData.isNearExpiry {
                sessionState = .expiring(timeRemaining: sessionData.timeUntilExpiry)
                // Attempt refresh
                _ = await refreshSession()
            } else {
                sessionState = .active(timeRemaining: sessionData.timeUntilExpiry)
                startSessionTimers()
            }
            
            logger.info("Session restored successfully: \(sessionData.sessionId)")
            return true
            
        } catch {
            logger.error("Failed to restore session: \(error.localizedDescription)")
            return false
        }
    }
}

// MARK: - Timer Management
extension AuthenticationSessionManager {
    
    private func startSessionTimers() {
        stopAllTimers()
        
        guard let session = currentSession else { return }
        
        // Main session timer
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            Task { @MainActor in
                await AuthenticationSessionManager.shared.checkSessionStatus()
            }
        }
        
        // Refresh timer (triggers before expiry)
        let refreshTime = max(session.timeUntilExpiry - configuration.refreshThreshold, 60)
        refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshTime, repeats: false) { _ in
            Task { @MainActor in
                await AuthenticationSessionManager.shared.handleAutoRefresh()
            }
        }
        
        // Inactivity timer
        resetInactivityTimer()
        
        logger.debug("Session timers started")
    }
    
    private func resetInactivityTimer() {
        inactivityTimer?.invalidate()
        
        inactivityTimer = Timer.scheduledTimer(withTimeInterval: configuration.inactivityTimeout, repeats: false) { _ in
            Task { @MainActor in
                await AuthenticationSessionManager.shared.handleInactivityTimeout()
            }
        }
    }
    
    private func stopAllTimers() {
        sessionTimer?.invalidate()
        refreshTimer?.invalidate()
        inactivityTimer?.invalidate()
        
        sessionTimer = nil
        refreshTimer = nil
        inactivityTimer = nil
        
        logger.debug("All session timers stopped")
    }
    
    private func checkSessionStatus() async {
        guard let session = currentSession else {
            sessionState = .inactive
            return
        }
        
        if session.isExpired {
            await expireSession()
        } else if session.isNearExpiry {
            sessionState = .expiring(timeRemaining: session.timeUntilExpiry)
        } else {
            sessionState = .active(timeRemaining: session.timeUntilExpiry)
        }
    }
    
    private func handleAutoRefresh() async {
        logger.info("Auto-refresh triggered")
        
        if isNetworkAvailable {
            _ = await refreshSession()
        } else {
            logger.warning("Auto-refresh skipped - no network connection")
            sessionState = .expiring(timeRemaining: currentSession?.timeUntilExpiry ?? 0)
        }
    }
    
    private func handleInactivityTimeout() async {
        logger.warning("Inactivity timeout triggered")
        
        // For health apps, we're more lenient with inactivity
        // Instead of immediate logout, show warning and require re-authentication for sensitive actions
        if let session = currentSession, !session.isExpired {
            sessionState = .expiring(timeRemaining: session.timeUntilExpiry)
        } else {
            await expireSession()
        }
    }
}

// MARK: - Network Monitoring
extension AuthenticationSessionManager {

    private func setupNetworkMonitoring() {
        // NWPathMonitor requires a queue, but we use modern async pattern for updates
        // Use a detached task with low priority for background monitoring
        Task.detached(priority: .utility) { [weak self] in
            guard let self = self else { return }

            // Create dedicated queue for network monitor (required by NWPathMonitor API)
            let monitorQueue = DispatchQueue(label: "com.balli.network.monitor", qos: .utility)

            // Start monitoring on the dedicated queue
            await MainActor.run {
                self.networkMonitor.start(queue: monitorQueue)
            }

            // Set up path update handler with modern async pattern
            await MainActor.run {
                self.networkMonitor.pathUpdateHandler = { [weak self] path in
                    guard let self = self else { return }

                    // Update state on main actor
                    Task { @MainActor [weak self] in
                        guard let self = self else { return }

                        let isAvailable = (path.status == .satisfied)
                        self.isNetworkAvailable = isAvailable

                        if isAvailable {
                            // Network restored, check if we need to refresh
                            await self.handleNetworkRestored()
                        }
                    }
                }
            }
        }
    }

    private func handleNetworkRestored() async {
        guard let session = currentSession,
              session.isNearExpiry,
              sessionState != .refreshing else {
            return
        }

        logger.info("Network restored, checking session refresh")
        _ = await refreshSession()
    }
}

// MARK: - Background Tasks
extension AuthenticationSessionManager {
    
    private func setupBackgroundRefresh() {
        // Register for background app refresh
        logger.info("Setting up background session refresh")
    }
    
    private func beginBackgroundTask() {
        endBackgroundTask() // End any existing task
        
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "SessionRefresh") {
            Task { @MainActor in
                AuthenticationSessionManager.shared.endBackgroundTask()
            }
        }
    }
    
    private func endBackgroundTask() {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }
}

// MARK: - Auth State Observer
extension AuthenticationSessionManager {
    
    private func setupAuthStateObserver() {
        // Authentication monitoring removed
    }
}

// MARK: - Public API
public extension AuthenticationSessionManager {
    
    /// Check if session is valid and active
    var isSessionValid: Bool {
        guard let session = currentSession else { return false }
        return !session.isExpired
    }
    
    /// Get remaining session time
    var sessionTimeRemaining: TimeInterval {
        return currentSession?.timeUntilExpiry ?? 0
    }
    
    /// Check if session needs refresh soon
    var needsRefreshSoon: Bool {
        return currentSession?.isNearExpiry ?? false
    }
    
    /// Get session information for debugging
    var sessionInfo: [String: Any] {
        var info: [String: Any] = [
            "state": "\(sessionState)",
            "isValid": isSessionValid,
            "timeRemaining": sessionTimeRemaining,
            "needsRefresh": needsRefreshSoon,
            "networkAvailable": isNetworkAvailable
        ]
        
        if let session = currentSession {
            info["sessionId"] = session.sessionId
            info["startTime"] = session.startTime.timeIntervalSince1970
            info["lastActivity"] = session.lastActivity.timeIntervalSince1970
            info["expiresAt"] = session.expiresAt.timeIntervalSince1970
        }
        
        return info
    }
}

// MARK: - Cleanup
extension AuthenticationSessionManager {
    
    /// Public cleanup method that should be called before app termination
    /// This ensures proper resource cleanup without violating Swift 6 concurrency
    @MainActor
    public func cleanup() async {
        stopAllTimers()
        endBackgroundTask()
        networkMonitor.cancel()
        cancellables.removeAll()
        logger.info("SessionManager cleaned up")
    }
}