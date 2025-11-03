//
//  SearchModeSelector.swift
//  balli
//
//  Search mode selector for different query types
//  Swift 6 strict concurrency compliant
//

import SwiftUI

struct SearchModeSelector: View {
    @Binding var selectedMode: ResearchMode
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ResearchMode.allCases, id: \.self) { mode in
                    Button {
                        selectedMode = mode
                    } label: {
                        Label(mode.rawValue, systemImage: mode.icon)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(selectedMode == mode ? AppTheme.foregroundOnColor(for: colorScheme) : .primary)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(selectedMode == mode ? AppTheme.primaryPurple : Color.clear)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(selectedMode == mode ? Color.clear : Color.secondary.opacity(0.3), lineWidth: 1)
                    )
                }
            }
            .padding(.horizontal, 16)
        }
        .animation(.spring(response: 0.3), value: selectedMode)
    }
}
