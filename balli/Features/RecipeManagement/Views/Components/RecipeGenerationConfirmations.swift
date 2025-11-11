//
//  RecipeGenerationConfirmations.swift
//  balli
//
//  Confirmation overlays and loading animation for recipe generation
//  Provides visual feedback for user actions
//

import SwiftUI
import OSLog

// MARK: - Loading Steps Configuration

struct LoadingStepsConfiguration {
    static let steps: [(label: String, duration: TimeInterval, progress: Int)] = [
        ("Tarife tekrar bakıyorum", 5.0, 6),
        ("Malzemeleri gruplara ayırıyorum", 6.0, 13),
        ("Ham besin değerlerini hesaplıyorum", 7.0, 21),
        ("Pişirme yöntemlerini analiz ediyorum", 7.0, 30),
        ("Pişirme etkilerini belirliyorum", 7.0, 39),
        ("Sıvı emilimini hesaplıyorum", 7.0, 48),
        ("Pişirme kayıplarını hesaplıyorum", 7.0, 57),
        ("Pişmiş değerleri hesaplıyorum", 7.0, 66),
        ("Porsiyon değerlerini hesaplıyorum", 7.0, 75),
        ("100g için değerleri hesaplıyorum", 7.0, 84),
        ("Glisemik yükü hesaplıyorum", 7.0, 92),
        ("Sağlamasını yapıyorum", 8.0, 100)
    ]
}

// MARK: - Loading Animation Handler

@MainActor
class LoadingAnimationHandler: ObservableObject {
    @Published var currentLoadingStep: String?
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.balli",
        category: "LoadingAnimation"
    )

    func startLoadingAnimation(isCalculating: @escaping () -> Bool) {
        Task {
            for step in LoadingStepsConfiguration.steps {
                // Check if calculation is still in progress
                guard isCalculating() else {
                    logger.info("⏹️ [LOADING] Calculation completed early, stopping animation")
                    currentLoadingStep = nil
                    return
                }

                // Update current step
                currentLoadingStep = step.label
                logger.debug("📝 [LOADING] Step: '\(step.label)' (target: \(step.progress)%)")

                // Wait for step duration
                try? await Task.sleep(for: .seconds(step.duration))
            }

            // Clear loading step when done
            currentLoadingStep = nil
            logger.info("✅ [LOADING] Animation sequence completed")
        }
    }

    func clearLoadingStep() {
        currentLoadingStep = nil
    }
}

// MARK: - Save Confirmation Overlay

struct SaveConfirmationOverlay: View {
    let isShowing: Bool

    var body: some View {
        if isShowing {
            VStack {
                Spacer()
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(ThemeColors.primaryPurple)
                    Text("Tarif kaydedildi!")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .recipeGlass(tint: .warm, cornerRadius: 100)
                .padding(.bottom, 100)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isShowing)
        }
    }
}

// MARK: - Shopping Confirmation Overlay

struct ShoppingConfirmationOverlay: View {
    let isShowing: Bool

    var body: some View {
        if isShowing {
            VStack {
                Spacer()
                HStack(spacing: 12) {
                    Image(systemName: "cart.fill.badge.plus")
                        .font(.system(size: 20))
                        .foregroundColor(ThemeColors.primaryPurple)
                    Text("Alışveriş listesine eklendi!")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .recipeGlass(tint: .warm, cornerRadius: 100)
                .padding(.bottom, 100)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isShowing)
        }
    }
}

// MARK: - Combined Confirmation Overlays

struct RecipeGenerationOverlays: View {
    let showingSaveConfirmation: Bool
    let showingShoppingConfirmation: Bool

    var body: some View {
        ZStack {
            SaveConfirmationOverlay(isShowing: showingSaveConfirmation)
            ShoppingConfirmationOverlay(isShowing: showingShoppingConfirmation)
        }
    }
}
