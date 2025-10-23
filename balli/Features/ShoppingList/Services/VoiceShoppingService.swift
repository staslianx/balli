//
//  VoiceShoppingService.swift
//  balli
//
//  Service for voice-based shopping list management
//

import Foundation
import AVFoundation
import UIKit
import os.log

/// Parsed shopping item from voice input
public struct ParsedShoppingItem: Sendable {
    public let name: String
    public let quantity: String?
    public let unit: String?
    public let suggestion: String?
    
    public init(name: String, quantity: String? = nil, unit: String? = nil, suggestion: String? = nil) {
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.suggestion = suggestion
    }
}

/// Service for voice-based shopping list input
@MainActor
public final class VoiceShoppingService: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public var isRecording = false
    @Published public var isProcessing = false
    @Published public var parsedItems: [ParsedShoppingItem] = []
    @Published public var error: VoiceShoppingError?
    @Published public var audioLevel: Float = 0
    
    // MARK: - Private Properties
    
    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?
    // Note: AI service disabled pending new implementation
    // private let aiService: AIService
    private let aiService: Any? = nil  // Placeholder
    private let logger = os.Logger(subsystem: "com.balli.diabetes", category: "VoiceShopping")
    private var audioLevelTimer: Timer?
    
    // MARK: - Initialization

    public override init() {
        // Note: AI service initialization disabled pending new implementation
        // let firestoreService = FirestoreService()
        // let authService = AuthenticationService()
        // let healthKitService = HealthKitService()
        //
        // self.aiService = AIService(
        //     firestoreService: firestoreService,
        //     authService: authService,
        //     healthKitService: healthKitService
        // )

        // aiService already initialized above

        super.init()
        // Audio session setup moved to startRecording() after permission check
    }
    
    // MARK: - Audio Setup

    private func setupAudioSession() {
        // Check permission first (consistent across iOS versions)
        let hasPermission: Bool
        if #available(iOS 17.0, *) {
            hasPermission = AVAudioApplication.shared.recordPermission == .granted
        } else {
            hasPermission = AVAudioSession.sharedInstance().recordPermission == .granted
        }

        guard hasPermission else {
            logger.warning("Cannot setup audio session - no microphone permission")
            return
        }

        let audioSession = AVAudioSession.sharedInstance()

        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            logger.info("Audio session configured successfully")
        } catch {
            logger.error("Failed to setup audio session: \(error)")
        }
    }
    
    // MARK: - Recording Methods
    
    /// Start recording audio
    public func startRecording() async throws {
        // Check microphone permission first (consistent across iOS versions)
        let hasPermission: Bool
        if #available(iOS 17.0, *) {
            hasPermission = AVAudioApplication.shared.recordPermission == .granted
        } else {
            hasPermission = AVAudioSession.sharedInstance().recordPermission == .granted
        }

        if !hasPermission {
            throw VoiceShoppingError.microphonePermissionDenied
        }

        // Re-setup audio session in case it's the first time after permission
        setupAudioSession()

        // Small delay to let audio session settle (async, non-blocking)
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1s

        // Create temporary file for recording
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        recordingURL = documentsPath.appendingPathComponent("shopping_voice_\(UUID().uuidString).m4a")

        guard let recordingURL = recordingURL else {
            throw VoiceShoppingError.recordingSetupFailed
        }

        // Configure recorder settings for optimal quality
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        audioRecorder = try AVAudioRecorder(url: recordingURL, settings: settings)
        audioRecorder?.delegate = self
        audioRecorder?.isMeteringEnabled = true
        audioRecorder?.prepareToRecord()

        // Try to start recording with retry logic
        if audioRecorder?.record() != true {
            // Retry once after delay (async, non-blocking)
            try await Task.sleep(nanoseconds: 200_000_000) // 0.2s
            setupAudioSession()
            if audioRecorder?.record() != true {
                throw VoiceShoppingError.recordingSetupFailed
            }
        }

        isRecording = true
        error = nil

        // Start audio level monitoring
        startAudioLevelMonitoring()

        logger.info("Started recording shopping list voice input")
    }
    
    /// Stop recording and process audio
    public func stopRecording() async {
        guard isRecording else { return }
        
        audioRecorder?.stop()
        audioRecorder = nil
        isRecording = false
        
        // Stop audio level monitoring
        stopAudioLevelMonitoring()
        
        logger.info("Stopped recording")
        
        // Process the audio
        if let recordingURL = recordingURL {
            await processAudio(audioURL: recordingURL)
        }
    }
    
    // MARK: - Audio Level Monitoring
    
    private func startAudioLevelMonitoring() {
        audioLevelTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateAudioLevel()
            }
        }
    }
    
    private func stopAudioLevelMonitoring() {
        audioLevelTimer?.invalidate()
        audioLevelTimer = nil
        audioLevel = 0
    }
    
    private func updateAudioLevel() {
        audioRecorder?.updateMeters()
        let level = audioRecorder?.averagePower(forChannel: 0) ?? -160
        // Normalize to 0-1 range
        audioLevel = max(0, min(1, (level + 60) / 60))
    }
    
    // MARK: - Audio Processing
    
    private func processAudio(audioURL: URL) async {
        isProcessing = true
        parsedItems = []
        
        do {
            // Read audio file
            _ = try Data(contentsOf: audioURL)

            // Create prompt for AI processing
            _ = """
            Ses kaydındaki alışveriş listesini analiz et ve JSON formatında döndür.
            
            Kullanıcı şöyle konuşabilir: "2 domates 3 salatalık 4 yumurta 1 kalıp beyaz peynir 200 gram zeytin"
            
            Her ürün için:
            1. Ürün adını tespit et
            2. Miktarı tespit et (varsa)
            3. Birimi tespit et (adet, kilo, gram, litre, paket, kalıp vb.)
            4. Eğer ürün diyabet hastaları için uygun değilse, alternatif öneri ekle
            
            Diyabet için uygun olmayan ürünler ve alternatifleri:
            - Beyaz ekmek → Tam buğday ekmeği
            - Normal makarna → Tam buğday makarna
            - Beyaz pirinç → Esmer pirinç
            - Şeker → Stevia veya eritritol
            - Normal süt → Badem sütü (daha düşük karbonhidrat)
            - Meyve suyu → Taze meyve
            - Beyaz un → Tam buğday unu
            - Patates → Karnabahar
            - Mısır gevreği → Yulaf ezmesi
            
            JSON formatı:
            {
                "items": [
                    {
                        "name": "Domates",
                        "quantity": "2",
                        "unit": "adet",
                        "suggestion": null
                    },
                    {
                        "name": "Beyaz Ekmek",
                        "quantity": "1",
                        "unit": "adet",
                        "suggestion": "balli'den öneri: Tam buğday ekmeği"
                    }
                ]
            }
            
            SADECE JSON döndür, başka açıklama ekleme.
            """

            // Note: AI service disabled - return empty response as placeholder
            // let response = try await aiService.processAudioWithPrompt(
            //     audioData: audioData,
            //     mimeType: "audio/mp4",
            //     prompt: prompt
            // )
            let response = "[]" // Return empty array as placeholder
            
            // Parse JSON response
            let parsedData = try parseAIResponse(response)
            self.parsedItems = parsedData
            
            logger.info("Successfully parsed \(parsedData.count) items from voice input")
            
        } catch {
            logger.error("Failed to process audio: \(error)")
            // Provide user-friendly error message instead of technical details
            let userMessage = "Ses kayıt servisine şu anda ulaşılamıyor. Lütfen daha sonra tekrar deneyin veya manuel olarak girin."
            self.error = .processingFailed(userMessage)
            // Don't populate with mock data - leave parsedItems empty
            self.parsedItems = []
        }
        
        isProcessing = false
        
        // Clean up recording file
        try? FileManager.default.removeItem(at: audioURL)
        recordingURL = nil
    }
    
    private func parseAIResponse(_ response: String) throws -> [ParsedShoppingItem] {
        // Clean response to get JSON
        let cleanedResponse = response
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let data = cleanedResponse.data(using: .utf8) else {
            throw VoiceShoppingError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        let result = try decoder.decode(AIShoppingResponse.self, from: data)
        
        return result.items.map { item in
            ParsedShoppingItem(
                name: item.name,
                quantity: item.quantity,
                unit: item.unit,
                suggestion: item.suggestion
            )
        }
    }
}

// MARK: - AVAudioRecorderDelegate

extension VoiceShoppingService: AVAudioRecorderDelegate {
    nonisolated public func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            Task { @MainActor in
                logger.error("Recording failed")
                error = .recordingFailed
            }
        }
    }
}

// MARK: - Response Models

private struct AIShoppingResponse: Decodable {
    let items: [AIShoppingItem]
}

private struct AIShoppingItem: Decodable {
    let name: String
    let quantity: String?
    let unit: String?
    let suggestion: String?
}

// MARK: - Error Types

public enum VoiceShoppingError: LocalizedError {
    case microphonePermissionDenied
    case recordingSetupFailed
    case recordingFailed
    case processingFailed(String)
    case invalidResponse
    
    public var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return "Mikrofon erişim izni verilmedi. Ayarlar'dan izin verebilirsiniz."
        case .recordingSetupFailed:
            return "Ses kaydı başlatılamadı. Lütfen tekrar deneyin."
        case .recordingFailed:
            return "Ses kaydı tamamlanamadı. Lütfen tekrar deneyin."
        case .processingFailed(let message):
            return message  // Already user-friendly from above
        case .invalidResponse:
            return "Ses tanıma servisi beklenmedik bir yanıt verdi. Lütfen tekrar deneyin."
        }
    }
}