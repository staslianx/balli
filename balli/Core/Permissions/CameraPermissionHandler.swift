//
//  CameraPermissionHandler.swift
//  balli
//
//  Camera permission handling with comprehensive UI flow
//

import AVFoundation
import SwiftUI
import os.log

// MARK: - Permission State
public enum CameraPermissionState: String, Codable {
    case notDetermined
    case authorized
    case denied
    case restricted
    case checking
    
    var canRequestPermission: Bool {
        self == .notDetermined
    }
    
    var needsSettingsNavigation: Bool {
        self == .denied
    }
    
    var isUsable: Bool {
        self == .authorized
    }
}

// MARK: - Permission Events
public enum PermissionEvent {
    case userTappedAllow
    case userTappedDeny
    case userNavigatedToSettings
    case userReturnedFromSettings
    case systemPermissionChanged(AVAuthorizationStatus)
    case appBecameActive
}

// MARK: - Permission Analytics
struct PermissionAnalytics: Codable {
    var firstRequestDate: Date?
    var lastRequestDate: Date?
    var requestCount: Int = 0
    var finalStatus: CameraPermissionState?
    var timeToDecision: TimeInterval?
    var didUseEducationalPrompt: Bool = false
    var didNavigateToSettings: Bool = false
    var settingsNavigationCount: Int = 0
}

// MARK: - SwiftUI Lifecycle Notifications
extension Notification.Name {
    /// Posted when the app scene becomes active (replaces UIApplication/UIScene notifications)
    static let sceneDidBecomeActive = Notification.Name("com.balli.sceneDidBecomeActive")
}

// MARK: - Camera Permission Handler
@MainActor
public class CameraPermissionHandler: ObservableObject {
    @Published public private(set) var permissionState: CameraPermissionState = .checking
    @Published public var showEducationalPrompt = false
    @Published public var showPermissionDeniedAlert = false
    @Published public private(set) var isCheckingPermission = false
    
    private let logger = os.Logger(subsystem: "com.balli.diabetes", category: "CameraPermission")
    private var stateObservers: [UUID: @Sendable (CameraPermissionState) -> Void] = [:]
    private var analytics = PermissionAnalytics()
    private var permissionCheckTask: Task<Void, Never>?
    
    // Settings navigation
    private var settingsNavigationTime: Date?
    private let settingsReturnThreshold: TimeInterval = 2.0
    
    // Persistence
    private let analyticsKey = "com.balli.camera.permission.analytics"
    private let educationShownKey = "com.balli.camera.permission.education.shown"
    
    // Educational prompt continuation
    private var educationalPromptContinuation: CheckedContinuation<Bool, Never>?
    
    public init() {
        loadAnalytics()
        setupNotifications()
        checkInitialPermission()
    }
    
    deinit {
        permissionCheckTask?.cancel()
    }
    
    // MARK: - Permission Checking
    
    public func checkPermission() async -> CameraPermissionState {
        isCheckingPermission = true
        defer { isCheckingPermission = false }
        
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        let state = mapAuthorizationStatus(status)
        
        updateState(state)
        return state
    }
    
    private func checkInitialPermission() {
        permissionCheckTask = Task {
            _ = await checkPermission()
        }
    }
    
    private func mapAuthorizationStatus(_ status: AVAuthorizationStatus) -> CameraPermissionState {
        switch status {
        case .notDetermined:
            return .notDetermined
        case .authorized:
            return .authorized
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        @unknown default:
            logger.warning("Unknown authorization status: \(status.rawValue)")
            return .denied
        }
    }
    
    // MARK: - Permission Request Flow
    
    public func requestPermission() async -> Bool {
        logger.info("Starting permission request flow")
        
        // Check current state
        let currentState = await checkPermission()
        
        switch currentState {
        case .authorized:
            return true
            
        case .notDetermined:
            // Show educational prompt if not shown before
            if shouldShowEducationalPrompt() {
                return await requestWithEducation()
            } else {
                return await requestDirectly()
            }
            
        case .denied:
            // Guide to settings
            showPermissionDeniedAlert = true
            return false
            
        case .restricted:
            // Cannot request - device restricted
            logger.warning("Camera restricted by device policy")
            return false
            
        case .checking:
            // Wait for check to complete
            await permissionCheckTask?.value
            return permissionState.isUsable
        }
    }
    
    private func shouldShowEducationalPrompt() -> Bool {
        // Show education if not shown before and not in onboarding
        !UserDefaults.standard.bool(forKey: educationShownKey)
    }
    
    private func requestWithEducation() async -> Bool {
        logger.info("Showing educational prompt")
        
        analytics.didUseEducationalPrompt = true
        showEducationalPrompt = true
        
        // Wait for user to proceed from educational prompt
        return await withCheckedContinuation { continuation in
            educationalPromptContinuation = continuation
        }
    }
    
    public func userTappedContinueFromEducation() {
        showEducationalPrompt = false
        UserDefaults.standard.set(true, forKey: educationShownKey)
        
        Task {
            let granted = await requestDirectly()
            educationalPromptContinuation?.resume(returning: granted)
            educationalPromptContinuation = nil
        }
    }
    
    public func userDismissedEducation() {
        showEducationalPrompt = false
        educationalPromptContinuation?.resume(returning: false)
        educationalPromptContinuation = nil
    }
    
    private func requestDirectly() async -> Bool {
        logger.info("Requesting camera permission")
        
        analytics.firstRequestDate = analytics.firstRequestDate ?? Date()
        analytics.lastRequestDate = Date()
        analytics.requestCount += 1
        
        let requestStart = Date()
        
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        
        analytics.timeToDecision = Date().timeIntervalSince(requestStart)
        analytics.finalStatus = granted ? .authorized : .denied
        
        updateState(granted ? .authorized : .denied)
        saveAnalytics()
        
        logger.info("Permission request result: \(granted)")
        
        return granted
    }
    
    // MARK: - Settings Navigation

    /// Open Settings to allow user to grant camera permissions
    /// Uses SwiftUI-native notification pattern - no UIKit dependency
    public func openSettings() {
        settingsNavigationTime = Date()
        analytics.didNavigateToSettings = true
        analytics.settingsNavigationCount += 1

        logger.info("Requesting Settings open for camera permission")

        SettingsOpener.requestSettingsOpen()
        saveAnalytics()
    }
    
    // MARK: - State Management
    
    private func updateState(_ newState: CameraPermissionState) {
        guard newState != permissionState else { return }
        
        let oldState = permissionState
        permissionState = newState
        
        logger.info("Permission state changed: \(oldState.rawValue) → \(newState.rawValue)")
        
        // Notify observers
        stateObservers.values.forEach { observer in
            observer(newState)
        }
        
        // Update UI based on state
        handleStateTransition(from: oldState, to: newState)
    }
    
    private func handleStateTransition(from oldState: CameraPermissionState, to newState: CameraPermissionState) {
        switch (oldState, newState) {
        case (.denied, .authorized):
            // User granted permission in Settings
            logger.info("Permission granted via Settings")
            showPermissionDeniedAlert = false
            
        case (.notDetermined, .denied):
            // User denied on first request
            Task {
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s delay
                showPermissionDeniedAlert = true
            }
            
        default:
            break
        }
    }
    
    // MARK: - Lifecycle Handling

    private func setupNotifications() {
        // Listen for scene phase changes via SwiftUI notification pattern
        // The app should post this notification when scene becomes active
        NotificationCenter.default.addObserver(
            forName: .sceneDidBecomeActive,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                await self.checkPermissionAfterBackground()
            }
        }
    }
    
    private func checkPermissionAfterBackground() async {
        // Check if we're returning from Settings
        if let navigationTime = settingsNavigationTime,
           Date().timeIntervalSince(navigationTime) < settingsReturnThreshold {
            
            logger.info("Detected return from Settings")
            settingsNavigationTime = nil
            
            // Add small delay for Settings changes to propagate
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
        }
        
        // Always check permission when becoming active
        _ = await checkPermission()
    }
    
    // MARK: - Analytics
    
    private func loadAnalytics() {
        if let data = UserDefaults.standard.data(forKey: analyticsKey),
           let decoded = try? JSONDecoder().decode(PermissionAnalytics.self, from: data) {
            analytics = decoded
        }
    }
    
    private func saveAnalytics() {
        if let encoded = try? JSONEncoder().encode(analytics) {
            UserDefaults.standard.set(encoded, forKey: analyticsKey)
        }
    }
    
    // MARK: - Public API
    
    public func observePermissionState(_ observer: @escaping @Sendable (CameraPermissionState) -> Void) -> UUID {
        let id = UUID()
        stateObservers[id] = observer
        observer(permissionState) // Initial state
        return id
    }
    
    public func removeObserver(_ id: UUID) {
        stateObservers.removeValue(forKey: id)
    }
    
    public var canRequestPermission: Bool {
        permissionState.canRequestPermission
    }
    
    public var needsSettingsNavigation: Bool {
        permissionState.needsSettingsNavigation
    }
    
    public var isAuthorized: Bool {
        permissionState.isUsable
    }
}