//
//  MarkdownParser.swift
//  balli
//
//  Purpose: Parse markdown text into structured AST blocks
//  Handles all markdown syntax: headings, lists, code, blockquotes, inline elements
//  Pure Swift parser - no external dependencies
//  Swift 6 strict concurrency compliant (nonisolated for background parsing)
//

import Foundation

/// Markdown parser for converting raw text into structured blocks
/// All methods are nonisolated to enable safe background thread execution
enum MarkdownParser {

    /// Parse markdown text into structured blocks
    /// This is the main entry point for parsing
    nonisolated static func parse(_ content: String) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        let lines = content.components(separatedBy: .newlines)
        var currentParagraph: [InlineElement] = []
        var i = 0

        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Skip empty lines
            if trimmed.isEmpty {
                if !currentParagraph.isEmpty {
                    blocks.append(.paragraph(currentParagraph))
                    currentParagraph = []
                }
                i += 1
                continue
            }

            // Headings
            if let heading = parseHeading(trimmed) {
                if !currentParagraph.isEmpty {
                    blocks.append(.paragraph(currentParagraph))
                    currentParagraph = []
                }
                blocks.append(heading)
                i += 1
                continue
            }

            // Horizontal rule
            if trimmed.hasPrefix("---") || trimmed.hasPrefix("***") || trimmed.hasPrefix("___") {
                if !currentParagraph.isEmpty {
                    blocks.append(.paragraph(currentParagraph))
                    currentParagraph = []
                }
                blocks.append(.horizontalRule)
                i += 1
                continue
            }

            // Bullet list
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                if !currentParagraph.isEmpty {
                    blocks.append(.paragraph(currentParagraph))
                    currentParagraph = []
                }
                var listItems: [String] = []
                while i < lines.count {
                    let listLine = lines[i].trimmingCharacters(in: .whitespaces)
                    if listLine.hasPrefix("- ") || listLine.hasPrefix("* ") {
                        listItems.append(String(listLine.dropFirst(2)))
                        i += 1
                    } else if listLine.isEmpty {
                        break
                    } else {
                        break
                    }
                }
                blocks.append(.bulletList(listItems))
                continue
            }

            // Numbered list
            if trimmed.range(of: #"^\d+\.\s"#, options: .regularExpression) != nil {
                if !currentParagraph.isEmpty {
                    blocks.append(.paragraph(currentParagraph))
                    currentParagraph = []
                }
                var listItems: [String] = []
                while i < lines.count {
                    let listLine = lines[i].trimmingCharacters(in: .whitespaces)
                    if let itemMatch = listLine.range(of: #"^\d+\.\s"#, options: .regularExpression) {
                        listItems.append(String(listLine[itemMatch.upperBound...]))
                        i += 1
                    } else if listLine.isEmpty {
                        break
                    } else {
                        break
                    }
                }
                blocks.append(.numberedList(listItems))
                continue
            }

            // Code block
            if trimmed.hasPrefix("```") {
                if !currentParagraph.isEmpty {
                    blocks.append(.paragraph(currentParagraph))
                    currentParagraph = []
                }
                let language = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                i += 1
                var codeLines: [String] = []
                while i < lines.count {
                    let codeLine = lines[i]
                    if codeLine.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                        i += 1
                        break
                    }
                    codeLines.append(codeLine)
                    i += 1
                }
                blocks.append(.codeBlock(language: language.isEmpty ? nil : language, code: codeLines.joined(separator: "\n")))
                continue
            }

            // Blockquote
            if trimmed.hasPrefix("> ") {
                if !currentParagraph.isEmpty {
                    blocks.append(.paragraph(currentParagraph))
                    currentParagraph = []
                }
                var quoteLines: [String] = []
                while i < lines.count {
                    let quoteLine = lines[i].trimmingCharacters(in: .whitespaces)
                    if quoteLine.hasPrefix("> ") {
                        quoteLines.append(String(quoteLine.dropFirst(2)))
                        i += 1
                    } else if quoteLine.isEmpty {
                        break
                    } else {
                        break
                    }
                }
                blocks.append(.blockquote(quoteLines.joined(separator: " ")))
                continue
            }

            // Regular paragraph - parse inline elements
            currentParagraph.append(contentsOf: parseInlineElements(line))
            i += 1
        }

        // Add remaining paragraph
        if !currentParagraph.isEmpty {
            blocks.append(.paragraph(currentParagraph))
        }

        return blocks.isEmpty ? [.paragraph([.text(content)])] : blocks
    }

    // MARK: - Helper Parsing Methods

    /// Parse heading from line
    /// DEFENSIVE: Sanitizes malformed headings like "### ## Text" to prevent raw hash display
    nonisolated private static func parseHeading(_ line: String) -> MarkdownBlock? {
        // Helper function to sanitize heading text by removing extra leading hashes
        func sanitizeHeadingText(_ text: String) -> String {
            var sanitized = text

            // Remove any leading hash symbols from the extracted heading text
            // This handles malformed markdown like "### ## Heading" → "Heading"
            while sanitized.hasPrefix("#") {
                sanitized = String(sanitized.dropFirst())
            }

            // Trim any remaining leading/trailing whitespace
            return sanitized.trimmingCharacters(in: .whitespaces)
        }

        if line.hasPrefix("# ") {
            let text = sanitizeHeadingText(String(line.dropFirst(2)))
            return .heading(level: 1, text: text)
        } else if line.hasPrefix("## ") {
            let text = sanitizeHeadingText(String(line.dropFirst(3)))
            return .heading(level: 2, text: text)
        } else if line.hasPrefix("### ") {
            let text = sanitizeHeadingText(String(line.dropFirst(4)))
            return .heading(level: 3, text: text)
        } else if line.hasPrefix("#### ") {
            let text = sanitizeHeadingText(String(line.dropFirst(5)))
            return .heading(level: 4, text: text)
        } else if line.hasPrefix("##### ") {
            let text = sanitizeHeadingText(String(line.dropFirst(6)))
            return .heading(level: 5, text: text)
        } else if line.hasPrefix("###### ") {
            let text = sanitizeHeadingText(String(line.dropFirst(7)))
            return .heading(level: 6, text: text)
        }
        return nil
    }

    /// Parse inline elements (bold, italic, code, links, LaTeX)
    nonisolated static func parseInlineElements(_ text: String) -> [InlineElement] {
        var elements: [InlineElement] = []
        var currentText = ""
        var i = text.startIndex

        while i < text.endIndex {
            let char = text[i]

            // LaTeX inline math $...$
            // Must check BEFORE checking for underscores (which LaTeX uses)
            if char == "$" {
                // Check if it's display math $$ (requires looking ahead)
                if i < text.index(before: text.endIndex) && text[text.index(after: i)] == "$" {
                    // Display math $$...$$
                    if !currentText.isEmpty {
                        elements.append(.text(currentText))
                        currentText = ""
                    }
                    i = text.index(i, offsetBy: 2) // Skip $$
                    var latexText = ""
                    var foundEnd = false
                    while i < text.endIndex {
                        if text[i] == "$" && i < text.index(before: text.endIndex) && text[text.index(after: i)] == "$" {
                            i = text.index(i, offsetBy: 2) // Skip closing $$
                            foundEnd = true
                            break
                        }
                        latexText.append(text[i])
                        i = text.index(after: i)
                    }
                    if foundEnd && !latexText.isEmpty {
                        elements.append(.latex(content: latexText, isDisplayMode: true))
                    } else {
                        // Failed to parse, add as text
                        currentText.append("$$\(latexText)")
                    }
                    continue
                } else {
                    // Inline math $...$
                    if !currentText.isEmpty {
                        elements.append(.text(currentText))
                        currentText = ""
                    }
                    i = text.index(after: i) // Skip $
                    var latexText = ""
                    var foundEnd = false
                    while i < text.endIndex {
                        if text[i] == "$" {
                            i = text.index(after: i) // Skip closing $
                            foundEnd = true
                            break
                        }
                        latexText.append(text[i])
                        i = text.index(after: i)
                    }
                    if foundEnd && !latexText.isEmpty {
                        elements.append(.latex(content: latexText, isDisplayMode: false))
                    } else {
                        // Failed to parse, add as text
                        currentText.append("$\(latexText)")
                    }
                    continue
                }
            }

            // Bold **text**
            if char == "*" && i < text.index(before: text.endIndex) && text[text.index(after: i)] == "*" {
                if !currentText.isEmpty {
                    elements.append(.text(currentText))
                    currentText = ""
                }
                i = text.index(i, offsetBy: 2)
                var boldText = ""
                while i < text.endIndex {
                    if text[i] == "*" && i < text.index(before: text.endIndex) && text[text.index(after: i)] == "*" {
                        i = text.index(i, offsetBy: 2)
                        break
                    }
                    boldText.append(text[i])
                    i = text.index(after: i)
                }
                if !boldText.isEmpty {
                    elements.append(.bold(boldText))
                }
                continue
            }

            // Italic _text_
            if char == "_" {
                if !currentText.isEmpty {
                    elements.append(.text(currentText))
                    currentText = ""
                }
                i = text.index(after: i)
                var italicText = ""
                while i < text.endIndex {
                    if text[i] == "_" {
                        i = text.index(after: i)
                        break
                    }
                    italicText.append(text[i])
                    i = text.index(after: i)
                }
                if !italicText.isEmpty {
                    elements.append(.italic(italicText))
                }
                continue
            }

            // Inline code `code`
            if char == "`" {
                if !currentText.isEmpty {
                    elements.append(.text(currentText))
                    currentText = ""
                }
                i = text.index(after: i)
                var codeText = ""
                while i < text.endIndex {
                    if text[i] == "`" {
                        i = text.index(after: i)
                        break
                    }
                    codeText.append(text[i])
                    i = text.index(after: i)
                }
                if !codeText.isEmpty {
                    elements.append(.code(codeText))
                }
                continue
            }

            // Citation [N] or Link [text](url)
            if char == "[" {
                if !currentText.isEmpty {
                    elements.append(.text(currentText))
                    currentText = ""
                }
                i = text.index(after: i)
                var bracketContent = ""
                while i < text.endIndex && text[i] != "]" {
                    bracketContent.append(text[i])
                    i = text.index(after: i)
                }
                if i < text.endIndex && text[i] == "]" {
                    i = text.index(after: i)

                    // 🔧 FIX: Check if it's a citation with NEW multi-format parser
                    // Supports: [5], [5, 9], [10, 323338879]
                    // STREAMING FIX: Don't check against sourceCount - sources load AFTER citations stream
                    if let citationNumbers = parseCitationNumbers(bracketContent) {
                        // Append citation elements for each number found
                        for num in citationNumbers {
                            elements.append(.citation(number: num))
                        }
                        continue
                    }

                    // Check if it's a link [text](url)
                    if i < text.endIndex && text[i] == "(" {
                        i = text.index(after: i)
                        var url = ""
                        while i < text.endIndex && text[i] != ")" {
                            url.append(text[i])
                            i = text.index(after: i)
                        }
                        if i < text.endIndex && text[i] == ")" {
                            i = text.index(after: i)
                            elements.append(.link(text: bracketContent, url: url))
                            continue
                        }
                    }
                }
                // Failed to parse as citation or link, add as text
                currentText.append("[\(bracketContent)]")
                continue
            }

            // Regular text
            currentText.append(char)
            i = text.index(after: i)
        }

        if !currentText.isEmpty {
            elements.append(.text(currentText))
        }

        return elements.isEmpty ? [.text(text)] : elements
    }

    /// Parse citation numbers from bracket content
    /// Supports three formats:
    /// - Single: "5" → [5]
    /// - Multiple: "5, 9" → [5, 9]
    /// - Compound: "10, 323338879" → [10] (extracts first number only from very large compound citations)
    nonisolated private static func parseCitationNumbers(_ content: String) -> [Int]? {
        // Remove all whitespace for consistent parsing
        let cleaned = content.replacingOccurrences(of: " ", with: "")

        // Check if comma-separated numbers (multiple or compound citations)
        if cleaned.contains(",") {
            let parts = cleaned.split(separator: ",")
            var numbers: [Int] = []

            for part in parts {
                if let num = Int(part), num >= 1 && num <= 999 {
                    numbers.append(num)
                    // 🔧 FIX: For compound citations with huge numbers (like [10, 323338879]),
                    // only use the first valid number to avoid display issues
                    if numbers.count == 1 && parts.count > 1 {
                        // Check if second part is suspiciously large (> 999)
                        if let secondNum = Int(parts[1]), secondNum > 999 {
                            // This is a compound citation artifact - only use first number
                            return numbers
                        }
                    }
                }
            }

            return numbers.isEmpty ? nil : numbers
        }

        // Single number (existing logic)
        if let num = Int(cleaned), cleaned == String(num), num >= 1 && num <= 999 {
            return [num]
        }

        return nil
    }
}
