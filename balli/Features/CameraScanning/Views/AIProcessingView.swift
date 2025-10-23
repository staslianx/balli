//
//  AIProcessingView.swift
//  balli
//
//  AI nutrition analysis processing view
//

import SwiftUI

struct AIProcessingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    // The captured image to analyze
    let capturedImage: UIImage
    
    // Flow manager for processing state
    @ObservedObject var captureFlowManager: CaptureFlowManager
    
    // Callback when analysis completes successfully
    let onAnalysisComplete: (NutritionExtractionResult) -> Void
    
    var body: some View {
        ZStack {
            // Background
            Color(.systemGray6)
                .ignoresSafeArea()
            
            VStack {
                Spacer(minLength: ResponsiveDesign.height(50))
                
                // Photo with blur and analysis overlay
                analysisPhotoView
                
                Spacer(minLength: ResponsiveDesign.height(50))
                
                // Cancel button (only during analysis)
                Button(action: handleCancel) {
                    Text("İptal")
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundColor(AppTheme.primaryPurple)
                        .frame(width: ResponsiveDesign.width(140))
                        .frame(height: ResponsiveDesign.height(56))
                        .glassEffect(.regular.interactive(), in: Capsule())
                }
                .padding(.bottom, ResponsiveDesign.height(30))
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: handleCancel) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                }
            }
        }
        .onAppear {
            // Start analysis when view appears
            Task {
                await captureFlowManager.confirmAndProcess()
            }
        }
        .onChange(of: captureFlowManager.extractedNutrition) { oldValue, newValue in
            if let nutrition = newValue, !captureFlowManager.isAnalyzing {
                // Analysis completed successfully
                onAnalysisComplete(nutrition)
            }
        }
        .onChange(of: captureFlowManager.currentError) { oldValue, newValue in
            if newValue != nil {
                // Analysis failed - return to previous view
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    dismiss()
                }
            }
        }
    }
    
    private var analysisPhotoView: some View {
        ZStack {
            // Container
            RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.modal)
                .fill(Color.white)
                .frame(width: ResponsiveDesign.Components.foodLabelWidth, height: ResponsiveDesign.Components.foodLabelHeight)
                .overlay(
                    RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.modal)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.1), radius: ResponsiveDesign.height(10), x: 0, y: ResponsiveDesign.height(4))
                .overlay(
                    // Blurred image with analysis overlay
                    ZStack {
                        Image(uiImage: capturedImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(
                                width: ResponsiveDesign.Components.foodLabelWidth - ResponsiveDesign.Spacing.xSmall * 2,
                                height: ResponsiveDesign.Components.foodLabelHeight - ResponsiveDesign.Spacing.xSmall * 2
                            )
                            .blur(radius: 10)  // Always blurred during processing
                            .clipShape(RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.scanner))
                            .padding(ResponsiveDesign.Spacing.xSmall)
                        
                        // Analysis overlay
                        VStack(spacing: ResponsiveDesign.Spacing.medium) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.primaryPurple))
                                .scaleEffect(2)
                            
                            Text("Besin değerleri analiz ediliyor...")
                                .font(.system(size: 17, weight: .regular, design: .rounded))
                                .foregroundColor(.black)
                                .multilineTextAlignment(.center)
                            
                            if captureFlowManager.processingProgress > 0 {
                                VStack(spacing: ResponsiveDesign.Spacing.xSmall) {
                                    ProgressView(value: captureFlowManager.processingProgress)
                                        .progressViewStyle(LinearProgressViewStyle(tint: AppTheme.primaryPurple))
                                        .frame(width: ResponsiveDesign.width(200))
                                    
                                    Text("\(Int(captureFlowManager.processingProgress * 100))% tamamlandı")
                                        .font(.system(size: 12, weight: .regular, design: .rounded))
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            if let error = captureFlowManager.currentError {
                                Text("Hata: \(error.localizedDescription)")
                                    .font(.system(size: 12, weight: .regular, design: .rounded))
                                    .foregroundColor(.red)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .padding()
                        .background(Color.white.opacity(0.95))
                        .cornerRadius(ResponsiveDesign.CornerRadius.medium)
                    }
                )
        }
    }
    
    private func handleCancel() {
        // Cancel any ongoing processing
        Task {
            await captureFlowManager.cancelCapture()
        }
        dismiss()
    }
}

// MARK: - Preview
#Preview {
    AIProcessingView(
        capturedImage: UIImage(systemName: "photo.fill") ?? UIImage(),
        captureFlowManager: CaptureFlowManager(cameraManager: CameraManager()),
        onAnalysisComplete: { _ in print("Analysis complete") }
    )
}