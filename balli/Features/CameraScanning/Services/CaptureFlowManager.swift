//
//  CaptureFlowManager.swift
//  balli
//
//  Main coordinator for camera capture flow
//

import SwiftUI
import Combine
@preconcurrency import UIKit
import os.log
import CoreData

/// Main capture flow coordinator for SwiftUI views
@MainActor
public class CaptureFlowManager: ObservableObject, CaptureFlowCoordinating {
    private let logger = os.Logger(subsystem: "com.balli.diabetes", category: "CaptureFlowManager")
    
    // MARK: - Published Properties (CaptureFlowCoordinating)
    @Published public var isCapturing = false
    @Published public var isAnalyzing = false
    @Published public var currentError: CaptureError?
    @Published public var showingCapturedImage = false
    @Published public var capturedImage: UIImage?
    @Published public var extractedNutrition: NutritionExtractionResult?
    
    // Additional published properties
    @Published public var optimizedImage: UIImage?
    @Published public var foodItem: FoodItem?
    
    // Computed from components
    public var processingProgress: Double {
        stateMachine.processingProgress
    }
    
    public var currentSession: CaptureSession? {
        sessionManager.currentSession
    }
    
    public var recentSessions: [CaptureSession] {
        sessionManager.recentSessions
    }
    
    // MARK: - Components
    private let sessionManager: CaptureSessionManager
    private let stateMachine: CaptureFlowStateMachine
    private let delegateHandler: CaptureDelegateHandler
    private let hapticManager: HapticManager
    private let configuration: CaptureConfiguration
    
    // MARK: - Dependencies
    private let cameraManager: CameraManager
    private let imageProcessor = ImageProcessor()
    private let labelAnalysisService = LabelAnalysisService.shared
    private let securityManager = SecurityManager.shared
    
    // MARK: - Internal State
    private var processingTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Lifecycle Observers
    private var backgroundObserver: (any NSObjectProtocol)?
    private var foregroundObserver: (any NSObjectProtocol)?
    
    // MARK: - Initialization
    
    public init(cameraManager: CameraManager) {
        self.cameraManager = cameraManager
        self.configuration = .default
        self.hapticManager = HapticManager()

        // Initialize persistence - this is a critical component
        // If this fails, it indicates a serious system issue (corrupted file system, no permissions, etc.)
        let persistenceManager: CaptureSessionPersistence
        do {
            persistenceManager = try CaptureSessionPersistence()
            logger.info("Persistence initialized successfully")
        } catch {
            // This should never fail in normal operation as CaptureSessionPersistence
            // creates necessary directories. If it does fail, something is seriously wrong
            // with the device's file system or app permissions.
            logger.error("CRITICAL: Failed to initialize persistence: \(error.localizedDescription)")
            preconditionFailure("Cannot initialize CaptureSessionPersistence - file system may be corrupted or app lacks necessary permissions. Error: \(error.localizedDescription)")
        }

        // Initialize components
        self.sessionManager = CaptureSessionManager(
            persistenceManager: persistenceManager,
            configuration: configuration
        )
        self.stateMachine = CaptureFlowStateMachine()
        self.delegateHandler = CaptureDelegateHandler()

        setupBindings()
        setupObservers()
    }
    
    // MARK: - Setup
    
    private func setupBindings() {
        // Bind state machine progress
        stateMachine.$processingProgress
            .receive(on: RunLoop.main)
            .sink { [weak self] progress in
                self?.delegateHandler.notifyProcessingProgressDidUpdate(progress)
            }
            .store(in: &cancellables)

        // Bind session manager updates
        sessionManager.$currentSession
            .receive(on: RunLoop.main)
            .sink { [weak self] session in
                if let state = session?.state {
                    Task { [weak self] in
                        await self?.stateMachine.transition(to: state)
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupObservers() {
        backgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { [weak self] in
                await self?.handleEnterBackground()
            }
        }

        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { [weak self] in
                await self?.handleEnterForeground()
            }
        }
    }
    
    // MARK: - CaptureFlowCoordinating Implementation
    
    public func startCapture() async {
        logger.info("Starting capture flow")
        
        // Cancel any existing active session
        if let existing = currentSession, existing.isActive {
            await cancelCapture()
        }
        
        // Transition to capturing state
        await stateMachine.transition(to: .capturing)
        
        // Haptic feedback
        hapticManager.captureStarted()
        
        // Create new session
        let session = await sessionManager.createSession(
            with: cameraManager.currentZoom.rawValue
        )
        
        // Update UI state
        isCapturing = true
        currentError = nil
        
        // Notify delegates
        delegateHandler.notifyCaptureDidStart()
        
        // Start capture
        do {
            await cameraManager.capturePhoto()
            
            guard let capturedUIImage = cameraManager.lastCapturedImage else {
                throw CaptureError.imageConversionFailed
            }
            
            // Process captured image
            await handleCapturedImage(capturedUIImage, for: session.id)
            
        } catch {
            await handleCaptureError(error, for: session.id)
        }
    }
    
    public func confirmAndProcess() async {
        guard let sessionId = currentSession?.id else { return }
        
        isAnalyzing = true
        await stateMachine.transition(to: .optimizing)
        
        await processCapture(sessionId)
    }
    
    public func cancelCapture() async {
        guard let session = currentSession else { return }
        
        logger.info("Cancelling capture: \(session.id)")
        
        processingTask?.cancel()
        
        await stateMachine.transition(to: .cancelled)
        await sessionManager.markSessionCancelled(session.id)
        
        isCapturing = false
        isAnalyzing = false
        
        await sessionManager.deleteSession(id: session.id)
    }
    
    public func retryCapture(_ session: CaptureSession) async {
        guard sessionManager.canRetrySession(session) else { return }
        
        logger.info("Retrying capture: \(session.id)")
        
        await sessionManager.updateSession(session.id) { session in
            session.retryCount += 1
            session.error = nil
            session.processingStartTime = Date()
        }
        
        await resumeProcessing(session: session)
    }
    
    public func clearCapturedImage() {
        capturedImage = nil
        optimizedImage = nil
        showingCapturedImage = false
        extractedNutrition = nil
        foodItem = nil
        isCapturing = false
        isAnalyzing = false
        cameraManager.clearCapturedImage()
        stateMachine.reset()
    }
    
    // MARK: - Image Processing
    
    private func handleCapturedImage(_ image: UIImage, for sessionId: UUID) async {
        // Haptic feedback
        hapticManager.captureCompleted()
        
        // Transition state
        await stateMachine.transition(to: .captured)
        
        // Generate thumbnail
        let thumbnail = await imageProcessor.generateThumbnail(from: image, cacheKey: sessionId.uuidString)

        // Save image data
        async let imageDataTask = imageProcessor.jpegData(
            from: image,
            compressionQuality: configuration.compressionQuality
        )
        async let thumbnailDataTask = imageProcessor.jpegData(
            from: thumbnail,
            compressionQuality: configuration.thumbnailCompressionQuality
        )

        guard let imageData = await imageDataTask,
              let thumbnailData = await thumbnailDataTask else {
            await handleCaptureError(CaptureError.imageConversionFailed, for: sessionId)
            return
        }
        
        // Update session
        await sessionManager.updateSession(sessionId) { session in
            session.imageData = imageData
            session.thumbnailData = thumbnailData
            session.imageSize = image.size
            session.state = .captured
        }
        
        // Update UI
        self.capturedImage = image
        self.isCapturing = false
        self.showingCapturedImage = true
        
        // Notify delegates
        delegateHandler.notifyCaptureDidComplete(with: image)
        
        logger.info("✅ Capture completed: image size = \(image.size.width)x\(image.size.height)")
    }
    
    private func processCapture(_ sessionID: UUID) async {
        guard currentSession?.id == sessionID else { return }
        
        do {
            // Optimize image
            await stateMachine.transition(to: .optimizing)
            
            guard let imageData = currentSession?.imageData,
                  let originalImage = UIImage(data: imageData) else {
                throw CaptureError.imageConversionFailed
            }
            
            let optimized = try await imageProcessor.optimizeForAI(image: originalImage)
            self.optimizedImage = optimized
            
            // Save optimized image
            if let optimizedData = await imageProcessor.compressForStorage(image: optimized) {
                await sessionManager.updateSession(sessionID) { session in
                    session.optimizedImageData = optimizedData
                }
            }
            
            // AI Processing
            await stateMachine.transition(to: .processingAI)
            
            // Check rate limits
            guard await securityManager.canPerformAIScan() else {
                throw CaptureError.rateLimitExceeded
            }
            
            // Analyze the label using real AI processing via Firebase Functions
            let nutritionResult = try await labelAnalysisService.analyzeLabel(
                image: optimized,
                language: "tr"
            ) { [self] progressMessage in
                // Optional: Could update UI with progress messages
                logger.info("🏷️ AI Processing: \(progressMessage)")
            }

            // Validate the extracted data
            guard labelAnalysisService.validateNutritionData(nutritionResult) else {
                throw CaptureError.aiProcessingFailed("Extracted nutrition data failed validation")
            }

            self.extractedNutrition = nutritionResult
            
            // Create FoodItem if successful
            // Check if we have valid nutrition data
            if nutritionResult.metadata.confidence > 0.5 {
                // Note: FoodItem conversion from nutrition result requires Core Data mapping implementation
                // The CaptureFlowManager is MainActor-bound, so we can safely use viewContext when implemented
                // let context = PersistenceController.shared.viewContext
                // self.foodItem = nutritionResult.toFoodItem(in: context)
                self.foodItem = nil // Stub - set to nil for now
            }
            
            // Record successful scan
            await securityManager.recordAIScan()
            
            // Complete session
            await stateMachine.transition(to: .completed)
            await sessionManager.markSessionCompleted(sessionID)
            
            // Success feedback
            hapticManager.processingCompleted()
            delegateHandler.notifyAnalysisDidComplete(with: nutritionResult)
            
            // Set analyzing to false AFTER notifying delegates and setting the result
            // This ensures the UI can detect completion properly
            isAnalyzing = false
            
        } catch {
            await handleProcessingError(error, for: sessionID)
        }
    }
    
    // MARK: - Error Handling
    
    private func handleCaptureError(_ error: Error, for sessionId: UUID) async {
        logger.error("Capture failed: \(error)")
        
        let captureError = error as? CaptureError ?? .unknownError(error.localizedDescription)
        
        await stateMachine.transition(to: .failed)
        await sessionManager.markSessionFailed(sessionId, error: error.localizedDescription)
        
        self.currentError = captureError
        self.isCapturing = false
        self.showingCapturedImage = false
        
        hapticManager.captureFailed()
        delegateHandler.notifyCaptureDidFail(with: captureError)
    }
    
    private func handleProcessingError(_ error: Error, for sessionId: UUID) async {
        logger.error("Processing failed: \(error)")

        // Map LabelAnalysisError to appropriate CaptureError
        let captureError: CaptureError
        if let labelError = error as? LabelAnalysisError {
            switch labelError {
            case .networkError, .networkTimeout:
                captureError = .networkUnavailable
            case .serverError:
                captureError = .aiProcessingFailed(labelError.localizedDescription)
            case .imageProcessingFailed:
                captureError = .imageConversionFailed
            case .validationFailed, .noDataReceived:
                captureError = .aiProcessingFailed(labelError.localizedDescription)
            case .invalidURL, .encodingFailed:
                captureError = .processingFailed(labelError.localizedDescription)
            case .firebaseQuotaExceeded, .firebaseRateLimitExceeded:
                captureError = .rateLimitExceeded
            case .geminiVisionError:
                captureError = .aiProcessingFailed(labelError.localizedDescription)
            }
        } else {
            captureError = error as? CaptureError ?? .unknownError(error.localizedDescription)
        }

        await stateMachine.transition(to: .failed)
        await sessionManager.markSessionFailed(sessionId, error: error.localizedDescription)

        self.currentError = captureError
        self.isAnalyzing = false

        hapticManager.processingFailed()
        delegateHandler.notifyAnalysisDidFail(with: error)
    }
    
    // MARK: - Session Recovery
    
    private func resumeProcessing(session: CaptureSession) async {
        logger.info("Resuming processing for session: \(session.id)")
        
        isAnalyzing = true
        
        switch session.state {
        case .captured, .optimizing, .processingAI:
            await processCapture(session.id)

        case .waitingForNetwork:
            // Note: Network availability check could be implemented here if needed
            await processCapture(session.id)

        default:
            isAnalyzing = false
        }
    }
    
    // MARK: - Lifecycle Handling
    
    private func handleEnterBackground() async {
        logger.info("Handling background transition")
        
        if let session = currentSession {
            try? await sessionManager.saveSession(session)
        }
        
        await cameraManager.stop()
        processingTask?.cancel()
    }
    
    private func handleEnterForeground() async {
        logger.info("Handling foreground transition")
        
        if !showingCapturedImage {
            await cameraManager.prepare()
        }
        
        // Check for active session to resume
        if let activeSession = await sessionManager.getActiveSession() {
            if activeSession.isActive && !sessionManager.isSessionExpired(activeSession) {
                await resumeProcessing(session: activeSession)
            }
        }
    }
    
    // MARK: - Public Utilities
    
    public func getRemainingScans() async -> Int {
        return await securityManager.getRemainingScans()
    }
    
    public func deleteSession(id: UUID) async {
        await sessionManager.deleteSession(id: id)
    }
    
    public func clearHistory() async {
        await sessionManager.clearHistory()
    }
    
    // MARK: - Cleanup
    
    public func cleanup() {
        if let observer = backgroundObserver {
            NotificationCenter.default.removeObserver(observer)
            backgroundObserver = nil
        }
        if let observer = foregroundObserver {
            NotificationCenter.default.removeObserver(observer)
            foregroundObserver = nil
        }
        cancellables.removeAll()
    }
    
    deinit {
        // Cleanup should be called before deinit
    }
}
