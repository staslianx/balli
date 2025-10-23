//
//  TypewriterAnimator.swift
//  balli
//
//  Simulates ChatGPT-like character-by-character text animation
//  Based on standard implementation
//

import SwiftUI
import Combine

/// Animates text display character by character like ChatGPT
@MainActor
public final class TypewriterAnimator: ObservableObject {
    @Published public var displayedText: String = ""
    @Published public var isAnimating: Bool = false
    
    private var targetText: String = ""
    private var currentIndex: String.Index
    private var animationTask: Task<Void, Never>?
    
    // Animation timing configuration (milliseconds)
    private let characterDelay: UInt64 = 15_000_000    // 15ms per character
    private let spaceDelay: UInt64 = 5_000_000         // 5ms for spaces (faster)
    private let punctuationDelay: UInt64 = 50_000_000  // 50ms for punctuation (pause)
    private let newlineDelay: UInt64 = 100_000_000     // 100ms for newlines
    
    public init() {
        self.currentIndex = "".startIndex
    }
    
    /// Start animating text from current position to new target
    public func animateText(_ newText: String) {
        // If new text is shorter, reset
        if newText.count < displayedText.count {
            reset()
        }
        
        targetText = newText
        
        // Cancel any existing animation
        animationTask?.cancel()
        
        // Start new animation
        animationTask = Task { [weak self] in
            guard let self else { return }
            
            await self.performAnimation()
        }
    }
    
    /// Animate remaining text character by character
    private func performAnimation() async {
        isAnimating = true
        
        // Only animate the new portion
        let startIndex = displayedText.endIndex
        let newContent = String(targetText[startIndex...])
        
        for char in newContent {
            if Task.isCancelled {
                break
            }
            
            // Add character to displayed text
            displayedText.append(char)
            
            // Variable delay based on character type for natural feel
            let delay: UInt64 = switch char {
            case " ": spaceDelay
            case "\n": newlineDelay
            case ".", ",", "!", "?", ":", ";": punctuationDelay
            case "(", ")", "[", "]", "{", "}": characterDelay / 2  // Faster for brackets
            default: characterDelay
            }
            
            // Small variation for more natural typing (+/- 20%)
            let variation = Double.random(in: 0.8...1.2)
            let finalDelay = UInt64(Double(delay) * variation)
            
            try? await Task.sleep(nanoseconds: finalDelay)
        }
        
        isAnimating = false
    }
    
    /// Complete animation immediately
    public func completeAnimation() {
        animationTask?.cancel()
        displayedText = targetText
        isAnimating = false
    }
    
    /// Reset animator to initial state
    public func reset() {
        animationTask?.cancel()
        displayedText = ""
        targetText = ""
        currentIndex = "".startIndex
        isAnimating = false
    }
    
    /// Skip to end without animation
    public func skipAnimation() {
        completeAnimation()
    }
}

/// SwiftUI View Modifier for typewriter effect
struct TypewriterEffect: ViewModifier {
    let text: String
    @StateObject private var animator = TypewriterAnimator()
    
    func body(content: Content) -> some View {
        Text(animator.displayedText)
            .onChange(of: text) { _, newText in
                animator.animateText(newText)
            }
            .onTapGesture {
                // Allow users to skip animation by tapping
                if animator.isAnimating {
                    animator.skipAnimation()
                }
            }
    }
}

extension View {
    /// Apply typewriter animation to text
    public func typewriterEffect(_ text: String) -> some View {
        modifier(TypewriterEffect(text: text))
    }
}