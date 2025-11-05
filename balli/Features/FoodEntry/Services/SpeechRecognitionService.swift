//
//  SpeechRecognitionService.swift
//  balli
//
//  Real-time speech recognition using Apple's Speech framework
//  Provides word-by-word transcription for immediate user feedback
//

import Foundation
@preconcurrency import Speech
import AVFoundation
import Combine
import os.log
import os

// MARK: - Speech Recognition Service

/// Constants shared across speech recognition components
fileprivate enum SpeechRecognitionConstants {
    static let recognitionCancellationDelayNanoseconds: UInt64 = 100_000_000  // 0.1 seconds
    static let audioSetupTimeoutNanoseconds: UInt64 = 5_000_000_000           // 5 seconds
}

/// Main actor-isolated service for speech recognition
/// All UI-related state is safely accessed on the main actor
@MainActor
class SpeechRecognitionService: NSObject, ObservableObject {

    // Logger must be nonisolated since it's used in delegate methods
    nonisolated private let logger = os.Logger(subsystem: "com.balli.diabetes", category: "SpeechRecognition")

    // Speech recognition components - accessed only through actor-isolated methods
    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?

    // State management to prevent concurrent operations
    private var isStartingRecognition = false
    private var isStoppingRecognition = false

    // Audio engine wrapper for thread-safe access
    // AVAudioEngine is not Sendable, so we wrap it in an @unchecked Sendable class
    private let audioEngineWrapper: AudioEngineWrapper

    // Published state - all @Published properties are main-actor isolated by default
    @Published var transcribedText = ""
    @Published var isRecognizing = false
    @Published var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    @Published var microphonePermissionGranted = false
    @Published var error: SpeechRecognitionError?
    @Published var audioLevel: Float = 0.0 // 0.0 to 1.0 for glow visualization

    // Configuration
    private let locale = Locale(identifier: "tr-TR") // Turkish locale

    override init() {
        // Minimal initialization - defer heavy work to async methods
        // This prevents blocking @StateObject initialization

        // Initialize recognizer on background thread result
        var recognizer: SFSpeechRecognizer?
        if let turkishRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "tr-TR")) {
            recognizer = turkishRecognizer
        } else {
            recognizer = SFSpeechRecognizer()
        }
        self.speechRecognizer = recognizer

        // Initialize audio engine wrapper
        self.audioEngineWrapper = AudioEngineWrapper()

        super.init()

        // Lightweight checks only - no delegates or async work
        if speechRecognizer == nil {
            logger.error("❌ Failed to initialize speech recognizer")
        }

        logger.info("✅ SpeechRecognitionService init complete (lightweight)")
    }

    /// Complete initialization asynchronously - call this from .task {} modifier
    func completeInitialization() async {
        // Set up delegate on main actor
        speechRecognizer?.delegate = self

        // Check authorization status
        let currentStatus = SFSpeechRecognizer.authorizationStatus()
        authorizationStatus = currentStatus

        if speechRecognizer == nil {
            error = .recognizerNotAvailable
        }

        logger.info("✅ SpeechRecognitionService fully initialized - auth: \(String(describing: currentStatus))")
    }

    // MARK: - Authorization

    func checkAuthorizationStatus() {
        let status = SFSpeechRecognizer.authorizationStatus()
        authorizationStatus = status
        logger.info("Current speech recognition authorization status: \(String(describing: status))")

        switch status {
        case .authorized:
            logger.info("✅ Speech recognition authorized")
            error = nil
        case .denied:
            error = .authorizationDenied
        case .restricted:
            error = .restricted
        case .notDetermined:
            logger.info("⚠️ Speech recognition authorization not yet determined")
        @unknown default:
            error = .unknown
        }
    }

    func requestAuthorization() async {
        // First check if already authorized
        let currentStatus = SFSpeechRecognizer.authorizationStatus()
        if currentStatus == .authorized {
            await MainActor.run {
                authorizationStatus = .authorized
                error = nil
                logger.info("✅ Already authorized, skipping request")
            }
            return
        }

        // Only request if not already determined
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { [weak self] status in
                Task { @MainActor in
                    self?.authorizationStatus = status
                    self?.logger.info("Speech recognition authorization status after request: \(String(describing: status))")

                    switch status {
                    case .authorized:
                        self?.logger.info("✅ Speech recognition authorized")
                        self?.error = nil
                    case .denied:
                        self?.error = .authorizationDenied
                    case .restricted:
                        self?.error = .restricted
                    case .notDetermined:
                        self?.error = .notDetermined
                    @unknown default:
                        self?.error = .unknown
                    }

                    continuation.resume()
                }
            }
        }
    }

    // MARK: - Microphone Permission

    func checkMicrophonePermission() {
        let status = AVAudioApplication.shared.recordPermission
        microphonePermissionGranted = (status == .granted)
        logger.info("Microphone permission status: \(String(describing: status))")

        if status == .denied {
            error = .microphonePermissionDenied
        }
    }

    func requestMicrophonePermission() async {
        let status = AVAudioApplication.shared.recordPermission

        if status == .granted {
            await MainActor.run {
                microphonePermissionGranted = true
                logger.info("✅ Microphone already authorized")
            }
            return
        }

        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission(completionHandler: { [weak self] granted in
                Task { @MainActor in
                    self?.microphonePermissionGranted = granted
                    self?.logger.info("Microphone permission: \(granted ? "✅ granted" : "❌ denied")")

                    if !granted {
                        self?.error = .microphonePermissionDenied
                    }

                    continuation.resume()
                }
            })
        }
    }

    // MARK: - Recording Control

    func startRecording() async throws {
        logger.info("🎤 startRecording() called")

        // Prevent concurrent start operations
        guard !isStartingRecognition else {
            logger.warning("⚠️ Already starting recognition, ignoring duplicate request")
            return
        }

        isStartingRecognition = true
        defer { isStartingRecognition = false }

        // Check authorization on main actor
        guard authorizationStatus == .authorized else {
            logger.error("❌ Speech recognition not authorized")
            throw SpeechRecognitionError.authorizationDenied
        }

        guard microphonePermissionGranted else {
            logger.error("❌ Microphone permission not granted")
            throw SpeechRecognitionError.microphonePermissionDenied
        }

        guard let speechRecognizer = speechRecognizer,
              speechRecognizer.isAvailable else {
            logger.error("❌ Speech recognizer not available")
            throw SpeechRecognitionError.recognizerNotAvailable
        }

        // Properly clean up any ongoing task with synchronization
        if let existingTask = recognitionTask {
            logger.info("🔄 Cancelling existing recognition task")
            existingTask.cancel()
            recognitionTask = nil

            // Wait a moment for cancellation to complete
            try await Task.sleep(nanoseconds: SpeechRecognitionConstants.recognitionCancellationDelayNanoseconds)
        }

        // Update UI state immediately to show we're starting
        isRecognizing = true
        transcribedText = ""
        error = nil // Clear any previous errors
        logger.info("✅ UI updated - isRecognizing = true")

        // Create recognition request BEFORE audio session to avoid delays
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()

        guard let recognitionRequest = recognitionRequest else {
            isRecognizing = false
            throw SpeechRecognitionError.requestCreationFailed
        }

        recognitionRequest.shouldReportPartialResults = true // Real-time updates
        recognitionRequest.requiresOnDeviceRecognition = false // Use server for better accuracy

        // Configure audio session and engine WITHOUT blocking main actor
        // This runs entirely on background thread, with audio level updates
        try await audioEngineWrapper.startAudio(request: recognitionRequest) { [weak self] level in
            self?.audioLevel = level
        }

        logger.info("✅ Audio session configured")

        // Start recognition task - the callback runs on Speech framework's queue
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            // This closure runs on background dispatch queue from Speech framework
            guard let self = self else { return }

            // Dispatch to main actor for UI updates - proper isolation
            Task { @MainActor in
                // If we're already stopped, ignore this callback to prevent double-cleanup
                guard self.isRecognizing else {
                    self.logger.debug("Received recognition callback but already stopped - ignoring")
                    return
                }

                var isFinal = false

                if let result = result {
                    // Update transcribed text with the latest result
                    self.transcribedText = result.bestTranscription.formattedString
                    isFinal = result.isFinal

                    // Log confidence if available
                    if let segment = result.bestTranscription.segments.last {
                        let confidence = segment.confidence
                        self.logger.debug("Segment: \(segment.substring), Confidence: \(confidence)")
                    }
                }

                // Only stop if we received an error or final result AND we're still recognizing
                if (error != nil || isFinal) && self.isRecognizing {
                    self.stopRecording()

                    if let error = error {
                        self.logger.error("Recognition error: \(error.localizedDescription)")
                        // Only set error if it's not a cancellation (cancellation is expected when user stops)
                        let nsError = error as NSError
                        if nsError.domain != "kAFAssistantErrorDomain" || nsError.code != 203 {
                            self.error = .recognitionFailed(error.localizedDescription)
                        }
                    }
                }
            }
        }

        logger.info("🎤 Started speech recognition - ready to receive audio")
    }

    func stopRecording() {
        // Guard against multiple calls
        guard isRecognizing else {
            logger.debug("stopRecording called but not recognizing - skipping")
            return
        }

        // Prevent concurrent stop operations
        guard !isStoppingRecognition else {
            logger.warning("⚠️ Already stopping recognition, ignoring duplicate request")
            return
        }

        isStoppingRecognition = true
        defer { isStoppingRecognition = false }

        // Mark as not recognizing FIRST to prevent re-entry
        isRecognizing = false
        audioLevel = 0.0 // Reset audio level

        logger.info("🛑 Stopping speech recognition. Final text: \(self.transcribedText)")

        // Stop audio engine WITHOUT blocking main actor
        audioEngineWrapper.stopAudio()

        // Clean up recognition request
        if let request = recognitionRequest {
            request.endAudio()
            recognitionRequest = nil
        }

        // Cancel recognition task
        if let task = recognitionTask {
            task.cancel()
            recognitionTask = nil
        }

        logger.info("✅ Speech recognition stopped cleanly")
    }

    // MARK: - Cleanup

    func cleanup() {
        stopRecording()
    }

}

// MARK: - Speech Recognizer Delegate

extension SpeechRecognitionService: SFSpeechRecognizerDelegate {
    nonisolated func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        Task { @MainActor in
            if !available {
                logger.warning("⚠️ Speech recognizer became unavailable")
                error = .recognizerNotAvailable
                if isRecognizing {
                    stopRecording()
                }
            } else {
                logger.info("✅ Speech recognizer is available")
            }
        }
    }
}

// MARK: - Audio Engine Wrapper

/// Thread-safe wrapper for AVAudioEngine to prevent main actor blocking
/// AVAudioEngine is not Sendable, but we control all access through a serial queue
final class AudioEngineWrapper: @unchecked Sendable {
    private let audioEngine = AVAudioEngine()
    private let audioQueue = DispatchQueue(label: "com.balli.speech.audio", qos: .userInitiated)
    private let logger = os.Logger(subsystem: "com.balli.diabetes", category: "AudioEngine")

    /// Thread-safe state tracking for continuation management
    private let lock = OSAllocatedUnfairLock()
    private var _hasResumed = false

    /// Thread-safe access to hasResumed flag
    private var hasResumed: Bool {
        get { lock.withLock { _hasResumed } }
        set { lock.withLock { _hasResumed = newValue } }
    }

    /// Start audio engine and configure audio session on background thread with timeout protection
    /// - Parameters:
    ///   - request: The speech recognition request to send audio buffers to
    ///   - levelUpdate: Closure called with audio level (0.0 to 1.0) on main actor
    func startAudio(request: SFSpeechAudioBufferRecognitionRequest, levelUpdate: @escaping @MainActor (Float) -> Void) async throws {
        // Add timeout protection to prevent infinite hangs
        try await withThrowingTaskGroup(of: Void.self) { group in
            // Add timeout task
            group.addTask {
                try await Task.sleep(nanoseconds: SpeechRecognitionConstants.audioSetupTimeoutNanoseconds)
                throw SpeechRecognitionError.audioEngineTimeout
            }

            // Add main audio setup task
            group.addTask { [weak self] in
                guard let self = self else {
                    throw SpeechRecognitionError.unknown
                }

                try await self.performAudioSetup(request: request, levelUpdate: levelUpdate)
            }

            // Wait for first task to complete (either success or timeout)
            try await group.next()
            group.cancelAll() // Cancel remaining task
        }
    }

    /// Perform the actual audio setup with guaranteed continuation resolution
    private func performAudioSetup(request: SFSpeechAudioBufferRecognitionRequest, levelUpdate: @escaping @MainActor (Float) -> Void) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            audioQueue.async { [weak self] in
                guard let self = self else {
                    // Note: If self is deallocated, hasResumed state is irrelevant
                    // The continuation MUST be resumed to prevent hang
                    continuation.resume(throwing: SpeechRecognitionError.unknown)
                    return
                }

                // Reset state for this audio setup attempt (accessed on audioQueue - thread-safe)
                self.hasResumed = false

                // Wrap ENTIRE block in do-catch to guarantee continuation resume
                do {
                    // Configure audio session
                    let audioSession = AVAudioSession.sharedInstance()
                    try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
                    try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

                    // Access audio engine on dedicated queue (NOT main thread)
                    let inputNode = self.audioEngine.inputNode
                    let recordingFormat = inputNode.outputFormat(forBus: 0)

                    // Validate recording format
                    guard recordingFormat.sampleRate > 0 else {
                        throw SpeechRecognitionError.invalidAudioFormat
                    }

                    // Install tap with throttled level updates
                    var lastLevelUpdate = Date()
                    inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
                        // This runs on real-time audio thread - must be fast!
                        request.append(buffer)

                        // Throttle level updates to prevent Task accumulation
                        let now = Date()
                        if now.timeIntervalSince(lastLevelUpdate) > 0.05 { // Max 20 updates per second
                            lastLevelUpdate = now

                            // Calculate audio level (RMS - Root Mean Square)
                            let channelData = buffer.floatChannelData?[0]
                            let channelDataCount = Int(buffer.frameLength)

                            if let data = channelData {
                                var sum: Float = 0
                                for i in 0..<channelDataCount {
                                    let sample = data[i]
                                    sum += sample * sample
                                }
                                let rms = sqrt(sum / Float(channelDataCount))

                                // Normalize to 0-1 range with high sensitivity
                                let normalizedLevel = min(1.0, max(0.0, rms * 50.0))

                                // Update on main actor (Swift 6 concurrency compliance)
                                Task { @MainActor in
                                    levelUpdate(normalizedLevel)
                                }
                            }
                        }
                    }

                    // Prepare and start audio engine with individual error handling
                    self.audioEngine.prepare()

                    do {
                        try self.audioEngine.start()
                    } catch {
                        self.logger.error("❌ Audio engine start failed: \(error)")
                        // Clean up tap if start fails
                        inputNode.removeTap(onBus: 0)
                        throw SpeechRecognitionError.audioEngineStartFailed(error.localizedDescription)
                    }

                    self.logger.info("🎤 Audio engine started successfully")
                    if !self.hasResumed {
                        self.hasResumed = true
                        continuation.resume()
                    }

                } catch {
                    // GUARANTEED: This catch block ensures continuation always resumes
                    self.logger.error("❌ Audio setup failed with error: \(error)")

                    // Clean up audio engine state
                    self.audioEngine.stop()
                    self.audioEngine.inputNode.removeTap(onBus: 0)

                    if !self.hasResumed {
                        self.hasResumed = true
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }

    /// Stop audio engine on background thread to prevent main actor blocking
    func stopAudio() {
        audioQueue.async { [weak self] in
            guard let self = self else { return }

            self.audioEngine.stop()
            self.audioEngine.inputNode.removeTap(onBus: 0)

            self.logger.info("🛑 Audio engine stopped")
        }
    }
}

// MARK: - Error Types

enum SpeechRecognitionError: LocalizedError {
    case authorizationDenied
    case microphonePermissionDenied
    case restricted
    case notDetermined
    case unknown
    case recognizerNotAvailable
    case requestCreationFailed
    case recognitionFailed(String)
    case mealParsingFailed(String)
    case audioEngineTimeout
    case audioEnginePrepareFailed(String)
    case audioEngineStartFailed(String)
    case invalidAudioFormat

    var errorDescription: String? {
        switch self {
        case .authorizationDenied:
            return "Konuşma tanıma izni verilmedi. Lütfen Ayarlar'dan izin verin."
        case .microphonePermissionDenied:
            return "Mikrofon izni verilmedi. Lütfen Ayarlar'dan mikrofon erişimini açın."
        case .restricted:
            return "Konuşma tanıma bu cihazda kısıtlanmış."
        case .notDetermined:
            return "Konuşma tanıma izni henüz istenmedi."
        case .unknown:
            return "Bilinmeyen bir hata oluştu."
        case .recognizerNotAvailable:
            return "Konuşma tanıma şu anda kullanılamıyor."
        case .requestCreationFailed:
            return "Konuşma tanıma isteği oluşturulamadı."
        case .recognitionFailed(let message):
            return "Konuşma tanıma başarısız: \(message)"
        case .mealParsingFailed(let message):
            return "Öğün bilgisi çıkarılamadı: \(message)"
        case .audioEngineTimeout:
            return "Ses motoru başlatılamadı (zaman aşımı). Lütfen tekrar deneyin."
        case .audioEnginePrepareFailed(let message):
            return "Ses motoru hazırlanamadı: \(message)"
        case .audioEngineStartFailed(let message):
            return "Ses motoru başlatılamadı: \(message)"
        case .invalidAudioFormat:
            return "Geçersiz ses formatı. Lütfen cihazınızı yeniden başlatmayı deneyin."
        }
    }
}