//
//  ResponsiveDesign.swift
//  balli
//
//  Core responsive design system with screen calculations
//  Extracted from AppTheme.swift
//
//  PERFORMANCE FIX: Lazy initialization prevents unsafeForcedSync warnings
//  by deferring UIKit access until actually needed, not at struct creation time
//

import SwiftUI

struct ResponsiveDesign {
    // Reference dimensions from iPhone 15 Pro
    static let referenceWidth: CGFloat = 393
    static let referenceHeight: CGFloat = 852

    // PERFORMANCE FIX: Lazy computed properties instead of immediate evaluation
    // This prevents UIKit access during SwiftUI view initialization
    @MainActor private static var _widthScale: CGFloat?
    @MainActor private static var widthScale: CGFloat {
        if let cached = _widthScale {
            return cached
        }
        let scale = safeScreenWidth() / referenceWidth
        _widthScale = scale
        return scale
    }

    @MainActor private static var _heightScale: CGFloat?
    @MainActor private static var heightScale: CGFloat {
        if let cached = _heightScale {
            return cached
        }
        let scale = safeScreenHeight() / referenceHeight
        _heightScale = scale
        return scale
    }

    // MARK: - Core Scaling Functions

    /// Calculate responsive width maintaining exact proportions
    @MainActor
    static func width(_ value: CGFloat) -> CGFloat {
        let result = value * widthScale
        guard !result.isNaN && !result.isInfinite && result > 0 else {
            return value // Fallback to original value
        }
        return result
    }

    /// Calculate responsive height maintaining exact proportions
    @MainActor
    static func height(_ value: CGFloat) -> CGFloat {
        let result = value * heightScale
        guard !result.isNaN && !result.isInfinite && result > 0 else {
            return value // Fallback to original value
        }
        return result
    }

    // MARK: - Safe Screen Access

    @MainActor
    private static var cachedScreenWidth: CGFloat?

    @MainActor
    private static var cachedScreenHeight: CGFloat?

    @MainActor
    static func safeScreenWidth() -> CGFloat {
        if let cached = cachedScreenWidth, cached > 0 && !cached.isNaN && !cached.isInfinite {
            return cached
        }

        // Try different methods to get screen width
        var width: CGFloat = 0

        // Method 1: Key window scene screen (iOS 26+ preferred)
        if width <= 0 {
            if let windowScene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                width = windowScene.screen.bounds.width
            }
        }

        // Method 2: Key window bounds (fallback)
        if width <= 0 || width.isNaN || width.isInfinite {
            if #available(iOS 15.0, *) {
                if let windowScene = UIApplication.shared.connectedScenes
                    .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
                   let window = windowScene.windows.first {
                    width = window.bounds.width
                }
            } else {
                if let window = UIApplication.shared.windows.first {
                    width = window.bounds.width
                }
            }
        }

        // Validate and cache
        guard width > 0 && !width.isNaN && !width.isInfinite else {
            return referenceWidth // Fallback to reference width
        }
        cachedScreenWidth = width
        return width
    }

    @MainActor
    static func safeScreenHeight() -> CGFloat {
        if let cached = cachedScreenHeight, cached > 0 && !cached.isNaN && !cached.isInfinite {
            return cached
        }

        // Try different methods to get screen height
        var height: CGFloat = 0

        // Method 1: Key window scene screen (iOS 26+ preferred)
        if height <= 0 {
            if let windowScene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                height = windowScene.screen.bounds.height
            }
        }

        // Method 2: Key window bounds (fallback)
        if height <= 0 || height.isNaN || height.isInfinite {
            if #available(iOS 15.0, *) {
                if let windowScene = UIApplication.shared.connectedScenes
                    .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
                   let window = windowScene.windows.first {
                    height = window.bounds.height
                }
            } else {
                if let window = UIApplication.shared.windows.first {
                    height = window.bounds.height
                }
            }
        }

        // Validate and cache
        guard height > 0 && !height.isNaN && !height.isInfinite else {
            return referenceHeight // Fallback to reference height
        }
        cachedScreenHeight = height
        return height
    }
}
