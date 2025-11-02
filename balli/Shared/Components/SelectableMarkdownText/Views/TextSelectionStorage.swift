//
//  TextSelectionStorage.swift
//  balli
//
//  Purpose: Thread-safe storage for text selection state
//  Avoids SwiftUI @State updates that dismiss context menu
//  Swift 6 strict concurrency compliant
//

import Foundation

/// Thread-safe storage for current text selection
/// This avoids SwiftUI state updates that would dismiss the context menu
@MainActor
final class TextSelectionStorage {
    static let shared = TextSelectionStorage()

    private(set) var currentSelection: (range: NSRange, text: String)?

    private init() {}

    func updateSelection(range: NSRange, text: String) {
        currentSelection = (range: range, text: text)
    }

    func clearSelection() {
        currentSelection = nil
    }

    func getSelection() -> (range: NSRange, text: String)? {
        return currentSelection
    }
}
