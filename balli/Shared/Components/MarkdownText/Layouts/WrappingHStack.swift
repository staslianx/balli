//
//  WrappingHStack.swift
//  balli
//
//  Purpose: Custom layout that wraps elements like text, flowing citations inline
//  Enables word-level wrapping for markdown text with inline citations
//  Swift 6 strict concurrency compliant
//

import SwiftUI

/// Custom layout that wraps elements like text, flowing citations inline
struct WrappingHStack: Layout {
    var alignment: VerticalAlignment = .center
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlexLayout.layout(
            proposal: proposal,
            subviews: subviews,
            alignment: alignment,
            spacing: spacing
        )
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlexLayout.layout(
            proposal: proposal,
            subviews: subviews,
            alignment: alignment,
            spacing: spacing
        )

        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                     y: bounds.minY + result.positions[index].y),
                         proposal: result.proposals[index])
        }
    }
}
