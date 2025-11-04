//
//  DefinePortionPrompt.swift
//  balli
//
//  Created by Claude Code on 2025-11-04.
//  Alert banner prompting user to define portion for manual recipes
//

import SwiftUI

/// Alert banner shown when recipe portion is not defined
///
/// Displays an orange warning banner prompting the user to define
/// what "1 portion" means for the recipe. Tapping opens PortionDefinerModal.
///
/// # Usage
/// ```swift
/// if !recipe.isPortionDefined {
///     DefinePortionPrompt {
///         showPortionDefiner = true
///     }
/// }
/// ```
struct DefinePortionPrompt: View {

    // MARK: - Properties

    let onDefine: () -> Void

    // MARK: - Body

    var body: some View {
        Button(action: onDefine) {
            HStack(spacing: 12) {
                // Warning Icon
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title3)
                    .foregroundColor(.orange)

                // Text Content
                VStack(alignment: .leading, spacing: 4) {
                    Text("Porsiyon Tanımlanmadı")
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text("Besin değerlerini görebilmek için porsiyon miktarını belirle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                // Arrow Icon
                Image(systemName: "chevron.right")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.orange)
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color.orange.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Previews

#Preview {
    VStack(spacing: 20) {
        DefinePortionPrompt {
            print("Define portion tapped")
        }

        // Show in different contexts
        DefinePortionPrompt {
            print("Define portion tapped")
        }
        .padding()
        .background(Color.gray.opacity(0.1))
    }
    .padding()
}
