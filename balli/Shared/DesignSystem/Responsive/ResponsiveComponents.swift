//
//  ResponsiveComponents.swift
//  balli
//
//  Responsive component dimension calculations
//  Extracted from AppTheme.swift
//

import SwiftUI

extension ResponsiveDesign {
    /// Component dimensions
    struct Components {
        // Food label card (maintains 81.4% × 58.7% ratio)
        // width(360) means it scales: on iPhone 15 Pro (393px) = 360px, on other devices scales proportionally
        @MainActor static var foodLabelWidth: CGFloat { ResponsiveDesign.width(360) }
        @MainActor static var foodLabelHeight: CGFloat { ResponsiveDesign.height(520) }

        // Recipe card - can be different width than food label
        // Options for setting the width:
        // 1. Responsive: width(320) - scales with screen size
        // 2. Fixed pixels: return 320 - always 320px regardless of screen
        // 3. Percentage: UIScreen.main.bounds.width * 0.85 - 85% of screen width
        @MainActor static var recipeCardWidth: CGFloat {
            // Change this value to whatever you need:
            return ResponsiveDesign.width(394)  // Currently set to 394 (scaled)
            // return 320      // Uncomment for fixed 320px
            // return UIScreen.main.bounds.width * 0.85  // Uncomment for 85% of screen
        }

        // Product cards (maintains 43.3% × 20% ratio)
        @MainActor static var productCardSize: CGFloat { ResponsiveDesign.width(170) }

        @MainActor static var favoriteCardSize: CGFloat { ResponsiveDesign.width(180) }

        // Button dimensions
        @MainActor static var actionButtonHeight: CGFloat { ResponsiveDesign.height(70) }  // ~8.2% height
        @MainActor static var smallButtonSize: CGFloat { ResponsiveDesign.width(50) }      // 12.7% width
        @MainActor static var captureButtonSize: CGFloat { ResponsiveDesign.width(80) }    // 20.4% width
        @MainActor static var toggleButtonHeight: CGFloat { ResponsiveDesign.height(50) }  // 5.9% height

        // Text field heights
        @MainActor static var textFieldHeight: CGFloat { ResponsiveDesign.height(44) }     // 5.2% height

        // Scanner overlay dimensions
        @MainActor static var scannerGuideHeight: CGFloat { ResponsiveDesign.height(250) } // 29.3% height

        // Chat bubble max width
        @MainActor static var chatBubbleMaxWidth: CGFloat { ResponsiveDesign.width(280) }  // 71.2% width

        // Glucose chart height - reduced to make room for favorites
        @MainActor static var chartHeight: CGFloat { ResponsiveDesign.height(170) }        // 17.6% height
    }
}
