//
//  AnalysisHeaderView.swift
//  balli
//
//  Header section for AI Analysis with image preview
//

import SwiftUI

/// Header view showing the captured image preview
public struct AnalysisHeaderView: View {
    // MARK: - Properties
    
    /// The captured image to display
    let capturedImage: UIImage
    
    /// Current analysis stage for animation
    let currentStage: AnalysisStage
    
    /// Visual progress for overlay effects
    let visualProgress: Double
    
    // MARK: - Body
    
    public var body: some View {
        HStack {
            Spacer()
            
            ZStack {
                // Container with shadow
                containerBackground
                
                // Image with overlay
                imageContent
            }
            
            Spacer()
        }
        .padding(.top, ResponsiveDesign.Spacing.medium)
    }
    
    // MARK: - Private Views
    
    private var containerBackground: some View {
        RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.medium)
            .fill(Color.white)
            .frame(
                width: ResponsiveDesign.width(100),
                height: ResponsiveDesign.height(100)
            )
            .shadow(
                color: .black.opacity(0.1),
                radius: ResponsiveDesign.height(5)
            )
    }
    
    private var imageContent: some View {
        Image(uiImage: capturedImage)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(
                width: ResponsiveDesign.width(96),
                height: ResponsiveDesign.height(96)
            )
            .clipShape(RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.small))
            .overlay(imageOverlay)
            .overlay(progressOverlay)
    }
    
    private var imageOverlay: some View {
        RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.small)
            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
    }
    
    private var progressOverlay: some View {
        Group {
            if currentStage != .completed && currentStage != .error {
                RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.small)
                    .fill(
                        LinearGradient(
                            colors: [
                                AppTheme.primaryPurple.opacity(0.3),
                                AppTheme.lightPurple.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .opacity(1.0 - visualProgress)
                    .animation(.easeInOut(duration: 0.3), value: visualProgress)
            }
        }
    }
    
    // MARK: - Initialization
    
    public init(
        capturedImage: UIImage,
        currentStage: AnalysisStage,
        visualProgress: Double
    ) {
        self.capturedImage = capturedImage
        self.currentStage = currentStage
        self.visualProgress = visualProgress
    }
}