//
//  MarkdownRenderer.swift
//  balli
//
//  Purpose: Render markdown blocks to SwiftUI views
//  Handles all block-level elements: headings, paragraphs, lists, code blocks, blockquotes, etc.
//  Swift 6 strict concurrency compliant
//

import SwiftUI

/// Markdown block renderer
/// Configured with rendering parameters (font sizes, spacing, etc.)
@MainActor
struct MarkdownRenderer {
    let fontSize: CGFloat
    let enableSelection: Bool
    let sources: [ResearchSource]
    let headerFontSize: CGFloat
    let headerTopPadding: CGFloat
    let headerBottomPadding: CGFloat
    let fontName: String
    let headerFontName: String

    @ViewBuilder
    func renderBlock(_ block: MarkdownBlock) -> some View {
        switch block {
        case .heading(let level, let text):
            renderHeading(level: level, text: text)
        case .paragraph(let inlineElements):
            renderParagraph(inlineElements)
        case .bulletList(let items):
            renderBulletList(items)
        case .numberedList(let items):
            renderNumberedList(items)
        case .codeBlock(let language, let code):
            renderCodeBlock(language: language, code: code)
        case .blockquote(let text):
            renderBlockquote(text)
        case .horizontalRule:
            renderHorizontalRule()
        }
    }

    @ViewBuilder
    private func renderHeading(level: Int, text: String) -> some View {
        // Calculate size based on level using independent headerFontSize
        // H1 uses full headerFontSize, smaller headings use proportionally less
        let size: CGFloat = switch level {
        case 1: headerFontSize
        case 2: headerFontSize * 0.833  // ~83% of H1
        case 3: headerFontSize * 0.722  // ~72% of H1
        case 4: headerFontSize * 0.667  // ~67% of H1
        case 5: headerFontSize * 0.611  // ~61% of H1
        default: fontSize
        }

        // Use appropriate font based on headerFontName
        // For variable fonts (Playfair Display), use base name with .weight() modifier
        let headerFont: Font = if headerFontName.contains("Playfair") || headerFontName.contains("playfair") {
            .custom("Playfair Display", size: size).weight(.bold)
        } else {
            .custom(headerFontName, size: size)
        }

        if enableSelection {
            Text(text)
                .font(headerFont)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, headerTopPadding)
                .padding(.bottom, headerBottomPadding)
                .textSelection(.enabled)
        } else {
            Text(text)
                .font(headerFont)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, headerTopPadding)
                .padding(.bottom, headerBottomPadding)
        }
    }

    @ViewBuilder
    private func renderParagraph(_ elements: [InlineElement]) -> some View {
        if elements.isEmpty { EmptyView() }
        else {
            let segments = splitParagraphByDisplayMath(elements)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                    switch segment {
                    case .inline(let inlineElements):
                        // Build text string from elements for word-level flow layout
                        let textContent = CitationFormatter.buildTextString(from: inlineElements)
                        let citationNumbers = CitationFormatter.extractCitationNumbers(from: inlineElements)

                        FlowTextWithCitations(
                            text: textContent,
                            citations: citationNumbers,
                            sources: sources,
                            fontSize: fontSize,
                            enableSelection: enableSelection,
                            fontName: fontName
                        )
                        .padding(.vertical, 2)

                    case .displayLatex(let latex):
                        // Centered block math rendering for $$ ... $$
                        Text(LaTeXRenderer.render(latex))
                            .font(.system(size: fontSize * 1.2, design: .serif))
                            .frame(maxWidth: .infinity, alignment: .center)
                            .multilineTextAlignment(.center)
                            .padding(.vertical, 4)
                    }
                }
            }
        }
    }

    /// Split paragraph inline elements by display-math boundaries ($$...$$)
    private func splitParagraphByDisplayMath(_ elements: [InlineElement]) -> [ParagraphSegment] {
        var segments: [ParagraphSegment] = []
        var currentInline: [InlineElement] = []

        func flushInline() {
            if !currentInline.isEmpty {
                segments.append(.inline(currentInline))
                currentInline.removeAll()
            }
        }

        for element in elements {
            switch element {
            case .latex(let content, let isDisplay) where isDisplay:
                // End current inline run and append block math
                flushInline()
                segments.append(.displayLatex(content))
            default:
                currentInline.append(element)
            }
        }

        flushInline()
        return segments
    }

    private enum ParagraphSegment {
        case inline([InlineElement])
        case displayLatex(String)
    }

    @ViewBuilder
    private func renderBulletList(_ items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .top, spacing: 6) {
                    // Bullet outdented to the left
                    Text("•")
                        .font(.custom("Manrope", size: fontSize).weight(.heavy))
                        .foregroundStyle(.primary)
                        .frame(width: 14, alignment: .trailing)
                        .offset(x: -20) // Outdent bullet to the left

                    // Item content with inline citations and display math blocks
                    let elements = MarkdownParser.parseInlineElements(item)
                    let segments = splitParagraphByDisplayMath(elements)
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                            switch segment {
                            case .inline(let inlineElements):
                                let textContent = CitationFormatter.buildTextString(from: inlineElements)
                                let citationNumbers = CitationFormatter.extractCitationNumbers(from: inlineElements)
                                FlowTextWithCitations(
                                    text: textContent,
                                    citations: citationNumbers,
                                    sources: sources,
                                    fontSize: fontSize,
                                    enableSelection: enableSelection,
                                    fontName: fontName
                                )
                            case .displayLatex(let latex):
                                Text(LaTeXRenderer.render(latex))
                                    .font(.system(size: fontSize * 1.2, design: .serif))
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .multilineTextAlignment(.center)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.leading, 20) // Add padding to compensate for negative offset
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func renderNumberedList(_ items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .top, spacing: 6) {
                    // Number outdented to the left
                    Text("\(index + 1).")
                        .font(.custom("Manrope", size: fontSize).weight(.bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 24, alignment: .trailing)
                        .offset(x: -30) // Outdent number to the left

                    // Item content with inline citations and display math blocks
                    let elements = MarkdownParser.parseInlineElements(item)
                    let segments = splitParagraphByDisplayMath(elements)
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                            switch segment {
                            case .inline(let inlineElements):
                                let textContent = CitationFormatter.buildTextString(from: inlineElements)
                                let citationNumbers = CitationFormatter.extractCitationNumbers(from: inlineElements)
                                FlowTextWithCitations(
                                    text: textContent,
                                    citations: citationNumbers,
                                    sources: sources,
                                    fontSize: fontSize,
                                    enableSelection: enableSelection,
                                    fontName: fontName
                                )
                            case .displayLatex(let latex):
                                Text(LaTeXRenderer.render(latex))
                                    .font(.system(size: fontSize * 1.2, design: .serif))
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .multilineTextAlignment(.center)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.leading, 30) // Add padding to compensate for negative offset
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func renderCodeBlock(language: String?, code: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let language = language, !language.isEmpty {
                Text(language)
                    .font(.custom("Inter", size: fontSize - 2).weight(.medium).monospaced())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
            }
            if enableSelection {
                Text(code)
                    .font(.custom("Inter", size: fontSize - 1).monospaced())
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .textSelection(.enabled)
            } else {
                Text(code)
                    .font(.custom("Inter", size: fontSize - 1).monospaced())
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
        }
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func renderBlockquote(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Rectangle()
                .fill(Color.primary)
                .frame(width: 4)

            // Blockquote content supporting inline citations and display math blocks
            let elements = MarkdownParser.parseInlineElements(text)
            let segments = splitParagraphByDisplayMath(elements)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                    switch segment {
                    case .inline(let inlineElements):
                        let textContent = CitationFormatter.buildTextString(from: inlineElements)
                        let citationNumbers = CitationFormatter.extractCitationNumbers(from: inlineElements)
                        FlowTextWithCitations(
                            text: textContent,
                            citations: citationNumbers,
                            sources: sources,
                            fontSize: fontSize,
                            enableSelection: enableSelection,
                            fontName: "Manrope"
                        )
                    case .displayLatex(let latex):
                        Text(LaTeXRenderer.render(latex))
                            .font(.system(size: fontSize * 1.2, design: .serif))
                            .frame(maxWidth: .infinity, alignment: .center)
                            .multilineTextAlignment(.center)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private func renderHorizontalRule() -> some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.3))
            .frame(height: 1)
            .padding(.vertical, 12)
    }
}
