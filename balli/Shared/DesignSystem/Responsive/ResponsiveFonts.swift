//
//  ResponsiveFonts.swift
//  balli
//
//  Font scaling for responsive design
//  Extracted from AppTheme.swift
//

import Foundation

extension ResponsiveDesign {
    /// Font scaling
    struct Font {
        @MainActor
        static func scaledSize(_ baseSize: CGFloat) -> CGFloat {
            // Scale fonts proportionally but cap at 1.2x for readability
            let screenWidth = ResponsiveDesign.safeScreenWidth()
            let scale = min(screenWidth / ResponsiveDesign.referenceWidth, 1.2)
            guard !scale.isNaN && !scale.isInfinite && scale > 0 else {
                return baseSize // Fallback to original size
            }
            let result = baseSize * scale
            guard !result.isNaN && !result.isInfinite && result > 0 else {
                return baseSize // Fallback to original size
            }
            return result
        }
    }
}
