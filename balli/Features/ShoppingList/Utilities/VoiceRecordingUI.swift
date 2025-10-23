//
//  VoiceRecordingUI.swift
//  balli
//
//  UI-related types and state management for voice recording
//  Contains models, enums, and UI state structures
//

import Foundation

// MARK: - Voice Recording Result Models

public struct VoiceRecordingResult: Sendable {
    let audioData: Data
    let duration: TimeInterval
    let parsedItems: [ShoppingItemParsed]
}

public struct ShoppingItemParsed: Sendable, Identifiable {
    public let id = UUID()
    let name: String
    let quantity: String?
    let category: String
    let confidence: Double
}

// MARK: - Voice Recording Errors

public enum VoiceRecordingError: Error, Sendable {
    case permissionDenied
    case microphoneNotAvailable
    case recordingFailed(String)
    case processingFailed(String)
    case audioTooShort
    case audioTooLong
    case invalidAudioFormat
}

// MARK: - Voice Recording State

public enum VoiceRecordingState: Sendable {
    case idle
    case recording(duration: TimeInterval)
}

// MARK: - Recording Session Information

public struct RecordingSession: Sendable, Identifiable {
    public let id = UUID()
    let startTime: Date
    let endTime: Date?
    let duration: TimeInterval
    let status: RecordingStatus
    let fileSize: Int64?
    let transcriptionLength: Int?
    let itemCount: Int?
    
    public enum RecordingStatus: Sendable, Equatable {
        case recording
        case completed
        case failed(String)
        case cancelled
        
        public static func == (lhs: RecordingStatus, rhs: RecordingStatus) -> Bool {
            switch (lhs, rhs) {
            case (.recording, .recording), (.completed, .completed), (.cancelled, .cancelled):
                return true
            case (.failed(let lhsMessage), .failed(let rhsMessage)):
                return lhsMessage == rhsMessage
            default:
                return false
            }
        }
    }
}

// MARK: - Voice Recording Configuration

public struct VoiceRecordingConfiguration: Sendable {
    let maxRecordingDuration: TimeInterval
    let minRecordingDuration: TimeInterval
    let sampleRate: Double
    let enableAutoStop: Bool
    let enableNoiseReduction: Bool
    let confidenceThreshold: Double
    
    public static let standard = VoiceRecordingConfiguration(
        maxRecordingDuration: 60.0,
        minRecordingDuration: 1.0,
        sampleRate: 16000,
        enableAutoStop: true,
        enableNoiseReduction: false,
        confidenceThreshold: 0.7
    )
    
    public static let extended = VoiceRecordingConfiguration(
        maxRecordingDuration: 120.0,
        minRecordingDuration: 0.5,
        sampleRate: 22050,
        enableAutoStop: true,
        enableNoiseReduction: true,
        confidenceThreshold: 0.6
    )
}

// MARK: - Recording Analytics

public struct RecordingAnalytics: Sendable {
    let sessionId: UUID
    let startTimestamp: Date
    let endTimestamp: Date?
    let duration: TimeInterval
    let audioQuality: AudioQuality
    let transcriptionAccuracy: Double?
    let processingTime: TimeInterval?
    let errorCount: Int
    let successfulItemParsing: Int
    
    public enum AudioQuality: Sendable {
        case excellent
        case good
        case fair
        case poor
        case unknown
    }
}

// MARK: - Shopping List Categories

public enum ShoppingCategory: String, CaseIterable, Sendable {
    case meyve_sebze = "meyve_sebze"
    case et_tavuk_balık = "et_tavuk_balık"
    case süt_ürünleri = "süt_ürünleri"
    case ekmek = "ekmek"
    case konserve = "konserve"
    case bakliyat = "bakliyat"
    case yağ = "yağ"
    case atıştırmalık = "atıştırmalık"
    case içecek = "içecek"
    case temizlik = "temizlik"
    case protein = "protein"
    case genel = "genel"
    
    public var displayName: String {
        switch self {
        case .meyve_sebze: return "Meyve & Sebze"
        case .et_tavuk_balık: return "Et, Tavuk & Balık"
        case .süt_ürünleri: return "Süt Ürünleri"
        case .ekmek: return "Ekmek"
        case .konserve: return "Konserve"
        case .bakliyat: return "Bakliyat"
        case .yağ: return "Yağ"
        case .atıştırmalık: return "Atıştırmalık"
        case .içecek: return "İçecek"
        case .temizlik: return "Temizlik"
        case .protein: return "Protein"
        case .genel: return "Genel"
        }
    }
    
    public var systemColor: String {
        switch self {
        case .meyve_sebze: return "green"
        case .et_tavuk_balık: return "red"
        case .süt_ürünleri: return "blue"
        case .ekmek: return "orange"
        case .konserve: return "purple"
        case .bakliyat: return "brown"
        case .yağ: return "yellow"
        case .atıştırmalık: return "pink"
        case .içecek: return "cyan"
        case .temizlik: return "gray"
        case .protein: return "indigo"
        case .genel: return "black"
        }
    }
}

// MARK: - Voice Recording Delegate Protocol

@MainActor
public protocol VoiceRecordingDelegate: AnyObject {
    func voiceRecordingDidStart()
    func voiceRecordingDidStop(with result: VoiceRecordingResult?)
    func voiceRecordingDidFail(with error: VoiceRecordingError)
    func voiceRecordingDidUpdateDuration(_ duration: TimeInterval)
    func voiceRecordingDidUpdateState(_ state: VoiceRecordingState)
}

// MARK: - Audio Permissions Status

public enum AudioPermissionStatus: Sendable {
    case notDetermined
    case granted
    case denied
    case restricted
    
    public var isAuthorized: Bool {
        return self == .granted
    }
    
    public var requiresAction: Bool {
        switch self {
        case .notDetermined:
            return true
        case .denied, .restricted:
            return true
        case .granted:
            return false
        }
    }
}