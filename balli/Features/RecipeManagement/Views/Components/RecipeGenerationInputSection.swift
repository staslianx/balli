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

    @State private var editingItemId: UUID?
    @State private var editingText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Malzemeler")
                .font(.custom("Playfair Display", size: 33.32))
                .fontWeight(.bold)
                .foregroundColor(.primary.opacity(0.3))

            // Show existing manual ingredients
            ForEach(ingredients) { item in
                HStack(spacing: 8) {
                    Text("•")
                        .font(.custom("Manrope-Medium", size: 20))
                        .foregroundColor(.primary)

                    if editingItemId == item.id {
                        // Editing mode
                        TextField("", text: $editingText)
                            .font(.custom("Manrope-Medium", size: 20))
                            .focused(focusedField, equals: .ingredient)
                            .submitLabel(.done)
                            .onSubmit {
                                saveEdit(for: item.id)
                            }
                    } else {
                        // Display mode
                        Text(item.text)
                            .font(.custom("Manrope-Medium", size: 20))
                            .foregroundColor(.primary)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                startEditing(item: item)
                            }
                    }

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
                        .font(.custom("Manrope-Medium", size: 20))
                        .foregroundColor(.primary)
                    TextField("Örn: 250g tavuk göğsü", text: $newIngredientText)
                        .font(.custom("Manrope-Medium", size: 20))
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
                            .font(.custom("Manrope-Medium", size: 20))
                            .foregroundColor(.primary.opacity(0.7))
                        Text("Malzeme Ekle")
                            .font(.custom("Manrope-Medium", size: 20))
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
        // Keep the field focused to continue adding ingredients smoothly
        // No need to reassign focus - it's already focused
    }

    private func startEditing(item: RecipeItem) {
        editingItemId = item.id
        editingText = item.text
        focusedField.wrappedValue = .ingredient
    }

    private func saveEdit(for itemId: UUID) {
        guard !editingText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            editingItemId = nil
            return
        }
        if let index = ingredients.firstIndex(where: { $0.id == itemId }) {
            ingredients[index] = RecipeItem(text: editingText)
        }
        editingItemId = nil
        editingText = ""
    }
}

// MARK: - Manual Steps Section

struct ManualStepsSection: View {
    @Binding var steps: [RecipeItem]
    @Binding var isAddingStep: Bool
    @Binding var newStepText: String
    var focusedField: FocusState<RecipeGenerationView.FocusField?>.Binding

    @State private var editingItemId: UUID?
    @State private var editingText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Yapılışı")
                .font(.custom("Playfair Display", size: 33.32))
                .fontWeight(.bold)
                .foregroundColor(.primary.opacity(0.3))

            // Show existing manual steps
            ForEach(Array(steps.enumerated()), id: \.element.id) { index, item in
                HStack(spacing: 8) {
                    Text("\(index + 1).")
                        .font(.custom("Manrope-Medium", size: 20))
                        .foregroundColor(.primary)

                    if editingItemId == item.id {
                        // Editing mode
                        TextField("", text: $editingText)
                            .font(.custom("Manrope-Medium", size: 20))
                            .focused(focusedField, equals: .step)
                            .submitLabel(.done)
                            .onSubmit {
                                saveEdit(for: item.id)
                            }
                    } else {
                        // Display mode
                        Text(item.text)
                            .font(.custom("Manrope-Medium", size: 20))
                            .foregroundColor(.primary)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                startEditing(item: item)
                            }
                    }

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
                        .font(.custom("Manrope-Medium", size: 20))
                        .foregroundColor(.primary)
                    TextField("Örn: Tavukları zeytinyağında sotele", text: $newStepText)
                        .font(.custom("Manrope-Medium", size: 20))
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
                            .font(.custom("Manrope-Medium", size: 20))
                            .foregroundColor(.primary.opacity(0.7))
                        Text("Adım Ekle")
                            .font(.custom("Manrope-Medium", size: 20))
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
        // Keep the field focused to continue adding steps smoothly
        // No need to reassign focus - it's already focused
    }

    private func startEditing(item: RecipeItem) {
        editingItemId = item.id
        editingText = item.text
        focusedField.wrappedValue = .step
    }

    private func saveEdit(for itemId: UUID) {
        guard !editingText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            editingItemId = nil
            return
        }
        if let index = steps.firstIndex(where: { $0.id == itemId }) {
            steps[index] = RecipeItem(text: editingText)
        }
        editingItemId = nil
        editingText = ""
    }
}

// MARK: - Content Section

/// Displays either generated markdown content or manual input placeholders
struct RecipeGenerationContentSection: View {
    let recipeContent: String
    let isStreaming: Bool  // Actual streaming state from viewModel
    @Binding var manualIngredients: [RecipeItem]
    @Binding var manualSteps: [RecipeItem]
    @Binding var isAddingIngredient: Bool
    @Binding var isAddingStep: Bool
    @Binding var newIngredientText: String
    @Binding var newStepText: String
    var focusedField: FocusState<RecipeGenerationView.FocusField?>.Binding
    let onAnimationStateChange: ((Bool) -> Void)?  // Callback for animation state

    /// True when backend is generating but no content has arrived yet
    private var isWaitingForContent: Bool {
        isStreaming && recipeContent.isEmpty
    }

    var body: some View {
        Group {
            if isWaitingForContent {
                // Show shimmer placeholders while waiting for first content
                VStack(alignment: .leading, spacing: 32) {
                    IngredientsShimmerPlaceholder()
                    StepsShimmerPlaceholder()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else if isStreaming || !recipeContent.isEmpty {
                // Use TypewriterRecipeContentView for smooth streaming animation
                TypewriterRecipeContentView(
                    content: recipeContent,
                    isStreaming: isStreaming,  // Use actual state from parent
                    recipeId: "recipe-generation",
                    onAnimationStateChange: onAnimationStateChange  // Pass through callback
                )
            } else {
                // Interactive placeholder - let user add their own recipe
                // Only show when NOT streaming and content is empty
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
