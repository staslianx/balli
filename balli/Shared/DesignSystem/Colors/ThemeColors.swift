//
//  ThemeColors.swift
//  balli
//
//  Complete color system with gradients and adaptive helpers
//  Extracted from AppTheme.swift
//

import SwiftUI

struct ThemeColors {
    // MARK: - Primary Colors
    static let primaryPurple = Color(hex: "67619E")
    static let lightPurple = Color(hex: "9B96C7")
    static let darkPurple = Color(hex: "655F8F")
    static let purpleBackground = Color(hex: "F5F4FA")
    static let internationalOrange = Color(hex: "FF4F00")
    static let dexcomGreen = Color(hex: "30AB0D")

    // MARK: - Research Type Colors
    // Progressive shades of purple - baseline → darker → darkest

    /// Model (baseline purple) - intelligent and sophisticated
    static let modelPurple = Color(hex: "8B7EC8") // Baseline purple
    static let modelPurpleDark = Color(hex: "9B8ED8") // Lighter for dark mode

    /// Araştırma (darker purple) - enhanced research capability
    static let webSearchBlue = Color(hex: "655F8F") // Darker purple than model
    static let webSearchBlueDark = Color(hex: "7A6FA8") // Lighter for dark mode

    /// Derin Araştırma (darkest purple) - most comprehensive research
    static let deepResearchOrange = Color(hex: "4A4570") // Darkest purple
    static let deepResearchOrangeDark = Color(hex: "655F8F") // Lighter for dark mode

    // MARK: - Adaptive Color Helpers
    static func deepResearchColor(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? deepResearchOrangeDark : deepResearchOrange
    }

    static func webSearchColor(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? webSearchBlueDark : webSearchBlue
    }

    static func modelColor(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? modelPurpleDark : modelPurple
    }

    // MARK: - Semantic Colors
    static let accentColor = primaryPurple
    static let secondaryText = Color.secondary
    static let background = Color(.systemBackground)
    static let secondaryBackground = Color(.secondarySystemBackground)
    static let tertiaryBackground = Color(.tertiarySystemBackground)

    // MARK: - Card Colors
    static let cardBackground = Color(.secondarySystemBackground)
    static let cardShadow = Color.black.opacity(0.1)

    // MARK: - Status Colors
    static var success: Color {
        let hex = UserDefaults.standard.string(forKey: "impactColor.success") ?? "00D31F"
        return Color(hex: hex)
    }

    static var warning: Color {
        let hex = UserDefaults.standard.string(forKey: "impactColor.warning") ?? "FFCB10"
        return Color(hex: hex)
    }

    static var error: Color {
        let hex = UserDefaults.standard.string(forKey: "impactColor.error") ?? "FF3B30"
        return Color(hex: hex)
    }

    // MARK: - Glucose Chart Colors
    static let glucoseNormal = Color.green
    static let glucoseBorderline = Color.orange
    static let glucoseHigh = Color.red

    // MARK: - Chat Colors
    static let userBubble = primaryPurple
    static let aiBubble = Color(.secondarySystemBackground)

    // MARK: - Gradients
    static let purpleGradient = LinearGradient(
        colors: [primaryPurple, lightPurple],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let balliGradient = LinearGradient(
        colors: [Color(hex: "67619E"), Color(hex: "918CC4")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let balliGradientDark = LinearGradient(
        colors: [Color(hex: "3E3966"), Color(hex: "524E7D")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static func adaptiveBalliGradient(for colorScheme: ColorScheme) -> LinearGradient {
        return colorScheme == .dark ? balliGradientDark : balliGradient
    }
}
