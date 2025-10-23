//
//  ShoppingListIntegrationService.swift
//  balli
//
//  Service responsible for managing shopping list integration state and user interactions
//  Swift 6 strict concurrency compliant
//

import SwiftUI
import CoreData
import Foundation
import OSLog

// MARK: - Shopping List Integration Protocol

@MainActor
protocol ShoppingListIntegrationServiceProtocol {
    var isShoppingListExpanded: Bool { get set }
    var isShoppingListActive: Bool { get set }
    var navigateToShoppingList: Bool { get set }
    var sentIngredients: Set<String> { get set }
    
    func toggleShoppingList(ingredients: [String], recipeName: String)
    func addIngredientsToShoppingList(ingredients: [String], recipeName: String, dataManager: RecipeDataManager) async
    func resetShoppingListState()
    func hasValidIngredients(_ ingredients: [String]) -> Bool
    func hasValidTitle(_ recipeName: String) -> Bool
}

// MARK: - Shopping List Integration Service Implementation

@MainActor
final class ShoppingListIntegrationService: ShoppingListIntegrationServiceProtocol {

    // MARK: - Properties
    private let logger = AppLoggers.Shopping.list
    var isShoppingListExpanded = false
    var isShoppingListActive = false
    var navigateToShoppingList = false
    var sentIngredients: Set<String> = []
    
    // MARK: - Constants
    private struct Constants {
        static let defaultRecipeName = "Yeni Tarif"
        static let springResponse = 0.6
        static let springDampingFraction = 0.8
        static let checkmarkDelay = 1.5
    }
    
    // MARK: - Initialization
    init() {}
    
    // MARK: - Public Methods
    
    func toggleShoppingList(ingredients: [String], recipeName: String) {
        let hasValidIngredients = hasValidIngredients(ingredients)
        let hasTitle = hasValidTitle(recipeName)
        
        withAnimation(.spring(response: Constants.springResponse, dampingFraction: Constants.springDampingFraction)) {
            if !isShoppingListExpanded && hasValidIngredients && hasTitle {
                // First tap: expand the shopping list UI
                isShoppingListExpanded = true
                isShoppingListActive = false
            } else if !isShoppingListActive && isShoppingListExpanded {
                // Second tap: activate and process ingredients
                isShoppingListActive = true
                
                // Trigger async processing
                Task {
                    await processShoppingListAddition(ingredients: ingredients, recipeName: recipeName)
                }
            }
        }
    }
    
    func addIngredientsToShoppingList(ingredients: [String], recipeName: String, dataManager: RecipeDataManager) async {
        do {
            // Generate a unique ID for this recipe's shopping items
            let recipeId = UUID()
            
            // Use recipe name if available, otherwise use a default name
            let recipeNameToUse = recipeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? Constants.defaultRecipeName
                : recipeName.trimmingCharacters(in: .whitespacesAndNewlines)
            
            let updatedSentIngredients = try await dataManager.addIngredientsToShoppingList(
                ingredients: ingredients,
                sentIngredients: sentIngredients,
                recipeName: recipeNameToUse,
                recipeId: recipeId
            )
            
            sentIngredients = updatedSentIngredients
            
            // Show checkmark animation delay
            try? await Task.sleep(nanoseconds: UInt64(Constants.checkmarkDelay * 1_000_000_000))
            
            await MainActor.run {
                withAnimation(.spring(response: Constants.springResponse, dampingFraction: Constants.springDampingFraction)) {
                    isShoppingListActive = false
                    isShoppingListExpanded = false
                }
            }
        } catch {
            ErrorHandler.shared.handle(error)
            await MainActor.run {
                withAnimation(.spring(response: Constants.springResponse, dampingFraction: Constants.springDampingFraction)) {
                    isShoppingListActive = false
                    isShoppingListExpanded = false
                }
            }
        }
    }
    
    func resetShoppingListState() {
        withAnimation(.spring(response: Constants.springResponse, dampingFraction: Constants.springDampingFraction)) {
            isShoppingListExpanded = false
            isShoppingListActive = false
            navigateToShoppingList = false
        }
        sentIngredients.removeAll()
    }
    
    func hasValidIngredients(_ ingredients: [String]) -> Bool {
        return ingredients.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
    
    func hasValidTitle(_ recipeName: String) -> Bool {
        return !recipeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    // MARK: - Private Methods
    
    private func processShoppingListAddition(ingredients: [String], recipeName: String) async {
        // Note: This method is intended to be called with a dataManager parameter
        // in the actual implementation when refactoring RecipeViewModel
        logger.debug("Shopping list processing initiated for recipe: \(recipeName)")
    }
}

// MARK: - Shopping List Error Types

enum ShoppingListError: Error, UnifiedError {
    case invalidIngredients
    case emptyRecipeName
    case persistenceFailure(String)
    case networkUnavailable
    
    var category: ErrorCategory { .data }
    var severity: ErrorSeverity {
        switch self {
        case .invalidIngredients, .emptyRecipeName:
            return .warning
        case .persistenceFailure:
            return .error
        case .networkUnavailable:
            return .error
        }
    }
    
    var isRecoverable: Bool { true }
    
    var errorDescription: String? {
        switch self {
        case .invalidIngredients:
            return "No valid ingredients found to add to shopping list"
        case .emptyRecipeName:
            return "Recipe name is required for shopping list integration"
        case .persistenceFailure(let message):
            return "Failed to save shopping list items: \(message)"
        case .networkUnavailable:
            return "Network connection required for shopping list sync"
        }
    }
    
    var userAction: String? {
        switch self {
        case .invalidIngredients:
            return "Add some ingredients to your recipe first"
        case .emptyRecipeName:
            return "Please provide a recipe name"
        case .persistenceFailure:
            return "Try again or restart the app"
        case .networkUnavailable:
            return "Check your internet connection and try again"
        }
    }
    
    var technicalDetails: String? {
        switch self {
        case .persistenceFailure(let message):
            return "Core Data persistence error: \(message)"
        default:
            return nil
        }
    }
}