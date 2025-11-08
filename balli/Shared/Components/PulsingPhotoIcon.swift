//
//  PulsingPhotoIcon.swift
//  balli
//
//  Shimmer icon shown during photo generation
//  Uses shimmer effect only for clean, consistent UX
//

import SwiftUI

/// Spatial.capture icon with shimmer shown during photo generation
/// Uses shimmer effect only
struct PulsingPhotoIcon: View {
    var body: some View {
        Image(systemName: "spatial.capture")
            .font(.system(size: 64, weight: .light))
            .foregroundStyle(.white.opacity(0.8))
            .shimmer(duration: 2.5, bounceBack: false)
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
