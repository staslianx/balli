//
//  RecipeImageHandler.swift
//  balli
//
//  Handles image loading, preparation, and shopping list integration for recipes
//  Swift 6 strict concurrency compliant
//

import SwiftUI
import CoreData
import Foundation
import OSLog

@MainActor
public class RecipeImageHandler: ObservableObject {
    // MARK: - Dependencies
    private let formState: RecipeFormState
    private let dataManager: RecipeDataManager
    private let viewContext: NSManagedObjectContext
    private let logger = AppLoggers.Recipe.generation

    // MARK: - Image State
    @Published public var recipeImageURL: String?
    @Published public var recipeImageData: Data? {
        didSet {
            // PERFORMANCE FIX: Decode image asynchronously to prevent main thread blocking
            prepareImageAsync(from: recipeImageData)
        }
    }
    @Published public var isUploadingImage = false
    @Published public var isLoadingImageFromStorage = false

    // MARK: - Pre-decoded Image Cache (Performance Optimization)
    /// Pre-decoded UIImage to eliminate synchronous UIImage(data:) calls in SwiftUI body
    /// This prevents main thread blocking and eliminates unsafeForcedSync warnings
    @Published public var preparedImage: UIImage?

    // MARK: - Shopping List State
    @Published public var isShoppingListExpanded = false
    @Published public var isShoppingListActive = false
    @Published public var navigateToShoppingList = false
    @Published public var sentIngredients: Set<String> = []

    // MARK: - Computed Properties
    public var isImageFromLocalData: Bool {
        return recipeImageData != nil && !isLoadingImageFromStorage
    }

    // MARK: - Initialization
    public init(formState: RecipeFormState, context: NSManagedObjectContext) {
        self.formState = formState
        self.viewContext = context
        self.dataManager = RecipeDataManager(context: context)
    }

    // MARK: - Image Loading

    /// Loads image data from a URL and updates the recipe image
    /// Handles both base64 data URLs and HTTP/HTTPS URLs
    public func loadImageFromGeneratedURL(generatedPhotoURL: String?) async {
        logger.info("🖼️ [LOAD-IMAGE] loadImageFromGeneratedURL() called")
        if let photoURL = generatedPhotoURL {
            logger.debug("📋 [LOAD-IMAGE] generatedPhotoURL: present (\(photoURL.prefix(60))...)")
        } else {
            logger.debug("📋 [LOAD-IMAGE] generatedPhotoURL: nil")
        }

        guard let imageURL = generatedPhotoURL else {
            logger.warning("⚠️ [LOAD-IMAGE] Cannot load image: missing URL")
            return
        }

        // Handle base64 data URLs differently from HTTP URLs
        if imageURL.hasPrefix("data:") {
            // Extract base64 data from data URL
            logger.info("📦 [LOAD-IMAGE] Loading image from base64 data URL")

            // Data URL format: data:image/jpeg;base64,/9j/4AAQ...
            guard let commaIndex = imageURL.firstIndex(of: ",") else {
                logger.error("❌ [LOAD-IMAGE] Invalid data URL format: missing comma")
                return
            }

            let base64String = String(imageURL[imageURL.index(after: commaIndex)...])
            logger.debug("🔍 [LOAD-IMAGE] Extracted base64 string length: \(base64String.count) characters")

            guard let imageData = Data(base64Encoded: base64String) else {
                logger.error("❌ [LOAD-IMAGE] Failed to decode base64 image data")
                return
            }

            logger.info("✅ [LOAD-IMAGE] Successfully decoded base64 to Data (\(imageData.count) bytes)")

            await MainActor.run {
                logger.info("💾 [LOAD-IMAGE] Setting recipeImageData = imageData (\(imageData.count) bytes)")
                recipeImageData = imageData
                recipeImageURL = imageURL
                logger.info("✅ [LOAD-IMAGE] recipeImageData has been set")
            }
            logger.info("✅ [LOAD-IMAGE] Successfully loaded image from base64 data (\(imageData.count) bytes)")

        } else {
            // Handle HTTP/HTTPS URLs with URLSession
            guard let url = URL(string: imageURL) else {
                logger.warning("Cannot load image: invalid URL")
                return
            }

            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                await MainActor.run {
                    recipeImageData = data
                    recipeImageURL = imageURL
                }
                logger.info("✅ Successfully loaded generated recipe image from network")
            } catch {
                logger.error("❌ Failed to load generated image from URL: \(error.localizedDescription)")
                ErrorHandler.shared.handle(error)
            }
        }
    }

    /// Asynchronously decodes image data to UIImage on a background thread
    /// This prevents main thread blocking and eliminates unsafeForcedSync warnings
    private func prepareImageAsync(from data: Data?) {
        guard let data = data else {
            preparedImage = nil
            return
        }

        // Decode image on background thread to avoid blocking main thread
        Task.detached(priority: .userInitiated) {
            // UIImage(data:) is synchronous but we're on a background thread
            let image = UIImage(data: data)

            // Update UI on main thread
            await MainActor.run {
                self.preparedImage = image
            }
        }
    }

    // MARK: - Shopping List Integration

    public func toggleShoppingList() {
        toggleShoppingListInternal(ingredients: formState.ingredients, recipeName: formState.recipeName)

        if isShoppingListActive {
            Task {
                await addIngredientsToShoppingList()
            }
        }
    }

    public func addIngredientsToShoppingList() async {
        await addIngredientsToShoppingListInternal(
            ingredients: formState.ingredients,
            recipeName: formState.recipeName
        )
    }

    public func resetShoppingListState() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            isShoppingListExpanded = false
            isShoppingListActive = false
            navigateToShoppingList = false
        }
        sentIngredients.removeAll()
    }

    // MARK: - Private Shopping List Methods

    private func toggleShoppingListInternal(ingredients: [String], recipeName: String) {
        let hasValidIngredients = ingredients.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let hasTitle = !recipeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            if !isShoppingListExpanded && hasValidIngredients && hasTitle {
                isShoppingListExpanded = true
                isShoppingListActive = false
            } else if !isShoppingListActive && isShoppingListExpanded {
                isShoppingListActive = true

                Task {
                    await addIngredientsToShoppingListInternal(ingredients: ingredients, recipeName: recipeName)
                }
            }
        }
    }

    private func addIngredientsToShoppingListInternal(ingredients: [String], recipeName: String) async {
        do {
            let recipeNameToUse = recipeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "Yeni Tarif"
                : recipeName.trimmingCharacters(in: .whitespacesAndNewlines)

            // Try to find existing saved recipe to use its real ID
            let recipeId: UUID
            let fetchRequest: NSFetchRequest<Recipe> = Recipe.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "name == %@ AND source == %@", recipeNameToUse, RecipeConstants.Source.ai)
            fetchRequest.fetchLimit = 1

            if let existingRecipe = try? viewContext.fetch(fetchRequest).first {
                recipeId = existingRecipe.id
                logger.debug("Found existing saved recipe with ID: \(recipeId)")
            } else {
                recipeId = UUID()
                logger.debug("No saved recipe found, using temporary ID: \(recipeId)")
            }

            let updatedSentIngredients = try await dataManager.addIngredientsToShoppingList(
                ingredients: ingredients,
                sentIngredients: sentIngredients,
                recipeName: recipeNameToUse,
                recipeId: recipeId
            )

            sentIngredients = updatedSentIngredients
            logger.info("Successfully added \(updatedSentIngredients.count) ingredients to shopping list for '\(recipeNameToUse)'")

            try? await Task.sleep(for: .milliseconds(1500))

            await MainActor.run {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    isShoppingListActive = false
                    isShoppingListExpanded = false
                }
            }
        } catch {
            logger.error("Failed to add ingredients to shopping list: \(error.localizedDescription)")
            ErrorHandler.shared.handle(error)
            await MainActor.run {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    isShoppingListActive = false
                    isShoppingListExpanded = false
                }
            }
        }
    }

    // MARK: - Public Methods for Reset

    public func clearImageData() {
        recipeImageURL = nil
        recipeImageData = nil
        preparedImage = nil
    }
}
