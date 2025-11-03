//
//  ResearchSupportingViews.swift
//  balli
//
//  Supporting UI components for research views
//  Extracted from InformationRetrievalView for reusability
//

import SwiftUI

// MARK: - Suggestion Button

struct SuggestionButton: View {
    let icon: String
    let text: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(AppTheme.primaryPurple)
                    .frame(width: 24)

                Text(text)
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)

                Spacer()

                Image(systemName: "arrow.right")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Search Loading View

struct SearchLoadingView: View {
    let message: String
    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(AppTheme.primaryPurple)

            Text(message)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
