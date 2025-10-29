//
//  DualCurveChartView.swift
//  balli
//
//  Dual-curve chart showing insulin and glucose absorption over time
//  Uses Canvas for high-performance rendering
//

import SwiftUI

/// Chart displaying insulin and glucose curves with peak markers
struct DualCurveChartView: View {
    let insulinCurve: [InsulinCurvePoint]
    let glucoseCurve: [GlucoseCurvePoint]
    let insulinPeakTime: Int  // Minutes
    let glucosePeakTime: Int  // Minutes
    let mismatchMinutes: Int

    // Chart configuration
    private let chartWidth: CGFloat = 350
    private let chartHeight: CGFloat = 200
    private let chartPadding: CGFloat = 40
    private let lineWidth: CGFloat = 3.5

    // Curve colors
    private let insulinColor = Color(hex: "#FF6B35")  // Orange
    private let glucoseColor = Color(hex: "#9333EA")  // Purple
    private let mismatchColor = Color.red.opacity(0.6)

    var body: some View {
        VStack(spacing: 16) {
            // Main chart
            Canvas { context, size in
                // 1. Draw grid
                drawGrid(context: context, size: size)

                // 2. Draw glucose curve (behind insulin)
                drawCurve(
                    context: context,
                    points: glucoseCurve.map { ($0.timeMinutes, $0.intensity) },
                    color: glucoseColor,
                    size: size
                )

                // 3. Draw insulin curve (in front)
                drawCurve(
                    context: context,
                    points: insulinCurve.map { ($0.timeMinutes, $0.intensity) },
                    color: insulinColor,
                    size: size
                )

                // 4. Draw mismatch indicator (if significant)
                if mismatchMinutes > 60 {
                    drawMismatchIndicator(context: context, size: size)
                }
            }
            .frame(width: chartWidth, height: chartHeight)

            // Legend
            HStack(spacing: 24) {
                // Insulin legend
                HStack(spacing: 8) {
                    Circle()
                        .fill(insulinColor)
                        .frame(width: 8, height: 8)
                    Text("İnsülin (NovoRapid) • \(insulinPeakTime.formattedAsTime)")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.primary)
                }

                // Glucose legend
                HStack(spacing: 8) {
                    Circle()
                        .fill(glucoseColor)
                        .frame(width: 8, height: 8)
                    Text("Glikoz (Bu tarif) • \(glucosePeakTime.formattedAsTime)")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.primary)
                }
            }

            // Mismatch warning (if significant)
            if mismatchMinutes > 60 {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                    Text("Uyumsuzluk: \(mismatchMinutes.formattedAsTime)")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.red)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.red.opacity(0.1))
                )
            }
        }
    }

    // MARK: - Drawing Methods

    /// Draw grid lines and axes
    private func drawGrid(context: GraphicsContext, size: CGSize) {
        let drawableWidth = size.width - (chartPadding * 2)
        let drawableHeight = size.height - (chartPadding * 2)

        var path = Path()

        // Vertical time grid lines (0, 1h, 2h, 3h, 4h, 5h, 6h)
        for hour in 0...6 {
            let x = chartPadding + (drawableWidth * CGFloat(hour) / 6.0)
            path.move(to: CGPoint(x: x, y: chartPadding))
            path.addLine(to: CGPoint(x: x, y: size.height - chartPadding))
        }

        // Horizontal intensity grid lines (0%, 25%, 50%, 75%, 100%)
        for i in 0...4 {
            let y = chartPadding + (drawableHeight * CGFloat(i) / 4.0)
            path.move(to: CGPoint(x: chartPadding, y: y))
            path.addLine(to: CGPoint(x: size.width - chartPadding, y: y))
        }

        context.stroke(path, with: .color(.gray.opacity(0.2)), lineWidth: 1)

        // Draw time labels
        for hour in 0...6 {
            let x = chartPadding + (drawableWidth * CGFloat(hour) / 6.0)
            let text = Text("\(hour)s")
                .font(.system(size: 10, weight: .regular, design: .rounded))
                .foregroundColor(.secondary)

            context.draw(text, at: CGPoint(x: x, y: size.height - 10))
        }

        // Draw intensity labels (0%, 50%, 100%)
        let labels = [(0, "100%"), (2, "50%"), (4, "0%")]
        for (gridIndex, labelText) in labels {
            let y = chartPadding + (drawableHeight * CGFloat(gridIndex) / 4.0)
            let text = Text(labelText)
                .font(.system(size: 10, weight: .regular, design: .rounded))
                .foregroundColor(.secondary)

            context.draw(text, at: CGPoint(x: 15, y: y))
        }
    }

    /// Draw smooth curve through points
    private func drawCurve(context: GraphicsContext, points: [(time: Int, intensity: Double)], color: Color, size: CGSize) {
        guard points.count >= 2 else { return }

        let drawableWidth = size.width - (chartPadding * 2)
        let drawableHeight = size.height - (chartPadding * 2)
        let maxTime = 360.0  // 6 hours in minutes

        var path = Path()

        // Convert data points to screen coordinates
        let screenPoints = points.map { point -> CGPoint in
            let x = chartPadding + (drawableWidth * CGFloat(point.time) / CGFloat(maxTime))
            let y = (size.height - chartPadding) - (drawableHeight * CGFloat(point.intensity))
            return CGPoint(x: x, y: y)
        }

        // Start path
        path.move(to: screenPoints[0])

        // Draw smooth curve using quadratic curves
        for i in 1..<screenPoints.count {
            let current = screenPoints[i]
            let previous = screenPoints[i - 1]

            // Calculate control point for smooth curve
            let controlX = (previous.x + current.x) / 2
            let controlY = (previous.y + current.y) / 2

            path.addQuadCurve(to: current, control: CGPoint(x: controlX, y: controlY))
        }

        // Draw the curve
        context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))

        // Draw peak marker
        if let peakPoint = screenPoints.max(by: { $0.y > $1.y }) {  // Lowest y = highest intensity
            // Peak dot
            var dotPath = Path()
            dotPath.addEllipse(in: CGRect(x: peakPoint.x - 4, y: peakPoint.y - 4, width: 8, height: 8))
            context.fill(dotPath, with: .color(color))

            // White outline
            context.stroke(dotPath, with: .color(.white), lineWidth: 2)
        }
    }

    /// Draw dashed line indicating mismatch between peaks
    private func drawMismatchIndicator(context: GraphicsContext, size: CGSize) {
        let drawableWidth = size.width - (chartPadding * 2)
        let maxTime = 360.0  // 6 hours

        let insulinX = chartPadding + (drawableWidth * CGFloat(insulinPeakTime) / CGFloat(maxTime))
        let glucoseX = chartPadding + (drawableWidth * CGFloat(glucosePeakTime) / CGFloat(maxTime))

        var path = Path()
        path.move(to: CGPoint(x: insulinX, y: chartPadding + 30))
        path.addLine(to: CGPoint(x: glucoseX, y: chartPadding + 30))

        context.stroke(
            path,
            with: .color(mismatchColor),
            style: StrokeStyle(lineWidth: 2, dash: [5, 3])
        )
    }
}

// MARK: - Preview

#Preview("High Fat Recipe (210 min peak)") {
    VStack {
        DualCurveChartView(
            insulinCurve: InsulinCurveData.novorapidCurve,
            glucoseCurve: [
                GlucoseCurvePoint(timeMinutes: 0, intensity: 0.0),
                GlucoseCurvePoint(timeMinutes: 60, intensity: 0.2),
                GlucoseCurvePoint(timeMinutes: 120, intensity: 0.4),
                GlucoseCurvePoint(timeMinutes: 180, intensity: 0.7),
                GlucoseCurvePoint(timeMinutes: 210, intensity: 0.85),  // Peak
                GlucoseCurvePoint(timeMinutes: 240, intensity: 0.7),
                GlucoseCurvePoint(timeMinutes: 300, intensity: 0.4),
                GlucoseCurvePoint(timeMinutes: 360, intensity: 0.0)
            ],
            insulinPeakTime: 75,
            glucosePeakTime: 210,
            mismatchMinutes: 135
        )
    }
    .padding()
    .background(Color(.secondarySystemBackground))
}

#Preview("Good Alignment (90 min peak)") {
    VStack {
        DualCurveChartView(
            insulinCurve: InsulinCurveData.novorapidCurve,
            glucoseCurve: [
                GlucoseCurvePoint(timeMinutes: 0, intensity: 0.0),
                GlucoseCurvePoint(timeMinutes: 30, intensity: 0.3),
                GlucoseCurvePoint(timeMinutes: 60, intensity: 0.6),
                GlucoseCurvePoint(timeMinutes: 90, intensity: 1.0),  // Peak
                GlucoseCurvePoint(timeMinutes: 120, intensity: 0.7),
                GlucoseCurvePoint(timeMinutes: 180, intensity: 0.3),
                GlucoseCurvePoint(timeMinutes: 240, intensity: 0.0)
            ],
            insulinPeakTime: 75,
            glucosePeakTime: 90,
            mismatchMinutes: 15
        )
    }
    .padding()
    .background(Color(.secondarySystemBackground))
}
