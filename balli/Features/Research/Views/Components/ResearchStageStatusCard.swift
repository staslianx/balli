//
//  ResearchStageStatusCard.swift
//  balli
//
//  Research stage status card with progress bar and shimmer effect
//  Swift 6 strict concurrency compliant
//

import SwiftUI

/// Displays current research stage with animated progress bar and shimmer text
struct ResearchStageStatusCard: View {
    let stageMessage: String
    let progress: Double // 0.0 to 1.0
    let isActive: Bool // Controls shimmer animation

    @Environment(\.colorScheme) private var colorScheme
    @State private var animatedProgress: Double = 0.0

    init(stageMessage: String, progress: Double, isActive: Bool = true) {
        self.stageMessage = stageMessage
        self.progress = progress
        self.isActive = isActive
    }

    /// Map stage message to appropriate SF Symbol
    private var stageIcon: String {
        switch stageMessage {
        case "Araştırma planını yapıyorum":
            return "pencil.and.ruler"
        case "Araştırmaya başlıyorum":
            return "text.magnifyingglass"
        case "Kaynakları topluyorum":
            return "document.badge.plus"
        case "Kaynakları değerlendiriyorum":
            return "waveform.path.ecg.magnifyingglass"
        case "Ek kaynaklar arıyorum":
            return "plus.magnifyingglass"
        case "Ek kaynakları inceliyorum":
            return "waveform.path.ecg.magnifyingglass"
        case "En ilgili kaynakları seçiyorum":
            return "checkmark.seal.text.page"
        case "Bilgileri bir araya getiriyorum":
            return "list.star"
        case "Kapsamlı bir rapor yazıyorum":
            return "text.word.spacing"
        default:
            return "circle.fill"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Status text with stage-specific icon (fixed height to prevent jumping)
            HStack(spacing: 10) {
                Image(systemName: stageIcon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryPurple)
                    .symbolEffect(.pulse, options: .repeating)
                    .frame(width: 18, height: 18) // Fixed frame to prevent height variations
                    .aspectRatio(contentMode: .fit)

                Text(stageMessage)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.5) : Color.black.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
                    .modifier(
                        ConditionalShimmer(
                            isActive: isActive,
                            duration: 2.5,
                            bounceBack: false
                        )
                    )
            }
            .frame(height: 20, alignment: .leading) // Fixed height to prevent layout shift

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.15))
                        .frame(height: 8)

                    // Filled progress
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [
                                    AppTheme.primaryPurple,
                                    AppTheme.primaryPurple.opacity(0.7)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * animatedProgress, height: 8)
                }
            }
            .frame(height: 8)
        }
        .padding(25)
        .background {
            RoundedRectangle(cornerRadius: 38, style: .continuous)
                .fill(Color(.systemBackground).opacity(0.95))
        }
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 36, style: .continuous))
        .onChange(of: progress) { oldValue, newValue in
            // Animate progress bar smoothly
            withAnimation(.easeInOut(duration: 0.5)) {
                animatedProgress = newValue
            }
        }
        .onAppear {
            // Initialize progress with animation
            withAnimation(.easeInOut(duration: 0.5)) {
                animatedProgress = progress
            }
        }
    }
}

// MARK: - Previews

#Preview("Research Stage Status - Light Mode") {
    VStack(spacing: 20) {
        ResearchStageStatusCard(
            stageMessage: "Araştırma planını yapıyorum",
            progress: 0.15
        )

        ResearchStageStatusCard(
            stageMessage: "Kaynakları topluyorum",
            progress: 0.35
        )

        ResearchStageStatusCard(
            stageMessage: "En ilgili kaynakları seçiyorum",
            progress: 0.75
        )

        ResearchStageStatusCard(
            stageMessage: "Kapsamlı bir rapor yazıyorum",
            progress: 0.95
        )
    }
    .padding()
    .background(Color(.systemBackground))
}

#Preview("Research Stage Status - Dark Mode") {
    VStack(spacing: 20) {
        ResearchStageStatusCard(
            stageMessage: "Bilgileri bir araya getiriyorum",
            progress: 0.60
        )

        ResearchStageStatusCard(
            stageMessage: "Ek kaynaklar arıyorum",
            progress: 0.45
        )
    }
    .padding()
    .background(Color(.systemBackground))
    .preferredColorScheme(.dark)
}

#Preview("Progress Animation Test") {
    struct AnimationTest: View {
        @State private var progress: Double = 0.0

        var body: some View {
            VStack(spacing: 20) {
                ResearchStageStatusCard(
                    stageMessage: "Kaynakları değerlendiriyorum",
                    progress: progress
                )

                HStack {
                    Button("0%") { progress = 0.0 }
                    Button("25%") { progress = 0.25 }
                    Button("50%") { progress = 0.50 }
                    Button("75%") { progress = 0.75 }
                    Button("100%") { progress = 1.0 }
                }
                .buttonStyle(.bordered)
            }
            .padding()
        }
    }

    return AnimationTest()
}
