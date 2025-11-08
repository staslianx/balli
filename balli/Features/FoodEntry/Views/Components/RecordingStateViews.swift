//
//  RecordingStateViews.swift
//  balli
//
//  Recording state UI components for voice input
//  Swift 6 strict concurrency compliant
//

import SwiftUI

// MARK: - Processing State View

struct ProcessingStateView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack {
            Spacer()

            HStack(spacing: 12) {
                Image(systemName: "long.text.page.and.pencil.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryPurple)
                    .symbolEffect(.pulse.wholeSymbol, options: .repeat(.continuous))

                Text("Notumu alıyorum")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.7) : Color.black.opacity(0.7))
                    .shimmer(duration: 2.5, bounceBack: false)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Placeholder State View

struct PlaceholderStateView: View {
    let microphonePermissionGranted: Bool

    var body: some View {
        VStack {
            Spacer()

            VStack(spacing: ResponsiveDesign.Spacing.small) {
                if !microphonePermissionGranted {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 60))
                        .foregroundStyle(.red)

                    Text("Mikrofon İzni Gerekli")
                        .font(.system(size: 20, weight: .medium, design: .rounded))
                        .foregroundStyle(.red)

                    VStack(spacing: 8) {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.red)
                            Text("Mikrofon izni")
                                .foregroundStyle(.secondary)
                        }
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                    }
                    .padding(.horizontal)

                    Button {
                        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(settingsUrl)
                        }
                    } label: {
                        Text("Ayarları Aç")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(AppTheme.primaryPurple)
                            .clipShape(Capsule())
                    }
                    .padding(.top, ResponsiveDesign.Spacing.small)
                } else {
                    Image(systemName: "waveform.low")
                        .font(.system(size: 80, weight: .bold))
                        .foregroundStyle(.secondary.opacity(0.3))

                    Text("Kayıt için dokun")
                        .font(.system(size: 17, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Recording Active View

struct RecordingActiveView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack {
            Spacer()

            HStack(spacing: 12) {
                Image(systemName: "waveform")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryPurple)
                    .symbolEffect(.variableColor)

                Text("Dinliyorum")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.7) : Color.black.opacity(0.7))
                    .shimmer(duration: 2.5, bounceBack: false)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Previews

#Preview("Recording Active - Light") {
    RecordingActiveView()
        .preferredColorScheme(.light)
}

#Preview("Recording Active - Dark") {
    RecordingActiveView()
        .preferredColorScheme(.dark)
}

#Preview("Processing - Light") {
    ProcessingStateView()
        .preferredColorScheme(.light)
}

#Preview("Processing - Dark") {
    ProcessingStateView()
        .preferredColorScheme(.dark)
}

#Preview("All States") {
    VStack(spacing: 40) {
        RecordingActiveView()
            .frame(height: 200)
            .border(Color.gray.opacity(0.3))

        ProcessingStateView()
            .frame(height: 200)
            .border(Color.gray.opacity(0.3))
    }
    .padding()
}
