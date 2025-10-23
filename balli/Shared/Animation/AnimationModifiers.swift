//
//  AnimationModifiers.swift
//  balli
//
//  Centralized view modifiers for consistent animation management
//

import SwiftUI

// MARK: - Controlled Animation Modifier
struct ControlledAnimationModifier<V: Equatable>: ViewModifier {
    let value: V
    let preset: AnimationPreset
    let priority: AnimationController.AnimationPriority
    @StateObject private var controller = AnimationController.shared
    
    func body(content: Content) -> some View {
        content
            .animation(
                controller.shouldDisableAnimations ? nil : controller.animation(for: preset),
                value: value
            )
    }
}


// MARK: - Performance Optimized Modifier
struct PerformanceOptimizedModifier: ViewModifier {
    @StateObject private var controller = AnimationController.shared
    let forceOptimization: Bool
    
    func body(content: Content) -> some View {
        Group {
            if forceOptimization || controller.allowComplexAnimations {
                content
                    .drawingGroup()
            } else {
                content
            }
        }
    }
}

// MARK: - Fade In/Out Modifier
struct FadeInOutModifier: ViewModifier {
    let isVisible: Bool
    let fadeIn: Bool
    let fadeOut: Bool
    @StateObject private var controller = AnimationController.shared
    
    func body(content: Content) -> some View {
        content
            .opacity(opacity)
            .animation(animation, value: isVisible)
    }
    
    private var opacity: Double {
        if fadeIn && fadeOut {
            return isVisible ? 1 : 0
        } else if fadeIn {
            return isVisible ? 1 : 1
        } else if fadeOut {
            return isVisible ? 0 : 1
        } else {
            return 1
        }
    }
    
    private var animation: Animation? {
        guard !controller.shouldDisableAnimations else { return nil }
        
        if isVisible && fadeIn {
            return controller.animation(for: AnimationPresets.contentReveal)
        } else if !isVisible && fadeOut {
            return controller.animation(for: AnimationPresets.quickFade)
        }
        return nil
    }
}


// MARK: - Visibility Animation Modifier
struct VisibilityAnimationModifier: ViewModifier {
    let isVisible: Bool
    @StateObject private var controller = AnimationController.shared
    @State private var actuallyVisible = false
    
    func body(content: Content) -> some View {
        Group {
            if actuallyVisible {
                content
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.95)),
                        removal: .opacity.combined(with: .scale(scale: 0.95))
                    ))
            }
        }
        .onChange(of: isVisible) { _, newValue in
            if !controller.shouldDisableAnimations {
                withAnimation(controller.animation(for: AnimationPresets.smoothTransition)) {
                    actuallyVisible = newValue
                }
            } else {
                actuallyVisible = newValue
            }
        }
        .onAppear {
            actuallyVisible = isVisible
        }
    }
}

// MARK: - Staggered Fade In/Out Modifier
struct StaggeredFadeInOutModifier: ViewModifier {
    let isVisible: Bool
    let delay: TimeInterval
    @StateObject private var controller = AnimationController.shared
    @State private var localVisible = false
    @State private var opacity: Double = 0
    @State private var fadeTask: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .opacity(opacity)
            .onChange(of: isVisible) { _, newValue in
                fadeTask?.cancel()
                fadeTask = nil

                if newValue {
                    fadeTask = Task { [delay] in
                        guard delay > 0 else {
                            await MainActor.run {
                                withAnimation(.easeInOut(duration: 0.8)) {
                                    opacity = 1.0
                                }
                            }
                            return
                        }

                        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        guard !Task.isCancelled else { return }

                        await MainActor.run {
                            withAnimation(.easeInOut(duration: 0.8)) {
                                opacity = 1.0
                            }
                        }
                    }
                } else {
                    withAnimation(.easeOut(duration: 0.4)) {
                        opacity = 0.0
                    }
                }
            }
            .onAppear {
                opacity = isVisible ? 1.0 : 0.0
            }
            .onDisappear {
                fadeTask?.cancel()
                fadeTask = nil
            }
    }
}


// MARK: - View Extension
public extension View {
    /// Animate with centralized controller
    func animateWithController<V: Equatable>(
        _ value: V,
        preset: AnimationPreset = AnimationPresets.smoothTransition,
        priority: AnimationController.AnimationPriority = .normal
    ) -> some View {
        modifier(ControlledAnimationModifier(
            value: value,
            preset: preset,
            priority: priority
        ))
    }
    
    /// Optimize for complex animations
    func optimizedForPerformance(force: Bool = false) -> some View {
        modifier(PerformanceOptimizedModifier(forceOptimization: force))
    }
    
    /// Controlled fade in/out
    func fadeInOut(isVisible: Bool, fadeIn: Bool = true, fadeOut: Bool = true) -> some View {
        modifier(FadeInOutModifier(
            isVisible: isVisible,
            fadeIn: fadeIn,
            fadeOut: fadeOut
        ))
    }
    
    /// Animated visibility
    func animatedVisibility(isVisible: Bool) -> some View {
        modifier(VisibilityAnimationModifier(isVisible: isVisible))
    }
    
    /// Staggered fade in/out with delay
    func staggeredFadeInOut(isVisible: Bool, delay: TimeInterval) -> some View {
        modifier(StaggeredFadeInOutModifier(isVisible: isVisible, delay: delay))
    }

    /// Disable animations conditionally
    func disableAnimationsIfBusy() -> some View {
        self
    }
}

// MARK: - withControlledAnimation
/// Perform animations with centralized control
@MainActor
public func withControlledAnimation<Result>(
    _ preset: AnimationPreset = AnimationPresets.smoothTransition,
    priority: AnimationController.AnimationPriority = .normal,
    _ body: () throws -> Result
) rethrows -> Result {
    let controller = AnimationController.shared
    let animation = controller.shouldDisableAnimations ? nil : controller.animation(for: preset)

    if let animation = animation {
        return try withAnimation(animation, body)
    } else {
        return try body()
    }
}
