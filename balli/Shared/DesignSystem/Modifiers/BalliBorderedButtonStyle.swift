//
//  BalliBorderedButtonStyle.swift
//  balli
//
//  Reusable bordered prominent button style with balli branding
//  Purple background with light purple icon/text
//

import SwiftUI

/// Balli's signature bordered prominent button style
/// - Purple filled background (ThemeColors.primaryPurple)
/// - Light purple foreground color for icons/text
/// - Circular shape (iOS native bordered prominent)
///
/// Usage:
/// ```swift
/// Button {
///     // action
/// } label: {
///     Image(systemName: "checkmark")
/// }
/// .buttonStyle(.balliBordered)
/// ```
struct BalliBorderedButtonStyle: PrimitiveButtonStyle {
    /// Light purple color for icon/text visibility against purple background
    static let lightPurple = Color(red: 0.85, green: 0.75, blue: 1.0)

    let size: CGFloat?

    init(size: CGFloat? = nil) {
        self.size = size
    }

    func makeBody(configuration: Configuration) -> some View {
        if let size = size {
            // Custom size - create manual circular button
            Button(role: configuration.role) {
                configuration.trigger()
            } label: {
                configuration.label
                    .font(.system(size: size * 0.28, weight: .semibold))
                    .foregroundColor(Self.lightPurple)
                    .frame(width: size, height: size)
                    .background(
                        Circle()
                            .fill(ThemeColors.primaryPurple)
                    )
            }
        } else {
            // Standard size - use iOS bordered prominent
            Button(role: configuration.role) {
                configuration.trigger()
            } label: {
                configuration.label
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Self.lightPurple)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.circle)
            .tint(ThemeColors.primaryPurple)
        }
    }
}

// MARK: - ButtonStyle Extension

extension PrimitiveButtonStyle where Self == BalliBorderedButtonStyle {
    /// Balli's signature bordered prominent button style
    ///
    /// Creates a circular purple button with light purple foreground
    static var balliBordered: BalliBorderedButtonStyle {
        BalliBorderedButtonStyle()
    }

    /// Balli's bordered button style with custom size
    ///
    /// - Parameter size: Diameter of the circular button
    static func balliBordered(size: CGFloat) -> BalliBorderedButtonStyle {
        BalliBorderedButtonStyle(size: size)
    }
}

// MARK: - Preview

#Preview("BalliBordered Button Styles") {
    VStack(spacing: 40) {
        VStack(spacing: 16) {
            Text("Standard Size (.balliBordered)")
                .font(.caption)
                .foregroundColor(.secondary)

            Button {
                print("Standard size tapped")
            } label: {
                Image(systemName: "checkmark")
            }
            .buttonStyle(.balliBordered)
        }

        VStack(spacing: 16) {
            Text("Custom Size (.balliBordered(size: 72))")
                .font(.caption)
                .foregroundColor(.secondary)

            Button {
                print("Custom size tapped")
            } label: {
                Image(systemName: "checkmark")
            }
            .buttonStyle(.balliBordered(size: 72))
        }

        VStack(spacing: 16) {
            Text("Large Size (.balliBordered(size: 100))")
                .font(.caption)
                .foregroundColor(.secondary)

            Button {
                print("Large size tapped")
            } label: {
                Image(systemName: "checkmark")
            }
            .buttonStyle(.balliBordered(size: 100))
        }
    }
    .padding()
}
