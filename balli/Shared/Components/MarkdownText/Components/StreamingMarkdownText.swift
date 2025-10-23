//
//  StreamingMarkdownText.swift
//  balli
//
//  Purpose: Markdown text optimized for streaming with smooth fade-in animation
//  Updates content smoothly as tokens arrive without choppiness
//  Swift 6 strict concurrency compliant
//

import SwiftUI

/// Markdown text optimized for streaming with smooth fade-in animation
/// Updates content smoothly as tokens arrive without choppiness
struct StreamingMarkdownText: View {
    let content: String
    let fontSize: CGFloat
    let enableSelection: Bool
    let isStreaming: Bool
    let sourceCount: Int
    let sources: [ResearchSource]

    @State private var displayedContent: String = ""

    init(
        content: String,
        fontSize: CGFloat = 17,
        enableSelection: Bool = true,
        isStreaming: Bool = false,
        sourceCount: Int = 0,
        sources: [ResearchSource] = []
    ) {
        self.content = content
        self.fontSize = fontSize
        self.enableSelection = enableSelection
        self.isStreaming = isStreaming
        self.sourceCount = sourceCount
        self.sources = sources
    }

    var body: some View {
        MarkdownText(content: displayedContent, fontSize: fontSize, enableSelection: enableSelection, sourceCount: sourceCount, sources: sources)
            .onChange(of: content) { _, newValue in
                // Update content smoothly with animation
                withAnimation(.easeInOut(duration: 0.15)) {
                    displayedContent = newValue
                }
            }
            .onAppear {
                // Initialize displayed content
                displayedContent = content
            }
    }
}
