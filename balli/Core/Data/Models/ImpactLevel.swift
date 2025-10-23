//
//  ImpactLevel.swift
//  balli
//
//  Blood sugar impact level classification with visual styling
//

import SwiftUI

/// Represents different levels of blood sugar impact
enum ImpactLevel: String, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"

    /// Turkish display text for the impact level
    var displayText: String {
        switch self {
        case .low:
            return "Düşük"
        case .medium:
            return "Orta"
        case .high:
            return "Yüksek"
        }
    }

    /// Color representation using system colors (for label details)
    var color: Color {
        switch self {
        case .low:
            return AppTheme.success // Green
        case .medium:
            return AppTheme.warning // Orange
        case .high:
            return AppTheme.error // Red
        }
    }

    /// Card color - white for all impact levels on gradient backgrounds
    var cardColor: Color {
        return .white
    }

    /// Background color with reduced opacity for glass effect
    var backgroundTintColor: Color {
        color.opacity(0.1)
    }

    /// Border color with medium opacity
    var borderColor: Color {
        color.opacity(0.3)
    }

    /// Text color - uses the main color for contrast
    var textColor: Color {
        color
    }

    /// Calculate impact level from score based on evidence-based research thresholds
    /// Updated thresholds: 0-15 (Low), 16-35 (Medium), ≥36 (High)
    /// - Parameter score: The calculated impact score
    /// - Returns: Appropriate impact level
    static func from(score: Double) -> ImpactLevel {
        switch score {
        case ..<16:
            return .low
        case 16..<36:
            return .medium
        default:
            return .high
        }
    }

    /// Get impact level with additional context for accessibility
    var accessibilityLabel: String {
        switch self {
        case .low:
            return "Düşük kan şekeri etkisi"
        case .medium:
            return "Orta kan şekeri etkisi"
        case .high:
            return "Yüksek kan şekeri etkisi"
        }
    }

    /// System image name for impact level icon
    var systemImageName: String {
        switch self {
        case .low:
            return "checkmark.circle.fill"
        case .medium:
            return "exclamationmark.triangle.fill"
        case .high:
            return "exclamationmark.octagon.fill"
        }
    }

    /// System image name for impact level symbol in pill/compact views
    var pillSymbolName: String {
        switch self {
        case .low:
            return "checkmark.seal.text.page.fill"
        case .medium:
            return "questionmark.text.page.fill"
        case .high:
            return "exclamationmark.triangle.text.page.fill"
        }
    }

    /// System image name for product card impact badge (white on gradient)
    var cardSymbolName: String {
        switch self {
        case .low:
            return "checkmark.seal.fill"
        case .medium:
            return "questionmark.circle.fill"
        case .high:
            return "xmark.seal.fill"
        }
    }
}
