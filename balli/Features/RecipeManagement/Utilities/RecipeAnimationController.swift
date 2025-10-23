//
//  RecipeAnimationController.swift
//  balli
//
//  Controls recipe generation animations: fade in/out, logo rotation
//  Coordinates timing and state for smooth visual transitions
//  Swift 6 strict concurrency compliant
//

import SwiftUI
import OSLog

/// Manages animation state for recipe generation flow
@MainActor
public final class RecipeAnimationController: ObservableObject {
    // MARK: - Animation State
    @Published public var isRotatingLogo = false
    @Published public var isFadingOutContent = false
    @Published public var textVisible = true
    @Published public var isLogoAnimationComplete = false

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.anaxoniclabs.balli", category: "animation.controller")

    public init() {}

    // MARK: - Animation Control

    /// Start generation animations
    public func startGenerationAnimation() {
        logger.debug("Starting generation animation")
        isRotatingLogo = true
        isLogoAnimationComplete = false
    }

    /// Stop generation animations
    public func stopGenerationAnimation() {
        logger.debug("Stopping generation animation")
        isRotatingLogo = false
    }

    /// Called when logo animation completes
    public func onLogoAnimationComplete() {
        isLogoAnimationComplete = true
    }

    /// Fade out content before generation
    public func fadeOutContent() async {
        await MainActor.run {
            isFadingOutContent = true
            withAnimation(.easeOut(duration: 0.3)) {
                textVisible = false
            }
        }

        // Wait for fade out to complete
        try? await Task.sleep(for: .milliseconds(300))
    }

    /// Fade in content after generation
    public func fadeInContent() async {
        await MainActor.run {
            isFadingOutContent = false
            textVisible = true
        }

        // Brief delay to allow UI to settle
        try? await Task.sleep(for: .milliseconds(100))
    }

    /// Reset all animation state
    public func reset() {
        isRotatingLogo = false
        isFadingOutContent = false
        isLogoAnimationComplete = false
        textVisible = true
    }

    /// Reset to completed state (for existing recipes)
    public func setCompleted() {
        isLogoAnimationComplete = true
        textVisible = true
        isFadingOutContent = false
        isRotatingLogo = false
    }
}
