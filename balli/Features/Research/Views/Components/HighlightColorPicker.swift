//
//  HighlightColorPicker.swift
//  balli
//
//  Purpose: Color picker for text highlights
//  Displays horizontal row of colored circles for highlight color selection
//  Swift 6 strict concurrency compliant
//

import SwiftUI

/// Color picker for selecting text highlight colors
struct HighlightColorPicker: View {
    @Binding var selectedColor: TextHighlight.HighlightColor

    var body: some View {
        HStack(spacing: 16) {
            ForEach(TextHighlight.HighlightColor.allCases, id: \.self) { color in
                ColorCircle(
                    color: color,
                    isSelected: selectedColor == color
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedColor = color
                    }
                }
            }
        }
        .padding(.vertical, 12)
    }
}

// MARK: - Color Circle

private struct ColorCircle: View {
    let color: TextHighlight.HighlightColor
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            ZStack {
                // Background circle
                Circle()
                    .fill(Color(uiColor: color.uiColor))
                    .frame(width: 50, height: 50)
                    .overlay {
                        // Selection ring
                        if isSelected {
                            Circle()
                                .strokeBorder(Color.primary, lineWidth: 3)
                                .frame(width: 56, height: 56)
                        }
                    }

                // Checkmark for selected color
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(AppTheme.foregroundOnColor(for: colorScheme))
                        .shadow(color: Color.primary.opacity(0.3), radius: 2, x: 0, y: 1)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(color.displayName) vurgu rengi")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

// MARK: - Previews

#Preview("Color Picker") {
    VStack(spacing: 32) {
        Text("Vurgu Rengi Seç")
            .font(.headline)

        HighlightColorPicker(selectedColor: .constant(.yellow))

        Text("Seçilen: Sarı")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
    .padding()
}

#Preview("All Colors") {
    ScrollView {
        VStack(alignment: .leading, spacing: 24) {
            ForEach(TextHighlight.HighlightColor.allCases, id: \.self) { color in
                VStack(alignment: .leading, spacing: 8) {
                    HighlightColorPicker(selectedColor: .constant(color))

                    Text(color.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
    }
}

#Preview("In Sheet") {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            VStack(spacing: 24) {
                Text("Vurgu Rengi Seç")
                    .font(.headline)

                HighlightColorPicker(selectedColor: .constant(.blue))

                Button("Ekle") {
                    // Action
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 8)
            }
            .padding()
            .presentationDetents([.height(220)])
        }
}
