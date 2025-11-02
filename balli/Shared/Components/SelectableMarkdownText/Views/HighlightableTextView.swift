//
//  HighlightableTextView.swift
//  balli
//
//  Purpose: UITextView wrapper with native text selection and highlight support
//  NO selection change callbacks to avoid SwiftUI re-renders that dismiss context menu
//  Swift 6 strict concurrency compliant
//

import SwiftUI
import UIKit

/// UITextView wrapper that enables native iOS text selection
/// Stores selection internally without notifying SwiftUI to prevent context menu dismissal
struct HighlightableTextView: UIViewRepresentable {
    let attributedText: NSAttributedString
    let backgroundColor: UIColor

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()

        // Configure for read-only selection
        textView.isEditable = false
        textView.isSelectable = true
        textView.isScrollEnabled = false // Embedded in ScrollView

        // Set delegate
        textView.delegate = context.coordinator

        // Remove padding
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0

        // Disable data detectors (no auto-link conversion)
        textView.dataDetectorTypes = []

        // Styling
        textView.backgroundColor = backgroundColor

        // Accessibility
        textView.adjustsFontForContentSizeCategory = true

        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        // CRITICAL: Save selection before updating attributedText
        let savedSelection = textView.selectedRange

        textView.attributedText = attributedText
        textView.backgroundColor = backgroundColor

        // CRITICAL: Restore selection after updating attributedText
        if savedSelection.length > 0 && savedSelection.location + savedSelection.length <= attributedText.length {
            textView.selectedRange = savedSelection
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let width = proposal.width ?? .infinity
        let size = uiView.sizeThatFits(CGSize(width: width, height: .infinity))
        return size
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, UITextViewDelegate {
        func textViewDidChangeSelection(_ textView: UITextView) {
            let selectedRange = textView.selectedRange

            // Store selection in shared storage - NO SwiftUI state updates
            Task { @MainActor in
                if selectedRange.length > 0 {
                    let selectedText = (textView.text as NSString).substring(with: selectedRange)
                    TextSelectionStorage.shared.updateSelection(range: selectedRange, text: selectedText)
                } else {
                    TextSelectionStorage.shared.clearSelection()
                }
            }
        }
    }
}
