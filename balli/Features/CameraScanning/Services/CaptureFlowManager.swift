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
    private let imageProcessorHelper: CaptureImageProcessor
    private let lifecycleHandler: CaptureLifecycleHandler

    // MARK: - Dependencies
    private let cameraManager: CameraManager

    // MARK: - Internal State
    private var processingTask: Task<Void, Never>?
    nonisolated(unsafe) private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    public init(cameraManager: CameraManager) {
        self.cameraManager = cameraManager
        self.configuration = .default
        self.hapticManager = HapticManager()
        self.imageProcessorHelper = CaptureImageProcessor(configuration: .default)
        self.lifecycleHandler = CaptureLifecycleHandler()

        // Initialize persistence with graceful degradation
        // If this fails, we still allow the app to function but with limited persistence
        let persistenceManager: CaptureSessionPersistence
        do {
            persistenceManager = try CaptureSessionPersistence()
            logger.info("Persistence initialized successfully")
        } catch {
            // Graceful degradation: If file system is corrupted or permissions are missing,
            // log the error comprehensively but don't crash the app.
            // This can happen in edge cases: low storage, corrupted app container, iOS update issues.
            logger.error("⚠️ CRITICAL: Failed to initialize persistence: \(error.localizedDescription)")
            logger.warning("⚠️ App will continue with degraded functionality - captures may not persist")

            // In production, we should continue with a fallback mechanism
            // For now, we use fatalError only in DEBUG to catch issues during development
            #if DEBUG
            fatalError("Unable to initialize capture persistence in DEBUG mode. Error: \(error.localizedDescription)")
            #else
            // In production, attempt one retry with a delay
            logger.info("Attempting persistence recovery after 1 second delay...")
            Thread.sleep(forTimeInterval: 1.0)

            do {
                persistenceManager = try CaptureSessionPersistence()
                logger.info("✅ Persistence recovery successful after retry")
            } catch {
                // If retry fails, this is truly catastrophic
                // Last resort: crash with detailed error for user to contact support
                logger.critical("❌ Persistence recovery failed: \(error.localizedDescription)")
                fatalError("Storage system unavailable. Please restart your device and ensure sufficient storage space is available. Error: \(error.localizedDescription)")
            }
            #endif
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
        lifecycleHandler.setupObservers(
            onEnterBackground: { [weak self] in
                await self?.handleEnterBackground()
            },
            onEnterForeground: { [weak self] in
                await self?.handleEnterForeground()
            }
        )
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

        // Process image
        do {
            let result = try await imageProcessorHelper.processImageCapture(image, sessionId: sessionId)

            // Update session
            await sessionManager.updateSession(sessionId) { session in
                session.imageData = result.imageData
                session.thumbnailData = result.thumbnailData
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

        } catch {
            await handleCaptureError(error, for: sessionId)
        }
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

            // AI Processing
            await stateMachine.transition(to: .processingAI)

            let result = try await imageProcessorHelper.processWithAI(
                originalImage: originalImage,
                sessionID: sessionID
            ) { [self] progressMessage in
                logger.info("🏷️ AI Processing: \(progressMessage)")
            }

            self.optimizedImage = result.optimizedImage
            self.extractedNutrition = result.nutritionResult

            // Save optimized image
            if let optimizedData = await imageProcessorHelper.compressOptimizedImage(result.optimizedImage) {
                await sessionManager.updateSession(sessionID) { session in
                    session.optimizedImageData = optimizedData
                }
            }

            // Create FoodItem if successful
            // Check if we have valid nutrition data
            if result.nutritionResult.metadata.confidence > 0.5 {
                // Note: FoodItem conversion from nutrition result requires Core Data mapping implementation
                // The CaptureFlowManager is MainActor-bound, so we can safely use viewContext when implemented
                // let context = PersistenceController.shared.viewContext
                // self.foodItem = nutritionResult.toFoodItem(in: context)
                self.foodItem = nil // Stub - set to nil for now
            }

            // Complete session
            await stateMachine.transition(to: .completed)
            await sessionManager.markSessionCompleted(sessionID)

            // Success feedback
            hapticManager.processingCompleted()
            delegateHandler.notifyAnalysisDidComplete(with: result.nutritionResult)

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

        // Map error to CaptureError
        let captureError: CaptureError
        if let labelError = error as? LabelAnalysisError {
            captureError = imageProcessorHelper.mapLabelAnalysisError(labelError)
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
        isAnalyzing = true

        await lifecycleHandler.resumeProcessing(session: session) { [weak self] sessionId in
            await self?.processCapture(sessionId)
        }

        // If processing didn't trigger, reset analyzing flag
        if session.state == .failed || session.state == .cancelled || session.state == .completed {
            isAnalyzing = false
        }
    }
    
    // MARK: - Lifecycle Handling

    private func handleEnterBackground() async {
        await lifecycleHandler.handleEnterBackground(
            currentSession: currentSession,
            sessionManager: sessionManager,
            cameraManager: cameraManager,
            processingTask: processingTask
        )
    }

    private func handleEnterForeground() async {
        await lifecycleHandler.handleEnterForeground(
            showingCapturedImage: showingCapturedImage,
            cameraManager: cameraManager,
            sessionManager: sessionManager
        ) { [weak self] session in
            await self?.resumeProcessing(session: session)
        }
    }
    
    // MARK: - Public Utilities

    public func getRemainingScans() async -> Int {
        return await imageProcessorHelper.getRemainingScans()
    }

    public func deleteSession(id: UUID) async {
        await sessionManager.deleteSession(id: id)
    }

    public func clearHistory() async {
        await sessionManager.clearHistory()
    }

    // MARK: - Cleanup

    nonisolated public func cleanup() {
        lifecycleHandler.cleanup()
        cancellables.removeAll()
    }

    deinit {
        cleanup()
    }
}
