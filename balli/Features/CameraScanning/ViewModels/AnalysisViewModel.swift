//
//  AnalysisViewModel.swift
//  balli
//
//  ViewModel for AI Analysis with business logic and state management
//

import SwiftUI
import Combine
import UIKit

/// ViewModel managing all analysis business logic and state
@MainActor
public final class AnalysisViewModel: ObservableObject {
    // MARK: - Published Properties

    // PERFORMANCE: ViewState pattern consolidates processing state
    @Published public var analysisState: ViewState<NutritionExtractionResult> = .idle

    /// Visual progress animation (0.0 to 1.0) - separate UI concern
    @Published public var visualProgress: Double = 0

    /// Current analysis stage - separate UI concern
    @Published public var currentStage: AnalysisStage = .preparing

    /// Whether to show retry button - derived from error state
    @Published public var showRetryButton = false

    // MARK: - Convenience Properties

    /// Error message to display (derived from analysisState)
    public var errorMessage: String? {
        if let error = analysisState.error as? CaptureError {
            return formatErrorMessage(error)
        }
        return analysisState.error?.localizedDescription
    }

    /// Track if real processing is complete (derived from analysisState)
    public var isRealProcessingComplete: Bool {
        analysisState.isLoaded || analysisState.isError
    }

    // MARK: - Private Properties

    /// The captured image being analyzed
    public let capturedImage: UIImage

    /// Flow manager for processing state
    public let captureFlowManager: CaptureFlowManager

    /// Callback when analysis completes successfully
    private let onAnalysisComplete: (NutritionExtractionResult) -> Void
    
    /// Analysis timing
    private var analysisStartTime = Date()
    private var stageStartTime = Date()
    
    /// Task for visual progress updates (replaces legacy Timer)
    private var timerTask: Task<Void, Never>?

    /// View visibility for battery optimization
    private var isViewVisible = false
    
    // MARK: - Constants
    
    /// Stage duration in seconds
    private let stageDuration: TimeInterval = 1.5
    
    /// Total visual animation duration
    private let totalVisualDuration: TimeInterval = 6.0
    
    // MARK: - Initialization
    
    public init(
        capturedImage: UIImage,
        captureFlowManager: CaptureFlowManager,
        onAnalysisComplete: @escaping (NutritionExtractionResult) -> Void
    ) {
        self.capturedImage = capturedImage
        self.captureFlowManager = captureFlowManager
        self.onAnalysisComplete = onAnalysisComplete
    }
    
    // MARK: - Public Methods
    
    /// Start the analysis process
    public func startAnalysis() {
        // Reset visual state
        visualProgress = 0
        currentStage = .preparing
        showRetryButton = false
        analysisStartTime = Date()
        stageStartTime = Date()

        // Set loading state
        analysisState = .loading

        // Start visual timer (1 FPS for battery optimization)
        startVisualTimer()

        // Start actual AI processing in background
        Task { [captureFlowManager] in
            await captureFlowManager.confirmAndProcess()
        }
    }
    
    /// Handle retry action
    public func handleRetry() {
        showRetryButton = false
        startAnalysis()
    }
    
    /// Cancel the analysis
    public func handleCancel() async {
        stopVisualTimer()
        
        // Cancel any ongoing processing
        await captureFlowManager.cancelCapture()
    }
    
    /// Set view visibility for battery optimization
    public func setViewVisible(_ visible: Bool) {
        isViewVisible = visible
        if visible {
            startVisualTimer()
        } else {
            stopVisualTimer()
        }
    }
    
    /// Handle nutrition extraction result
    public func handleNutritionUpdate(_ nutrition: NutritionExtractionResult?) {
        guard let nutrition = nutrition else { return }
        analysisState = .loaded(nutrition)
    }

    /// Handle capture error
    public func handleErrorUpdate(_ error: CaptureError?) {
        guard let error = error else { return }
        analysisState = .error(error)
    }
    
    // MARK: - Private Methods

    private func startVisualTimer() {
        stopVisualTimer()
        timerTask = Task { [weak self] in
            for await _ in AsyncTimerSequence(interval: .seconds(1)) {
                guard !Task.isCancelled else { break }
                guard let self = self, self.isViewVisible else { continue }

                // Early termination optimization: If real processing completes quickly (< 2 seconds),
                // skip the artificial visual delay and complete immediately for better perceived performance
                let elapsed = Date().timeIntervalSince(self.analysisStartTime)
                if self.isRealProcessingComplete && elapsed < 2.0 {
                    self.visualProgress = 1.0
                    self.currentStage = .completed
                    self.completeAnalysis()
                    break
                }

                self.updateVisualProgress()
            }
        }
    }

    private func stopVisualTimer() {
        timerTask?.cancel()
        timerTask = nil
    }
    
    private func updateVisualProgress() {
        guard isViewVisible && currentStage != .error else { return }
        
        // Calculate time elapsed since start
        let elapsed = Date().timeIntervalSince(analysisStartTime)
        
        // Calculate target progress based on time (6 seconds total)
        let timeBasedProgress = min(elapsed / totalVisualDuration, 1.0)
        
        // If real processing is complete, allow completion
        // Otherwise, cap at 95% until real processing finishes
        let maxAllowedProgress = isRealProcessingComplete ? 1.0 : 0.95
        let targetProgress = min(timeBasedProgress, maxAllowedProgress)
        
        visualProgress = targetProgress
        
        // Update stage based on visual progress
        updateStageFromVisualProgress()
        
        // Check for completion
        if isRealProcessingComplete && visualProgress >= 0.98 {
            completeAnalysis()
        }
    }
    
    private func updateStageFromVisualProgress() {
        let newStage: AnalysisStage
        
        // Use target progress values from AnalysisConstants
        if visualProgress < AnalysisStage.preparing.targetProgress {
            newStage = .preparing
        } else if visualProgress < AnalysisStage.analyzing.targetProgress {
            newStage = .analyzing
        } else if visualProgress < AnalysisStage.reading.targetProgress {
            newStage = .reading
        } else if visualProgress < AnalysisStage.sending.targetProgress {
            newStage = .sending
        } else if visualProgress < AnalysisStage.processing.targetProgress {
            newStage = .processing
        } else if visualProgress < AnalysisStage.validating.targetProgress {
            newStage = .validating
        } else {
            newStage = .validating // Stay at validating instead of completed
        }
        
        if newStage != currentStage {
            currentStage = newStage
            stageStartTime = Date()
        }
    }
    
    private func completeAnalysis() {
        // Complete the visual progress
        visualProgress = 1.0
        currentStage = .completed

        // Handle result or error based on analysisState
        switch analysisState {
        case .loaded(let nutrition):
            handleSuccessfulAnalysis(nutrition)
        case .error(let error):
            if let captureError = error as? CaptureError {
                handleError(captureError)
            }
        default:
            break
        }
    }
    
    private func handleSuccessfulAnalysis(_ nutrition: NutritionExtractionResult) {
        // Haptic feedback
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        // Stop timer
        stopVisualTimer()

        // Directly transition to result view without completion state
        onAnalysisComplete(nutrition)
    }
    
    private func formatErrorMessage(_ error: CaptureError) -> String {
        switch error {
        case .networkUnavailable:
            return "İnternet bağlantısı yok. Lütfen bağlantınızı kontrol edin."
        case .rateLimitExceeded:
            return "Günlük tarama limitiniz doldu. Yarın tekrar deneyebilirsiniz."
        case .imageConversionFailed, .optimizationFailed:
            return "Fotoğraf işlenemedi. Lütfen tekrar çekin."
        case .aiProcessingFailed(let message):
            if message.contains("permission") || message.contains("403") {
                return "AI servisi geçici olarak kullanılamıyor."
            } else {
                return "Besin değerleri okunamadı. Daha net bir fotoğraf çekin."
            }
        default:
            return error.localizedDescription
        }
    }

    private func handleError(_ error: CaptureError) {
        currentStage = .error

        // Set retry button based on error type
        switch error {
        case .rateLimitExceeded:
            showRetryButton = false
        default:
            showRetryButton = true
        }

        // Haptic feedback
        UINotificationFeedbackGenerator().notificationOccurred(.error)

        // Stop timer
        stopVisualTimer()
    }
    
}