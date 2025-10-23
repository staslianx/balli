//
//  AnalysisToolbar.swift
//  balli
//
//  Action buttons and toolbar for AI Analysis
//

import SwiftUI

/// Toolbar view with action buttons for analysis
public struct AnalysisToolbar: View {
    // MARK: - Properties

    /// Current analysis stage
    let currentStage: AnalysisStage

    /// Whether to show retry button
    let showRetryButton: Bool

    /// Actions
    let onCancel: () -> Void
    let onRetry: () -> Void
    let onManualEntry: () -> Void

    // Environment
    @Environment(\.colorScheme) private var colorScheme
    
    // MARK: - Body
    
    public var body: some View {
        VStack(spacing: ResponsiveDesign.Spacing.medium) {
            if showRetryButton {
                retrySection
            } else if currentStage != .completed && currentStage != .error {
                cancelButton
            }
        }
        .padding(.bottom, ResponsiveDesign.height(30))
    }
    
    // MARK: - Private Views
    
    private var retrySection: some View {
        VStack(spacing: ResponsiveDesign.Spacing.medium) {
            retryButton
            manualEntryButton
        }
    }
    
    private var retryButton: some View {
        Button(action: onRetry) {
            HStack(spacing: ResponsiveDesign.Spacing.small) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: ResponsiveDesign.Font.scaledSize(18), weight: .semibold, design: .rounded))
                Text("Tekrar Dene")
                    .font(.system(size: ResponsiveDesign.Font.scaledSize(18), weight: .semibold, design: .rounded))
            }
            .foregroundColor(.white)
            .frame(width: ResponsiveDesign.width(180))
            .frame(height: ResponsiveDesign.height(56))
            .background(AppTheme.adaptiveBalliGradient(for: colorScheme))
            .clipShape(Capsule())
            .shadow(color: AppTheme.primaryPurple.opacity(0.3), radius: ResponsiveDesign.height(4), x: 0, y: ResponsiveDesign.height(2))
        }
    }
    
    private var manualEntryButton: some View {
        Button(action: onManualEntry) {
            Text("Manuel Giriş")
                .font(.system(size: ResponsiveDesign.Font.scaledSize(18), weight: .semibold, design: .rounded))
                .foregroundColor(AppTheme.primaryPurple)
                .frame(width: ResponsiveDesign.width(180))
                .frame(height: ResponsiveDesign.height(48))
                .background(
                    Capsule()
                        .stroke(AppTheme.primaryPurple, lineWidth: 2)
                        .fill(Color.clear)
                )
        }
    }
    
    private var cancelButton: some View {
        // Show loading animation during analysis, cancel button on error
        Group {
            if currentStage == .error {
                Button(action: onCancel) {
                    Text("İptal Et")
                        .font(.system(size: ResponsiveDesign.Font.scaledSize(18), weight: .semibold, design: .rounded))
                        .foregroundColor(AppTheme.primaryPurple)
                        .frame(width: ResponsiveDesign.width(180))
                        .frame(height: ResponsiveDesign.height(56))
                        .background(
                            Capsule()
                                .fill(Color(.systemBackground))
                        )
                        .overlay(
                            Capsule()
                                .stroke(AppTheme.primaryPurple, lineWidth: 2)
                        )
                }
            } else {
                // Cancel button during analysis - allows user to stop the process
                cancelAnalysisButton
            }
        }
    }

    private var cancelAnalysisButton: some View {
        Button(action: onCancel) {
            Image(systemName: "xmark")
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundColor(.primary)
        }
        .toolbarCircularGlass(size: ResponsiveDesign.height(72))
    }
    
    // MARK: - Initialization
    
    public init(
        currentStage: AnalysisStage,
        showRetryButton: Bool,
        onCancel: @escaping () -> Void,
        onRetry: @escaping () -> Void,
        onManualEntry: @escaping () -> Void
    ) {
        self.currentStage = currentStage
        self.showRetryButton = showRetryButton
        self.onCancel = onCancel
        self.onRetry = onRetry
        self.onManualEntry = onManualEntry
    }
}