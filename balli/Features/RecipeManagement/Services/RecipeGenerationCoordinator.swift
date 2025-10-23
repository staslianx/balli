//
//  RecipeGenerationCoordinator.swift
//  balli
//
//  Coordinates AI recipe generation
//  Orchestrates: animation → API call → parse
//  Swift 6 strict concurrency compliant
//

import Foundation
import OSLog

/// Coordinates the complete recipe generation flow
@MainActor
public final class RecipeGenerationCoordinator: ObservableObject {
    // MARK: - Logging
    private let logger = AppLoggers.Recipe.generation

    // MARK: - Generation State
    @Published public var isGenerating = false
    @Published public var generationError: String?
    @Published public var showPhotoButton = false
    @Published public var streamingContent = ""  // Real-time markdown content as it streams
    @Published public var tokenCount = 0  // Track streaming progress

    // Dependencies
    private let animationController: RecipeAnimationController
    private let formState: RecipeFormState
    private let generationService: RecipeGenerationService
    private let streamingService: RecipeStreamingService
    private let memoryService: RecipeMemoryService

    init(
        animationController: RecipeAnimationController,
        formState: RecipeFormState,
        generationService: RecipeGenerationService? = nil,
        memoryService: RecipeMemoryService? = nil
    ) {
        self.animationController = animationController
        self.formState = formState
        self.generationService = generationService ?? RecipeGenerationService.shared
        self.streamingService = RecipeStreamingService()
        self.memoryService = memoryService ?? RecipeMemoryService()
    }

    // MARK: - Recipe Generation

    /// Generate recipe with AI
    public func generateRecipe(mealType: String, styleType: String) async {
        logger.info("📥 [COORDINATOR] generateRecipe called - mealType: \(mealType), styleType: \(styleType)")

        isGenerating = true
        animationController.startGenerationAnimation()
        generationError = nil

        do {
            // Get user ID for personalization
            let userId = getUserId()

            logger.info("👤 [COORDINATOR] User ID resolved: \(userId)")

            // Fetch memory for diversity checking
            let memoryDicts = await fetchMemoryForGeneration(styleType: styleType)

            // Convert to SimpleRecentRecipe for service call
            let recentRecipes: [SimpleRecentRecipe] = memoryDicts?.compactMap { dict in
                guard let ingredients = dict["mainIngredients"] as? [String],
                      let recipeName = dict["recipeName"] as? String else {
                    return nil
                }
                // Use first ingredient as main ingredient, or empty string if none
                let mainIngredient = ingredients.first ?? ""
                // Use generic cooking method since we don't store it
                return SimpleRecentRecipe(
                    title: recipeName,
                    mainIngredient: mainIngredient,
                    cookingMethod: "Genel"
                )
            } ?? []

            logger.info("🚀 [COORDINATOR] Starting recipe generation - mealType: \(mealType), styleType: \(styleType), userId: \(userId), recentRecipesCount: \(recentRecipes.count)")

            let startTime = Date()

            // Call simple generation service on background thread with recent recipes
            let response = try await Task.detached(priority: .userInitiated) { [generationService] in
                return try await generationService.generateSpontaneousRecipe(
                    mealType: mealType,
                    styleType: styleType,
                    userId: userId,
                    recentRecipes: recentRecipes
                )
            }.value

            let duration = Date().timeIntervalSince(startTime)
            logger.info("⏱️ [COORDINATOR] Recipe generation completed in \(String(format: "%.2f", duration))s")

            // Back on MainActor for UI updates
            logger.info("🍳 [COORDINATOR] Recipe generated successfully: \(response.recipeName)")

            // Populate form state
            formState.loadFromGenerationResponse(response)

            // Record in memory using ingredients from response
            await recordRecipeInMemory(
                styleType: styleType,
                extractedIngredients: response.ingredients,
                recipeName: response.recipeName
            )

            // Debug: Verify form state was populated
            logger.info("📊 [DEBUG] Form state after loading:")
            logger.info("   recipeName: '\(self.formState.recipeName)'")
            logger.info("   ingredients count: \(self.formState.ingredients.count)")
            logger.info("   directions count: \(self.formState.directions.count)")
            logger.info("   hasRecipeData: \(self.formState.hasRecipeData)")

            // PERFORMANCE FIX: Removed redundant objectWillChange.send()
            // The formState.loadFromGenerationResponse() method now batches updates internally

            // Stop logo rotation
            animationController.stopGenerationAnimation()

            // Show photo button after successful generation
            showPhotoButton = true

        } catch {
            await handleGenerationError(error)
        }

        isGenerating = false
    }

    /// Generate recipe with streaming support
    public func generateRecipeWithStreaming(mealType: String, styleType: String) async {
        logger.info("📥 [COORDINATOR] generateRecipeWithStreaming called - mealType: \(mealType), styleType: \(styleType)")

        isGenerating = true
        animationController.startGenerationAnimation()
        generationError = nil
        streamingContent = ""
        tokenCount = 0

        do {
            // Get user ID for personalization
            let userId = getUserId()

            logger.info("👤 [COORDINATOR] User ID resolved: \(userId)")

            // Fetch memory for diversity checking
            let memoryDicts = await fetchMemoryForGeneration(styleType: styleType)

            // Convert to SimpleRecentRecipe for service call
            let recentRecipes: [SimpleRecentRecipe] = memoryDicts?.compactMap { dict in
                guard let ingredients = dict["mainIngredients"] as? [String],
                      let recipeName = dict["recipeName"] as? String else {
                    return nil
                }
                let mainIngredient = ingredients.first ?? ""
                return SimpleRecentRecipe(
                    title: recipeName,
                    mainIngredient: mainIngredient,
                    cookingMethod: "Genel"
                )
            } ?? []

            logger.info("🚀 [COORDINATOR] Starting recipe generation with streaming - mealType: \(mealType), styleType: \(styleType), userId: \(userId), recentRecipesCount: \(recentRecipes.count)")

            let startTime = Date()

            // Call streaming service
            await streamingService.generateSpontaneous(
                mealType: mealType,
                styleType: styleType,
                userId: userId,
                recentRecipes: recentRecipes,
                onConnected: {
                    Task { @MainActor in
                        self.logger.info("✅ [STREAMING] Connected to recipe generation")
                    }
                },
                onChunk: { chunkText, fullContent, count in
                    Task { @MainActor in
                        // Update streaming content incrementally
                        self.streamingContent = fullContent
                        self.tokenCount = count

                        // Try to parse JSON incrementally to extract recipeContent if available
                        if let jsonData = fullContent.data(using: .utf8),
                           let parsedJSON = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                           let recipeContent = parsedJSON["recipeContent"] as? String {
                            // Update form state with streaming markdown content
                            self.formState.recipeContent = recipeContent
                        }

                        self.logger.debug("📦 [STREAMING] Received chunk: \(count) tokens, \(fullContent.count) chars")
                    }
                },
                onComplete: { response in
                    Task { @MainActor in
                        let duration = Date().timeIntervalSince(startTime)
                        self.logger.info("⏱️ [COORDINATOR] Recipe generation completed in \(String(format: "%.2f", duration))s")
                        self.logger.info("🍳 [COORDINATOR] Recipe generated successfully: \(response.recipeName)")

                        // Populate form state with complete response
                        self.formState.loadFromGenerationResponse(response)

                        // Record in memory using ingredients from response
                        await self.recordRecipeInMemory(
                            styleType: styleType,
                            extractedIngredients: response.ingredients,
                            recipeName: response.recipeName
                        )

                        // Debug: Verify form state was populated
                        self.logger.info("📊 [DEBUG] Form state after loading:")
                        self.logger.info("   recipeName: '\(self.formState.recipeName)'")
                        self.logger.info("   recipeContent length: \(self.formState.recipeContent.count) chars")
                        self.logger.info("   hasRecipeData: \(self.formState.hasRecipeData)")

                        // Stop logo rotation
                        self.animationController.stopGenerationAnimation()

                        // Show photo button after successful generation
                        self.showPhotoButton = true

                        self.isGenerating = false
                    }
                },
                onError: { error in
                    Task { @MainActor in
                        await self.handleGenerationError(error)
                        self.isGenerating = false
                    }
                }
            )

        } catch {
            await handleGenerationError(error)
            isGenerating = false
        }
    }

    // MARK: - Memory Integration

    /// Fetch memory entries for a subcategory and convert to Cloud Functions format
    private func fetchMemoryForGeneration(styleType: String) async -> [[String: Any]]? {
        // Parse subcategory from styleType (which is the raw value)
        guard let subcategory = RecipeSubcategory(rawValue: styleType) else {
            logger.warning("Could not parse subcategory from styleType: \(styleType)")
            return nil
        }

        logger.info("📚 [MEMORY] Fetching memory for subcategory: \(subcategory.rawValue)")
        let memoryEntries = await memoryService.getMemoryForCloudFunctions(for: subcategory, limit: 10)
        logger.info("📚 [MEMORY] Retrieved \(memoryEntries.count) memory entries")

        return memoryEntries.isEmpty ? nil : memoryEntries
    }

    /// Record generated recipe in memory
    private func recordRecipeInMemory(
        styleType: String,
        extractedIngredients: [String]?,
        recipeName: String
    ) async {
        // Parse subcategory from styleType
        guard let subcategory = RecipeSubcategory(rawValue: styleType) else {
            logger.warning("Could not parse subcategory from styleType: \(styleType)")
            return
        }

        // Only record if we have extracted ingredients
        guard let ingredients = extractedIngredients, !ingredients.isEmpty else {
            logger.warning("No extracted ingredients to record in memory")
            return
        }

        do {
            try await memoryService.recordRecipe(
                subcategory: subcategory,
                ingredients: ingredients,
                recipeName: recipeName
            )
            logger.info("✅ [MEMORY] Recorded recipe '\(recipeName)' in memory")
        } catch {
            logger.error("❌ [MEMORY] Failed to record recipe in memory: \(error.localizedDescription)")
            // Don't throw - memory failure shouldn't block the flow
        }
    }

    // MARK: - Error Handling

    /// Handle generation errors
    private func handleGenerationError(_ error: Error) async {
        logger.error("Recipe generation failed: \(error.localizedDescription)")

        generationError = error.localizedDescription

        // Clear ALL state to prevent showing stale recipe data from previous generation
        resetAll()
        logger.debug("Cleared all state after generation failure")

        // Stop animations
        animationController.stopGenerationAnimation()
        animationController.reset()

        // Handle error globally
        ErrorHandler.shared.handle(error)
    }

    // MARK: - User ID Management

    /// Get user ID - hardcoded for personal app with 2 users
    /// Returns: "serhat@balli.com" or "dilara@balli.com" based on stored preference
    private func getUserId() -> String {
        // Hardcoded user IDs for personal app
        // Serhat (developer/tester): serhat@balli.com
        // Dilara (main user): dilara@balli.com

        let userIdKey = "balli.currentUserId"

        // Check if user ID is already set
        if let savedUserId = UserDefaults.standard.string(forKey: userIdKey) {
            return savedUserId
        }

        // Default to serhat (developer) for first launch
        let defaultUserId = "serhat@balli.com"
        UserDefaults.standard.set(defaultUserId, forKey: userIdKey)

        logger.info("First launch - defaulting to user: \(defaultUserId)")
        logger.info("To switch users, change UserDefaults key 'balli.currentUserId' to 'dilara@balli.com'")

        return defaultUserId
    }

    // MARK: - Reset

    /// Reset generation state (called when starting fresh or after manual clear)
    public func reset() {
        isGenerating = false
        generationError = nil
        showPhotoButton = false
        streamingContent = ""
        tokenCount = 0
    }

    /// Reset everything including form state (called on generation failure)
    public func resetAll() {
        isGenerating = false
        generationError = nil
        showPhotoButton = false
        streamingContent = ""
        tokenCount = 0
        formState.clearAll()
    }
}
