//
//  AIAnalysisView.swift
//  balli
//
//  AI Analysis View - Refactored container view for analysis flow
//

import SwiftUI
import Combine

/// Main AI Analysis view container
struct AIAnalysisView: View {
    // MARK: - Environment
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    // MARK: - Properties
    
    /// The captured image to analyze
    let capturedImage: UIImage
    
    /// Flow manager for processing state
    @ObservedObject var captureFlowManager: CaptureFlowManager
    
    /// Callback when analysis completes successfully
    let onAnalysisComplete: (NutritionExtractionResult) -> Void
    
    // MARK: - View Model
    
    @StateObject private var viewModel: AnalysisViewModel
    
    // MARK: - Initialization
    
    init(
        capturedImage: UIImage,
        captureFlowManager: CaptureFlowManager,
        onAnalysisComplete: @escaping (NutritionExtractionResult) -> Void
    ) {
        self.capturedImage = capturedImage
        self.captureFlowManager = captureFlowManager
        self.onAnalysisComplete = onAnalysisComplete
        
        // Initialize view model
        self._viewModel = StateObject(wrappedValue: AnalysisViewModel(
            capturedImage: capturedImage,
            captureFlowManager: captureFlowManager,
            onAnalysisComplete: onAnalysisComplete
        ))
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Background gradient
            backgroundGradient
            
            // Main content with nutrition label preview
            VStack {
                Spacer(minLength: ResponsiveDesign.height(50))

                // Nutrition label during analysis
                AnalysisNutritionLabelView(
                    capturedImage: capturedImage,
                    currentStage: viewModel.currentStage,
                    visualProgress: viewModel.visualProgress,
                    errorMessage: viewModel.errorMessage,
                    nutritionResult: captureFlowManager.extractedNutrition
                )

                Spacer(minLength: ResponsiveDesign.height(50))

                // Action toolbar
                AnalysisToolbar(
                    currentStage: viewModel.currentStage,
                    showRetryButton: viewModel.showRetryButton,
                    onCancel: handleCancel,
                    onRetry: { viewModel.handleRetry() },
                    onManualEntry: handleManualEntry
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, ResponsiveDesign.Spacing.large)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            navigationToolbar
        }
        .onAppear {
            handleAppear()
        }
        .onDisappear {
            handleDisappear()
        }
        .onChange(of: captureFlowManager.extractedNutrition) { oldValue, newValue in
            viewModel.handleNutritionUpdate(newValue)
        }
        .onChange(of: captureFlowManager.currentError) { oldValue, newValue in
            viewModel.handleErrorUpdate(newValue)
        }
    }
    
    // MARK: - Private Views
    
    private var backgroundGradient: some View {
        Color(.systemGray6)
            .ignoresSafeArea()
    }
    
    @ToolbarContentBuilder
    private var navigationToolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button(action: handleCancel) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium, design: .rounded))
            }
            .disabled(viewModel.currentStage == .completed)
        }
    }
    
    // MARK: - Actions
    
    private func handleAppear() {
        viewModel.setViewVisible(true)
        viewModel.startAnalysis()
    }
    
    private func handleDisappear() {
        viewModel.setViewVisible(false)
    }
    
    private func handleCancel() {
        Task {
            await viewModel.handleCancel()
            dismiss()
        }
    }
    
    private func handleManualEntry() {
        // Note: Manual entry navigation could be implemented here
        dismiss()
    }
}

// MARK: - Preview

#Preview("Analysis in Progress") {
    NavigationStack {
        AIAnalysisView(
            capturedImage: UIImage(systemName: "photo.fill") ?? UIImage(),
            captureFlowManager: {
                let manager = CaptureFlowManager(cameraManager: CameraManager())
                manager.isAnalyzing = true
                return manager
            }(),
            onAnalysisComplete: { _ in print("Analysis complete") }
        )
    }
}

#Preview("Analysis with Error") {
    NavigationStack {
        AIAnalysisView(
            capturedImage: UIImage(systemName: "photo.fill") ?? UIImage(),
            captureFlowManager: {
                let manager = CaptureFlowManager(cameraManager: CameraManager())
                manager.currentError = .networkUnavailable
                return manager
            }(),
            onAnalysisComplete: { _ in print("Analysis complete") }
        )
    }
}