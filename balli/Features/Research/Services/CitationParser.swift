//
//  CitationParser.swift
//  balli
//
//  Parser for citation links in markdown text
//  Swift 6 strict concurrency compliant
//

import Foundation
import SwiftUI
import OSLog

/// Parser for citation links in markdown text
final class CitationParser: Sendable {
    private static let logger = AppLoggers.Research.parsing

    /// Enrich an already-formatted AttributedString with tappable citation links
    /// - Parameters:
    ///   - attributed: Pre-formatted AttributedString with markdown rendering
    ///   - sourceCount: Number of available sources (for validation)
    /// - Returns: Enriched AttributedString with citation links added
    static func enrichWithCitations(_ attributed: AttributedString, sourceCount: Int) -> AttributedString {
        var result = attributed
        let text = String(attributed.characters)
        let pattern = "\\[(\\d+)\\]"

        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            logger.error("Failed to create citation regex")
            return result
        }

        let nsString = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsString.length))

        // Process matches in reverse to maintain string indices
        for match in matches.reversed() {
            let numberRange = match.range(at: 1)
            let fullRange = match.range

            guard let citationNumber = Int(nsString.substring(with: numberRange)) else {
                continue
            }

            // VALIDATION: Check citation is within bounds
            if citationNumber < 1 || citationNumber > sourceCount {
                logger.error("Invalid citation [\(citationNumber)] - only \(sourceCount) sources available")
                // Keep as plain text, don't make tappable
                continue
            }

            // Convert NSRange to Swift Range
            guard let range = Range(fullRange, in: text) else { continue }

            // Convert to AttributedString range
            let lowerBound = AttributedString.Index(range.lowerBound, within: result)
            let upperBound = AttributedString.Index(range.upperBound, within: result)

            guard let lowerBound = lowerBound, let upperBound = upperBound else {
                continue
            }

            let attributedRange = lowerBound..<upperBound

            // Make tappable with link (preserve existing formatting like bold/italic)
            result[attributedRange].link = URL(string: "citation://\(citationNumber)")
            result[attributedRange].font = .caption.bold()
            result[attributedRange].foregroundColor = AppTheme.primaryPurple
            result[attributedRange].baselineOffset = 4 // Superscript effect
        }

        return result
    }

    /// Parse citations from markdown text and create tappable AttributedString
    /// - Parameters:
    ///   - text: Markdown text with citations like [1][2][3]
    ///   - sourceCount: Number of available sources (for validation)
    /// - Returns: AttributedString with tappable citation links
    /// - Note: DEPRECATED - Use enrichWithCitations instead to preserve markdown formatting
    static func parseWithCitations(_ text: String, sourceCount: Int) -> AttributedString {
        var attributed = AttributedString(text)
        let pattern = "\\[(\\d+)\\]"

        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            logger.error("Failed to create citation regex")
            return attributed
        }

        let nsString = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsString.length))

        // Process matches in reverse to maintain string indices
        for match in matches.reversed() {
            let numberRange = match.range(at: 1)
            let fullRange = match.range

            guard let citationNumber = Int(nsString.substring(with: numberRange)) else {
                continue
            }

            // VALIDATION: Check citation is within bounds
            if citationNumber < 1 || citationNumber > sourceCount {
                logger.error("Invalid citation [\(citationNumber)] - only \(sourceCount) sources available")
                // Keep as plain text, don't make tappable
                continue
            }

            // Convert NSRange to Swift Range
            guard let range = Range(fullRange, in: text) else { continue }

            // Convert to AttributedString range
            let lowerBound = AttributedString.Index(range.lowerBound, within: attributed)
            let upperBound = AttributedString.Index(range.upperBound, within: attributed)

            guard let lowerBound = lowerBound, let upperBound = upperBound else {
                continue
            }

            let attributedRange = lowerBound..<upperBound

            // Make tappable with link
            attributed[attributedRange].link = URL(string: "citation://\(citationNumber)")
            attributed[attributedRange].font = .caption.bold()
            attributed[attributedRange].foregroundColor = AppTheme.primaryPurple
            attributed[attributedRange].baselineOffset = 4 // Superscript effect
        }

        return attributed
    }

    /// Validate all citations in text are within bounds
    /// - Returns: Array of invalid citation numbers
    static func validateCitations(_ text: String, sourceCount: Int) -> [Int] {
        let pattern = "\\[(\\d+)\\]"
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return []
        }

        let nsString = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsString.length))

        var invalidCitations: [Int] = []

        for match in matches {
            let numberRange = match.range(at: 1)
            if let citationNumber = Int(nsString.substring(with: numberRange)) {
                if citationNumber < 1 || citationNumber > sourceCount {
                    invalidCitations.append(citationNumber)
                }
            }
        }

        return invalidCitations
    }
}
