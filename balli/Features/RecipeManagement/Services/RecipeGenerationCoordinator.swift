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
    private let diversityService = RecipeDiversityService.shared

    init(
        animationController: RecipeAnimationController,
        formState: RecipeFormState,
        generationService: RecipeGenerationService? = nil
    ) {
        self.animationController = animationController
        self.formState = formState
        self.generationService = generationService ?? RecipeGenerationService.shared
        self.streamingService = RecipeStreamingService()
    }

    // MARK: - Recipe Generation

    /// Generate recipe with AI
    public func generateRecipe(mealType: String, styleType: String) async {
        logger.info("📥 [COORDINATOR] generateRecipe called - mealType: \(mealType), styleType: \(styleType)")

        isGenerating = true
        animationController.startGenerationAnimation()
        generationError = nil

        do {
            // Load recent recipes for diversity
            let recentRecipes = await diversityService.loadRecentRecipes(
                mealType: mealType,
                styleType: styleType
            )
            logger.info("📚 [DIVERSITY] Loaded \(recentRecipes.count) recent recipes for this category")

            // Get user ID for personalization
            let userId = getUserId()

            logger.info("👤 [COORDINATOR] User ID resolved: \(userId)")
            logger.info("🚀 [COORDINATOR] Starting recipe generation - mealType: \(mealType), styleType: \(styleType), userId: \(userId)")

            // Convert RecentRecipe to SimpleRecentRecipe for API
            let simpleRecipes = recentRecipes.map { recipe in
                SimpleRecentRecipe(
                    title: recipe.title,
                    mainIngredient: recipe.mainIngredient,
                    cookingMethod: recipe.cookingMethod
                )
            }

            if !simpleRecipes.isEmpty {
                logger.debug("   Recent recipe titles for diversity:")
                for recipe in simpleRecipes.prefix(5) {
                    logger.debug("   - \(recipe.title)")
                }
            }

            let startTime = Date()

            // Call simple generation service on background thread with recent recipes
            let response = try await Task.detached(priority: .userInitiated) { [generationService] in
                return try await generationService.generateSpontaneousRecipe(
                    mealType: mealType,
                    styleType: styleType,
                    userId: userId,
                    recentRecipes: simpleRecipes
                )
            }.value

            let duration = Date().timeIntervalSince(startTime)
            logger.info("⏱️ [COORDINATOR] Recipe generation completed in \(String(format: "%.2f", duration))s")

            // Back on MainActor for UI updates
            logger.info("🍳 [COORDINATOR] Recipe generated successfully: \(response.recipeName)")

            // Populate form state
            formState.loadFromGenerationResponse(response)

            // Debug: Verify form state was populated
            logger.info("📊 [DEBUG] Form state after loading:")
            logger.info("   recipeName: '\(self.formState.recipeName)'")
            logger.info("   ingredients count: \(self.formState.ingredients.count)")
            logger.info("   directions count: \(self.formState.directions.count)")
            logger.info("   hasRecipeData: \(self.formState.hasRecipeData)")

            // Save recipe to diversity history
            await saveToRecipeHistory(
                response: response,
                mealType: mealType,
                styleType: styleType
            )

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
            // Load recent recipes for diversity
            let recentRecipes = await diversityService.loadRecentRecipes(
                mealType: mealType,
                styleType: styleType
            )
            logger.info("📚 [DIVERSITY] Loaded \(recentRecipes.count) recent recipes for this category")

            // Get user ID for personalization
            let userId = getUserId()

            logger.info("👤 [COORDINATOR] User ID resolved: \(userId)")
            logger.info("🚀 [COORDINATOR] Starting recipe generation with streaming - mealType: \(mealType), styleType: \(styleType), userId: \(userId)")

            // Convert RecentRecipe to SimpleRecentRecipe for API
            let simpleRecipes = recentRecipes.map { recipe in
                SimpleRecentRecipe(
                    title: recipe.title,
                    mainIngredient: recipe.mainIngredient,
                    cookingMethod: recipe.cookingMethod
                )
            }

            if !simpleRecipes.isEmpty {
                logger.debug("   Recent recipe titles for diversity:")
                for recipe in simpleRecipes.prefix(5) {
                    logger.debug("   - \(recipe.title)")
                }
            }

            let startTime = Date()

            // Call streaming service
            await streamingService.generateSpontaneous(
                mealType: mealType,
                styleType: styleType,
                userId: userId,
                recentRecipes: simpleRecipes,
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

                        // Debug: Verify form state was populated
                        self.logger.info("📊 [DEBUG] Form state after loading:")
                        self.logger.info("   recipeName: '\(self.formState.recipeName)'")
                        self.logger.info("   recipeContent length: \(self.formState.recipeContent.count) chars")
                        self.logger.info("   hasRecipeData: \(self.formState.hasRecipeData)")

                        // Save recipe to diversity history
                        await self.saveToRecipeHistory(
                            response: response,
                            mealType: mealType,
                            styleType: styleType
                        )

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

    // MARK: - Diversity Tracking

    /// Save generated recipe to diversity history
    /// Extracts metadata and stores in UserDefaults for future diversity
    private func saveToRecipeHistory(
        response: RecipeGenerationResponse,
        mealType: String,
        styleType: String
    ) async {
        // Extract metadata from response
        let mainIngredient = RecipeMetadataExtractor.extractMainIngredient(from: response.ingredients)
        let cookingMethod = RecipeMetadataExtractor.extractCookingMethod(from: response.recipeName)

        // Create recent recipe entry
        let recentRecipe = RecentRecipe(
            title: response.recipeName,
            mainIngredient: mainIngredient,
            cookingMethod: cookingMethod,
            mealType: mealType,
            styleType: styleType
        )

        // Save to diversity service
        await diversityService.saveRecipe(recentRecipe)

        logger.info("💾 [DIVERSITY] Saved recipe to history:")
        logger.info("   Title: \(recentRecipe.title)")
        logger.info("   Main Ingredient: \(mainIngredient)")
        logger.info("   Cooking Method: \(cookingMethod)")
        logger.info("   Category: \(recentRecipe.categoryKey)")
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
