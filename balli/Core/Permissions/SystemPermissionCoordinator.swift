//
//  SystemPermissionCoordinator.swift
//  balli
//
//  System permission coordination for Camera, Microphone, and HealthKit
//  Ensures permissions work immediately after being granted without app restart
//

import AVFoundation
import HealthKit
import UIKit
import SwiftUI
import os.log

// MARK: - Permission Types

public enum PermissionType: String, CaseIterable {
    case camera = "Camera"
    case microphone = "Microphone"
    case health = "Health"
    
    var systemName: String {
        switch self {
        case .camera: return "camera.fill"
        case .microphone: return "mic.fill"
        case .health: return "heart.fill"
        }
    }
    
    var description: String {
        switch self {
        case .camera: return "Take photos and scan labels"
        case .microphone: return "Record voice for transcription"
        case .health: return "Read glucose and nutrition data"
        }
    }
}

// MARK: - Permission Status

public enum UnifiedPermissionStatus: String, Sendable {
    case notDetermined
    case authorized
    case denied
    case restricted
    case checking
    
    var isUsable: Bool {
        self == .authorized
    }
    
    var canRequest: Bool {
        self == .notDetermined
    }
    
    var needsSettings: Bool {
        self == .denied
    }
}

// MARK: - System Permission Coordinator

@MainActor
public class SystemPermissionCoordinator: ObservableObject {
    // MARK: - Published States
    
    @Published public private(set) var cameraStatus: UnifiedPermissionStatus = .checking
    @Published public private(set) var microphoneStatus: UnifiedPermissionStatus = .checking
    @Published public private(set) var healthStatus: UnifiedPermissionStatus = .checking
    @Published public private(set) var isCheckingAnyPermission = false
    
    // MARK: - Private Properties
    
    private let logger = os.Logger(subsystem: "com.balli.diabetes", category: "UnifiedPermissions")
    private let healthStore = HKHealthStore()
    
    // Settings navigation tracking
    private var settingsNavigationTime: Date?
    private let settingsReturnThreshold: TimeInterval = 2.0
    
    // Permission check tasks
    private var permissionCheckTasks: [PermissionType: Task<Void, Never>] = [:]
    
    // State observers for reactive updates
    private var stateObservers: [UUID: (PermissionType, UnifiedPermissionStatus) -> Void] = [:]
    
    // MARK: - Singleton

    public static let shared = SystemPermissionCoordinator()
    
    private init() {
        setupLifecycleObservers()
        checkAllPermissions()
    }
    
    // MARK: - Lifecycle Observers
    
    private func setupLifecycleObservers() {
        // App became active - check for permission changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appBecameActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        
        // Scene phase changes for iOS 13+
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sceneDidBecomeActive),
            name: UIScene.didActivateNotification,
            object: nil
        )
        
        logger.info("Lifecycle observers configured")
    }
    
    @objc private func appBecameActive() {
        logger.debug("App became active, checking all permissions")
        Task {
            await checkPermissionsAfterBackground()
        }
    }
    
    @objc private func sceneDidBecomeActive(_ notification: Notification) {
        Task {
            await checkPermissionsAfterBackground()
        }
    }
    
    private func checkPermissionsAfterBackground() async {
        // Check if we're returning from Settings
        if let navigationTime = settingsNavigationTime,
           Date().timeIntervalSince(navigationTime) < settingsReturnThreshold {
            
            logger.info("Detected return from Settings, refreshing permissions")
            settingsNavigationTime = nil
            
            // Add small delay for Settings changes to propagate
            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2s
        }
        
        // Always check all permissions when becoming active
        checkAllPermissions()
    }
    
    // MARK: - Permission Checking
    
    public func checkAllPermissions() {
        Task {
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await self.checkCameraPermission() }
                group.addTask { await self.checkMicrophonePermission() }
                group.addTask { await self.checkHealthPermission() }
            }
        }
    }
    
    public func checkPermission(_ type: PermissionType) async -> UnifiedPermissionStatus {
        switch type {
        case .camera:
            return await checkCameraPermission()
        case .microphone:
            return await checkMicrophonePermission()
        case .health:
            return await checkHealthPermission()
        }
    }
    
    @discardableResult
    private func checkCameraPermission() async -> UnifiedPermissionStatus {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        let unifiedStatus = mapCameraStatus(status)
        
        if cameraStatus != unifiedStatus {
            cameraStatus = unifiedStatus
            notifyObservers(.camera, unifiedStatus)
            logger.info("Camera permission status: \(unifiedStatus.rawValue)")
        }
        
        return unifiedStatus
    }
    
    @discardableResult
    private func checkMicrophonePermission() async -> UnifiedPermissionStatus {
        // Check permission status (different APIs for different iOS versions)
        let unifiedStatus: UnifiedPermissionStatus

        if #available(iOS 17.0, *) {
            // iOS 17+ uses AVAudioApplication
            let appPermission = AVAudioApplication.shared.recordPermission
            switch appPermission {
            case .granted:
                unifiedStatus = .authorized
            case .denied:
                unifiedStatus = .denied
            case .undetermined:
                unifiedStatus = .notDetermined
            @unknown default:
                unifiedStatus = .notDetermined
            }
        } else {
            // Earlier iOS uses AVAudioSession
            let sessionPermission = AVAudioSession.sharedInstance().recordPermission
            unifiedStatus = mapMicrophoneStatus(sessionPermission)
        }

        if microphoneStatus != unifiedStatus {
            microphoneStatus = unifiedStatus
            notifyObservers(.microphone, unifiedStatus)
            logger.info("Microphone permission status: \(unifiedStatus.rawValue)")
        }

        return unifiedStatus
    }
    
    @discardableResult
    private func checkHealthPermission() async -> UnifiedPermissionStatus {
        guard HKHealthStore.isHealthDataAvailable() else {
            healthStatus = .restricted
            return .restricted
        }

        // Use HealthKitPermissionManager for reliable status checking via test queries
        let permissionManager = HealthKitPermissionManager.shared

        // Check if we've previously requested authorization
        if !permissionManager.hasRequestedAuthorization {
            // First time - user hasn't been asked yet
            let unifiedStatus = UnifiedPermissionStatus.notDetermined
            if healthStatus != unifiedStatus {
                healthStatus = unifiedStatus
                notifyObservers(.health, unifiedStatus)
                logger.info("Health permission status: notDetermined (never requested)")
            }
            return unifiedStatus
        }

        // We've requested before - check actual access via test query
        let hasAccess = await permissionManager.hasGlucoseDataAccess()
        let unifiedStatus = hasAccess ? UnifiedPermissionStatus.authorized : UnifiedPermissionStatus.denied

        if healthStatus != unifiedStatus {
            healthStatus = unifiedStatus
            notifyObservers(.health, unifiedStatus)
            logger.info("Health permission status: \(unifiedStatus.rawValue) (verified via test query)")
        }

        return unifiedStatus
    }
    
    // MARK: - Permission Requesting
    
    public func requestPermission(_ type: PermissionType) async -> Bool {
        logger.info("Requesting permission for: \(type.rawValue)")
        
        isCheckingAnyPermission = true
        defer { isCheckingAnyPermission = false }
        
        switch type {
        case .camera:
            return await requestCameraPermission()
        case .microphone:
            return await requestMicrophonePermission()
        case .health:
            return await requestHealthPermission()
        }
    }
    
    private func requestCameraPermission() async -> Bool {
        let currentStatus = await checkCameraPermission()
        
        switch currentStatus {
        case .authorized:
            return true
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            cameraStatus = granted ? .authorized : .denied
            notifyObservers(.camera, cameraStatus)
            
            // Setup session immediately after permission grant
            if granted {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s for system to settle
            }
            
            return granted
        default:
            return false
        }
    }
    
    private func requestMicrophonePermission() async -> Bool {
        let currentStatus = await checkMicrophonePermission()
        
        switch currentStatus {
        case .authorized:
            return true
        case .notDetermined:
            let granted = await withCheckedContinuation { continuation in
                if #available(iOS 17.0, *) {
                    AVAudioApplication.requestRecordPermission { granted in
                        continuation.resume(returning: granted)
                    }
                } else {
                    AVAudioSession.sharedInstance().requestRecordPermission { granted in
                        continuation.resume(returning: granted)
                    }
                }
            }
            
            microphoneStatus = granted ? .authorized : .denied
            notifyObservers(.microphone, microphoneStatus)
            
            // Setup audio session immediately after permission grant
            if granted {
                try? await Task.sleep(nanoseconds: 200_000_000) // 0.2s for system to settle
                await setupAudioSessionAfterPermission()
            }
            
            return granted
        default:
            return false
        }
    }
    
    private func requestHealthPermission() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else {
            healthStatus = .restricted
            return false
        }

        let currentStatus = await checkHealthPermission()

        switch currentStatus {
        case .authorized:
            return true
        case .notDetermined:
            // Use HealthKitPermissionManager to handle authorization
            let permissionManager = HealthKitPermissionManager.shared

            do {
                // This will show the system dialog and update permission status
                try await permissionManager.requestAllPermissions()

                // Add small delay for iOS to finalize the permission state
                try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s

                // Now verify what permissions were actually granted
                let hasGlucoseAccess = await permissionManager.hasGlucoseDataAccess()
                let hasActivityAccess = await permissionManager.hasActivityDataAccess()

                // Grant if we have at least the required glucose data access
                if hasGlucoseAccess {
                    healthStatus = .authorized
                    notifyObservers(.health, healthStatus)

                    // Setup background delivery
                    await setupHealthKitBackgroundDelivery()

                    logger.info("HealthKit authorization successful (glucose: true, activity: \(hasActivityAccess))")
                    return true
                } else {
                    healthStatus = .denied
                    notifyObservers(.health, healthStatus)
                    logger.warning("HealthKit authorization incomplete (glucose: false, activity: \(hasActivityAccess))")
                    return false
                }
            } catch {
                logger.error("Health authorization failed: \(error.localizedDescription)")
                healthStatus = .denied
                notifyObservers(.health, healthStatus)
                return false
            }
        default:
            return false
        }
    }
    
    // MARK: - Setup After Permission
    
    private func setupAudioSessionAfterPermission() async {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothHFP])
            try audioSession.setActive(true)
            logger.info("Audio session configured after permission grant")
        } catch {
            logger.error("Failed to setup audio session: \(error)")
        }
    }
    
    private func setupHealthKitBackgroundDelivery() async {
        // Setup background delivery for glucose data
        let glucoseType = HKQuantityType(.bloodGlucose)
        
        do {
            try await healthStore.enableBackgroundDelivery(for: glucoseType, frequency: .hourly)
            logger.info("HealthKit background delivery enabled")
        } catch {
            logger.error("Failed to enable background delivery: \(error)")
        }
    }
    
    // MARK: - Settings Navigation
    
    public func openSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else {
            logger.error("Failed to create settings URL")
            return
        }
        
        settingsNavigationTime = Date()
        logger.info("Opening settings for permissions")
        
        UIApplication.shared.open(settingsURL) { success in
            if !success {
                self.logger.error("Failed to open settings")
            }
        }
    }
    
    // MARK: - Status Mapping
    
    private func mapCameraStatus(_ status: AVAuthorizationStatus) -> UnifiedPermissionStatus {
        switch status {
        case .notDetermined: return .notDetermined
        case .authorized: return .authorized
        case .denied: return .denied
        case .restricted: return .restricted
        @unknown default: return .denied
        }
    }
    
    private func mapMicrophoneStatus(_ status: AVAudioSession.RecordPermission) -> UnifiedPermissionStatus {
        switch status {
        case .undetermined: return .notDetermined
        case .granted: return .authorized
        case .denied: return .denied
        @unknown default: return .denied
        }
    }
    
    // MARK: - Observers
    
    public func observePermissionChanges(_ observer: @escaping (PermissionType, UnifiedPermissionStatus) -> Void) -> UUID {
        let id = UUID()
        stateObservers[id] = observer
        
        // Send current states
        observer(.camera, cameraStatus)
        observer(.microphone, microphoneStatus)
        observer(.health, healthStatus)
        
        return id
    }
    
    public func removeObserver(_ id: UUID) {
        stateObservers.removeValue(forKey: id)
    }
    
    private func notifyObservers(_ type: PermissionType, _ status: UnifiedPermissionStatus) {
        stateObservers.values.forEach { observer in
            observer(type, status)
        }
    }
    
    // MARK: - Convenience Properties
    
    public func status(for type: PermissionType) -> UnifiedPermissionStatus {
        switch type {
        case .camera: return cameraStatus
        case .microphone: return microphoneStatus
        case .health: return healthStatus
        }
    }
    
    public func isAuthorized(for type: PermissionType) -> Bool {
        status(for: type).isUsable
    }
    
    public func canRequest(for type: PermissionType) -> Bool {
        status(for: type).canRequest
    }
    
    public func needsSettings(for type: PermissionType) -> Bool {
        status(for: type).needsSettings
    }
}