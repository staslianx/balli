//
//  CaptureSession.swift
//  balli
//
//  Model for tracking camera capture sessions and their state
//

import Foundation
import UIKit

// MARK: - Capture Flow State
public enum CaptureFlowState: String, Codable, Sendable {
    case idle
    case capturing
    case captured
    case optimizing
    case processingAI
    case waitingForNetwork
    case completed
    case failed
    case cancelled
}

// MARK: - Capture Session
public struct CaptureSession: Codable, Identifiable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public var state: CaptureFlowState
    public var imageData: Data?
    public var thumbnailData: Data?
    public var optimizedImageData: Data?
    public var aiResponse: String?
    public var error: String?
    public var retryCount: Int
    public var processingStartTime: Date?
    public var processingEndTime: Date?
    
    // Additional metadata
    public var imageSize: CGSize?
    public var captureZoomLevel: String?
    public var deviceModel: String
    public var iosVersion: String
    
    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        state: CaptureFlowState = .idle,
        imageData: Data? = nil,
        thumbnailData: Data? = nil,
        optimizedImageData: Data? = nil,
        aiResponse: String? = nil,
        error: String? = nil,
        retryCount: Int = 0,
        processingStartTime: Date? = nil,
        processingEndTime: Date? = nil,
        imageSize: CGSize? = nil,
        captureZoomLevel: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.state = state
        self.imageData = imageData
        self.thumbnailData = thumbnailData
        self.optimizedImageData = optimizedImageData
        self.aiResponse = aiResponse
        self.error = error
        self.retryCount = retryCount
        self.processingStartTime = processingStartTime
        self.processingEndTime = processingEndTime
        self.imageSize = imageSize
        self.captureZoomLevel = captureZoomLevel
        
        // System info - will be set from UI thread
        self.deviceModel = ""
        self.iosVersion = ""
    }
    
    public var isActive: Bool {
        switch state {
        case .idle, .completed, .failed, .cancelled:
            return false
        default:
            return true
        }
    }
    
    public var canRetry: Bool {
        state == .failed && retryCount < 3
    }
    
    public var processingDuration: TimeInterval? {
        guard let start = processingStartTime,
              let end = processingEndTime else { return nil }
        return end.timeIntervalSince(start)
    }
    
    public var isExpired: Bool {
        // Sessions older than 24 hours are considered expired
        Date().timeIntervalSince(timestamp) > 86400
    }
    
    public var progress: Double {
        switch state {
        case .idle: return 0.0
        case .capturing: return 0.1
        case .captured: return 0.3
        case .optimizing: return 0.5
        case .processingAI: return 0.7
        case .waitingForNetwork: return 0.8
        case .completed: return 1.0
        case .failed, .cancelled: return 0.0
        }
    }
}

// MARK: - Capture Error
public enum CaptureError: LocalizedError, Sendable, Equatable {
    case imageConversionFailed
    case optimizationFailed
    case aiProcessingFailed(String)
    case processingFailed(String)
    case networkUnavailable
    case sessionExpired
    case maxRetriesExceeded
    case cancelled
    case rateLimitExceeded
    case unknownError(String)
    
    public var errorDescription: String? {
        switch self {
        case .imageConversionFailed:
            return "Fotoğraf işlenirken hata oluştu"
        case .optimizationFailed:
            return "Görüntü optimize edilemedi"
        case .aiProcessingFailed(let message):
            return "AI işleme hatası: \(message)"
        case .processingFailed(let message):
            return "İşleme hatası: \(message)"
        case .networkUnavailable:
            return "İnternet bağlantısı yok"
        case .sessionExpired:
            return "Oturum zaman aşımına uğradı"
        case .maxRetriesExceeded:
            return "Maksimum deneme sayısına ulaşıldı"
        case .cancelled:
            return "İşlem iptal edildi"
        case .rateLimitExceeded:
            return "Günlük tarama limiti aşıldı. Lütfen daha sonra tekrar deneyin."
        case .unknownError(let message):
            return "Bilinmeyen hata: \(message)"
        }
    }
}

// MARK: - Session Storage Keys
public struct CaptureSessionKeys {
    public static let activeSessionKey = "com.balli.capture.activeSession"
    public static let sessionHistoryKey = "com.balli.capture.sessionHistory"
    public static let maxHistoryCount = 10
}