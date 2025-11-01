//
//  RecipeGenerationActions.swift
//  balli
//
//  Action handling and button components for recipe generation
//  Provides favorite, notes, and shopping list functionality
//

import SwiftUI
import OSLog

// MARK: - Recipe Generation Actions Handler

@MainActor
class RecipeGenerationActionsHandler: ObservableObject {
    @Published var isFavorited = false
    @Published var showingNotesModal = false
    @Published var showingShoppingConfirmation = false

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.balli",
        category: "RecipeActions"
    )

    func toggleFavorite(viewModel: RecipeViewModel) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isFavorited.toggle()
        }

        // Only update the form state, don't save
        viewModel.formState.isFavorite = isFavorited
    }

    func handleNotes() {
        showingNotesModal = true
    }

    func handleShopping(viewModel: RecipeViewModel) {
        logger.info("🛒 [ACTIONS] Adding \(viewModel.ingredients.count) ingredients to shopping list")
        logger.debug("📋 [ACTIONS] Recipe name: '\(viewModel.recipeName)'")
        logger.debug("📋 [ACTIONS] First 3 ingredients: \(viewModel.ingredients.prefix(3).joined(separator: ", "))")

        Task {
            await viewModel.addIngredientsToShoppingList()
            logger.info("✅ [ACTIONS] Ingredients successfully added to shopping list")

            // Show confirmation toast
            await MainActor.run {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    showingShoppingConfirmation = true
                }
            }

            // Hide confirmation after 2 seconds
            try? await Task.sleep(for: .seconds(2))
            await MainActor.run {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    showingShoppingConfirmation = false
                }
            }
        }
    }

    func handleAction(_ action: RecipeAction, viewModel: RecipeViewModel) {
        switch action {
        case .favorite:
            toggleFavorite(viewModel: viewModel)
        case .notes:
            handleNotes()
        case .shopping:
            handleShopping(viewModel: viewModel)
        default:
            break
        }
    }
}

// MARK: - Action Buttons Section

struct RecipeGenerationActionButtons: View {
    let isFavorited: Bool
    let onAction: (RecipeAction) -> Void

    var body: some View {
        RecipeActionRow(
            actions: [.favorite, .notes, .shopping],
            activeStates: [isFavorited, false, false],
            loadingStates: [false, false, false],
            completedStates: [false, false, false],
            progressStates: [0, 0, 0]
        ) { action in
            onAction(action)
        }
    }
}
