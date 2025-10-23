//
//  CitationFormatter.swift
//  balli
//
//  Purpose: Format citation numbers for display
//  Converts numeric citations to Unicode circled numbers for inline display
//  Swift 6 strict concurrency compliant
//

import Foundation

/// Citation formatting utilities
enum CitationFormatter {

    /// Convert number to Unicode circled number (for inline citations)
    /// Numbers 1-20 have Unicode circled versions, others use bracketed format
    static func convertToCircledNumber(_ number: Int) -> String {
        let circledNumbers = [
            "①", "②", "③", "④", "⑤", "⑥", "⑦", "⑧", "⑨", "⑩",
            "⑪", "⑫", "⑬", "⑭", "⑮", "⑯", "⑰", "⑱", "⑲", "⑳"
        ]

        if number >= 1 && number <= 20 {
            return circledNumbers[number - 1]
        } else {
            // For numbers > 20, use superscript format
            return "[\(number)]"
        }
    }

    /// Build plain text string from inline elements (for word-level rendering)
    static func buildTextString(from elements: [InlineElement]) -> String {
        var result = ""
        for element in elements {
            switch element {
            case .text(let text):
                result += text
            case .bold(let text):
                result += "**\(text)**"
            case .italic(let text):
                result += "_\(text)_"
            case .code(let text):
                result += "`\(text)`"
            case .link(let text, _):
                result += text
            case .latex(let content, _):
                result += LaTeXRenderer.render(content)
            case .citation(let number):
                result += "[\(number)]"
            }
        }
        return result
    }

    /// Extract citation numbers from inline elements
    static func extractCitationNumbers(from elements: [InlineElement]) -> [Int] {
        var citations: [Int] = []
        for element in elements {
            if case .citation(let number) = element {
                citations.append(number)
            }
        }
        return citations
    }
}
