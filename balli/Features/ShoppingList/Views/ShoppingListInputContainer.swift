//
//  ShoppingListInputContainer.swift
//  balli
//
//  Chat-style input container for shopping list ingredients with voice support
//

import SwiftUI
import CoreData

// Note: Using iOS 26 native Liquid Glass system with .glassEffect for authentic morphing

// MARK: - iOS 26 Glass Effect Container
/// Container for optimal Liquid Glass morphing performance in iOS 26
struct GlassEffectContainer<Content: View>: View {
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        content()
    }
}

// MARK: - Shopping List Input Container

struct ShoppingListInputContainer: View {
    
    // MARK: - Dependencies
    let onAddIngredients: ([ParsedIngredient]) -> Void
    
    // MARK: - State
    @State private var inputText = ""
    @FocusState private var isInputFocused: Bool

    // CRITICAL FIX: Lazy initialize heavy services
    // Don't create until actually needed to prevent blocking on view init
    @State private var ingredientParser: IngredientParser?
    
    // UI state
    @Environment(\.colorScheme) private var colorScheme
    
    @ViewBuilder
    private var messageBoxView: some View {
        VStack(spacing: ResponsiveDesign.Spacing.small) {
                // Text area at the top
                // ULTRA PERFORMANCE FIX: Minimal TextField configuration for instant keyboard response
                TextField("Malzemelerini ekle", text: $inputText, axis: .vertical)
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
                        if !inputText.isEmpty {
                            sendIngredients()
                        }
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

                // Send button at the bottom
                HStack {
                    Spacer()

                    Button(action: sendIngredients) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: ResponsiveDesign.Font.scaledSize(36), weight: .regular, design: .rounded))
                            .foregroundColor(inputText.isEmpty ? Color(.systemGray3) : AppTheme.primaryPurple)
                    }
                    .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .padding(.trailing, ResponsiveDesign.height(6))
                }
                .padding(.bottom, ResponsiveDesign.Spacing.xSmall)
            }
            // iOS 26 Native Liquid Glass Effect with interactive response
            .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            // CRITICAL FIX: Only animate button color change, not entire view
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: inputText.isEmpty)
    }
    
    @ViewBuilder
    private var inputAreaView: some View {
        VStack(spacing: 0) {
            // Message box container with iOS 26 Liquid Glass
            VStack(spacing: ResponsiveDesign.Spacing.small) {
                messageBoxView
            }
            .padding(.horizontal)
            .padding(.bottom, ResponsiveDesign.Spacing.medium)
        }
    }
    
    var body: some View {
        inputAreaView
    }
    
    // MARK: - Helper Functions

    private func getIngredientParser() -> IngredientParser {
        if let parser = ingredientParser {
            return parser
        }
        let newParser = IngredientParser()
        ingredientParser = newParser
        return newParser
    }

    
    // MARK: - Actions
    
    private func sendIngredients() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        Task {
            let parser = getIngredientParser()
            let ingredients = await parser.parseIngredients(from: text)
            
            await MainActor.run {
                if !ingredients.isEmpty {
                    onAddIngredients(ingredients)
                    inputText = ""

                    // Keep focus for continuous adding
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                        isInputFocused = true
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    VStack {
        Spacer()

        ShoppingListInputContainer(
            onAddIngredients: { _ in }
        )
    }
    .background(Color(.systemGray6))
}