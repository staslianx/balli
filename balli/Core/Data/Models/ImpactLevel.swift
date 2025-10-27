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

    /// Calculate impact level from score using Nestlé research thresholds
    /// Thresholds based on glycemic load classification:
    /// - Low: GL < 5.0 (very low impact, safe without insulin)
    /// - Medium: GL 5.0-10.0 (moderate impact, caution advised)
    /// - High: GL ≥ 10.0 (high impact, requires insulin)
    /// - Parameter score: The calculated glycemic load score
    /// - Returns: Appropriate impact level
    static func from(score: Double) -> ImpactLevel {
        switch score {
        case ..<5.0:
            return .low
        case 5.0..<10.0:
            return .medium
        default:
            return .high
        }
    }

    /// Calculate impact level from score AND macronutrient thresholds (Nestlé three-factor model)
    /// ALL THREE thresholds must pass for LOW impact:
    /// - Score: < 5.0 (low glycemic load)
    /// - Fat: < 5.0g (minimal gastric delay)
    /// - Protein: < 10.0g (minimal gluconeogenesis)
    /// - Parameters:
    ///   - score: Glycemic load impact score
    ///   - fat: Fat content in grams
    ///   - protein: Protein content in grams
    /// - Returns: Impact level (low/medium/high)
    static func from(score: Double, fat: Double, protein: Double) -> ImpactLevel {
        // Define threshold checks
        let scoreGreen = score < 5.0        // Very low glycemic load
        let fatGreen = fat < 5.0            // Minimal gastric delay (< 30 min)
        let proteinGreen = protein < 10.0   // Minimal gluconeogenesis

        // LOW: All three thresholds pass (safest)
        if scoreGreen && fatGreen && proteinGreen {
            return .low
        }

        // HIGH: Any single threshold in danger zone
        // - Score ≥ 10.0: High glycemic load
        // - Fat ≥ 15.0g: Major gastric delay (90-120+ min)
        // - Protein ≥ 20.0g: Significant late rise (4-5 hours)
        if score >= 10.0 || fat >= 15.0 || protein >= 20.0 {
            return .high
        }

        // MEDIUM: In between (caution zone)
        // - Score 5.0-10.0: Moderate glycemic load
        // - Fat 5.0-15.0g: Moderate delay (30-90 min)
        // - Protein 10.0-20.0g: Moderate late rise (3-4 hours)
        return .medium
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
