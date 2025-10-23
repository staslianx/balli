//
//  VoiceRecordingManager.swift
//  balli
//
//  Voice recording coordinator for shopping list creation
//  Orchestrates audio recording, transcription, and file management
//  Uses AI 2.5 Flash for speech-to-text and item parsing
//

import Foundation
import os.log

// MARK: - Voice Recording Manager Actor

actor VoiceRecordingManager {
    private let logger = os.Logger(subsystem: "com.balli.diabetes", category: "VoiceRecordingManager")
    
    // Component actors
    private let audioRecorder: AudioRecorder
    private let audioTranscriber: AudioTranscriber
    private let audioFileManager: AudioFileManager
    
    // State management
    private var currentSession: RecordingSession?
    private var configuration: VoiceRecordingConfiguration
    
    // Callback closures for events (simpler than delegate pattern for Swift 6 concurrency)
    private var onRecordingStart: (@Sendable () async -> Void)?
    private var onRecordingStop: (@Sendable (VoiceRecordingResult?) async -> Void)?
    private var onRecordingFail: (@Sendable (VoiceRecordingError) async -> Void)?
    private var onDurationUpdate: (@Sendable (TimeInterval) async -> Void)?
    private var onStateUpdate: (@Sendable (VoiceRecordingState) async -> Void)?
    
    init(configuration: VoiceRecordingConfiguration = .standard) {
        self.configuration = configuration
        self.audioRecorder = AudioRecorder()
        self.audioTranscriber = AudioTranscriber()
        self.audioFileManager = AudioFileManager()
        
        logger.info("VoiceRecordingManager initialized with configuration")
        
        // Start session monitoring for analytics and cleanup
        Task {
            await startSessionMonitoring()
        }
    }
    
    // MARK: - Public Interface
    
    func setCallbacks(
        onStart: (@Sendable () async -> Void)? = nil,
        onStop: (@Sendable (VoiceRecordingResult?) async -> Void)? = nil,
        onFail: (@Sendable (VoiceRecordingError) async -> Void)? = nil,
        onDurationUpdate: (@Sendable (TimeInterval) async -> Void)? = nil,
        onStateUpdate: (@Sendable (VoiceRecordingState) async -> Void)? = nil
    ) {
        self.onRecordingStart = onStart
        self.onRecordingStop = onStop
        self.onRecordingFail = onFail
        self.onDurationUpdate = onDurationUpdate
        self.onStateUpdate = onStateUpdate
    }
    
    func updateConfiguration(_ newConfiguration: VoiceRecordingConfiguration) {
        self.configuration = newConfiguration
        logger.info("Configuration updated")
    }
    
    // MARK: - Permission Management
    
    func requestPermissions() async throws {
        try await audioRecorder.requestPermissions()
        logger.info("Permissions granted successfully")
    }
    
    func checkPermissions() async -> AudioPermissionStatus {
        let isGranted = await audioRecorder.checkPermissions()
        return isGranted ? .granted : .denied
    }
    
    // MARK: - Recording Controls
    
    func startRecording() async throws {
        guard currentSession == nil else {
            logger.warning("Recording session already active")
            return
        }
        
        // Create new session
        currentSession = RecordingSession(
            startTime: Date(),
            endTime: nil,
            duration: 0,
            status: .recording,
            fileSize: nil,
            transcriptionLength: nil,
            itemCount: nil
        )
        
        do {
            // Start recording through audio recorder
            _ = try await audioRecorder.startRecording()
            logger.info("Recording started successfully")
            
            // Notify callback
            if let onStart = onRecordingStart {
                await onStart()
            }
            
            // Start duration monitoring
            Task {
                await monitorRecordingDuration()
            }
            
        } catch {
            currentSession = nil
            logger.error("Failed to start recording: \(error)")
            
            if let onFail = onRecordingFail {
                await onFail(error as? VoiceRecordingError ?? .recordingFailed(error.localizedDescription))
            }
            
            throw error
        }
    }
    
    func stopRecording() async -> VoiceRecordingResult? {
        guard let session = currentSession else {
            logger.warning("No active recording session to stop")
            return nil
        }
        
        // Stop the actual recording
        guard let audioData = await audioRecorder.stopRecording() else {
            logger.error("Failed to stop recording or retrieve audio data")
            currentSession = nil
            
            if let onFail = onRecordingFail {
                await onFail(.recordingFailed("Failed to retrieve audio data"))
            }
            
            return nil
        }
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(session.startTime)
        
        // Check duration constraints
        guard duration >= configuration.minRecordingDuration else {
            logger.warning("Recording too short: \(duration)s")
            currentSession = nil
            
            if let onFail = onRecordingFail {
                await onFail(.audioTooShort)
            }
            
            return nil
        }
        
        guard duration <= configuration.maxRecordingDuration else {
            logger.warning("Recording too long: \(duration)s")
            currentSession = nil
            
            if let onFail = onRecordingFail {
                await onFail(.audioTooLong)
            }
            
            return nil
        }
        
        do {
            // Process audio through transcriber
            let parsedItems = try await audioTranscriber.processVoiceRecording(audioData)
            
            // Create result
            let result = VoiceRecordingResult(
                audioData: audioData,
                duration: duration,
                parsedItems: parsedItems
            )
            
            // Update session
            currentSession = RecordingSession(
                startTime: session.startTime,
                endTime: endTime,
                duration: duration,
                status: .completed,
                fileSize: Int64(audioData.count),
                transcriptionLength: nil, // Could be calculated if needed
                itemCount: parsedItems.count
            )
            
            logger.info("Recording completed successfully with \(parsedItems.count) items")
            
            // Cleanup and notify
            await cleanup()
            
            if let onStop = onRecordingStop {
                await onStop(result)
            }
            
            return result
            
        } catch {
            logger.error("Failed to process recording: \(error)")
            currentSession = nil
            
            if let onFail = onRecordingFail {
                await onFail(error as? VoiceRecordingError ?? .processingFailed(error.localizedDescription))
            }
            
            return nil
        }
    }
    
    func cancelRecording() async {
        guard let session = currentSession else {
            logger.warning("No active recording session to cancel")
            return
        }
        
        await audioRecorder.cancelRecording()
        
        // Update session status
        currentSession = RecordingSession(
            startTime: session.startTime,
            endTime: Date(),
            duration: Date().timeIntervalSince(session.startTime),
            status: .cancelled,
            fileSize: nil,
            transcriptionLength: nil,
            itemCount: nil
        )
        
        await cleanup()
        logger.info("Recording cancelled")
        
        if let onStop = onRecordingStop {
            await onStop(nil)
        }
    }
    
    // MARK: - Transcription Only (without Shopping List Parsing)
    
    func transcribeAudio(_ audioData: Data) async throws -> String {
        return try await audioTranscriber.transcribeAudioOnly(audioData)
    }
    
    func processVoiceRecording(_ audioData: Data) async throws -> [ShoppingItemParsed] {
        return try await audioTranscriber.processVoiceRecording(audioData)
    }
    
    // MARK: - State Management
    
    var currentState: VoiceRecordingState {
        get async {
            return await audioRecorder.currentRecordingState
        }
    }
    
    var currentRecordingSession: RecordingSession? {
        return currentSession
    }
    
    // MARK: - Storage Management
    
    func getStorageStatistics() async -> AudioStorageStatistics {
        return await audioFileManager.getStorageStatistics()
    }
    
    func cleanupOldFiles() async {
        await audioFileManager.cleanupOldFiles()
    }
    
    // MARK: - Private Implementation
    
    private func monitorRecordingDuration() async {
        while currentSession?.status == .recording {
            do {
                try await Task.sleep(nanoseconds: 250_000_000) // 0.25 second updates
                
                if let session = currentSession {
                    let currentDuration = Date().timeIntervalSince(session.startTime)
                    
                    if let onDurationUpdate = onDurationUpdate {
                        await onDurationUpdate(currentDuration)
                    }
                    
                    let state = VoiceRecordingState.recording(duration: currentDuration)
                    if let onStateUpdate = onStateUpdate {
                        await onStateUpdate(state)
                    }
                    
                    // Auto-stop if max duration reached
                    if currentDuration >= configuration.maxRecordingDuration {
                        logger.info("Auto-stopping recording at max duration")
                        _ = await stopRecording()
                        break
                    }
                }
            } catch {
                logger.error("Duration monitoring interrupted: \(error)")
                break
            }
        }
    }
    
    private func cleanup() async {
        // Cleanup recording file if it exists
        if let recordingURL = await audioRecorder.recordingFileURL {
            await audioFileManager.cleanupRecordingFile(at: recordingURL)
        }
        
        currentSession = nil
    }
    
    private func startSessionMonitoring() async {
        // Periodic cleanup and monitoring task
        while true {
            do {
                // Sleep for 5 minutes between monitoring cycles
                try await Task.sleep(nanoseconds: 300_000_000_000) // 5 minutes
                
                // Perform maintenance tasks
                await audioFileManager.cleanupOldFiles()
                
                logger.debug("Session monitoring cycle completed")
            } catch {
                logger.error("Session monitoring interrupted: \(error)")
                break
            }
        }
    }
    
}

// MARK: - Extension for Analytics

extension VoiceRecordingManager {
    
    func getRecordingAnalytics() async -> RecordingAnalytics? {
        guard let session = currentSession else { return nil }
        
        let endTime = session.endTime ?? Date()
        let duration = endTime.timeIntervalSince(session.startTime)
        
        return RecordingAnalytics(
            sessionId: session.id,
            startTimestamp: session.startTime,
            endTimestamp: session.endTime,
            duration: duration,
            audioQuality: .unknown, // Could be enhanced with actual audio analysis
            transcriptionAccuracy: nil, // Could be calculated if reference is available
            processingTime: nil, // Could be tracked during processing
            errorCount: 0, // Could be tracked during session
            successfulItemParsing: session.itemCount ?? 0
        )
    }
}
