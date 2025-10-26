//
//  VoiceGlowView.swift
//  balli
//
//  Voice-reactive glow animation for speech input
//  Shoots up from bottom of screen with purple color
//

import SwiftUI

/// Voice-reactive glow animation that shoots up from bottom of screen
/// Reacts to user's voice amplitude with smooth, damped response
struct VoiceGlowView: View {
    let audioLevel: Float // 0.0 to 1.0

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size

            // Calculate glow height directly from audio level
            let baseHeight: CGFloat = 300  // Much larger base for always-visible glow
            let maxReactiveHeight: CGFloat = size.height * 0.7  // More reactive range

            // Dramatic amplification for high sensitivity
            let amplifiedLevel = min(1.0, audioLevel * 4.0)

            let targetHeight = baseHeight + (CGFloat(amplifiedLevel) * maxReactiveHeight)

            ZStack {
                // Layer 1: Outermost glow (most blurred, largest)
                GlowLayer(height: targetHeight, size: size)
                    .blur(radius: 100)
                    .opacity(0.3)

                // Layer 2: Mid glow
                GlowLayer(height: targetHeight * 0.8, size: size)
                    .blur(radius: 60)
                    .opacity(0.4)

                // Layer 3: Inner glow
                GlowLayer(height: targetHeight * 0.6, size: size)
                    .blur(radius: 35)
                    .opacity(0.5)

                // Layer 4: Core (least blurred, brightest)
                GlowLayer(height: targetHeight * 0.4, size: size)
                    .blur(radius: 20)
                    .opacity(0.6)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

/// Single glow layer with elliptical gradient in purple (wider than tall)
struct GlowLayer: View {
    let height: CGFloat
    let size: CGSize

    var body: some View {
        VStack {
            Spacer()

            // Elliptical gradient for wider, shorter organic glow shape
            EllipticalGradient(
                gradient: Gradient(colors: [
                    AppTheme.primaryPurple.opacity(0.9),
                    AppTheme.primaryPurple.opacity(0.6),
                    AppTheme.primaryPurple.opacity(0.3),
                    Color.clear
                ]),
                center: .bottom,
                startRadiusFraction: 0,
                endRadiusFraction: 1.0
            )
            .frame(width: size.width * 1.5, height: height * 0.6)
            .offset(x: -size.width * 0.25) // Shift left to perfectly center the oversized glow
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: height)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        VoiceGlowView(audioLevel: 0.7)
    }
}
