//
//  SelectableMarkdownText.swift
//  balli
//
//  Purpose: Markdown text component with native iOS text selection
//  Drop-in replacement for MarkdownText in read-only contexts (like history views)
//  Swift 6 strict concurrency compliant
//

import SwiftUI
import OSLog

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.balli",
    category: "SelectableMarkdownText"
)

/// Renders markdown text with native iOS text selection (draggable handles, magnifying loupe)
/// Uses UITextView for true native selection behavior
/// Citation circles rendered as visual-only elements (non-interactive)
/// Supports text highlights with color annotations
struct SelectableMarkdownText: View {
    let content: String
    let fontSize: CGFloat
    let sources: [ResearchSource]
    let headerFontSize: CGFloat
    let fontName: String
    let highlights: [TextHighlight]

    @Environment(\.colorScheme) private var colorScheme
    @State private var attributedString: NSAttributedString = NSAttributedString()
    @State private var lastParsedContent: String = ""
    @State private var lastHighlightCount: Int = 0

    init(
        content: String,
        fontSize: CGFloat = 19,
        sources: [ResearchSource] = [],
        headerFontSize: CGFloat = 30,
        fontName: String = "Manrope",
        highlights: [TextHighlight] = []
    ) {
        self.content = content
        self.fontSize = fontSize
        self.sources = sources
        self.headerFontSize = headerFontSize
        self.fontName = fontName
        self.highlights = highlights
    }

    var body: some View {
        HighlightableTextView(
            attributedText: attributedString,
            backgroundColor: .systemBackground
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        .task(id: content) {
            await buildAttributedString()
        }
        .task(id: highlights.count) {
            // Rebuild when highlights change
            if lastHighlightCount != highlights.count {
                await buildAttributedString()
            }
        }
        .onAppear {
            // Handle initial render if task hasn't run yet
            if attributedString.length == 0 && !content.isEmpty {
                Task {
                    await buildAttributedString()
                }
            }
        }
    }

    /// Parse markdown and build NSAttributedString asynchronously
    @MainActor
    private func buildAttributedString() async {
        // Skip if content hasn't changed and highlights haven't changed
        let highlightCountChanged = lastHighlightCount != highlights.count
        guard content != lastParsedContent || highlightCountChanged else { return }

        let contentToParse = content
        let fontSize = self.fontSize
        let fontName = self.fontName
        let headerFontSize = self.headerFontSize
        let sources = self.sources
        let highlights = self.highlights

        // Parse markdown on background thread
        let blocks = await Task.detached(priority: .userInitiated) {
            MarkdownParser.parse(contentToParse)
        }.value

        // Build attributed string on main thread (NSAttributedString is not Sendable)
        let mutableAttributed = NSMutableAttributedString(
            attributedString: AttributedStringBuilder.build(
                from: blocks,
                fontSize: fontSize,
                fontName: fontName,
                headerFontSize: headerFontSize,
                sources: sources
            )
        )

        // Apply highlights to attributed string
        AttributedStringBuilder.applyHighlights(highlights, to: mutableAttributed)

        // Update state on main thread
        attributedString = mutableAttributed
        lastParsedContent = contentToParse
        lastHighlightCount = highlights.count

        logger.debug("Built attributed string: \(mutableAttributed.length) characters with \(highlights.count) highlights")
    }
}

// MARK: - Previews

#Preview("Basic Markdown") {
    ScrollView {
        SelectableMarkdownText(
            content: """
            # Heading 1

            This is **bold** text and this is _italic_ text.

            Here's some `inline code` in a sentence.
            """,
            fontSize: 19,
            headerFontSize: 35.72
        )
        .padding()
    }
}

#Preview("With Citations") {
    ScrollView {
        SelectableMarkdownText(
            content: """
            # Research Findings

            Recent studies show significant results [1][2] in diabetes management.

            ## Key Points

            - First important finding [1]
            - Second discovery [2]
            - Third conclusion [3]

            > Important: Always consult healthcare providers [1][2]
            """,
            fontSize: 19,
            sources: [
                ResearchSource(
                    id: "1",
                    url: URL(string: "https://example.com")!,
                    domain: "example.com",
                    title: "Study 1",
                    snippet: "...",
                    publishDate: nil,
                    author: nil,
                    credibilityBadge: nil,
                    faviconURL: nil
                ),
                ResearchSource(
                    id: "2",
                    url: URL(string: "https://example.com")!,
                    domain: "example.com",
                    title: "Study 2",
                    snippet: "...",
                    publishDate: nil,
                    author: nil,
                    credibilityBadge: nil,
                    faviconURL: nil
                )
            ],
            headerFontSize: 35.72
        )
        .padding()
    }
}

#Preview("Code Block") {
    ScrollView {
        SelectableMarkdownText(
            content: """
            # Code Example

            Here's how to use async/await in Swift:

            ```swift
            func fetchData() async throws -> Data {
                let (data, _) = try await URLSession.shared.data(from: url)
                return data
            }
            ```

            The function returns data asynchronously.
            """,
            fontSize: 19,
            headerFontSize: 35.72
        )
        .padding()
    }
}

#Preview("Lists") {
    ScrollView {
        SelectableMarkdownText(
            content: """
            # Management Strategies

            ## Bullet List

            - Regular exercise helps control blood sugar
            - Healthy diet is essential
            - Monitor levels consistently

            ## Numbered List

            1. Check blood sugar in morning
            2. Take medication as prescribed
            3. Log readings in app
            """,
            fontSize: 19,
            headerFontSize: 35.72
        )
        .padding()
    }
}

#Preview("Dark Mode") {
    ScrollView {
        SelectableMarkdownText(
            content: """
            # Dark Mode Test

            This is **bold text** and _italic text_ in dark mode.

            - Bullet point one
            - Bullet point two

            > Blockquote in dark mode
            """,
            fontSize: 19,
            headerFontSize: 35.72
        )
        .padding()
    }
    .preferredColorScheme(.dark)
}

#Preview("Bold Text Spacing") {
    ScrollView {
        SelectableMarkdownText(
            content: """
            # Bold Text Spacing Test

            Testing bold text spacing with the pattern: regular **bold** regular **bold** regular.

            Here is some normal text with **bold words** mixed in to verify proper spacing between bold and regular text.

            Multiple **bold** sections **should** have **proper** spacing **throughout** the paragraph.

            ## Comparison

            All bold: **This entire sentence is bold for comparison.**

            Mixed: This sentence **mixes bold** and regular **text frequently** to test spacing.
            """,
            fontSize: 19,
            headerFontSize: 35.72
        )
        .padding()
    }
}
