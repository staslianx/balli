//
//  InlineCitationView.swift
//  balli
//
//  Inline citation circles for research answers
//  Swift 6 strict concurrency compliant
//

import SwiftUI

/// Circular citation badge that opens source detail sheet when tapped
/// Unified design matching SourceListRow and SourceDetailSheet
struct InlineCitationView: View {
    let number: Int
    let source: ResearchSource
    @State private var showDetail = false

    var body: some View {
        Button {
            showDetail = true
        } label: {
            Text("\(number)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.primaryPurple)
                .frame(width: 20, height: 20)
                .background {
                    Circle()
                        .fill(AppTheme.primaryPurple.opacity(0.1))
                }
                .glassEffect(.regular.interactive(), in: Circle())
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showDetail) {
            SourceDetailSheet(source: source, index: number)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
}

/// Helper view to render text with inline citations
struct TextWithCitations: View {
    let content: String
    let sources: [ResearchSource]

    var body: some View {
        // Parse content and create attributed string with citations
        let (attributedText, _) = parseCitations(from: content, sources: sources)

        Text(attributedText)
            .font(.system(size: 16, weight: .regular, design: .default))
            .foregroundStyle(.primary)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Parse markdown content and identify citation positions
    private func parseCitations(from markdown: String, sources: [ResearchSource]) -> (AttributedString, [(range: Range<String.Index>, number: Int)]) {
        var attributed: AttributedString

        do {
            attributed = try AttributedString(
                markdown: markdown,
                options: AttributedString.MarkdownParsingOptions(
                    interpretedSyntax: .full
                )
            )
        } catch {
            attributed = AttributedString(markdown)
        }

        // Find citation patterns [1], [2], etc.
        let pattern = "\\[(\\d+)\\]"
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return (attributed, [])
        }

        let nsString = markdown as NSString
        let matches = regex.matches(in: markdown, range: NSRange(location: 0, length: nsString.length))

        for match in matches.reversed() { // Process in reverse to maintain indices
            guard let numberRange = Range(match.range(at: 1), in: markdown),
                  let citationNumber = Int(markdown[numberRange]),
                  citationNumber > 0 && citationNumber <= sources.count else {
                continue
            }

            if let fullRange = Range(match.range, in: markdown) {
                // Replace [N] with styled citation badge in attributed string
                // Unified design matching inline citation button
                if let attrRange = Range(fullRange, in: attributed) {
                    let citation = AttributedString("\(citationNumber)")
                    var styledCitation = citation
                    styledCitation.font = .system(size: 11, weight: .bold)
                    styledCitation.foregroundColor = AppTheme.primaryPurple
                    styledCitation.backgroundColor = AppTheme.primaryPurple.opacity(0.1)

                    attributed.replaceSubrange(attrRange, with: styledCitation)
                }
            }
        }

        return (attributed, [])
    }
}

#Preview {
    VStack(spacing: 20) {
        Text("Inline Citation Examples")
            .font(.headline)

        if let url1 = URL(string: "https://mayoclinic.org"),
           let url2 = URL(string: "https://diabetes.org") {
            InlineCitationView(
                number: 1,
                source: ResearchSource(
                    id: "1",
                    url: url1,
                    domain: "mayoclinic.org",
                    title: "Diabetes Overview",
                    snippet: "Sample snippet",
                    publishDate: nil,
                    author: nil,
                    credibilityBadge: .medicalSource,
                    faviconURL: nil
                )
            )

            InlineCitationView(
                number: 2,
                source: ResearchSource(
                    id: "2",
                    url: url2,
                    domain: "diabetes.org",
                    title: "Type 2 Diabetes",
                    snippet: "Sample snippet",
                    publishDate: nil,
                    author: nil,
                    credibilityBadge: .peerReviewed,
                    faviconURL: nil
                )
            )
        }
    }
    .padding()
}
