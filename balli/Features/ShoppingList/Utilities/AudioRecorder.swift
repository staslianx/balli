//
//  AudioRecorder.swift
//  balli
//
//  Audio recording functionality with AVAudioRecorder integration
//  Thread-safe actor-based implementation for voice recording
//

import Foundation
import AVFoundation
import os.log

// MARK: - Audio Recording Actor

actor AudioRecorder {
    private let logger = os.Logger(subsystem: "com.balli.diabetes", category: "AudioRecorder")
    
    // Audio components
    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?
    private var isRecording = false
    
    // State management
    private var recordingStartTime: Date?
    
    // Configuration
    private let maxRecordingDuration: TimeInterval = 60.0 // 1 minute max
    private let minRecordingDuration: TimeInterval = 1.0  // 1 second min
    private let sampleRate: Double = 16000 // 16kHz for optimal AI processing
    
    init() {
        logger.info("AudioRecorder initialized")
    }
    
    // MARK: - Audio Session Setup
    
    private func setupAudioSession() throws {
        let audioSession = AVAudioSession.sharedInstance()
        
        do {
            // Set category with options for better recording
            try audioSession.setCategory(
                .playAndRecord,
                mode: .default,
                options: [.defaultToSpeaker, .allowBluetoothHFP]
            )
            
            // Activate the audio session
            try audioSession.setActive(true)
            logger.info("Audio session configured successfully")
            
        } catch let error as NSError {
            logger.error("Failed to configure audio session: \(error.localizedDescription)")
            logger.error("Audio session error code: \(error.code)")
            throw VoiceRecordingError.recordingFailed("Audio session setup failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Permission Handling
    
    func requestPermissions() async throws {
        // Request microphone permission (iOS 17+ compatible)
        let microphoneStatus = await withCheckedContinuation { continuation in
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
        
        guard microphoneStatus else {
            logger.error("Microphone permission denied")
            throw VoiceRecordingError.permissionDenied
        }
        
        logger.info("Audio permissions granted successfully")
        
        // Add delay after first-time permission grant to let system settle
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5s delay
        
        // Try to setup audio session immediately after permission grant
        do {
            try setupAudioSession()
            logger.info("Audio session initialized after permission grant")
        } catch {
            logger.error("Failed to setup audio session after permission: \(error)")
            // Don't throw here, will retry when recording starts
        }
    }
    
    func checkPermissions() async -> Bool {
        if #available(iOS 17.0, *) {
            return AVAudioApplication.shared.recordPermission == .granted
        } else {
            let microphoneStatus = AVAudioSession.sharedInstance().recordPermission
            return microphoneStatus == .granted
        }
    }
    
    // MARK: - Recording Controls
    
    func startRecording() async throws -> URL {
        guard !isRecording else {
            logger.warning("Already recording, ignoring start request")
            throw VoiceRecordingError.recordingFailed("Recording already in progress")
        }
        
        // Check permissions first
        guard await checkPermissions() else {
            throw VoiceRecordingError.permissionDenied
        }
        
        // Setup audio session BEFORE creating recorder
        // Retry with delay if it fails (in case of first-time permission)
        do {
            try setupAudioSession()
        } catch {
            logger.warning("First audio session setup failed, retrying after delay: \(error)")
            try await Task.sleep(nanoseconds: 300_000_000) // 0.3s delay
            try setupAudioSession()
        }
        
        // Setup recording file
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        recordingURL = documentsPath.appendingPathComponent("voice_recording_\(Date().timeIntervalSince1970).wav")
        
        guard let recordingURL = recordingURL else {
            throw VoiceRecordingError.recordingFailed("Could not create recording URL")
        }
        
        // Configure audio format for AI processing (16kHz, 16-bit, mono)
        let audioFormat: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: recordingURL, settings: audioFormat)
            audioRecorder?.prepareToRecord()
            
            let success = audioRecorder?.record() ?? false
            
            if success {
                isRecording = true
                recordingStartTime = Date()
                logger.info("Voice recording started successfully")
                
                // Set up automatic stop after max duration
                Task {
                    try await Task.sleep(nanoseconds: UInt64(maxRecordingDuration * 1_000_000_000))
                    if isRecording {
                        logger.info("Auto-stopping recording after max duration")
                        _ = await stopRecording()
                    }
                }
                
                return recordingURL
            } else {
                throw VoiceRecordingError.recordingFailed("Failed to start recording")
            }
            
        } catch {
            logger.error("Audio recorder setup failed: \(error)")
            throw VoiceRecordingError.recordingFailed("Recording setup failed: \(error.localizedDescription)")
        }
    }
    
    func stopRecording() async -> Data? {
        guard isRecording, let recorder = audioRecorder else {
            logger.warning("No active recording to stop")
            return nil
        }
        
        recorder.stop()
        isRecording = false
        
        guard let recordingURL = recordingURL,
              let startTime = recordingStartTime else {
            logger.error("Recording URL or start time not available")
            return nil
        }
        
        let duration = Date().timeIntervalSince(startTime)
        logger.info("Recording stopped. Duration: \(duration)s")
        
        // Check minimum duration
        guard duration >= minRecordingDuration else {
            logger.warning("Recording too short: \(duration)s")
            return nil
        }
        
        // Read audio data
        do {
            let audioData = try Data(contentsOf: recordingURL)
            logger.info("Audio data loaded: \(audioData.count) bytes")
            return audioData
        } catch {
            logger.error("Failed to load audio data: \(error)")
            return nil
        }
    }
    
    func cancelRecording() async {
        if isRecording {
            audioRecorder?.stop()
            isRecording = false
            logger.info("Recording cancelled")
        }
    }
    
    // MARK: - State Management
    
    var currentRecordingState: VoiceRecordingState {
        if isRecording {
            let duration = recordingStartTime?.timeIntervalSinceNow.magnitude ?? 0
            return .recording(duration: duration)
        } else {
            return .idle
        }
    }
    
    var recordingFileURL: URL? {
        return recordingURL
    }
}