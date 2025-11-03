//
//  AttributedStringBuilder.swift
//  balli
//
//  Purpose: Convert markdown AST blocks to NSAttributedString with full styling
//  Supports headers, lists, code blocks, inline formatting, and citation circles
//  Swift 6 strict concurrency compliant
//

import UIKit
import SwiftUI
import OSLog

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.balli",
    category: "AttributedStringBuilder"
)

/// Builds NSAttributedString from markdown blocks for native text selection in UITextView
enum AttributedStringBuilder {

    // MARK: - Theme Colors

    /// Primary purple color matching AppTheme.primaryPurple (#67619E)
    private static let primaryPurple = UIColor(red: 103/255, green: 97/255, blue: 158/255, alpha: 1.0)
    private static let primaryPurpleLight = UIColor(red: 103/255, green: 97/255, blue: 158/255, alpha: 0.1)

    // MARK: - Public API

    /// Build complete NSAttributedString from markdown blocks
    static func build(
        from blocks: [MarkdownBlock],
        fontSize: CGFloat,
        fontName: String,
        headerFontSize: CGFloat,
        sources: [ResearchSource]
    ) -> NSAttributedString {
        let result = NSMutableAttributedString()

        for (index, block) in blocks.enumerated() {
            let blockString = buildBlock(
                block,
                fontSize: fontSize,
                fontName: fontName,
                headerFontSize: headerFontSize,
                sources: sources
            )
            result.append(blockString)

            // Add spacing between blocks (except after last block)
            if index < blocks.count - 1 {
                result.append(NSAttributedString(string: "\n\n"))
            }
        }

        return result
    }

    /// Apply text highlights to an attributed string
    static func applyHighlights(
        _ highlights: [TextHighlight],
        to attributedString: NSMutableAttributedString
    ) {
        guard !highlights.isEmpty else { return }

        for highlight in highlights {
            let range = NSRange(location: highlight.startOffset, length: highlight.length)

            // Validate range is within bounds
            guard range.location >= 0,
                  range.location + range.length <= attributedString.length else {
                continue
            }

            // Apply background color with transparency (fixed color, no dark mode adaptation)
            attributedString.addAttribute(
                .backgroundColor,
                value: highlight.color.highlightColor,
                range: range
            )
        }
    }

    // MARK: - Block Rendering

    private static func buildBlock(
        _ block: MarkdownBlock,
        fontSize: CGFloat,
        fontName: String,
        headerFontSize: CGFloat,
        sources: [ResearchSource]
    ) -> NSAttributedString {
        switch block {
        case .heading(let level, let text):
            return buildHeading(level: level, text: text, headerFontSize: headerFontSize)
        case .paragraph(let elements):
            return buildParagraph(elements, fontSize: fontSize, fontName: fontName, sources: sources)
        case .bulletList(let items):
            return buildBulletList(items, fontSize: fontSize, fontName: fontName, sources: sources)
        case .numberedList(let items):
            return buildNumberedList(items, fontSize: fontSize, fontName: fontName, sources: sources)
        case .codeBlock(let language, let code):
            return buildCodeBlock(language: language, code: code, fontSize: fontSize)
        case .blockquote(let text):
            return buildBlockquote(text, fontSize: fontSize, sources: sources)
        case .horizontalRule:
            return buildHorizontalRule()
        }
    }

    // MARK: - Heading

    private static func buildHeading(level: Int, text: String, headerFontSize: CGFloat) -> NSAttributedString {
        // Calculate size based on level
        let size: CGFloat = switch level {
        case 1: headerFontSize
        case 2: headerFontSize * 0.833
        case 3: headerFontSize * 0.722
        case 4: headerFontSize * 0.667
        case 5: headerFontSize * 0.611
        default: headerFontSize * 0.556
        }

        // Use Playfair Display with bold descriptor (matches conversation view)
        let baseFont = UIFont(name: "Playfair Display", size: size)
            ?? UIFont.systemFont(ofSize: size)

        // Apply bold trait
        let font: UIFont
        if let descriptor = baseFont.fontDescriptor.withSymbolicTraits(.traitBold) {
            font = UIFont(descriptor: descriptor, size: size)
        } else {
            font = baseFont
        }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.label
        ]

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.paragraphSpacing = 4

        let result = NSMutableAttributedString(string: text, attributes: attributes)
        result.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: result.length))

        return result
    }

    // MARK: - Paragraph

    private static func buildParagraph(
        _ elements: [InlineElement],
        fontSize: CGFloat,
        fontName: String,
        sources: [ResearchSource]
    ) -> NSAttributedString {
        let result = NSMutableAttributedString()

        for element in elements {
            let elementString = buildInlineElement(element, fontSize: fontSize, fontName: fontName, sources: sources)
            result.append(elementString)
        }

        return result
    }

    private static func buildInlineElement(
        _ element: InlineElement,
        fontSize: CGFloat,
        fontName: String,
        sources: [ResearchSource]
    ) -> NSAttributedString {
        switch element {
        case .text(let string):
            return buildStyledText(string, fontSize: fontSize, fontName: fontName, isBold: false, isItalic: false)
        case .bold(let string):
            return buildStyledText(string, fontSize: fontSize, fontName: fontName, isBold: true, isItalic: false)
        case .italic(let string):
            return buildStyledText(string, fontSize: fontSize, fontName: fontName, isBold: false, isItalic: true)
        case .code(let string):
            return buildInlineCode(string, fontSize: fontSize)
        case .link(let text, _):
            // Links rendered as regular text (history view is read-only)
            return buildStyledText(text, fontSize: fontSize, fontName: fontName, isBold: false, isItalic: false)
        case .citation(let number):
            return buildCitation(number, sources: sources)
        case .latex(let content, let isDisplay):
            return buildLatex(content, isDisplay: isDisplay, fontSize: fontSize)
        }
    }

    // MARK: - Styled Text

    private static func buildStyledText(
        _ text: String,
        fontSize: CGFloat,
        fontName: String,
        isBold: Bool,
        isItalic: Bool
    ) -> NSAttributedString {
        let baseFont = UIFont(name: fontName, size: fontSize)
            ?? UIFont.systemFont(ofSize: fontSize)

        var font = baseFont

        if isBold || isItalic {
            var traits: UIFontDescriptor.SymbolicTraits = []
            if isBold { traits.insert(.traitBold) }
            if isItalic { traits.insert(.traitItalic) }

            if let descriptor = baseFont.fontDescriptor.withSymbolicTraits(traits) {
                font = UIFont(descriptor: descriptor, size: fontSize)
            }
        }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.label
        ]

        return NSAttributedString(string: text, attributes: attributes)
    }

    // MARK: - Inline Code

    private static func buildInlineCode(_ text: String, fontSize: CGFloat) -> NSAttributedString {
        let font = UIFont(name: "Menlo", size: fontSize - 1)
            ?? UIFont.monospacedSystemFont(ofSize: fontSize - 1, weight: .regular)

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.label,
            .backgroundColor: UIColor.secondarySystemFill.withAlphaComponent(0.5)
        ]

        return NSAttributedString(string: text, attributes: attributes)
    }

    // MARK: - Citation Circle

    private static func buildCitation(_ number: Int, sources: [ResearchSource]) -> NSAttributedString {
        let attachment = createCitationAttachment(number)
        return NSAttributedString(attachment: attachment)
    }

    private static func createCitationAttachment(_ number: Int) -> NSTextAttachment {
        let size = CGSize(width: 20, height: 20)

        // Render citation circle to image
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            // Draw purple circle background
            primaryPurpleLight.setFill()
            let circlePath = UIBezierPath(ovalIn: CGRect(origin: .zero, size: size))
            circlePath.fill()

            // Draw number text
            let text = "\(number)" as NSString
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center

            // Try to get rounded system font
            let baseFont = UIFont.systemFont(ofSize: 11, weight: .bold)
            let roundedFont: UIFont
            if let descriptor = baseFont.fontDescriptor.withDesign(.rounded) {
                roundedFont = UIFont(descriptor: descriptor, size: 11)
            } else {
                roundedFont = baseFont
            }

            let attributes: [NSAttributedString.Key: Any] = [
                .font: roundedFont,
                .foregroundColor: primaryPurple,
                .paragraphStyle: paragraphStyle
            ]

            let textSize = text.size(withAttributes: attributes)
            let textRect = CGRect(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )
            text.draw(in: textRect, withAttributes: attributes)
        }

        let attachment = NSTextAttachment()
        attachment.image = image
        attachment.bounds = CGRect(x: 0, y: -3, width: 20, height: 20) // Baseline adjustment

        return attachment
    }

    // MARK: - LaTeX

    private static func buildLatex(_ content: String, isDisplay: Bool, fontSize: CGFloat) -> NSAttributedString {
        let rendered = LaTeXRenderer.render(content)
        let size = isDisplay ? fontSize * 1.2 : fontSize

        // Try to get serif font
        let baseFont = UIFont.systemFont(ofSize: size)
        let font: UIFont
        if let descriptor = baseFont.fontDescriptor.withDesign(.serif) {
            font = UIFont(descriptor: descriptor, size: size)
        } else {
            font = baseFont
        }

        let paragraphStyle = NSMutableParagraphStyle()
        if isDisplay {
            paragraphStyle.alignment = .center
            paragraphStyle.paragraphSpacing = 8
        }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.label,
            .paragraphStyle: paragraphStyle
        ]

        return NSAttributedString(string: rendered, attributes: attributes)
    }

    // MARK: - Bullet List

    private static func buildBulletList(
        _ items: [String],
        fontSize: CGFloat,
        fontName: String,
        sources: [ResearchSource]
    ) -> NSAttributedString {
        let result = NSMutableAttributedString()

        for (index, item) in items.enumerated() {
            // Bullet with purple color - use Heavy weight since ExtraBold doesn't exist in UIFont
            let bulletFont = UIFont(name: "Manrope-ExtraBold", size: fontSize)
                ?? UIFont.systemFont(ofSize: fontSize, weight: .heavy)

            let bulletAttributes: [NSAttributedString.Key: Any] = [
                .font: bulletFont,
                .foregroundColor: primaryPurple
            ]

            result.append(NSAttributedString(string: "•  ", attributes: bulletAttributes))

            // Item content
            let elements = MarkdownParser.parseInlineElements(item)
            let itemContent = buildParagraph(elements, fontSize: fontSize, fontName: fontName, sources: sources)
            result.append(itemContent)

            // Add newline between items (except after last)
            if index < items.count - 1 {
                result.append(NSAttributedString(string: "\n\n"))
            }
        }

        return result
    }

    // MARK: - Numbered List

    private static func buildNumberedList(
        _ items: [String],
        fontSize: CGFloat,
        fontName: String,
        sources: [ResearchSource]
    ) -> NSAttributedString {
        let result = NSMutableAttributedString()

        for (index, item) in items.enumerated() {
            // Number with purple color
            let numberFont = UIFont(name: "Manrope-Bold", size: fontSize)
                ?? UIFont.boldSystemFont(ofSize: fontSize)

            let numberAttributes: [NSAttributedString.Key: Any] = [
                .font: numberFont,
                .foregroundColor: primaryPurple
            ]

            result.append(NSAttributedString(string: "\(index + 1).  ", attributes: numberAttributes))

            // Item content
            let elements = MarkdownParser.parseInlineElements(item)
            let itemContent = buildParagraph(elements, fontSize: fontSize, fontName: fontName, sources: sources)
            result.append(itemContent)

            // Add newline between items (except after last)
            if index < items.count - 1 {
                result.append(NSAttributedString(string: "\n\n"))
            }
        }

        return result
    }

    // MARK: - Code Block

    private static func buildCodeBlock(language: String?, code: String, fontSize: CGFloat) -> NSAttributedString {
        let result = NSMutableAttributedString()

        // Language label (if present)
        if let language = language, !language.isEmpty {
            let labelFont = UIFont(name: "Inter-Medium", size: fontSize - 2)
                ?? UIFont.systemFont(ofSize: fontSize - 2, weight: .medium)
            let labelAttributes: [NSAttributedString.Key: Any] = [
                .font: labelFont,
                .foregroundColor: UIColor.secondaryLabel
            ]
            result.append(NSAttributedString(string: language + "\n", attributes: labelAttributes))
        }

        // Code content - use monospace font
        let codeFont = UIFont(name: "Menlo-Regular", size: fontSize - 1)
            ?? UIFont.monospacedSystemFont(ofSize: fontSize - 1, weight: .regular)

        let codeAttributes: [NSAttributedString.Key: Any] = [
            .font: codeFont,
            .foregroundColor: UIColor.label,
            .backgroundColor: UIColor.secondarySystemFill.withAlphaComponent(0.3)
        ]

        result.append(NSAttributedString(string: code, attributes: codeAttributes))

        return result
    }

    // MARK: - Blockquote

    private static func buildBlockquote(
        _ text: String,
        fontSize: CGFloat,
        sources: [ResearchSource]
    ) -> NSAttributedString {
        // Parse inline elements
        let elements = MarkdownParser.parseInlineElements(text)
        let content = buildParagraph(elements, fontSize: fontSize, fontName: "Manrope", sources: sources)

        // Add visual separator (we'll simulate the left border with a character)
        let result = NSMutableAttributedString()
        result.append(NSAttributedString(string: "▎ ")) // Left border character
        result.append(content)

        return result
    }

    // MARK: - Horizontal Rule

    private static func buildHorizontalRule() -> NSAttributedString {
        // Represent as a line of characters
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 1),
            .foregroundColor: primaryPurple
        ]
        return NSAttributedString(string: "────────────────────", attributes: attributes)
    }
}
