//
//  MarkdownText.swift
//  balli
//
//  Full-featured markdown text component for iOS 26
//  Renders ALL markdown syntax including block-level elements during streaming
//  Pure Swift implementation - no external dependencies
//  Swift 6 strict concurrency compliant
//
//  REFACTORED: This file now orchestrates extracted components
//  - Models: MarkdownBlock, InlineElement
//  - Parsing: MarkdownParser, LaTeXRenderer
//  - Rendering: MarkdownRenderer, InlineTextRenderer, CitationFormatter
//  - Components: FlowTextWithCitations, StreamingMarkdownText
//  - Layouts: WrappingHStack, FlexLayout
//

import SwiftUI
import UIKit
import OSLog

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.anaxoniclabs.balli", category: "MarkdownText")

/// Renders markdown text with FULL formatting support including block-level elements
/// Supports: headings, lists (bullet/numbered/nested), tables, code blocks, blockquotes,
/// bold, italic, links, inline code, strikethrough, horizontal rules, citations
/// PERFORMANCE: Caches parsed blocks and parses on background thread for smooth 60 FPS streaming
struct MarkdownText: View {
    let content: String
    let fontSize: CGFloat
    let enableSelection: Bool
    let sourceCount: Int
    let sources: [ResearchSource]
    let blockSpacing: CGFloat
    let lineSpacing: CGFloat
    let headerFontSize: CGFloat
    let headerTopPadding: CGFloat
    let headerBottomPadding: CGFloat
    let fontName: String
    let headerFontName: String
    let skipFirstHeading: Bool

    // PERFORMANCE FIX: Cache parsed blocks to avoid re-parsing on every render
    @State private var parsedBlocks: [MarkdownBlock] = []
    @State private var lastParsedContent: String = ""
    @State private var lastContentLength: Int = 0
    @State private var isInitialParse = true
    @State private var parseTask: Task<Void, Never>?

    init(
        content: String,
        fontSize: CGFloat = 19,
        enableSelection: Bool = true,
        sourceCount: Int = 0,
        sources: [ResearchSource] = [],
        blockSpacing: CGFloat = 12,
        lineSpacing: CGFloat = 4,
        headerFontSize: CGFloat = 30,
        headerTopPadding: CGFloat = 8,
        headerBottomPadding: CGFloat = 0,
        fontName: String = "Playfair Display",
        headerFontName: String = "PlayfairDisplay",
        skipFirstHeading: Bool = false
    ) {
        self.content = content
        self.fontSize = fontSize
        self.enableSelection = enableSelection
        self.sourceCount = sourceCount
        self.sources = sources
        self.blockSpacing = blockSpacing
        self.lineSpacing = lineSpacing
        self.headerFontSize = headerFontSize
        self.headerTopPadding = headerTopPadding
        self.headerBottomPadding = headerBottomPadding
        self.fontName = fontName
        self.headerFontName = headerFontName
        self.skipFirstHeading = skipFirstHeading
    }

    var body: some View {
        let renderer = MarkdownRenderer(
            fontSize: fontSize,
            enableSelection: enableSelection,
            sources: sources,
            headerFontSize: headerFontSize,
            headerTopPadding: headerTopPadding,
            headerBottomPadding: headerBottomPadding,
            fontName: fontName,
            headerFontName: headerFontName
        )

        VStack(alignment: .leading, spacing: blockSpacing) {
            ForEach(Array(parsedBlocks.enumerated()), id: \.element.id) { index, block in
                // Skip first heading if requested (for recipe generation where title is shown separately)
                if skipFirstHeading && index == 0 && isHeading(block) {
                    EmptyView()
                } else {
                    renderer.renderBlock(block)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onChange(of: content) { _, newContent in
            // STREAMING FIX: Parse immediately without canceling for smooth streaming
            // Don't cancel previous parse - let it complete and queue new one
            parseTask = Task {
                await parseContentAsync()
            }
        }
        .onAppear {
            // Handle initial render
            Task {
                await parseContentAsync()
            }
        }
    }

    /// Check if a block is a heading
    private func isHeading(_ block: MarkdownBlock) -> Bool {
        if case .heading = block {
            return true
        }
        return false
    }

    /// Parse content asynchronously on background thread
    /// Uses Task.detached for true off-main-thread parsing
    @MainActor
    private func parseContentAsync() async {
        let contentToParse = content

        // STREAMING FIX: Always parse, don't skip based on lastParsedContent
        // This ensures smooth incremental updates during streaming

        // Parse on background thread with high priority for responsive UI
        let blocks = await Task.detached(priority: .userInitiated) {
            MarkdownParser.parse(contentToParse)
        }.value

        // Update state on main thread
        parsedBlocks = blocks
        lastParsedContent = contentToParse
        lastContentLength = contentToParse.count
        isInitialParse = false
    }
}

// MARK: - Previews

#Preview("All Markdown Features") {
    ScrollView {
        VStack(alignment: .leading, spacing: 20) {
            Text("Comprehensive Markdown Test")
                .font(.headline)

            MarkdownText(content: """
            # Heading 1
            ## Heading 2
            ### Heading 3
            #### Heading 4

            **Bold text** and _italic text_ and **_bold italic_**

            Here's a [link to Apple](https://apple.com)

            Inline `code` works great

            ## Lists

            - Bullet item 1
            - Bullet item 2
            - Bullet item 3

            1. Numbered item 1
            2. Numbered item 2
            3. Numbered item 3

            ## Code Block

            ```swift
            func hello() {
                debugPrint("Hello, World!")
            }
            ```

            ## Blockquote

            > This is a blockquote
            > with multiple lines

            ## Table

            | Column 1 | Column 2 | Column 3 |
            |----------|----------|----------|
            | Data 1   | Data 2   | Data 3   |
            | More     | Data     | Here     |

            ---

            Horizontal rule above!
            """)
        }
        .padding()
    }
}

#Preview("Research View Style - Interactive Spacing") {
    struct ResearchStylePreview: View {
        @State private var blockSpacing: CGFloat = 12
        @State private var fontSize: CGFloat = 17
        @State private var content = ""
        @State private var isStreaming = false

        let sampleAnswer = """
        # Managing Blood Sugar Levels

        **Type 2 diabetes** requires consistent monitoring and lifestyle adjustments to maintain healthy blood sugar levels.

        ## Key Management Strategies

        1. **Regular Exercise**: Aim for at least 150 minutes of moderate activity per week
        2. **Balanced Diet**: Focus on whole grains, lean proteins, and plenty of vegetables
        3. **Medication Adherence**: Take prescribed medications as directed by your healthcare provider
        4. **Blood Sugar Monitoring**: Check your levels as recommended by your doctor

        > Important: Always consult with your healthcare team before making major changes to your diabetes management plan.

        ### Common Symptoms to Watch

        - Increased thirst and frequent urination
        - Unexplained weight loss
        - Fatigue and blurred vision
        - Slow-healing wounds

        Research shows that lifestyle modifications can significantly improve outcomes for people with type 2 diabetes [1][2].

        ```swift
        // Example: Tracking blood sugar
        func logBloodSugar(reading: Double) {
            debugPrint("Blood sugar: \\(reading) mg/dL")
        }
        ```

        For more information, visit [American Diabetes Association](https://diabetes.org)
        """

        var body: some View {
            VStack(spacing: 0) {
                // Controls panel
                VStack(spacing: 12) {
                    HStack {
                        Text("Research View Preview")
                            .font(.system(size: 17, weight: .semibold))
                        Spacer()
                        Button(isStreaming ? "Streaming..." : "Test Stream") {
                            simulateStreaming()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isStreaming)
                        .controlSize(.small)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Block Spacing: \\(Int(blockSpacing))")
                                .font(.caption)
                            Spacer()
                            Text("Font Size: \\(Int(fontSize))")
                                .font(.caption)
                        }

                        HStack(spacing: 12) {
                            VStack(alignment: .leading) {
                                Text("Spacing")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Slider(value: $blockSpacing, in: 4...24, step: 2)
                            }

                            VStack(alignment: .leading) {
                                Text("Size")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Slider(value: $fontSize, in: 14...20, step: 1)
                            }
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))

                Divider()

                // Research view styled content
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        // User question (matches AnswerCardView)
                        Text("What are the best ways to manage type 2 diabetes?")
                            .font(.system(size: 24, weight: .medium, design: .default))
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        // Badge (like research view)
                        HStack(spacing: 8) {
                            Image(systemName: "globe")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Araştırma")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundStyle(.purple)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.purple.opacity(0.1))
                        .clipShape(Capsule())
                        .overlay(Capsule().strokeBorder(Color.purple.opacity(0.3), lineWidth: 1.5))

                        // Answer content with adjustable spacing
                        renderContent(content.isEmpty ? sampleAnswer : content)
                            .padding(.vertical, 8)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
                .background(Color(.systemBackground))
            }
        }

        private func simulateStreaming() {
            content = ""
            isStreaming = true

            Task {
                for char in sampleAnswer {
                    try? await Task.sleep(for: .milliseconds(15))
                    await MainActor.run {
                        content.append(char)
                    }
                }
                await MainActor.run {
                    isStreaming = false
                }
            }
        }

        // Use MarkdownText directly with custom spacing
        @ViewBuilder
        private func renderContent(_ text: String) -> some View {
            MarkdownText(content: text, fontSize: fontSize, blockSpacing: blockSpacing)
        }
    }

    return ResearchStylePreview()
}
