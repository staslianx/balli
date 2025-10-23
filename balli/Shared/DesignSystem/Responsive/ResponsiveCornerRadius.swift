//
//  ResponsiveCornerRadius.swift
//  balli
//
//  Responsive corner radius values including device-specific screen corners
//  Extracted from AppTheme.swift
//

import SwiftUI

extension ResponsiveDesign {
    /// Responsive corner radius
    struct CornerRadius {
        @MainActor static var xSmall: CGFloat { ResponsiveDesign.height(4) }    // 0.47% of height
        @MainActor static var small: CGFloat { ResponsiveDesign.height(8) }     // 0.94% of height
        @MainActor static var medium: CGFloat { ResponsiveDesign.height(12) }   // 1.41% of height
        @MainActor static var large: CGFloat { ResponsiveDesign.height(20) }    // 2.35% of height
        @MainActor static var card: CGFloat { ResponsiveDesign.height(32) }     // 3.76% of height
        @MainActor static var modal: CGFloat { ResponsiveDesign.height(44) }    // 5.16% of height
        @MainActor static var scanner: CGFloat { ResponsiveDesign.height(38) }  // 4.46% of height
        @MainActor static var bubble: CGFloat { ResponsiveDesign.height(18) }   // 2.11% of height
        @MainActor static var button: CGFloat { ResponsiveDesign.height(12) }   // 1.41% of height

        /// Get the device's actual screen corner radius for seamless modal presentations
        /// Returns the corner radius of the device's display for perfect visual alignment
        @MainActor static var screenCornerRadius: CGFloat {
            // Try to get corner radius from active window scene
            if #available(iOS 15.0, *) {
                if let windowScene = UIApplication.shared.connectedScenes
                    .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                    let screen = windowScene.screen
                    // Try to access displayCornerRadius if available (iOS 13+)
                    if let cornerRadius = screen.value(forKey: "displayCornerRadius") as? CGFloat {
                        return cornerRadius
                    }
                }
            }

            // Fallback: Use device-specific values based on screen size
            let screenHeight = ResponsiveDesign.safeScreenHeight()

            // iPhone corner radii by screen height
            switch screenHeight {
            case 926: // iPhone 14 Pro Max, 15 Pro Max (6.7")
                return 55.0
            case 852: // iPhone 14 Pro, 15 Pro (6.1")
                return 55.0
            case 844: // iPhone 14, 15, 13 (6.1")
                return 47.33
            case 812: // iPhone 13 mini, 12 mini (5.4")
                return 39.0
            case 896: // iPhone 11 Pro Max, XS Max (6.5")
                return 39.0
            case 667: // iPhone SE 2nd/3rd gen (4.7")
                return 0.0 // No rounded corners
            default:
                // Default to a reasonable value for unknown devices
                return 47.0
            }
        }

        /// Reduced corner radius for modal top corners (less rounded than bottom)
        /// Bottom corners match screen radius, top corners are more subtle
        @MainActor static var modalTopCornerRadius: CGFloat {
            // Use about 60% of the screen corner radius for a more subtle top curve
            return screenCornerRadius * 0.6
        }
    }
}
