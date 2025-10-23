//
//  LoadingView.swift
//  balli
//
//  Standardized loading view component
//

import SwiftUI

struct LoadingView: View {
    let message: String?
    let style: LoadingStyle
    let progress: Double?
    
    @State private var isAnimating = false
    @State private var rotationAngle: Double = 0
    @Environment(\.colorScheme) private var colorScheme
    
    enum LoadingStyle {
        case standard
        case overlay
        case inline
        case fullScreen
        case skeleton
    }
    
    init(
        message: String? = nil,
        style: LoadingStyle = .standard,
        progress: Double? = nil
    ) {
        self.message = message
        self.style = style
        self.progress = progress
    }
    
    var body: some View {
        switch style {
        case .standard:
            standardView
        case .overlay:
            overlayView
        case .inline:
            inlineView
        case .fullScreen:
            fullScreenView
        case .skeleton:
            skeletonView
        }
    }
    
    // MARK: - Standard Loading View
    private var standardView: some View {
        VStack(spacing: ResponsiveDesign.Spacing.medium) {
            balliLoader
            
            if let message = message {
                Text(message)
                    .font(.system(size: 17, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            if let progress = progress {
                ProgressView(value: progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: AppTheme.primaryPurple))
                    .frame(width: ResponsiveDesign.width(200))
                
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary)
            }
        }
        .padding(ResponsiveDesign.Spacing.large)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Overlay Loading View
    private var overlayView: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: ResponsiveDesign.Spacing.medium) {
                balliLoader
                
                if let message = message {
                    Text(message)
                        .font(.system(size: 16, weight: .regular, design: .rounded))
                        .foregroundColor(.primary)
                        .padding(.horizontal)
                }
            }
            .padding(ResponsiveDesign.Spacing.large)
            .background(Color(.systemBackground).opacity(0.95))
            .clipShape(RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.large, style: .continuous))
            .shadow(radius: ResponsiveDesign.height(10))
        }
    }
    
    // MARK: - Inline Loading View
    private var inlineView: some View {
        HStack(spacing: ResponsiveDesign.Spacing.small) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.primaryPurple))
                .scaleEffect(0.8)
            
            if let message = message {
                Text(message)
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, ResponsiveDesign.Spacing.xSmall)
    }
    
    // MARK: - Full Screen Loading View
    private var fullScreenView: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [
                    AppTheme.primaryPurple.opacity(0.1),
                    AppTheme.accentColor.opacity(0.1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: ResponsiveDesign.Spacing.xLarge) {
                // Animated Logo
                Image("AppIcon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: ResponsiveDesign.width(120), height: ResponsiveDesign.width(120))
                    .scaleEffect(isAnimating ? 1.1 : 0.9)
                    .animation(
                        .easeInOut(duration: 1.0)
                        .repeatForever(autoreverses: true),
                        value: isAnimating
                    )
                
                balliLoader
                
                if let message = message {
                    Text(message)
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                if let progress = progress {
                    VStack(spacing: ResponsiveDesign.Spacing.small) {
                        ProgressView(value: progress)
                            .progressViewStyle(LinearProgressViewStyle(tint: AppTheme.primaryPurple))
                            .frame(width: ResponsiveDesign.width(250))
                        
                        Text("\(Int(progress * 100))%")
                            .font(.system(size: 16, weight: .regular, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
    
    // MARK: - Skeleton Loading View
    private var skeletonView: some View {
        VStack(spacing: ResponsiveDesign.Spacing.medium) {
            ForEach(0..<3) { _ in
                HStack(spacing: ResponsiveDesign.Spacing.medium) {
                    RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.small)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: ResponsiveDesign.width(60), height: ResponsiveDesign.width(60))

                    VStack(alignment: .leading, spacing: ResponsiveDesign.Spacing.xSmall) {
                        RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.xSmall)
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: ResponsiveDesign.height(20))

                        RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.xSmall)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: ResponsiveDesign.width(150), height: ResponsiveDesign.height(16))
                    }

                    Spacer()
                }
                .padding(ResponsiveDesign.Spacing.medium)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.medium, style: .continuous))
            }
        }
        .padding()
    }
    
    // MARK: - Custom Balli Loader
    private var balliLoader: some View {
        ZStack {
            // Outer ring
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [AppTheme.primaryPurple, AppTheme.accentColor],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: ResponsiveDesign.height(3)
                )
                .frame(width: ResponsiveDesign.width(60), height: ResponsiveDesign.width(60))
                .rotationEffect(Angle(degrees: rotationAngle))
            
            // Inner dots
            ForEach(0..<8) { index in
                Circle()
                    .fill(AppTheme.primaryPurple.opacity(Double(index) / 8))
                    .frame(width: ResponsiveDesign.width(8), height: ResponsiveDesign.width(8))
                    .offset(y: -ResponsiveDesign.width(25))
                    .rotationEffect(Angle(degrees: Double(index) * 45 + rotationAngle))
            }
        }
        .onAppear {
            withAnimation(
                .linear(duration: 2)
                .repeatForever(autoreverses: false)
            ) {
                rotationAngle = 360
            }
        }
    }
}

// MARK: - Activity Indicator Modifier
struct ActivityIndicator: ViewModifier {
    let isLoading: Bool
    let message: String?
    
    func body(content: Content) -> some View {
        ZStack {
            content
                .disabled(isLoading)
            
            if isLoading {
                LoadingView(message: message, style: .overlay)
            }
        }
    }
}

extension View {
    func activityIndicator(isLoading: Bool, message: String? = nil) -> some View {
        modifier(ActivityIndicator(isLoading: isLoading, message: message))
    }
}

// MARK: - Preview
#Preview("Standard Loading") {
    LoadingView(
        message: "Yükleniyor...",
        style: .standard
    )
}

#Preview("Overlay Loading") {
    ZStack {
        Color.blue.opacity(0.3)
        
        LoadingView(
            message: "Lütfen bekleyin...",
            style: .overlay
        )
    }
}

#Preview("Full Screen Loading") {
    LoadingView(
        message: "Balli başlatılıyor...",
        style: .fullScreen,
        progress: 0.7
    )
}

#Preview("Skeleton Loading") {
    LoadingView(style: .skeleton)
}