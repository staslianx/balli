//
//  CurvePeakMarkerView.swift
//  balli
//
//  Peak time marker for insulin/glucose curve charts
//  Shows a colored dot with time label
//

import SwiftUI

/// Visual marker for curve peak times
struct CurvePeakMarkerView: View {
    let timeMinutes: Int
    let color: Color
    let label: String

    private let dotRadius: CGFloat = 6
    private let labelOffset: CGFloat = 15

    var body: some View {
        VStack(spacing: 4) {
            // Peak label
            Text(label)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(color)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(color.opacity(0.15))
                )

            // Peak dot
            Circle()
                .fill(color)
                .frame(width: dotRadius * 2, height: dotRadius * 2)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                )
                .shadow(color: color.opacity(0.3), radius: 3, x: 0, y: 2)
        }
    }
}

/// Format time in minutes to human-readable string
extension Int {
    var formattedAsTime: String {
        if self < 60 {
            return "\(self)dk"  // Minutes
        } else {
            let hours = Double(self) / 60.0
            if hours.truncatingRemainder(dividingBy: 1) == 0 {
                return "\(Int(hours))s"  // Whole hours
            } else {
                return String(format: "%.1fs", hours)  // Fractional hours
            }
        }
    }
}

// MARK: - Preview

#Preview("Insulin Peak (75 min)") {
    VStack(spacing: 40) {
        CurvePeakMarkerView(
            timeMinutes: 75,
            color: Color(hex: "#FF6B35"),  // Orange
            label: "İnsülin Piki • \(75.formattedAsTime)"
        )

        CurvePeakMarkerView(
            timeMinutes: 210,
            color: Color(hex: "#9333EA"),  // Purple
            label: "Glikoz Piki • \(210.formattedAsTime)"
        )
    }
    .padding()
    .background(Color(.systemBackground))
}
