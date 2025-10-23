//
//  AnimationPresets.swift
//  balli
//
//  Standardized animation curves and timings for consistent performance
//

import SwiftUI

/// Standard animation presets for consistent app-wide animations
public enum AnimationPresets {
    
    // MARK: - Quick Fade (0.2s)
    /// For rapid UI state changes like toggles, selections
    public struct QuickFade: AnimationPreset, Sendable {
        public var standardAnimation: Animation {
            .easeInOut(duration: 0.2)
        }
        
        public var reducedAnimation: Animation {
            .easeInOut(duration: 0.1)
        }
        
        public var optimalAnimation: Animation {
            .easeInOut(duration: 0.2)
        }
    }
    
    // MARK: - Smooth Transition (0.35s)
    /// For view transitions, navigation, modal presentations
    public struct SmoothTransition: AnimationPreset, Sendable {
        public var standardAnimation: Animation {
            .easeInOut(duration: 0.35)
        }
        
        public var reducedAnimation: Animation {
            .easeInOut(duration: 0.15)
        }
        
        public var optimalAnimation: Animation {
            .smooth(duration: 0.35, extraBounce: 0)
        }
    }
    
    // MARK: - Springy Interaction (Spring 0.4, 0.8)
    /// For user interactions like buttons, cards, favorites
    public struct SpringyInteraction: AnimationPreset, Sendable {
        public var standardAnimation: Animation {
            .spring(response: 0.4, dampingFraction: 0.8)
        }
        
        public var reducedAnimation: Animation {
            .easeOut(duration: 0.2)
        }
        
        public var optimalAnimation: Animation {
            .spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0.1)
        }
    }
    
    // MARK: - Data Update (0.25s)
    /// For Core Data changes, list updates, content refreshes
    public struct DataUpdate: AnimationPreset, Sendable {
        public var standardAnimation: Animation {
            .easeInOut(duration: 0.25)
        }
        
        public var reducedAnimation: Animation {
            .easeOut(duration: 0.1)
        }
        
        public var optimalAnimation: Animation {
            .easeInOut(duration: 0.25)
        }
    }
    
    // MARK: - Content Reveal (0.6s)
    /// For loading content, shimmer effects, progressive reveals
    public struct ContentReveal: AnimationPreset, Sendable {
        public var standardAnimation: Animation {
            .easeOut(duration: 0.6)
        }
        
        public var reducedAnimation: Animation {
            .easeOut(duration: 0.3)
        }
        
        public var optimalAnimation: Animation {
            .smooth(duration: 0.6, extraBounce: 0)
        }
    }
    
    // MARK: - Bouncy Emphasis (Spring with bounce)
    /// For celebrations, achievements, important actions
    public struct BouncyEmphasis: AnimationPreset, Sendable {
        public var standardAnimation: Animation {
            .spring(duration: 0.5, bounce: 0.4)
        }
        
        public var reducedAnimation: Animation {
            .easeOut(duration: 0.3)
        }
        
        public var optimalAnimation: Animation {
            .bouncy(duration: 0.5, extraBounce: 0.2)
        }
    }
    
    // MARK: - Gentle Move (0.8s)
    /// For large content shifts, recipe generation, page transitions
    public struct GentleMove: AnimationPreset, Sendable {
        public var standardAnimation: Animation {
            .easeInOut(duration: 0.8)
        }
        
        public var reducedAnimation: Animation {
            .easeInOut(duration: 0.4)
        }
        
        public var optimalAnimation: Animation {
            .smooth(duration: 0.8, extraBounce: 0)
        }
    }
    
    // MARK: - Snappy Action (Spring snappy)
    /// For quick actions, dismissals, swipes
    public struct SnappyAction: AnimationPreset, Sendable {
        public var standardAnimation: Animation {
            .snappy(duration: 0.35, extraBounce: 0)
        }
        
        public var reducedAnimation: Animation {
            .easeOut(duration: 0.2)
        }
        
        public var optimalAnimation: Animation {
            .snappy(duration: 0.35, extraBounce: 0.1)
        }
    }
    
    // MARK: - Loading Loop (Continuous)
    /// For loading indicators, progress animations
    public struct LoadingLoop: AnimationPreset, Sendable {
        public var standardAnimation: Animation {
            .linear(duration: 1.0).repeatForever(autoreverses: false)
        }
        
        public var reducedAnimation: Animation {
            .linear(duration: 0.5).repeatForever(autoreverses: false)
        }
        
        public var optimalAnimation: Animation {
            .linear(duration: 1.0).repeatForever(autoreverses: false)
        }
    }
}

// MARK: - Convenience Static Properties
public extension AnimationPresets {
    static let quickFade = QuickFade()
    static let smoothTransition = SmoothTransition()
    static let springyInteraction = SpringyInteraction()
    static let dataUpdate = DataUpdate()
    static let contentReveal = ContentReveal()
    static let bouncyEmphasis = BouncyEmphasis()
    static let gentleMove = GentleMove()
    static let snappyAction = SnappyAction()
    static let loadingLoop = LoadingLoop()
}

// MARK: - Animation Extensions
public extension Animation {
    /// Get animation from controller based on preset
    @MainActor
    static func controlled(_ preset: AnimationPreset) -> Animation {
        AnimationController.shared.animation(for: preset)
    }
    
    /// Quick fade animation
    @MainActor
    static var quickFade: Animation {
        controlled(AnimationPresets.quickFade)
    }
    
    /// Smooth transition animation
    @MainActor
    static var smoothTransition: Animation {
        controlled(AnimationPresets.smoothTransition)
    }
    
    /// Springy interaction animation
    @MainActor
    static var springyInteraction: Animation {
        controlled(AnimationPresets.springyInteraction)
    }
    
    /// Data update animation
    @MainActor
    static var dataUpdate: Animation {
        controlled(AnimationPresets.dataUpdate)
    }
    
    /// Content reveal animation
    @MainActor
    static var contentReveal: Animation {
        controlled(AnimationPresets.contentReveal)
    }
    
    /// Bouncy emphasis animation
    @MainActor
    static var bouncyEmphasis: Animation {
        controlled(AnimationPresets.bouncyEmphasis)
    }
    
    /// Gentle move animation
    @MainActor
    static var gentleMove: Animation {
        controlled(AnimationPresets.gentleMove)
    }
    
    /// Snappy action animation
    @MainActor
    static var snappyAction: Animation {
        controlled(AnimationPresets.snappyAction)
    }
}