//
//  SelectableTextView.swift
//  balli
//
//  Purpose: UITextView wrapper with native iOS text selection
//  Provides draggable handles, magnifying loupe, and visual selection highlight
//  Swift 6 strict concurrency compliant
//

import SwiftUI
import UIKit

/// UITextView wrapper that enables native iOS text selection with draggable handles
struct SelectableTextView: UIViewRepresentable {
    let attributedText: NSAttributedString
    let backgroundColor: UIColor

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()

        // Configure for read-only selection
        textView.isEditable = false
        textView.isSelectable = true
        textView.isScrollEnabled = false // Embedded in ScrollView

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
        textView.attributedText = attributedText
        textView.backgroundColor = backgroundColor
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let width = proposal.width ?? .infinity
        let size = uiView.sizeThatFits(CGSize(width: width, height: .infinity))
        return size
    }
}
