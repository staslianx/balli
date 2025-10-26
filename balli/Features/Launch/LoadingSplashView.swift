//
//  LoadingSplashView.swift
//  balli
//
//  Launch screen for app initialization
//  Shows the balli logo while loading happens in background
//

import SwiftUI

struct LoadingSplashView: View {

    // MARK: - Properties

    let progress: Double
    let operation: String

    // MARK: - Animation State

    @State private var logoOpacity: Double = 0.0
    @State private var logoPulse: Bool = false

    // MARK: - Body

    var body: some View {
        ZStack {
            // Background
            Color(.systemBackground)
                .ignoresSafeArea()

            // Content - Just the logo, no progress bar
            VStack {
                Spacer()

                // Logo with subtle animation
                Image("balli-text-logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200)
                    .opacity(logoOpacity)
                    .scaleEffect(logoPulse ? 1.02 : 1.0)

                Spacer()
            }
            .padding(.horizontal, 32)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.6)) {
                logoOpacity = 1.0
            }

            // Gentle pulse animation
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                logoPulse = true
            }
        }
    }
}

// MARK: - Previews

#Preview("Launch Screen - Light") {
    LoadingSplashView(
        progress: 0.5,
        operation: "Loading..."
    )
}

#Preview("Launch Screen - Dark") {
    LoadingSplashView(
        progress: 0.5,
        operation: "Loading..."
    )
    .preferredColorScheme(.dark)
}
