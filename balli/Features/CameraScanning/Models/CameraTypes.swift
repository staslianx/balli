//
//  CameraTypes.swift
//  balli
//
//  Camera-related types, states, errors, and events
//

import Foundation
import AVFoundation
import UIKit

// MARK: - Camera State
public enum CameraState: String, Codable, Equatable, Sendable {
    case uninitialized
    case preparingSession
    case ready
    case capturingPhoto
    case processingCapture
    case interrupted
    case failed
    case backgrounded
    case thermallyThrottled
    case permissionDenied
    
    /// Whether the camera can start capture operations in this state
    var canCapture: Bool {
        switch self {
        case .ready:
            return true
        default:
            return false
        }
    }
    
    /// Whether the camera session should be running in this state
    var shouldRunSession: Bool {
        switch self {
        case .ready, .capturingPhoto, .processingCapture:
            return true
        default:
            return false
        }
    }
}

// MARK: - Camera Error
public enum CameraError: LocalizedError, Equatable {
    case sessionConfigurationFailed
    case deviceNotAvailable
    case captureDeviceLocked
    case systemPressure(level: String)
    case thermalStateExceeded
    case interrupted(reason: String)
    case failedToCapture(description: String)
    case backgrounded
    case permissionDenied
    case invalidStateTransition(from: CameraState, to: CameraState)
    case timeout(operation: String)
    case continuationLeak
    
    public var errorDescription: String? {
        switch self {
        case .sessionConfigurationFailed:
            return "Kamera yapılandırması başarısız oldu"
        case .deviceNotAvailable:
            return "Kamera kullanılamıyor"
        case .captureDeviceLocked:
            return "Kamera cihazı kilitli"
        case .systemPressure(let level):
            return "Sistem baskı altında: \(level)"
        case .thermalStateExceeded:
            return "Cihaz kamera kullanmak için çok sıcak"
        case .interrupted(let reason):
            return "Kamera kesintiye uğradı: \(reason)"
        case .failedToCapture(let description):
            return "Çekim başarısız: \(description)"
        case .backgrounded:
            return "Kamera arka planda kullanılamaz"
        case .permissionDenied:
            return "Kamera izni reddedildi"
        case .invalidStateTransition(let from, let to):
            return "Geçersiz durum geçişi: \(from.rawValue) → \(to.rawValue)"
        case .timeout(let operation):
            return "İşlem zaman aşımı: \(operation)"
        case .continuationLeak:
            return "Bellek sızıntısı tespit edildi"
        }
    }
}

// MARK: - Camera Events
public enum CameraEvent {
    case startSession
    case stopSession
    case capturePhoto
    case handleInterruption(reason: AVCaptureSession.InterruptionReason)
    case handleInterruptionEnded
    case enterBackground
    case enterForeground
    case systemPressureChanged(AVCaptureDevice.SystemPressureState)
    case thermalStateChanged(ProcessInfo.ThermalState)
    case permissionChanged(AVAuthorizationStatus)
    case deviceChanged(AVCaptureDevice?)
    case zoomLevelChanged(CameraZoom)
}

// MARK: - Camera Zoom
public enum CameraZoom: String, CaseIterable, Codable, Sendable {
    case halfX = "0.5x"
    case oneX = "1x"
    case twoX = "2x"
    case threeX = "3x"
    
    /// The zoom factor for this zoom level
    var zoomFactor: CGFloat {
        switch self {
        case .halfX: return 0.5
        case .oneX: return 1.0
        case .twoX: return 2.0
        case .threeX: return 3.0
        }
    }
    
    /// The next zoom level in the cycle
    var next: CameraZoom {
        let allCases = Self.allCases
        guard let currentIndex = allCases.firstIndex(of: self) else { return .oneX }
        let nextIndex = (currentIndex + 1) % allCases.count
        return allCases[nextIndex]
    }
}

// MARK: - State Persistence
public struct CameraStateData: Codable, Sendable {
    let state: CameraState
    let timestamp: Date
    let sessionID: UUID
    let lastError: String?
    
    /// Check if this state data is recent (within 5 minutes)
    var isRecent: Bool {
        Date().timeIntervalSince(timestamp) < 300
    }
}

// MARK: - State Transition
public struct StateTransition: Sendable {
    let from: CameraState
    let to: CameraState
    let timestamp: Date
    let reason: String?
    
    init(from: CameraState, to: CameraState, reason: String? = nil) {
        self.from = from
        self.to = to
        self.timestamp = Date()
        self.reason = reason
    }
}

// MARK: - Camera Configuration
public struct CameraConfiguration: Sendable {
    let hasUltraWide: Bool
    let hasWide: Bool
    let hasTelephoto: Bool
    let telephotoZoomFactor: CGFloat
    let supportedZoomLevels: [CameraZoom]
    let defaultCamera: AVCaptureDevice.DeviceType
    
    /// Get available zoom levels based on device capabilities
    static func availableZoomLevels(hasUltraWide: Bool, hasTelephoto: Bool, telephotoZoom: CGFloat) -> [CameraZoom] {
        var levels: [CameraZoom] = [.oneX] // Always have 1x
        
        if hasUltraWide {
            levels.insert(.halfX, at: 0)
        }
        
        if hasTelephoto {
            if telephotoZoom >= 3.0 {
                levels.append(.threeX)
            } else {
                levels.append(.twoX)
            }
        }
        
        return levels
    }
}

// MARK: - Capture Result
public struct CaptureResult: Sendable {
    let image: UIImage
    let metadata: CaptureMetadata
    let timestamp: Date
}

// MARK: - Capture Metadata
public struct CaptureMetadata: Sendable {
    let deviceType: AVCaptureDevice.DeviceType
    let zoomFactor: CGFloat
    let exposureDuration: CMTime?
    let iso: Float?
    let flashMode: AVCaptureDevice.FlashMode
}

// MARK: - Observer Management
public struct ObserverToken: Hashable {
    let id: UUID
    let type: ObserverType
    
    enum ObserverType {
        case state
        case error
        case capture
    }
}

// MARK: - System Monitoring
public struct SystemStatus {
    let thermalState: ProcessInfo.ThermalState
    let systemPressureLevel: AVCaptureDevice.SystemPressureState.Level?
    let availableMemory: Int64
    let batteryLevel: Float
    let isLowPowerModeEnabled: Bool
    
    /// Whether the system is under stress
    var isUnderStress: Bool {
        if thermalState == .critical || thermalState == .serious {
            return true
        }
        
        if let pressure = systemPressureLevel,
           pressure == .critical || pressure == .shutdown {
            return true
        }
        
        if availableMemory < 100_000_000 { // Less than 100MB
            return true
        }
        
        return false
    }
}

// MARK: - Performance Metrics
public struct CameraPerformanceMetrics: Sendable {
    let sessionPreparationTime: TimeInterval
    let captureLatency: TimeInterval
    let previewStartTime: TimeInterval
    let memoryUsage: Int64
    let cpuUsage: Double
    
    static let targets = PerformanceTargets(
        maxSessionPreparation: 0.8,
        maxCaptureLatency: 0.1,
        maxPreviewStart: 0.5,
        maxMemoryUsage: 50_000_000, // 50MB
        maxCPUUsage: 0.20 // 20%
    )
    
    struct PerformanceTargets: Sendable {
        let maxSessionPreparation: TimeInterval
        let maxCaptureLatency: TimeInterval
        let maxPreviewStart: TimeInterval
        let maxMemoryUsage: Int64
        let maxCPUUsage: Double
    }
}