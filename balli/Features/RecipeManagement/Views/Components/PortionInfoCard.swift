//
//  PortionInfoCard.swift
//  balli
//
//  Created by Claude Code on 2025-11-04.
//  Displays portion information on recipe detail view
//

import SwiftUI

/// Card displaying portion size and count information
///
/// Shows:
/// - Portion size in grams
/// - Total portions the recipe makes
/// - "Adjust" button to open PortionDefinerModal
///
/// # Usage
/// ```swift
/// if recipe.isPortionDefined {
///     PortionInfoCard(recipe: recipe) {
///         showPortionDefiner = true
///     }
/// }
/// ```
struct PortionInfoCard: View {

    // MARK: - Properties

    let recipe: Recipe
    let onAdjust: () -> Void

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "fork.knife")
                    .font(.title3)
                    .foregroundColor(.blue)

                Text("Porsiyon Bilgisi")
                    .font(.headline)
                    .foregroundColor(.primary)

                Spacer()

                // Adjust Button
                Button(action: onAdjust) {
                    HStack(spacing: 6) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.caption)
                        Text("Düzenle")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
                }
            }

            Divider()

            // Portion Details
            if let portionCount = recipe.portionCount,
               recipe.portionSize > 0 {
                let portionSize = recipe.portionSize

                HStack(alignment: .top, spacing: 24) {
                    // Portion Size
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Bir Porsiyon")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)

                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(Int(portionSize))")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(.blue)

                            Text("g")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.bottom, 4)
                        }
                    }

                    Divider()
                        .frame(height: 50)

                    // Portion Count
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Toplam")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)

                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(String(format: "%.1f", portionCount))
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(.green)

                            Text("porsiyon")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.bottom, 4)
                        }
                    }
                }

                // Helper Text
                Text("Bu tarif toplam **\(String(format: "%.1f", portionCount))** porsiyon çıkarıyor")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.blue.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Previews

#Preview("Single Portion") {
    let recipe = Recipe(context: PersistenceController.preview.container.viewContext)
    recipe.id = UUID()
    recipe.name = "Test Recipe"
    recipe.totalRecipeWeight = 342
    recipe.portionSize = 342  // Full recipe = 1 portion

    return PortionInfoCard(recipe: recipe) {
    }
    .padding()
}

#Preview("Multiple Portions") {
    let recipe = Recipe(context: PersistenceController.preview.container.viewContext)
    recipe.id = UUID()
    recipe.name = "Test Recipe"
    recipe.totalRecipeWeight = 756
    recipe.portionSize = 252  // 3 portions

    return PortionInfoCard(recipe: recipe) {
    }
    .padding()
}

#Preview("Many Small Portions") {
    let recipe = Recipe(context: PersistenceController.preview.container.viewContext)
    recipe.id = UUID()
    recipe.name = "Test Recipe"
    recipe.totalRecipeWeight = 1200
    recipe.portionSize = 150  // 8 portions

    return PortionInfoCard(recipe: recipe) {
    }
    .padding()
}
