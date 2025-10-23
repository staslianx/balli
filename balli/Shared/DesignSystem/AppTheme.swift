//
//  AppTheme.swift
//  balli
//
//  Main design system entry point
//  Refactored from 650 lines into modular components
//

import SwiftUI
import CoreText

// MARK: - Main Theme Struct

struct AppTheme {
    // MARK: - Colors (from ThemeColors)
    static let primaryPurple = ThemeColors.primaryPurple
    static let lightPurple = ThemeColors.lightPurple
    static let darkPurple = ThemeColors.darkPurple
    static let purpleBackground = ThemeColors.purpleBackground
    static let internationalOrange = ThemeColors.internationalOrange
    static let dexcomGreen = ThemeColors.dexcomGreen

    // Research Type Colors
    static let deepResearchOrange = ThemeColors.deepResearchOrange
    static let deepResearchOrangeDark = ThemeColors.deepResearchOrangeDark
    static let webSearchBlue = ThemeColors.webSearchBlue
    static let webSearchBlueDark = ThemeColors.webSearchBlueDark
    static let modelPurple = ThemeColors.modelPurple
    static let modelPurpleDark = ThemeColors.modelPurpleDark

    // Adaptive color helpers
    static func recallColor(for colorScheme: ColorScheme) -> Color {
        ThemeColors.recallColor(for: colorScheme)
    }

    static func deepResearchColor(for colorScheme: ColorScheme) -> Color {
        ThemeColors.deepResearchColor(for: colorScheme)
    }

    static func webSearchColor(for colorScheme: ColorScheme) -> Color {
        ThemeColors.webSearchColor(for: colorScheme)
    }

    static func modelColor(for colorScheme: ColorScheme) -> Color {
        ThemeColors.modelColor(for: colorScheme)
    }

    // Semantic Colors
    static let accentColor = ThemeColors.accentColor
    static let secondaryText = ThemeColors.secondaryText
    static let background = ThemeColors.background
    static let secondaryBackground = ThemeColors.secondaryBackground
    static let tertiaryBackground = ThemeColors.tertiaryBackground

    // Card Colors
    static let cardBackground = ThemeColors.cardBackground
    static let cardShadow = ThemeColors.cardShadow

    // Status Colors
    static let success = ThemeColors.success
    static let warning = ThemeColors.warning
    static let error = ThemeColors.error

    // Glucose Chart Colors
    static let glucoseNormal = ThemeColors.glucoseNormal
    static let glucoseBorderline = ThemeColors.glucoseBorderline
    static let glucoseHigh = ThemeColors.glucoseHigh

    // Chat Colors
    static let userBubble = ThemeColors.userBubble
    static let aiBubble = ThemeColors.aiBubble

    // Gradients
    static let purpleGradient = ThemeColors.purpleGradient
    static let balliGradient = ThemeColors.balliGradient
    static let balliGradientDark = ThemeColors.balliGradientDark

    static func adaptiveBalliGradient(for colorScheme: ColorScheme) -> LinearGradient {
        ThemeColors.adaptiveBalliGradient(for: colorScheme)
    }

    // MARK: - Spacing (from ThemeSpacing)
    typealias Spacing = ThemeSpacing

    // MARK: - Corner Radius (from ThemeCornerRadius)
    typealias CornerRadius = ThemeCornerRadius
}
