//
//  TextHighlight.swift
//  balli
//
//  Purpose: Model for text highlights in research answers
//  Stores highlight color, position (character offset), and text content
//  Swift 6 strict concurrency compliant
//

import Foundation
import SwiftUI

/// Represents a highlighted text segment in a research answer
struct TextHighlight: Codable, Sendable, Identifiable, Equatable {
    let id: UUID
    let color: HighlightColor
    let startOffset: Int  // Character offset in raw markdown content
    let length: Int       // Length of highlighted text in characters
    let text: String      // Actual highlighted text (for validation)
    let createdAt: Date

    init(
        id: UUID = UUID(),
        color: HighlightColor,
        startOffset: Int,
        length: Int,
        text: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.color = color
        self.startOffset = startOffset
        self.length = length
        self.text = text
        self.createdAt = createdAt
    }

    /// Available highlight colors
    enum HighlightColor: String, Codable, CaseIterable, Sendable {
        case green = "#03ff00"      // Vibrant neon green (3,255,0)
        case pink = "#ff00bc"       // Hot magenta pink (255,0,188)
        case yellow = "#deff00"     // Bright lime yellow (222,255,0)
        case cyan = "#00cdff"       // Electric cyan blue (0,205,255)
        case purple = "#8500ff"     // Deep violet purple (133,0,255)

        /// Convert to UIColor (fixed color, no dark mode adaptation)
        var uiColor: UIColor {
            // Create colors with explicit display P3 color space to prevent dynamic behavior
            switch self {
            case .green:
                return UIColor(displayP3Red: 3/255, green: 255/255, blue: 0/255, alpha: 1.0)
            case .pink:
                return UIColor(displayP3Red: 255/255, green: 0/255, blue: 188/255, alpha: 1.0)
            case .yellow:
                return UIColor(displayP3Red: 222/255, green: 255/255, blue: 0/255, alpha: 1.0)
            case .cyan:
                return UIColor(displayP3Red: 0/255, green: 205/255, blue: 255/255, alpha: 1.0)
            case .purple:
                return UIColor(displayP3Red: 133/255, green: 0/255, blue: 255/255, alpha: 1.0)
            }
        }

        /// UIColor with 30% alpha for highlights (fixed, no dark mode adaptation)
        var highlightColor: UIColor {
            switch self {
            case .green:
                return UIColor(displayP3Red: 3/255, green: 255/255, blue: 0/255, alpha: 0.3)
            case .pink:
                return UIColor(displayP3Red: 255/255, green: 0/255, blue: 188/255, alpha: 0.3)
            case .yellow:
                return UIColor(displayP3Red: 222/255, green: 255/255, blue: 0/255, alpha: 0.3)
            case .cyan:
                return UIColor(displayP3Red: 0/255, green: 205/255, blue: 255/255, alpha: 0.3)
            case .purple:
                return UIColor(displayP3Red: 133/255, green: 0/255, blue: 255/255, alpha: 0.3)
            }
        }

        /// SwiftUI Color for menu display (fixed, no dark mode adaptation)
        var swiftUIColor: Color {
            switch self {
            case .green:
                return Color(red: 3/255, green: 255/255, blue: 0/255)
            case .pink:
                return Color(red: 255/255, green: 0/255, blue: 188/255)
            case .yellow:
                return Color(red: 222/255, green: 255/255, blue: 0/255)
            case .cyan:
                return Color(red: 0/255, green: 205/255, blue: 255/255)
            case .purple:
                return Color(red: 133/255, green: 0/255, blue: 255/255)
            }
        }

        /// Display name for color (Turkish)
        var displayName: String {
            switch self {
            case .green: return "Yeşil"
            case .pink: return "Pembe"
            case .yellow: return "Sarı"
            case .cyan: return "Mavi"
            case .purple: return "Mor"
            }
        }
    }
}

// MARK: - UIColor Hex Extension

extension UIColor {
    /// Create UIColor from hex string
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            red: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: CGFloat(a) / 255
        )
    }
}
