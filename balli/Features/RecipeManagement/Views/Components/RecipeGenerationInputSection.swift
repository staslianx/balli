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

    @FocusState private var focusedIngredientId: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Malzemeler")
                .font(.custom("Playfair Display", size: 33.32))
                .fontWeight(.bold)
                .foregroundColor(.primary.opacity(0.3))

            // Show all ingredients (including empty ones being typed)
            ForEach($ingredients) { $item in
                HStack(spacing: 8) {
                    Text("•")
                        .font(.custom("Manrope-Medium", size: 20))
                        .foregroundColor(.primary)

                    TextField("Örn: 250g tavuk göğsü", text: $item.text)
                        .font(.custom("Manrope-Medium", size: 20))
                        .foregroundColor(.primary)
                        .focused($focusedIngredientId, equals: item.id)
                        .submitLabel(.next)
                        .onSubmit {
                            moveToNextIngredient(currentId: item.id)
                        }

                    Spacer()

                    Button(action: {
                        deleteIngredient(id: item.id)
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.secondary.opacity(0.5))
                    }
                }
            }

            // Add ingredient button (only shown when not currently adding)
            if !isAddingIngredient {
                Button(action: {
                    addNewIngredientField()
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
        .onChange(of: focusedIngredientId) { _, newValue in
            // Update parent's isAddingIngredient state based on focus
            isAddingIngredient = newValue != nil
        }
    }

    private func addNewIngredientField() {
        let newItem = RecipeItem(text: "")
        ingredients.append(newItem)
        isAddingIngredient = true
        // Focus on the new field
        focusedIngredientId = newItem.id
    }

    private func moveToNextIngredient(currentId: UUID) {
        guard let currentIndex = ingredients.firstIndex(where: { $0.id == currentId }) else { return }

        let currentItem = ingredients[currentIndex]

        // If current field is empty, dismiss keyboard and stop adding
        if currentItem.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            ingredients.removeAll { $0.id == currentId }
            focusedIngredientId = nil
            isAddingIngredient = false
            return
        }

        // Current field has content - create next field
        let newItem = RecipeItem(text: "")
        ingredients.append(newItem)
        // Move focus to new field
        focusedIngredientId = newItem.id
    }

    private func deleteIngredient(id: UUID) {
        // If we're deleting the focused field, clear focus first
        if focusedIngredientId == id {
            focusedIngredientId = nil
        }
        ingredients.removeAll { $0.id == id }
    }
}

// MARK: - Manual Steps Section

struct ManualStepsSection: View {
    @Binding var steps: [RecipeItem]
    @Binding var isAddingStep: Bool
    @Binding var newStepText: String
    var focusedField: FocusState<RecipeGenerationView.FocusField?>.Binding

    @FocusState private var focusedStepId: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Yapılışı")
                .font(.custom("Playfair Display", size: 33.32))
                .fontWeight(.bold)
                .foregroundColor(.primary.opacity(0.3))

            // Show all steps (including empty ones being typed)
            ForEach(Array($steps.enumerated()), id: \.element.id) { index, $item in
                HStack(spacing: 8) {
                    Text("\(index + 1).")
                        .font(.custom("Manrope-Medium", size: 20))
                        .foregroundColor(.primary)

                    TextField("Örn: Tavukları zeytinyağında sotele", text: $item.text)
                        .font(.custom("Manrope-Medium", size: 20))
                        .foregroundColor(.primary)
                        .focused($focusedStepId, equals: item.id)
                        .submitLabel(.next)
                        .onSubmit {
                            moveToNextStep(currentId: item.id)
                        }

                    Spacer()

                    Button(action: {
                        deleteStep(id: item.id)
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.secondary.opacity(0.5))
                    }
                }
            }

            // Add step button (only shown when not currently adding)
            if !isAddingStep {
                Button(action: {
                    addNewStepField()
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
        .onChange(of: focusedStepId) { _, newValue in
            // Update parent's isAddingStep state based on focus
            isAddingStep = newValue != nil
        }
    }

    private func addNewStepField() {
        let newItem = RecipeItem(text: "")
        steps.append(newItem)
        isAddingStep = true
        // Focus on the new field
        focusedStepId = newItem.id
    }

    private func moveToNextStep(currentId: UUID) {
        guard let currentIndex = steps.firstIndex(where: { $0.id == currentId }) else { return }

        let currentItem = steps[currentIndex]

        // If current field is empty, dismiss keyboard and stop adding
        if currentItem.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            steps.removeAll { $0.id == currentId }
            focusedStepId = nil
            isAddingStep = false
            return
        }

        // Current field has content - create next field
        let newItem = RecipeItem(text: "")
        steps.append(newItem)
        // Move focus to new field
        focusedStepId = newItem.id
    }

    private func deleteStep(id: UUID) {
        // If we're deleting the focused field, clear focus first
        if focusedStepId == id {
            focusedStepId = nil
        }
        steps.removeAll { $0.id == id }
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
