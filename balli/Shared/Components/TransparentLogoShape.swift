//
//  TransparentLogoShape.swift
//  balli
//
//  Transparent recreation of the launch logo using SwiftUI shapes
//  Eliminates the beige background issue by drawing the logo programmatically
//

import SwiftUI

/// A SwiftUI shape that recreates the balli logo with full transparency
struct TransparentLogoShape: View {
    let size: CGFloat

    init(size: CGFloat = 20) {
        self.size = size
    }

    var body: some View {
        Canvas { context, canvasSize in
            let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
            let petalLength = size * 0.35
            let petalWidth = size * 0.25
            let centerDotRadius = size * 0.08

            // Draw 8 petals in a circular pattern
            for i in 0..<8 {
                let angle = Double(i) * (2 * Double.pi / 8)
                drawPetal(context: context, center: center, angle: angle, length: petalLength, width: petalWidth)
            }

            // Draw center dot
            let centerDotRect = CGRect(
                x: center.x - centerDotRadius,
                y: center.y - centerDotRadius,
                width: centerDotRadius * 2,
                height: centerDotRadius * 2
            )
            context.fill(Path(ellipseIn: centerDotRect), with: .color(AppTheme.primaryPurple))
        }
        .frame(width: size, height: size)
    }

    private func drawPetal(context: GraphicsContext, center: CGPoint, angle: Double, length: CGFloat, width: CGFloat) {
        // Create petal shape using a path
        var path = Path()

        // Calculate petal tip position
        let tipX = center.x + cos(angle) * length
        let tipY = center.y + sin(angle) * length

        // Calculate control points for smooth curves
        let baseRadius = width * 0.6
        let controlOffset = length * 0.6

        // Left base point
        let leftBaseX = center.x + cos(angle - Double.pi/2) * baseRadius
        let leftBaseY = center.y + sin(angle - Double.pi/2) * baseRadius

        // Right base point
        let rightBaseX = center.x + cos(angle + Double.pi/2) * baseRadius
        let rightBaseY = center.y + sin(angle + Double.pi/2) * baseRadius

        // Control points for curves
        let leftControlX = leftBaseX + cos(angle) * controlOffset
        let leftControlY = leftBaseY + sin(angle) * controlOffset

        let rightControlX = rightBaseX + cos(angle) * controlOffset
        let rightControlY = rightBaseY + sin(angle) * controlOffset

        // Build the petal path
        path.move(to: CGPoint(x: leftBaseX, y: leftBaseY))
        path.addQuadCurve(
            to: CGPoint(x: tipX, y: tipY),
            control: CGPoint(x: leftControlX, y: leftControlY)
        )
        path.addQuadCurve(
            to: CGPoint(x: rightBaseX, y: rightBaseY),
            control: CGPoint(x: rightControlX, y: rightControlY)
        )
        path.closeSubpath()

        // Create gradient for the petal
        let gradient = Gradient(colors: [
            AppTheme.primaryPurple.opacity(0.9),
            AppTheme.primaryPurple.opacity(0.7),
            AppTheme.primaryPurple
        ])

        context.fill(path, with: .linearGradient(
            gradient,
            startPoint: center,
            endPoint: CGPoint(x: tipX, y: tipY)
        ))
    }
}

/// A view that provides the transparent logo with proper sizing and styling
struct TransparentLogoView: View {
    let size: CGFloat

    init(size: CGFloat = 20) {
        self.size = size
    }

    var body: some View {
        TransparentLogoShape(size: size)
            .background(Color.clear)
    }
}

#Preview("Transparent Logo Sizes") {
    VStack(spacing: 20) {
        TransparentLogoView(size: 20)
        TransparentLogoView(size: 40)
        TransparentLogoView(size: 60)
        TransparentLogoView(size: 80)
    }
    .padding()
    .background(Color.gray.opacity(0.1))
}

#Preview("Transparent Logo on Dark") {
    VStack(spacing: 20) {
        TransparentLogoView(size: 20)
        TransparentLogoView(size: 40)
        TransparentLogoView(size: 60)
    }
    .padding()
    .background(Color.black)
    .preferredColorScheme(.dark)
}