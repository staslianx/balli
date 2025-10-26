//
//  LaunchTransitionView.swift
//  balli
//
//  Created on 2025-08-10
//  Purpose: Provides a smooth transition from system font launch screen to custom font app
//

import SwiftUI

/// A view that mimics the launch screen but with custom fonts
/// This creates a seamless transition from the system font launch screen
/// to the app's custom Galano Grotesque font
struct LaunchTransitionView: View {
    @State private var isAnimating = false
    @State private var shouldTransition = false
    
    /// Duration of the transition animation
    private let animationDuration: Double = 0.5
    
    /// Delay before transitioning to main app
    private let transitionDelay: Double = 0.3
    
    var body: some View {
        ZStack {
            // Match the launch screen background
            Color(UIColor.systemBackground)
                .ignoresSafeArea()
            
            // Logo and text container matching launch screen layout
            HStack(spacing: 0) {
                // Logo image
                Image("balli-logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                
                // "balli" text with custom font
                Text("balli")
                    .font(.system(size: 48, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                    .opacity(isAnimating ? 1 : 0)
                    .scaleEffect(isAnimating ? 1 : 0.95)
            }
            .frame(height: 50)
        }
        .onAppear {
            // Smooth fade-in animation for custom font
            withAnimation(.easeInOut(duration: animationDuration)) {
                isAnimating = true
            }
            
            // Trigger transition to main app after brief display
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64((transitionDelay + animationDuration) * 1_000_000_000))
                shouldTransition = true
            }
        }
    }
}

/// Extension to handle the launch transition in the main app
extension View {
    /// Wraps the view with a launch transition if needed
    /// - Parameter showTransition: Whether to show the transition view
    /// - Returns: The view with or without transition
    func withLaunchTransition(_ showTransition: Bool = true) -> some View {
        Group {
            if showTransition {
                ZStack {
                    self
                    LaunchTransitionView()
                        .transition(.opacity)
                }
            } else {
                self
            }
        }
    }
}

#Preview("Launch Transition") {
    LaunchTransitionView()
}

#Preview("Launch Transition Dark") {
    LaunchTransitionView()
        .preferredColorScheme(.dark)
}
