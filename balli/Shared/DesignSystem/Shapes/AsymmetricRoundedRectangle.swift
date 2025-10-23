//
//  AsymmetricRoundedRectangle.swift
//  balli
//
//  Custom shape with different corner radii for top and bottom
//  Extracted from AppTheme.swift
//

import SwiftUI

/// Custom shape with different corner radii for top and bottom
struct AsymmetricRoundedRectangle: Shape {
    var topCornerRadius: CGFloat
    var bottomCornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let width = rect.width
        let height = rect.height

        // Start from top-left, after the corner radius
        path.move(to: CGPoint(x: topCornerRadius, y: 0))

        // Top edge to top-right corner
        path.addLine(to: CGPoint(x: width - topCornerRadius, y: 0))

        // Top-right corner
        path.addArc(
            center: CGPoint(x: width - topCornerRadius, y: topCornerRadius),
            radius: topCornerRadius,
            startAngle: Angle(degrees: -90),
            endAngle: Angle(degrees: 0),
            clockwise: false
        )

        // Right edge to bottom-right corner
        path.addLine(to: CGPoint(x: width, y: height - bottomCornerRadius))

        // Bottom-right corner
        path.addArc(
            center: CGPoint(x: width - bottomCornerRadius, y: height - bottomCornerRadius),
            radius: bottomCornerRadius,
            startAngle: Angle(degrees: 0),
            endAngle: Angle(degrees: 90),
            clockwise: false
        )

        // Bottom edge to bottom-left corner
        path.addLine(to: CGPoint(x: bottomCornerRadius, y: height))

        // Bottom-left corner
        path.addArc(
            center: CGPoint(x: bottomCornerRadius, y: height - bottomCornerRadius),
            radius: bottomCornerRadius,
            startAngle: Angle(degrees: 90),
            endAngle: Angle(degrees: 180),
            clockwise: false
        )

        // Left edge back to top-left corner
        path.addLine(to: CGPoint(x: 0, y: topCornerRadius))

        // Top-left corner
        path.addArc(
            center: CGPoint(x: topCornerRadius, y: topCornerRadius),
            radius: topCornerRadius,
            startAngle: Angle(degrees: 180),
            endAngle: Angle(degrees: 270),
            clockwise: false
        )

        path.closeSubpath()
        return path
    }
}
