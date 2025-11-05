//
//  AudioRecordingService.swift
//  balli
//
//  Lightweight audio recording service for Gemini transcription
//  Records audio to a file for upload to Cloud Functions
//

import Foundation
import AVFoundation
import Combine
import os.log
import UIKit

// MARK: - Audio Recording Errors

enum AudioRecordingError: LocalizedError {
    case microphonePermissionDenied
    case recordingSetupFailed(String)
    case recordingFailed(String)
    case notRecording
    case unknown

    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return "Microphone access is required to record meals. Please enable it in Settings."
        case .recordingSetupFailed(let message):
            return "Failed to set up recording: \(message)"
        case .recordingFailed(let message):
            return "Recording failed: \(message)"
        case .notRecording:
            return "No recording in progress."
        case .unknown:
            return "An unknown error occurred."
        }
    }
}

// MARK: - Audio Recording Service

/// Main actor-isolated service for audio recording
/// Provides simple file-based recording for Gemini transcription
@MainActor
class AudioRecordingService: NSObject, ObservableObject {

    // Logger for debugging
    private let logger = Logger(subsystem: "com.balli.diabetes", category: "AudioRecording")

    // Audio recorder
    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?

    // Audio level monitoring timer
    private var levelTimer: Timer?

    // Background observer for cleanup
    private var backgroundObserver: NSObjectProtocol?

    // Published state
    @Published var isRecording = false
    @Published var microphonePermissionGranted = false
    @Published var error: AudioRecordingError?
    @Published var audioLevel: Float = 0.0 // 0.0 to 1.0 for glow visualization
    @Published var recordingDuration: TimeInterval = 0.0

    // Recording settings - matching SpeechRecognitionService for consistency
    private let recordingSettings: [String: Any] = [
        AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
        AVSampleRateKey: 16000,
        AVNumberOfChannelsKey: 1,
        AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
    ]

    override init() {
        super.init()
        logger.info("✅ AudioRecordingService initialized")

        // CRITICAL: Stop recording when app goes to background to prevent battery drain
        backgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                if self.isRecording {
                    self.logger.warning("⚠️ App backgrounded - stopping recording to save battery")
                    _ = self.stopRecording()
                }
            }
        }
    }

    deinit {
        // Note: Cleanup happens automatically via ARC
        // Manual cleanup in deinit is not possible with strict concurrency
        // as deinit is nonisolated and cannot access @MainActor isolated properties
        logger.info("🧹 AudioRecordingService deinit - automatic cleanup via ARC")
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

        // Check microphone permission
        guard microphonePermissionGranted else {
            logger.error("❌ Microphone permission not granted")
            throw AudioRecordingError.microphonePermissionDenied
        }

        // Stop any existing recording
        if audioRecorder?.isRecording == true {
            _ = stopRecording()
        }

        // Generate unique filename in temporary directory
        let tempDir = FileManager.default.temporaryDirectory
        let filename = "meal_recording_\(UUID().uuidString).m4a"
        recordingURL = tempDir.appendingPathComponent(filename)

        guard let url = recordingURL else {
            throw AudioRecordingError.recordingSetupFailed("Failed to create recording URL")
        }

        do {
            // Configure audio session
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .default, options: [])
            try audioSession.setActive(true)

            logger.info("✅ Audio session configured")

            // Create recorder
            audioRecorder = try AVAudioRecorder(url: url, settings: recordingSettings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true // Enable audio level monitoring

            // Start recording
            let started = audioRecorder?.record() ?? false

            if started {
                isRecording = true
                recordingDuration = 0.0
                error = nil

                // Start level monitoring timer
                startLevelMonitoring()

                logger.info("✅ Recording started to: \(url.lastPathComponent)")
            } else {
                throw AudioRecordingError.recordingSetupFailed("Failed to start recording")
            }

        } catch {
            logger.error("❌ Recording setup failed: \(error.localizedDescription)")
            throw AudioRecordingError.recordingSetupFailed(error.localizedDescription)
        }
    }

    func stopRecording() -> URL? {
        logger.info("🛑 stopRecording() called")

        // Stop level monitoring
        stopLevelMonitoring()

        guard let recorder = audioRecorder, recorder.isRecording else {
            logger.warning("⚠️ Not currently recording")
            return nil
        }

        // Stop recording
        recorder.stop()
        isRecording = false
        audioLevel = 0.0

        // Deactivate audio session
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            logger.warning("⚠️ Failed to deactivate audio session: \(error.localizedDescription)")

            // Track error for analytics (helps identify iOS audio conflicts)
            Task {
                await AnalyticsService.shared.trackError(.audioSessionDeactivationFailed, error: error)
            }
        }

        logger.info("✅ Recording stopped, duration: \(self.recordingDuration)s")

        return recordingURL
    }

    // MARK: - Audio Level Monitoring

    private func startLevelMonitoring() {
        // Create timer on main thread for UI updates
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateAudioLevel()
            }
        }
    }

    private func stopLevelMonitoring() {
        levelTimer?.invalidate()
        levelTimer = nil
        audioLevel = 0.0
    }

    private func updateAudioLevel() {
        guard let recorder = audioRecorder, recorder.isRecording else {
            audioLevel = 0.0
            return
        }

        recorder.updateMeters()

        // Get average power in decibels (-160 to 0)
        let averagePower = recorder.averagePower(forChannel: 0)

        // Normalize to 0.0 - 1.0 range for UI
        // -50 dB is silence, 0 dB is max
        let normalizedLevel = max(0.0, min(1.0, (averagePower + 50.0) / 50.0))
        audioLevel = normalizedLevel

        // Update duration
        recordingDuration = recorder.currentTime
    }

    // MARK: - Cleanup

    func cleanup() {
        _ = stopRecording()

        // Delete temporary recording file
        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
            recordingURL = nil
        }
    }

    // MARK: - Get Recording Data

    /// Get the recorded audio data for upload
    /// Returns nil if no recording exists
    func getRecordingData() throws -> Data? {
        guard let url = recordingURL else {
            logger.warning("⚠️ No recording URL available")
            return nil
        }

        guard FileManager.default.fileExists(atPath: url.path) else {
            logger.error("❌ Recording file does not exist at: \(url.path)")
            throw AudioRecordingError.recordingFailed("Recording file not found")
        }

        do {
            let data = try Data(contentsOf: url)
            let sizeKB = Double(data.count) / 1024.0
            logger.info("✅ Retrieved recording data: \(String(format: "%.2f", sizeKB)) KB")
            return data
        } catch {
            logger.error("❌ Failed to read recording data: \(error.localizedDescription)")
            throw AudioRecordingError.recordingFailed("Failed to read recording: \(error.localizedDescription)")
        }
    }
}

// MARK: - AVAudioRecorderDelegate

extension AudioRecordingService: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in
            logger.info("Recording finished successfully: \(flag)")

            if !flag {
                error = .recordingFailed("Recording did not complete successfully")
            }
        }
    }

    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task { @MainActor in
            if let error = error {
                logger.error("❌ Recording encode error: \(error.localizedDescription)")
                self.error = .recordingFailed(error.localizedDescription)
            }
        }
    }
}
