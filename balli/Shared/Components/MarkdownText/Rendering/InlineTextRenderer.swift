//
//  InlineTextRenderer.swift
//  balli
//
//  Purpose: Render inline markdown elements to AttributedString
//  CONSOLIDATES 4 previously duplicated buildAttributedString methods into ONE unified method
//  Supports different font styles for different contexts (paragraphs, tables, blockquotes)
//  Swift 6 strict concurrency compliant
//

import SwiftUI
import UIKit

/// Configuration for inline text rendering style
struct InlineTextStyle {
    let fontName: String
    let fontSize: CGFloat
    let includeCitations: Bool
    let citationFontSize: CGFloat
    let citationBaselineOffset: CGFloat

    /// Default style for paragraphs (Playfair Display)
    static func paragraph(fontSize: CGFloat) -> InlineTextStyle {
        InlineTextStyle(
            fontName: "Playfair Display",
            fontSize: fontSize,
            includeCitations: true,
            citationFontSize: fontSize * 0.9,
            citationBaselineOffset: 2
        )
    }

    /// Style for tables (Manrope, smaller)
    static func table(fontSize: CGFloat) -> InlineTextStyle {
        InlineTextStyle(
            fontName: "Manrope",
            fontSize: fontSize - 1,
            includeCitations: true,
            citationFontSize: (fontSize - 1) * 0.9,
            citationBaselineOffset: 1
        )
    }

    /// Style for blockquotes (Manrope)
    static func blockquote(fontSize: CGFloat) -> InlineTextStyle {
        InlineTextStyle(
            fontName: "Manrope",
            fontSize: fontSize,
            includeCitations: true,
            citationFontSize: fontSize * 0.9,
            citationBaselineOffset: 2
        )
    }

    /// Legacy style without citations
    static func legacy(fontSize: CGFloat) -> InlineTextStyle {
        InlineTextStyle(
            fontName: "Playfair Display",
            fontSize: fontSize,
            includeCitations: true,
            citationFontSize: fontSize * 0.9,
            citationBaselineOffset: 2
        )
    }
}

/// Inline text renderer - builds AttributedString from inline elements
enum InlineTextRenderer {

    /// Build attributed string with configurable style
    /// UNIFIED METHOD: Replaces 4 previously duplicated methods
    /// - buildAttributedString (legacy)
    /// - buildAttributedStringWithInlineCitations
    /// - buildTableAttributedString
    /// - buildBlockquoteAttributedString
    static func buildAttributedString(
        from elements: [InlineElement],
        style: InlineTextStyle
    ) -> AttributedString {
        var result = AttributedString()

        for element in elements {
            switch element {
            case .text(let text):
                var attributed = AttributedString(text)
                attributed.font = .custom(style.fontName, size: style.fontSize).weight(.semibold)
                result += attributed

            case .bold(let text):
                var attributed = AttributedString(text)
                attributed.font = .custom(style.fontName, size: style.fontSize).weight(.semibold).weight(.bold)
                result += attributed

            case .italic(let text):
                var attributed = AttributedString(text)
                // For italic, we need to construct a UIFont with italic traits
                if let baseFont = UIFont(name: style.fontName, size: style.fontSize),
                   let italicDescriptor = baseFont.fontDescriptor.withSymbolicTraits(.traitItalic) {
                    let italicFont = UIFont(descriptor: italicDescriptor, size: style.fontSize)
                    attributed.font = Font(italicFont)
                } else {
                    // Fallback to system italic
                    let design: Font.Design = style.fontName == "Manrope" ? .default : .serif
                    attributed.font = .system(size: style.fontSize, design: design).italic()
                }
                result += attributed

            case .code(let text):
                var attributed = AttributedString(text)
                // Tables/blockquotes use Menlo, paragraphs use custom font
                if style.fontName == "Manrope" {
                    attributed.font = .custom("Menlo", size: style.fontSize - 1).monospaced()
                } else {
                    attributed.font = .custom(style.fontName, size: style.fontSize - 1).monospaced()
                }
                attributed.backgroundColor = Color.secondary.opacity(0.15)
                result += attributed

            case .link(let text, let url):
                var attributed = AttributedString(text)
                attributed.font = .custom(style.fontName, size: style.fontSize).weight(.semibold)
                attributed.foregroundColor = .blue
                attributed.underlineStyle = .single
                if let linkUrl = URL(string: url) {
                    attributed.link = linkUrl
                }
                result += attributed

            case .latex(let content, let isDisplayMode):
                // Render LaTeX content
                let renderedLatex = LaTeXRenderer.render(content)
                var attributed = AttributedString(renderedLatex)

                if isDisplayMode {
                    // Display mode: centered, larger serif font for mathematical look
                    attributed.font = .system(size: style.fontSize * 1.2, design: .serif)
                } else {
                    // Inline mode: regular serif font for mathematical look
                    attributed.font = .system(size: style.fontSize, design: .serif)
                }

                result += attributed

            case .citation(let number):
                if style.includeCitations {
                    // Render citation as inline circular badge using Unicode circled numbers
                    // This ensures citations appear INLINE within the text, not as separate elements
                    let citationText = CitationFormatter.convertToCircledNumber(number)
                    var attributed = AttributedString(citationText)
                    attributed.font = .system(size: style.citationFontSize, weight: .bold, design: .rounded)
                    attributed.foregroundColor = AppTheme.primaryPurple
                    attributed.baselineOffset = style.citationBaselineOffset // Slight superscript effect
                    result += attributed
                }
            }
        }

        return result
    }
}
