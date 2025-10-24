//
//  LoadingSplashView.swift
//  balli
//
//  Professional loading screen for app initialization
//  Shows progress and current operation
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

            // Content
            VStack(spacing: 40) {
                Spacer()

                // Logo with animation
                logoView

                // Progress section
                progressView

                Spacer()
            }
            .padding(.horizontal, 32)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.3)) {
                logoOpacity = 1.0
            }

            // Start pulse animation
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                logoPulse = true
            }
        }
    }

    // MARK: - Logo View

    private var logoView: some View {
        Image("balli-logo")
            .resizable()
            .scaledToFit()
            .frame(width: 100, height: 100)
            .opacity(logoOpacity)
            .scaleEffect(logoPulse ? 1.05 : 1.0)
    }

    // MARK: - Progress View

    private var progressView: some View {
        VStack(spacing: 16) {
            // Progress bar
            ProgressView(value: progress)
                .tint(AppTheme.primaryPurple)
                .frame(width: 240)
                .scaleEffect(y: 2.0) // Make bar thicker

            // Progress percentage and operation
            VStack(spacing: 4) {
                // Percentage
                Text("\(Int(progress * 100))%")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.primaryPurple)

                // Operation text
                Text(operation)
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    .id(operation) // Force SwiftUI to animate text changes
            }
            .frame(height: 50) // Fixed height to prevent layout shifts
        }
    }
}

// MARK: - Previews

#Preview("Loading - 0%") {
    LoadingSplashView(
        progress: 0.0,
        operation: "Kullanıcı profili yükleniyor..."
    )
}

#Preview("Loading - 30%") {
    LoadingSplashView(
        progress: 0.3,
        operation: "Veritabanı hazırlanıyor..."
    )
}

#Preview("Loading - 60%") {
    LoadingSplashView(
        progress: 0.6,
        operation: "Sağlık izinleri kontrol ediliyor..."
    )
}

#Preview("Loading - 100%") {
    LoadingSplashView(
        progress: 1.0,
        operation: "Hazır!"
    )
}

#Preview("Loading - Dark Mode") {
    LoadingSplashView(
        progress: 0.5,
        operation: "Uygulama ayarları yapılandırılıyor..."
    )
    .preferredColorScheme(.dark)
}
