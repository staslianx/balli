//
//  FlexLayout.swift
//  balli
//
//  Purpose: Flexible wrapping layout helper for WrappingHStack
//  Calculates positions for flowing text elements across multiple lines
//  Swift 6 strict concurrency compliant
//

import SwiftUI

/// Helper for flexible wrapping layout
enum FlexLayout {
    struct Result {
        var size: CGSize
        var positions: [CGPoint]
        var proposals: [ProposedViewSize]
    }

    static func layout(
        proposal: ProposedViewSize,
        subviews: Layout.Subviews,
        alignment: VerticalAlignment,
        spacing: CGFloat
    ) -> Result {
        var positions: [CGPoint] = []
        var proposals: [ProposedViewSize] = []
        var totalHeight: CGFloat = 0
        var lineHeight: CGFloat = 0
        var x: CGFloat = 0
        var y: CGFloat = 0

        let maxWidth = proposal.width ?? .infinity

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            // Check if we need to wrap to next line
            if x + size.width > maxWidth && x > 0 {
                // Move to next line
                y += lineHeight + spacing
                x = 0
                lineHeight = 0
            }

            // Place subview
            positions.append(CGPoint(x: x, y: y))
            proposals.append(ProposedViewSize(size))

            // Update position and line height
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }

        // Total height is the last line's y position plus its height
        totalHeight = y + lineHeight

        return Result(
            size: CGSize(width: maxWidth, height: totalHeight),
            positions: positions,
            proposals: proposals
        )
    }
}
