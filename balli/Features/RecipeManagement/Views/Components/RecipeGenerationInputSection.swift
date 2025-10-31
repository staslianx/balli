//
//  RecipeGenerationInputSection.swift
//  balli
//
//  Manual recipe input components for ingredients and steps
//  Provides inline text fields for user-created recipes
//

import SwiftUI

// MARK: - RecipeItem Model

struct RecipeItem: Identifiable, Equatable, Sendable {
    let id = UUID()
    var text: String

    static func == (lhs: RecipeItem, rhs: RecipeItem) -> Bool {
        lhs.id == rhs.id && lhs.text == rhs.text
    }
}

// MARK: - Manual Ingredients Section

struct ManualIngredientsSection: View {
    @Binding var ingredients: [RecipeItem]
    @Binding var isAddingIngredient: Bool
    @Binding var newIngredientText: String
    var focusedField: FocusState<RecipeGenerationView.FocusField?>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Malzemeler")
                .font(.custom("GalanoGrotesqueAlt-Bold", size: 33.32))
                .foregroundColor(.primary.opacity(0.3))

            // Show existing manual ingredients
            ForEach(ingredients) { item in
                HStack(spacing: 8) {
                    Text("•")
                        .font(.custom("Manrope", size: 20))
                        .foregroundColor(.primary)
                    Text(item.text)
                        .font(.custom("Manrope", size: 20))
                        .foregroundColor(.primary)

                    Spacer()

                    Button(action: {
                        ingredients.removeAll { $0.id == item.id }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.secondary.opacity(0.5))
                    }
                }
            }

            // Inline input or add button
            if isAddingIngredient {
                HStack(spacing: 8) {
                    Text("•")
                        .font(.custom("Manrope", size: 20))
                        .foregroundColor(.primary)
                    TextField("Örn: 250g tavuk göğsü", text: $newIngredientText)
                        .font(.custom("Manrope", size: 20))
                        .focused(focusedField, equals: .ingredient)
                        .submitLabel(.done)
                        .onSubmit {
                            addIngredient()
                        }
                }
            } else {
                Button(action: {
                    isAddingIngredient = true
                    focusedField.wrappedValue = .ingredient
                }) {
                    HStack(spacing: 8) {
                        Text("•")
                            .font(.custom("Manrope", size: 20))
                            .foregroundColor(.primary.opacity(0.7))
                        Text("Malzeme Ekle")
                            .font(.custom("Manrope", size: 20))
                            .foregroundColor(.primary.opacity(0.7))
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func addIngredient() {
        guard !newIngredientText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            isAddingIngredient = false
            return
        }
        ingredients.append(RecipeItem(text: newIngredientText))
        newIngredientText = ""
        focusedField.wrappedValue = .ingredient
    }
}

// MARK: - Manual Steps Section

struct ManualStepsSection: View {
    @Binding var steps: [RecipeItem]
    @Binding var isAddingStep: Bool
    @Binding var newStepText: String
    var focusedField: FocusState<RecipeGenerationView.FocusField?>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Yapılışı")
                .font(.custom("GalanoGrotesqueAlt-Bold", size: 33.32))
                .foregroundColor(.primary.opacity(0.3))

            // Show existing manual steps
            ForEach(Array(steps.enumerated()), id: \.element.id) { index, item in
                HStack(spacing: 8) {
                    Text("\(index + 1).")
                        .font(.custom("Manrope", size: 20))
                        .foregroundColor(.primary)
                    Text(item.text)
                        .font(.custom("Manrope", size: 20))
                        .foregroundColor(.primary)

                    Spacer()

                    Button(action: {
                        steps.removeAll { $0.id == item.id }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.secondary.opacity(0.5))
                    }
                }
            }

            // Inline input or add button
            if isAddingStep {
                HStack(spacing: 8) {
                    Text("\(steps.count + 1).")
                        .font(.custom("Manrope", size: 20))
                        .foregroundColor(.primary)
                    TextField("Örn: Tavukları zeytinyağında sotele", text: $newStepText)
                        .font(.custom("Manrope", size: 20))
                        .focused(focusedField, equals: .step)
                        .submitLabel(.done)
                        .onSubmit {
                            addStep()
                        }
                }
            } else {
                Button(action: {
                    isAddingStep = true
                    focusedField.wrappedValue = .step
                }) {
                    HStack(spacing: 8) {
                        Text("\(steps.count + 1).")
                            .font(.custom("Manrope", size: 20))
                            .foregroundColor(.primary.opacity(0.7))
                        Text("Adım Ekle")
                            .font(.custom("Manrope", size: 20))
                            .foregroundColor(.primary.opacity(0.7))
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func addStep() {
        guard !newStepText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            isAddingStep = false
            return
        }
        steps.append(RecipeItem(text: newStepText))
        newStepText = ""
        focusedField.wrappedValue = .step
    }
}

// MARK: - Content Section

/// Displays either generated markdown content or manual input placeholders
struct RecipeGenerationContentSection: View {
    let recipeContent: String
    @Binding var manualIngredients: [RecipeItem]
    @Binding var manualSteps: [RecipeItem]
    @Binding var isAddingIngredient: Bool
    @Binding var isAddingStep: Bool
    @Binding var newIngredientText: String
    @Binding var newStepText: String
    var focusedField: FocusState<RecipeGenerationView.FocusField?>.Binding

    var body: some View {
        Group {
            if !recipeContent.isEmpty {
                MarkdownText(
                    content: recipeContent,
                    fontSize: 20,
                    enableSelection: true,
                    sourceCount: 0,
                    sources: [],
                    headerFontSize: 20 * 2.0,
                    fontName: "Manrope"
                )
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                // Interactive placeholder - let user add their own recipe
                VStack(alignment: .leading, spacing: 32) {
                    ManualIngredientsSection(
                        ingredients: $manualIngredients,
                        isAddingIngredient: $isAddingIngredient,
                        newIngredientText: $newIngredientText,
                        focusedField: focusedField
                    )

                    ManualStepsSection(
                        steps: $manualSteps,
                        isAddingStep: $isAddingStep,
                        newStepText: $newStepText,
                        focusedField: focusedField
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
