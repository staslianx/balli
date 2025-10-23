//
//  MarkdownModels.swift
//  balli
//
//  Purpose: Data models for markdown AST (Abstract Syntax Tree)
//  Defines block-level and inline-level markdown elements
//  Swift 6 strict concurrency compliant
//

import Foundation

// MARK: - Markdown AST Models

enum MarkdownBlock: Identifiable {
    case heading(level: Int, text: String)
    case paragraph([InlineElement])
    case bulletList([String])
    case numberedList([String])
    case codeBlock(language: String?, code: String)
    case blockquote(String)
    case horizontalRule

    /// Stable ID based on content hash
    /// This ensures SwiftUI doesn't truncate long content with unstable IDs
    var id: String {
        switch self {
        case .heading(let level, let text):
            return "h\(level)-\(text.hashValue)"
        case .paragraph(let elements):
            // Create hash from all inline elements
            let combined = elements.map { element in
                switch element {
                case .text(let t): return "t:\(t)"
                case .bold(let t): return "b:\(t)"
                case .italic(let t): return "i:\(t)"
                case .code(let t): return "c:\(t)"
                case .link(let text, let url): return "l:\(text):\(url)"
                case .latex(let content, let isDisplay): return "x:\(content):\(isDisplay)"
                case .citation(let num): return "cite:\(num)"
                }
            }.joined()
            return "p-\(combined.hashValue)"
        case .bulletList(let items):
            return "ul-\(items.joined().hashValue)"
        case .numberedList(let items):
            return "ol-\(items.joined().hashValue)"
        case .codeBlock(let lang, let code):
            return "code-\(lang ?? "none")-\(code.hashValue)"
        case .blockquote(let text):
            return "quote-\(text.hashValue)"
        case .horizontalRule:
            return "hr-\(UUID().uuidString)" // Each HR is unique
        }
    }
}

enum InlineElement {
    case text(String)
    case bold(String)
    case italic(String)
    case code(String)
    case link(text: String, url: String)
    case latex(content: String, isDisplayMode: Bool)
    case citation(number: Int)
}
