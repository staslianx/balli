//
//  ResponsiveSpacing.swift
//  balli
//
//  Responsive spacing values that scale with screen size
//  Extracted from AppTheme.swift
//

import Foundation

extension ResponsiveDesign {
    /// Responsive spacing maintaining exact proportions
    struct Spacing {
        @MainActor static var xxSmall: CGFloat { ResponsiveDesign.height(4) }   // 0.47% of height
        @MainActor static var xSmall: CGFloat { ResponsiveDesign.height(8) }    // 0.94% of height
        @MainActor static var small: CGFloat { ResponsiveDesign.height(12) }    // 1.41% of height
        @MainActor static var medium: CGFloat { ResponsiveDesign.height(16) }   // 1.88% of height
        @MainActor static var large: CGFloat { ResponsiveDesign.height(20) }    // 2.35% of height
        @MainActor static var xLarge: CGFloat { ResponsiveDesign.height(24) }   // 2.82% of height
        @MainActor static var xxLarge: CGFloat { ResponsiveDesign.height(30) }  // 3.52% of height
    }
}
