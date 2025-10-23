//
//  SearchBarView.swift
//  balli
//
//  Liquid Glass search input box for research view
//  Swift 6 strict concurrency compliant
//

import SwiftUI

struct SearchBarView: View {
    @Binding var searchQuery: String
    let onSubmit: () -> Void
    let onCancel: () -> Void
    let isSearching: Bool
    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var isInputFocused: Bool

    private func handleSubmit() {
        if !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty {
            isInputFocused = false // Dismiss keyboard
            onSubmit()
            // Clear the input box so user can type next question
            // CONCURRENCY FIX: Use Task.sleep for Swift 6 compliance
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(100))
                searchQuery = ""
            }
        }
    }

    private func handleStopOrSend() {
        if isSearching {
            onCancel()
        } else {
            handleSubmit()
        }
    }

    var body: some View {
        VStack(spacing: ResponsiveDesign.Spacing.small) {
            // Text area at the top
            // ULTRA PERFORMANCE FIX: Minimal TextField configuration for instant keyboard response
            TextField("balli'ye sor", text: $searchQuery, axis: .vertical)
                .textFieldStyle(.plain)
                .focused($isInputFocused)
                .lineLimit(1...6)
                // Remove heavy design font modifier
                .font(.system(size: 17))
                .foregroundColor(.primary)
                .padding(.horizontal, ResponsiveDesign.Spacing.medium)
                .padding(.top, ResponsiveDesign.Spacing.medium)
                .submitLabel(.send)
                .onSubmit {
                    handleSubmit()
                }
                // CRITICAL: Disable autocorrection for faster typing
                .autocorrectionDisabled(true)
                // Optimize keyboard for faster response
                .keyboardType(.default)
                // Swipe down gesture to dismiss keyboard
                .gesture(
                    DragGesture(minimumDistance: 20)
                        .onEnded { value in
                            // Only dismiss if dragging downward
                            if value.translation.height > 0 {
                                isInputFocused = false
                            }
                        }
                )

            // Send/Stop button at the bottom
            HStack {
                Spacer()

                Button(action: handleStopOrSend) {
                    if isSearching {
                        // Stop button (red) during streaming
                        Image(systemName: "stop.circle.fill")
                            .font(.system(size: ResponsiveDesign.Font.scaledSize(36), weight: .regular, design: .rounded))
                            .foregroundColor(.red)
                    } else {
                        // Send button (purple) when idle
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: ResponsiveDesign.Font.scaledSize(36), weight: .regular, design: .rounded))
                            .foregroundColor(searchQuery.isEmpty ? Color(.systemGray3) : AppTheme.primaryPurple)
                    }
                }
                .disabled(!isSearching && searchQuery.trimmingCharacters(in: .whitespaces).isEmpty)
                .padding(.trailing, ResponsiveDesign.height(6))
            }
            .padding(.bottom, ResponsiveDesign.Spacing.xSmall)
        }
        // iOS 26 Native Liquid Glass Effect with interactive response
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        // CRITICAL FIX: Only animate button color change, not entire view
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSearching)
    }
}

// MARK: - Comprehensive Previews

#Preview("Empty State") {
    SearchBarView(
        searchQuery: .constant(""),
        onSubmit: { print("Search submitted") },
        onCancel: { print("Search cancelled") },
        isSearching: false
    )
    .previewWithPadding()
}

#Preview("With Text") {
    @Previewable @State var query = "What are the best foods for Type 1 diabetes?"

    SearchBarView(
        searchQuery: $query,
        onSubmit: { print("Search submitted: \(query)") },
        onCancel: { print("Search cancelled") },
        isSearching: false
    )
    .previewWithPadding()
}

#Preview("Searching (Stop Button)") {
    @Previewable @State var query = "Loading response..."

    SearchBarView(
        searchQuery: $query,
        onSubmit: { print("Search submitted") },
        onCancel: { print("Search cancelled") },
        isSearching: true
    )
    .previewWithPadding()
}

#Preview("Long Multiline Query") {
    @Previewable @State var query = "Can you explain the detailed mechanisms of how different types of exercise affect blood glucose levels in people with Type 1 diabetes, including both aerobic and resistance training?"

    SearchBarView(
        searchQuery: $query,
        onSubmit: { print("Search submitted") },
        onCancel: { print("Search cancelled") },
        isSearching: false
    )
    .previewWithPadding()
}

#Preview("Dark Mode") {
    @Previewable @State var query = "How does insulin work?"

    SearchBarView(
        searchQuery: $query,
        onSubmit: { print("Search submitted") },
        onCancel: { print("Search cancelled") },
        isSearching: false
    )
    .previewWithPadding()
    .preferredColorScheme(.dark)
}

#Preview("Light Mode") {
    @Previewable @State var query = "Carb counting tips"

    SearchBarView(
        searchQuery: $query,
        onSubmit: { print("Search submitted") },
        onCancel: { print("Search cancelled") },
        isSearching: false
    )
    .previewWithPadding()
    .preferredColorScheme(.light)
}

#Preview("Interactive State") {
    @Previewable @State var query = ""

    VStack(spacing: 20) {
        Text("Tap to type, press send button to submit")
            .font(.caption)
            .foregroundStyle(.secondary)

        SearchBarView(
            searchQuery: $query,
            onSubmit: {
                query = ""
            },
            onCancel: { },
            isSearching: false
        )
    }
    .previewWithPadding()
}
