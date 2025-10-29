//
//  PulsingPhotoIcon.swift
//  balli
//
//  Pulsing icon shown during photo generation
//  Uses opacity-only animation for clean, consistent UX
//

import SwiftUI

/// Pulsing spatial.capture icon shown during photo generation
/// Uses opacity animation only - no scale, no text
struct PulsingPhotoIcon: View {
    @State private var isAnimating = false

    var body: some View {
        Image(systemName: "spatial.capture")
            .font(.system(size: 64, weight: .light))
            .foregroundStyle(.white.opacity(0.8))
            .opacity(isAnimating ? 0.3 : 1.0)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    isAnimating = true
                }
            }
    }
}

#Preview("Pulsing Photo Icon") {
    ZStack {
        // Dark background to simulate hero image
        LinearGradient(
            colors: [
                ThemeColors.primaryPurple,
                ThemeColors.lightPurple
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        PulsingPhotoIcon()
    }
}
