//
//  ShoppingListViewModel.swift
//  balli
//
//  ViewModel for shopping list with proper MVVM architecture
//  Handles business logic, Core Data operations, and state management
//

import SwiftUI
import CoreData
import OSLog

@MainActor
final class ShoppingListViewModel: ObservableObject {
    private let logger = AppLoggers.Shopping.list
    private var viewContext: NSManagedObjectContext
    private let ingredientParser = IngredientParser()

    // MARK: - Published State

    @Published var showCompletedItems = false
    @Published var errorMessage: String?

    // MARK: - Initialization

    init(viewContext: NSManagedObjectContext) {
        self.viewContext = viewContext
    }

    // MARK: - Context Management

    func updateContext(_ context: NSManagedObjectContext) {
        self.viewContext = context
    }

    // MARK: - Computed Properties for Data Grouping

    func uncheckedItems(from items: [ShoppingListItem]) -> [ShoppingListItem] {
        items.filter { !$0.isCompleted && !$0.isFromRecipe }
    }

    func completedItems(from items: [ShoppingListItem]) -> [ShoppingListItem] {
        items.filter { $0.isCompleted && !$0.isFromRecipe }
    }

    func recipeGroups(from items: [ShoppingListItem]) -> [(recipeName: String, recipeId: UUID, items: [ShoppingListItem], allCompleted: Bool)] {
        let recipeItems = items.filter { $0.isFromRecipe }

        let grouped = Dictionary(grouping: recipeItems) { item in
            item.recipeId ?? UUID()
        }

        return grouped.compactMap { recipeId, items in
            guard let firstItem = items.first else { return nil }
            let recipeName = firstItem.recipeName ?? "Tarif"
            let allCompleted = items.allSatisfy { $0.isCompleted }

            // Only return recipes that are not fully completed
            if allCompleted {
                return nil
            }

            return (recipeName: recipeName, recipeId: recipeId, items: items, allCompleted: allCompleted)
        }.sorted { $0.items.first?.dateCreated ?? Date() > $1.items.first?.dateCreated ?? Date() }
    }

    func completedRecipeGroups(from items: [ShoppingListItem]) -> [(recipeName: String, recipeId: UUID, items: [ShoppingListItem])] {
        let recipeItems = items.filter { $0.isFromRecipe }

        let grouped = Dictionary(grouping: recipeItems) { item in
            item.recipeId ?? UUID()
        }

        return grouped.compactMap { recipeId, items in
            guard let firstItem = items.first else { return nil }
            let recipeName = firstItem.recipeName ?? "Tarif"
            let allCompleted = items.allSatisfy { $0.isCompleted }

            // Only return recipes that are fully completed
            if !allCompleted {
                return nil
            }

            return (recipeName: recipeName, recipeId: recipeId, items: items)
        }.sorted { $0.items.first?.dateCreated ?? Date() > $1.items.first?.dateCreated ?? Date() }
    }

    // MARK: - Business Logic

    func addIngredients(_ ingredients: [ParsedIngredient]) {
        Task {
            let _ = await ingredientParser.createShoppingItems(
                from: ingredients,
                in: viewContext
            )

            await MainActor.run {
                saveContext()
            }
        }
    }

    func saveItem(_ item: ShoppingListItem, newText: String, newQuantity: String?) {
        let trimmed = newText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            deleteItem(item)
            return
        }

        item.name = trimmed.capitalized
        item.quantity = newQuantity?.trimmingCharacters(in: .whitespacesAndNewlines)
        item.lastModified = Date()
        saveContext()
    }

    func toggleItem(_ item: ShoppingListItem, allItems: [ShoppingListItem]) {
        withAnimation(.spring()) {
            item.isCompleted.toggle()
            item.lastModified = Date()

            // If this item is from a recipe and we just checked it off,
            // check if all other items in the recipe are also completed
            if item.isFromRecipe && item.isCompleted, let recipeId = item.recipeId {
                let recipeItems = allItems.filter { $0.isFromRecipe && $0.recipeId == recipeId }
                let allCompleted = recipeItems.allSatisfy { $0.isCompleted }

                // If all items in the recipe are now completed,
                // the recipe will automatically move to completed section via recipeGroups filtering
                logger.debug("Recipe \(recipeId) completion status: \(allCompleted)")
            }

            saveContext()
        }
    }

    func deleteItem(_ item: ShoppingListItem) {
        withAnimation(.spring()) {
            viewContext.delete(item)
            saveContext()
        }
    }

    func deleteRecipe(recipeId: UUID, allItems: [ShoppingListItem]) {
        withAnimation(.spring()) {
            // Find all items belonging to this recipe
            let recipeItems = allItems.filter { $0.isFromRecipe && $0.recipeId == recipeId }

            // Delete all items
            for item in recipeItems {
                viewContext.delete(item)
            }

            saveContext()
            logger.info("Deleted \(recipeItems.count) items from recipe \(recipeId)")
        }
    }

    func updateItemNote(_ item: ShoppingListItem, note: String?) {
        item.notes = note?.isEmpty == true ? nil : note
        item.lastModified = Date()
        saveContext()
    }

    func toggleCompletedSection() {
        withAnimation(.spring()) {
            showCompletedItems.toggle()
        }
    }

    // MARK: - Private Helpers

    private func saveContext() {
        do {
            try viewContext.save()
        } catch {
            logger.error("Failed to save shopping list context: \(error.localizedDescription)")
            errorMessage = "Kaydetme başarısız oldu. Lütfen tekrar deneyin."
        }
    }
}

// MARK: - Preview Helper

extension ShoppingListViewModel {
    static var preview: ShoppingListViewModel {
        ShoppingListViewModel(viewContext: PersistenceController.previewFast.container.viewContext)
    }
}
