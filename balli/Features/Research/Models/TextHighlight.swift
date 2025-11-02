//
//  TextHighlight.swift
//  balli
//
//  Purpose: Model for text highlights in research answers
//  Stores highlight color, position (character offset), and text content
//  Swift 6 strict concurrency compliant
//

import Foundation
import UIKit

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
        case yellow = "#FFEB3B"
        case green = "#4CAF50"
        case blue = "#2196F3"
        case pink = "#E91E63"
        case orange = "#FF9800"

        /// Convert hex color to UIColor with alpha
        var uiColor: UIColor {
            UIColor(hex: rawValue)
        }

        /// Display name for color (Turkish)
        var displayName: String {
            switch self {
            case .yellow: return "Sarı"
            case .green: return "Yeşil"
            case .blue: return "Mavi"
            case .pink: return "Pembe"
            case .orange: return "Turuncu"
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
