//
//  AnalysisContentView.swift
//  balli
//
//  Main content view for AI Analysis progress display
//

import SwiftUI

/// Main content view showing analysis progress
public struct AnalysisContentView: View {
    // MARK: - Properties
    
    /// Current analysis stage
    let currentStage: AnalysisStage
    
    /// Visual progress (0.0 to 1.0)
    let visualProgress: Double
    
    /// Error message if any
    let errorMessage: String?
    
    /// Color scheme for dynamic colors
    @Environment(\.colorScheme) private var colorScheme
    
    // MARK: - Body
    
    public var body: some View {
        VStack(spacing: ResponsiveDesign.Spacing.large) {
            // Stage icon with animation
            stageIconSection
            
            // Status text
            statusTextSection
            
            // Progress bar with smooth animation
            progressBarSection
            
            // Stage indicators
            stageIndicators
        }
    }
    
    // MARK: - Private Views
    
    private var stageIconSection: some View {
        ZStack {
            Circle()
                .fill(currentStage.iconColor.opacity(0.1))
                .frame(
                    width: ResponsiveDesign.width(120),
                    height: ResponsiveDesign.height(120)
                )
            
            Circle()
                .stroke(currentStage.iconColor.opacity(0.3), lineWidth: 2)
                .frame(
                    width: ResponsiveDesign.width(120),
                    height: ResponsiveDesign.height(120)
                )
            
            Image(systemName: currentStage.icon)
                .font(.system(size: ResponsiveDesign.Font.scaledSize(50), weight: .regular, design: .rounded))
                .foregroundColor(currentStage.iconColor)
                .scaleEffect(currentStage == .completed ? 1.2 : 1.0)
                .animation(.spring(response: 0.5, dampingFraction: 0.6), value: currentStage)
        }
        .rotationEffect(.degrees(rotationDegrees))
        .animation(rotationAnimation, value: currentStage)
    }
    
    private var statusTextSection: some View {
        VStack(spacing: ResponsiveDesign.Spacing.xSmall) {
            Text(currentStage.message)
                .font(.system(size: ResponsiveDesign.Font.scaledSize(22), weight: .semibold, design: .rounded))
                .foregroundColor(colorScheme == .dark ? .white : .black)
                .multilineTextAlignment(.center)
                .animation(.easeInOut, value: currentStage)
            
            if let error = errorMessage {
                Text(error)
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.top, ResponsiveDesign.Spacing.xSmall)
            }
        }
    }
    
    private var progressBarSection: some View {
        VStack(spacing: ResponsiveDesign.Spacing.xSmall) {
            // Progress bar container
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: ResponsiveDesign.height(6))
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: ResponsiveDesign.height(12))
                    
                    // Progress fill - using mask for smooth animation
                    RoundedRectangle(cornerRadius: ResponsiveDesign.height(6))
                        .fill(
                            LinearGradient(
                                colors: [
                                    AppTheme.primaryPurple,
                                    AppTheme.lightPurple
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: ResponsiveDesign.height(12))
                        .mask(
                            HStack(spacing: 0) {
                                Rectangle()
                                    .frame(width: geometry.size.width * CGFloat(visualProgress))
                                Spacer(minLength: 0)
                            }
                        )
                        .animation(.spring(response: 0.8, dampingFraction: 0.8), value: visualProgress)
                    
                    // Shimmer overlay
                    if currentStage != .completed && currentStage != .error {
                        RoundedRectangle(cornerRadius: ResponsiveDesign.height(6))
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0),
                                        Color.white.opacity(0.2),
                                        Color.white.opacity(0)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: ResponsiveDesign.width(60), height: ResponsiveDesign.height(12))
                            .offset(x: shimmerAnimationOffset(for: geometry.size.width))
                            .animation(
                                .linear(duration: 2.0).repeatForever(autoreverses: false),
                                value: currentStage
                            )
                            .allowsHitTesting(false)
                            .mask(
                                HStack(spacing: 0) {
                                    Rectangle()
                                        .frame(width: geometry.size.width * CGFloat(visualProgress))
                                    Spacer(minLength: 0)
                                }
                            )
                    }
                }
            }
            .frame(maxWidth: ResponsiveDesign.width(300), maxHeight: ResponsiveDesign.height(12))
            
            // Percentage text
            percentageText
        }
    }
    
    private func shimmerAnimationOffset(for width: CGFloat) -> CGFloat {
        let progressWidth = width * CGFloat(visualProgress)
        return progressWidth > ResponsiveDesign.width(30) ? progressWidth - ResponsiveDesign.width(30) : 0
    }
    
    private var percentageText: some View {
        Text("\(Int(visualProgress * 100))%")
            .font(.system(size: ResponsiveDesign.Font.scaledSize(16), weight: .medium, design: .rounded))
            .foregroundColor(AppTheme.primaryPurple)
            .monospacedDigit()
    }
    
    private var stageIndicators: some View {
        HStack(spacing: ResponsiveDesign.Spacing.small) {
            ForEach(allStages, id: \.self) { stage in
                Circle()
                    .fill(
                        visualProgress >= stage.targetProgress
                            ? AppTheme.primaryPurple
                            : Color.gray.opacity(0.3)
                    )
                    .frame(
                        width: ResponsiveDesign.width(8),
                        height: ResponsiveDesign.height(8)
                    )
                    .animation(.easeInOut(duration: 0.3), value: visualProgress)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var rotationDegrees: Double {
        currentStage == .processing ? 360 : 0
    }
    
    private var rotationAnimation: Animation? {
        currentStage == .processing
            ? .linear(duration: 2).repeatForever(autoreverses: false)
            : .default
    }
    
    private var allStages: [AnalysisStage] {
        [.preparing, .analyzing, .reading, .sending, .processing, .validating]
    }
    
    // MARK: - Initialization
    
    public init(
        currentStage: AnalysisStage,
        visualProgress: Double,
        errorMessage: String?
    ) {
        self.currentStage = currentStage
        self.visualProgress = visualProgress
        self.errorMessage = errorMessage
    }
}