//
//  FlowTextWithCitations.swift
//  balli
//
//  Purpose: Renders text with inline citation circles using word-level flow layout
//  Allows citations to wrap naturally with text across multiple lines
//  Swift 6 strict concurrency compliant
//

import SwiftUI

/// Renders text with inline citation circles using word-level flow layout
/// This allows citations to wrap naturally with text across multiple lines
struct FlowTextWithCitations: View {
    let text: String
    let citations: [Int]
    let sources: [ResearchSource]
    let fontSize: CGFloat
    let enableSelection: Bool
    let fontName: String // Font to use for rendering (default: PlayfairDisplay, can be Manrope for blockquotes)

    @State private var selectedCitationIndex: Int?

    init(
        text: String,
        citations: [Int],
        sources: [ResearchSource],
        fontSize: CGFloat,
        enableSelection: Bool,
        fontName: String = "Playfair Display"
    ) {
        self.text = text
        self.citations = citations
        self.sources = sources
        self.fontSize = fontSize
        self.enableSelection = enableSelection
        self.fontName = fontName
    }

    var body: some View {
        let parts = splitTextByCitations(text)

        WrappingHStack(alignment: .firstTextBaseline, spacing: 2) {
            ForEach(Array(parts.enumerated()), id: \.offset) { _, part in
                renderTextPart(part)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sheet(item: citationBinding) { wrapper in
            if wrapper.index < sources.count {
                SourceDetailSheet(source: sources[wrapper.index], index: wrapper.index + 1)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    private var citationBinding: Binding<IndexWrapper?> {
        Binding(
            get: {
                // Safe: Views are always accessed on MainActor
                MainActor.assumeIsolated {
                    selectedCitationIndex.map { IndexWrapper(index: $0) }
                }
            },
            set: { newValue in
                // Safe: Views are always accessed on MainActor
                MainActor.assumeIsolated {
                    selectedCitationIndex = newValue?.index
                }
            }
        )
    }

    // Helper to make Int identifiable for sheet
    struct IndexWrapper: Identifiable {
        let id = UUID()
        let index: Int
    }

    @ViewBuilder
    private func renderTextPart(_ part: TextPart) -> some View {
        switch part {
        case .text(let string):
            renderTextSegment(string)
        case .citation(let number):
            renderInlineCitation(number)
        }
    }

    @ViewBuilder
    private func renderTextSegment(_ string: String) -> some View {
        let segments = splitByEmphasisAndCode(string)

        ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
            switch segment {
            case .regular(let text):
                renderWords(text, isBold: false, isItalic: false, isCode: false)
            case .bold(let text):
                renderWords(text, isBold: true, isItalic: false, isCode: false)
            case .italic(let text):
                renderWords(text, isBold: false, isItalic: true, isCode: false)
            case .code(let text):
                renderWords(text, isBold: false, isItalic: false, isCode: true)
            }
        }
    }

    @ViewBuilder
    private func renderWords(_ text: String, isBold: Bool, isItalic: Bool, isCode: Bool) -> some View {
        let words = text.split(separator: " ", omittingEmptySubsequences: true)

        ForEach(Array(words.enumerated()), id: \.offset) { wordIndex, word in
            let trailingSpace = wordIndex < words.count - 1 ? " " : ""

            if isCode {
                // Render code with background and monospace font
                Text(String(word) + trailingSpace)
                    .font(.custom("Menlo", size: fontSize - 1).monospaced())
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            } else {
                // Use specific font variant names for custom fonts (fontWeight modifier doesn't work reliably with custom fonts)
                let fontVariant = if isBold {
                    fontName + "-Bold"
                } else {
                    fontName + "-Medium"
                }

                let baseText = Text(String(word) + trailingSpace)
                    .font(.custom(fontVariant, size: fontSize))
                    .foregroundStyle(.primary)

                if isItalic {
                    baseText.italic()
                } else {
                    baseText
                }
            }
        }
    }

    @ViewBuilder
    private func renderInlineCitation(_ number: Int) -> some View {
        if number >= 1 && number <= sources.count {
            Button {
                selectedCitationIndex = number - 1
            } label: {
                ZStack {
                    Circle()
                        .fill(AppTheme.primaryPurple.opacity(0.1))
                        .frame(width: 20, height: 20)

                    Text("\(number)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.primaryPurple)
                }
            }
            .buttonStyle(.plain)
        } else {
            // Fallback for citations without sources yet (during streaming)
            ZStack {
                Circle()
                    .fill(AppTheme.primaryPurple.opacity(0.1))
                    .frame(width: 20, height: 20)

                Text("\(number)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.primaryPurple)
            }
        }
    }

    /// Split text by citation markers [1], [2], [1, 2], etc.
    private func splitTextByCitations(_ text: String) -> [TextPart] {
        var parts: [TextPart] = []
        let pattern = "\\[([\\d,\\s]+)\\]"

        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return [.text(text)]
        }

        let matches = regex.matches(in: text, range: NSRange(location: 0, length: text.utf16.count))
        var lastIndex = text.startIndex

        for match in matches {
            if let range = Range(match.range, in: text),
               let numbersRange = Range(match.range(at: 1), in: text) {

                // Add text before citation
                if lastIndex < range.lowerBound {
                    let textPart = String(text[lastIndex..<range.lowerBound])
                    if !textPart.isEmpty {
                        parts.append(.text(textPart))
                    }
                }

                // Parse multiple comma-separated numbers
                let numbersString = String(text[numbersRange])
                let numbers = numbersString
                    .split(separator: ",")
                    .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }

                // Add each citation as a separate part
                for number in numbers {
                    parts.append(.citation(number))
                }

                lastIndex = range.upperBound
            }
        }

        // Add remaining text
        if lastIndex < text.endIndex {
            let remaining = String(text[lastIndex...])
            if !remaining.isEmpty {
                parts.append(.text(remaining))
            }
        }

        return parts
    }

    /// Split text by bold markers **text**, italic markers, and code markers `text`
    private func splitByEmphasisAndCode(_ text: String) -> [EmphasisPart] {
        // First split by code `...`
        let codePattern = "`([^`]+)`"
        let codeRegex = try? NSRegularExpression(pattern: codePattern)

        func splitCode(_ input: String) -> [EmphasisPart] {
            guard let regex = codeRegex else { return splitByEmphasis(input) }
            let matches = regex.matches(in: input, range: NSRange(location: 0, length: input.utf16.count))
            if matches.isEmpty { return splitByEmphasis(input) }
            var parts: [EmphasisPart] = []
            var lastIndex = input.startIndex
            for match in matches {
                if let range = Range(match.range, in: input),
                   let codeRange = Range(match.range(at: 1), in: input) {
                    if lastIndex < range.lowerBound {
                        let textBefore = String(input[lastIndex..<range.lowerBound])
                        parts.append(contentsOf: splitByEmphasis(textBefore))
                    }
                    let codeText = String(input[codeRange])
                    if !codeText.isEmpty { parts.append(.code(codeText)) }
                    lastIndex = range.upperBound
                }
            }
            if lastIndex < input.endIndex {
                let remaining = String(input[lastIndex...])
                if !remaining.isEmpty { parts.append(contentsOf: splitByEmphasis(remaining)) }
            }
            return parts
        }

        return splitCode(text)
    }

    /// Split text by bold markers **text**
    private func splitByEmphasis(_ text: String) -> [EmphasisPart] {
        // First split by bold **...**
        let boldPattern = "\\*\\*(.*?)\\*\\*"
        let boldRegex = try? NSRegularExpression(pattern: boldPattern)

        func splitBold(_ input: String) -> [EmphasisPart] {
            guard let regex = boldRegex else { return [.regular(input)] }
            let matches = regex.matches(in: input, range: NSRange(location: 0, length: input.utf16.count))
            if matches.isEmpty { return [.regular(input)] }
            var parts: [EmphasisPart] = []
            var lastIndex = input.startIndex
            for match in matches {
                if let range = Range(match.range, in: input),
                   let boldRange = Range(match.range(at: 1), in: input) {
                    if lastIndex < range.lowerBound {
                        let regular = String(input[lastIndex..<range.lowerBound])
                        if !regular.isEmpty { parts.append(.regular(regular)) }
                    }
                    let boldText = String(input[boldRange])
                    if !boldText.isEmpty { parts.append(.bold(boldText)) }
                    lastIndex = range.upperBound
                }
            }
            if lastIndex < input.endIndex {
                let remaining = String(input[lastIndex...])
                if !remaining.isEmpty { parts.append(.regular(remaining)) }
            }
            return parts
        }

        // Then split italic markers in regular segments: *...* or _..._
        func splitItalic(_ input: String) -> [EmphasisPart] {
            // Match either *text* or _text_
            let italicPattern = "(\\*([^*]+)\\*|_([^_]+)_)"
            guard let regex = try? NSRegularExpression(pattern: italicPattern) else { return [.regular(input)] }
            let matches = regex.matches(in: input, range: NSRange(location: 0, length: input.utf16.count))
            if matches.isEmpty { return [.regular(input)] }
            var parts: [EmphasisPart] = []
            var lastIndex = input.startIndex
            for match in matches {
                if let range = Range(match.range, in: input) {
                    // Add preceding regular text
                    if lastIndex < range.lowerBound {
                        let regular = String(input[lastIndex..<range.lowerBound])
                        if !regular.isEmpty { parts.append(.regular(regular)) }
                    }
                    // Extract either group 2 or group 3 (star or underscore)
                    let grp2 = match.range(at: 2)
                    let grp3 = match.range(at: 3)
                    if grp2.location != NSNotFound, let italRange = Range(grp2, in: input) {
                        parts.append(.italic(String(input[italRange])))
                    } else if grp3.location != NSNotFound, let italRange = Range(grp3, in: input) {
                        parts.append(.italic(String(input[italRange])))
                    }
                    lastIndex = range.upperBound
                }
            }
            if lastIndex < input.endIndex {
                let remaining = String(input[lastIndex...])
                if !remaining.isEmpty { parts.append(.regular(remaining)) }
            }
            return parts
        }

        // Apply bold split, then italic inside regular pieces
        var output: [EmphasisPart] = []
        for part in splitBold(text) {
            switch part {
            case .bold:
                output.append(part)
            case .regular(let str):
                output.append(contentsOf: splitItalic(str))
            case .italic:
                output.append(part)
            case .code:
                output.append(part)
            }
        }
        return output
    }

    enum TextPart {
        case text(String)
        case citation(Int)
    }

    enum EmphasisPart {
        case regular(String)
        case bold(String)
        case italic(String)
        case code(String)
    }
}
