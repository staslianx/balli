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
import Combine

/// Coordinates the complete recipe generation flow
@MainActor
public final class RecipeGenerationCoordinator: ObservableObject {
    // MARK: - Logging
    private let logger = AppLoggers.Recipe.generation

    // MARK: - Generation State
    @Published public var isGenerating = false
    @Published public var generationError: String?
    @Published public var showPhotoButton = false
    @Published public var streamingContent = ""  // Real-time markdown content as it streams (SSE direct)
    @Published public var tokenCount = 0  // Track streaming progress
    @Published public var prepTime: Int?  // Preparation time in minutes (extracted from markdown)
    @Published public var cookTime: Int?  // Cooking time in minutes (extracted from markdown)
    @Published public var waitTime: Int?  // Waiting time in minutes - marinating, resting, rising (extracted from markdown)

    // Dependencies
    private let animationController: RecipeAnimationController
    private let formState: RecipeFormState
    private let generationService: RecipeGenerationServiceProtocol
    private let streamingService: RecipeStreamingService
    private let memoryService: RecipeMemoryService
    private var cancellables = Set<AnyCancellable>()

    init(
        animationController: RecipeAnimationController,
        formState: RecipeFormState,
        generationService: RecipeGenerationServiceProtocol? = nil,
        memoryService: RecipeMemoryService? = nil
    ) {
        self.animationController = animationController
        self.formState = formState
        self.generationService = generationService ?? RecipeGenerationService.shared
        self.streamingService = RecipeStreamingService()
        self.memoryService = memoryService ?? RecipeMemoryService()
    }

    // MARK: - Helper Functions

    /// Extracts recipe name from the first line if it's a markdown heading
    /// Returns the name as it streams in, character by character
    private func extractRecipeName(from content: String) -> String? {
        let lines = content.components(separatedBy: "\n")
        guard let firstLine = lines.first else { return nil }

        let trimmed = firstLine.trimmingCharacters(in: .whitespaces)

        // Check if first line is a markdown heading (# or ##)
        if trimmed.starts(with: "##") {
            let name = trimmed.dropFirst(2).trimmingCharacters(in: .whitespaces)
            return name.isEmpty ? nil : String(name)
        } else if trimmed.starts(with: "#") {
            let name = trimmed.dropFirst(1).trimmingCharacters(in: .whitespaces)
            return name.isEmpty ? nil : String(name)
        }

        return nil
    }

    /// Extracts prep, cooking, and waiting times from markdown content
    /// Returns tuple of (prepTime, cookTime, waitTime) in minutes, or nil if not found
    /// Format: **Hazırlık:** 15 dakika | **Pişirme:** 20 dakika | **Bekleme:** 30 dakika
    private func extractTimes(from content: String) -> (prepTime: Int?, cookTime: Int?, waitTime: Int?)? {
        let lines = content.components(separatedBy: "\n")

        // Look for the metadata line (usually second line after title)
        // It contains **Hazırlık:** and/or **Pişirme:** and/or **Bekleme:**
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.contains("**Hazırlık:**") || trimmed.contains("**Pişirme:**") || trimmed.contains("**Bekleme:**") {
                // Extract prep time
                let prepMatch = trimmed.range(of: #"\*\*Hazırlık:\*\*\s*(\d+)\s*dakika"#, options: .regularExpression)
                var prepTime: Int?
                if let match = prepMatch {
                    let matchString = String(trimmed[match])
                    if let timeString = matchString.components(separatedBy: CharacterSet.decimalDigits.inverted)
                        .joined()
                        .split(separator: " ")
                        .first,
                       let time = Int(timeString) {
                        prepTime = time
                    }
                }

                // Extract cook time
                let cookMatch = trimmed.range(of: #"\*\*Pişirme:\*\*\s*(\d+)\s*dakika"#, options: .regularExpression)
                var cookTime: Int?
                if let match = cookMatch {
                    let matchString = String(trimmed[match])
                    if let timeString = matchString.components(separatedBy: CharacterSet.decimalDigits.inverted)
                        .joined()
                        .split(separator: " ")
                        .first,
                       let time = Int(timeString) {
                        cookTime = time
                    }
                }

                // Extract waiting time (for marinating, resting, rising, etc.)
                let waitMatch = trimmed.range(of: #"\*\*Bekleme:\*\*\s*(\d+)\s*dakika"#, options: .regularExpression)
                var waitTime: Int?
                if let match = waitMatch {
                    let matchString = String(trimmed[match])
                    if let timeString = matchString.components(separatedBy: CharacterSet.decimalDigits.inverted)
                        .joined()
                        .split(separator: " ")
                        .first,
                       let time = Int(timeString) {
                        waitTime = time
                    }
                }

                return (prepTime: prepTime, cookTime: cookTime, waitTime: waitTime)
            }
        }

        return nil
    }

    /// Removes recipe name heading and metadata line (prep/cooking times) from recipe content
    /// - Removes first line if it's a heading (starts with # or ##)
    /// - Removes second line entirely (contains prep/cooking/portion metadata)
    /// This keeps the recipe body clean and allows separate display of title and times
    private func removeHeaderAndMetadata(from content: String) -> String {
        var lines = content.components(separatedBy: "\n")
        guard !lines.isEmpty else { return content }

        // STEP 1: Remove recipe name heading (first line if it's a markdown heading)
        if let firstLine = lines.first, firstLine.trimmingCharacters(in: .whitespaces).starts(with: "#") {
            lines.removeFirst()
        }

        // STEP 2: Remove empty line after heading if present
        if lines.first?.trimmingCharacters(in: .whitespaces).isEmpty == true {
            lines.removeFirst()
        }

        // STEP 3: Remove metadata line entirely (contains **Hazırlık:** and/or **Pişirme:**)
        if let firstLine = lines.first, firstLine.contains("**Hazırlık:**") || firstLine.contains("**Pişirme:**") {
            lines.removeFirst()
        }

        // STEP 4: Remove empty line after metadata if present
        if lines.first?.trimmingCharacters(in: .whitespaces).isEmpty == true {
            lines.removeFirst()
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Recipe Generation

    /// Smart router: Generate recipe with or without ingredients based on availability
    public func generateRecipeSmartRouting(
        mealType: String,
        styleType: String,
        ingredients: [String]?,
        userContext: String?
    ) async {
        if let ingredients = ingredients, !ingredients.isEmpty {
            await generateRecipeFromIngredients(
                mealType: mealType,
                styleType: styleType,
                ingredients: ingredients,
                userContext: userContext
            )
        } else {
            await generateRecipeWithStreaming(mealType: mealType, styleType: styleType, userContext: userContext)
        }
    }

    /// Generate recipe from user-provided ingredients WITH STREAMING
    /// - Parameters:
    ///   - mealType: The type of meal (e.g., "Kahvaltı", "Akşam Yemeği")
    ///   - styleType: The style subcategory for the meal type
    ///   - ingredients: Available ingredients to use in the recipe
    ///   - userContext: Optional user notes/context (e.g., "diabetes-friendly tiramisu")
    public func generateRecipeFromIngredients(
        mealType: String,
        styleType: String,
        ingredients: [String],
        userContext: String?
    ) async {
        logger.info("🚀 [GENERATION] Starting ingredients-based generation")
        isGenerating = true
        logger.info("▶️ [STATE] isGenerating set to true")
        animationController.startGenerationAnimation()
        generationError = nil
        streamingContent = ""
        tokenCount = 0

        let userId = getUserId()
        _ = Date() // Track generation start

        // Call streaming service for ingredients-based generation
        await streamingService.generateWithIngredients(
            ingredients: ingredients,
            mealType: mealType,
            styleType: styleType,
            userId: userId,
            userContext: userContext,
            onConnected: {},
            onChunk: { chunkText, fullContent, count in
                Task { @MainActor in
                    // SSE STREAMING: Direct display without animation
                    // Extract recipe name from first heading and update immediately
                    if let recipeName = self.extractRecipeName(from: fullContent) {
                        self.formState.recipeName = recipeName
                    }

                    // Extract prep, cooking, and waiting times
                    if let times = self.extractTimes(from: fullContent) {
                        self.prepTime = times.prepTime
                        self.cookTime = times.cookTime
                        self.waitTime = times.waitTime

                        // CRITICAL: Update formState with extracted times for persistence
                        if let prep = times.prepTime {
                            self.formState.prepTime = "\(prep)"
                        }
                        if let cook = times.cookTime {
                            self.formState.cookTime = "\(cook)"
                        }
                        if let wait = times.waitTime {
                            self.formState.waitTime = "\(wait)"
                        }
                    }

                    // CRITICAL FIX: Parse ingredients and directions from markdown during streaming
                    // This ensures formState has ingredients even if stream ends without "completed" event
                    let parsed = self.formState.parseMarkdownContent(fullContent)
                    if !parsed.ingredients.isEmpty {
                        self.formState.ingredients = parsed.ingredients
                        self.logger.debug("🔧 [STREAMING] Parsed \(parsed.ingredients.count) ingredients from markdown during streaming")
                    }
                    if !parsed.directions.isEmpty {
                        self.formState.directions = parsed.directions
                        self.logger.debug("🔧 [STREAMING] Parsed \(parsed.directions.count) directions from markdown during streaming")
                    }

                    // Remove header and metadata from displayed content
                    let cleanedContent = self.removeHeaderAndMetadata(from: fullContent)
                    self.streamingContent = cleanedContent
                    self.tokenCount = count

                    // Update formState content directly (SSE streaming - no animation)
                    self.formState.recipeContent = cleanedContent
                }
            },
            onComplete: { [weak self] response in
                guard let self else { return }

                // CRITICAL: This closure is @MainActor so executes synchronously on MainActor
                // This ensures isGenerating is set to false BEFORE the streaming function returns
                self.logger.info("🏁 [GENERATION] onComplete called for ingredients-based generation")
                self.logger.info("📊 [STATE] isGenerating before stop: \(self.isGenerating)")

                // Stop animation and update state immediately (non-blocking)
                self.logger.info("🎬 [ANIMATION] Calling stopGenerationAnimation()")
                self.animationController.stopGenerationAnimation()

                self.showPhotoButton = true

                self.logger.info("🛑 [STATE] Setting isGenerating = false")
                self.isGenerating = false
                self.logger.info("✅ [STATE] isGenerating after stop: \(self.isGenerating)")

                // Load response asynchronously to avoid blocking main thread during typewriter animation
                // Only load response if it contains actual data (real completed event from server)
                if !response.recipeName.isEmpty {
                    self.logger.info("📥 [RESPONSE] Loading response asynchronously with recipe name: '\(response.recipeName)'")
                    Task {
                        await MainActor.run {
                            self.formState.loadFromGenerationResponse(response)
                        }
                    }
                } else {
                    self.logger.info("⏭️ [RESPONSE] Skipping loadFromGenerationResponse - using already-streamed content")
                }

                // Record in memory asynchronously (non-blocking)
                // Only if we have actual extracted ingredients from server response
                if let extractedIngredients = response.extractedIngredients, !extractedIngredients.isEmpty {
                    Task {
                        await self.recordRecipeInMemory(
                            mealType: mealType,
                            styleType: styleType,
                            extractedIngredients: extractedIngredients,
                            recipeName: response.recipeName
                        )
                    }
                }
            },
            onError: { [weak self] error in
                guard let self else { return }

                // CRITICAL: This closure is @MainActor so executes synchronously on MainActor
                self.logger.error("❌ [GENERATION] onError called (ingredients): \(error.localizedDescription)")
                self.logger.info("🛑 [STATE] Stopping animation and setting isGenerating = false in error handler")

                // CRITICAL: Stop animation BEFORE setting isGenerating = false
                // This ensures loading UI transitions to stopped state properly
                self.animationController.stopGenerationAnimation()
                self.isGenerating = false
                self.logger.info("✅ [STATE] isGenerating after error: \(self.isGenerating)")

                // Handle error asynchronously (non-blocking)
                Task {
                    await self.handleGenerationError(error)
                }
            }
        )
    }

    /// Generate recipe with AI (spontaneous, no ingredients)
    public func generateRecipe(mealType: String, styleType: String, userContext: String? = nil) async {
        isGenerating = true
        animationController.startGenerationAnimation()
        generationError = nil

        do {
            let userId = getUserId()
            let shouldUseMemory = userContext == nil || userContext?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true

            let recentRecipes: [SimpleRecentRecipe]
            let diversityConstraints: DiversityConstraints?

            if shouldUseMemory {

                // Fetch memory for diversity checking
                let memoryDicts = await fetchMemoryForGeneration(mealType: mealType, styleType: styleType)

                // Convert to SimpleRecentRecipe for service call
                recentRecipes = memoryDicts?.compactMap { dict in
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

                diversityConstraints = await buildDiversityConstraints(mealType: mealType, styleType: styleType)
            } else {
                recentRecipes = []
                diversityConstraints = nil
            }

            _ = Date() // Track generation start

            // Call simple generation service on background thread with recent recipes and diversity constraints
            let response = try await Task.detached(priority: .userInitiated) { [generationService] in
                return try await generationService.generateSpontaneousRecipe(
                    mealType: mealType,
                    styleType: styleType,
                    userId: userId,
                    recentRecipes: recentRecipes,
                    diversityConstraints: diversityConstraints,
                    userContext: userContext
                )
            }.value

            formState.loadFromGenerationResponse(response)

            await recordRecipeInMemory(
                mealType: mealType,
                styleType: styleType,
                extractedIngredients: response.extractedIngredients,
                recipeName: response.recipeName
            )

            animationController.stopGenerationAnimation()
            showPhotoButton = true

        } catch {
            await handleGenerationError(error)
        }

        isGenerating = false
    }

    /// Generate recipe using ONLY user context (no meal type hints)
    /// This is used for Flow 3 (Notes only) and Flow 4 (Ingredients + Notes)
    /// When the user writes notes, they're telling us exactly what to make
    public func generateRecipeWithUserContextOnly(
        ingredients: [String]?,
        userContext: String?
    ) async {
        if let ingredients = ingredients {
            await generateRecipeFromIngredients(
                mealType: "Genel",
                styleType: "Genel",
                ingredients: ingredients,
                userContext: userContext
            )
        } else {
            await generateRecipeWithStreaming(
                mealType: "Genel",
                styleType: "Genel",
                userContext: userContext
            )
        }
    }

    /// Generate recipe with streaming support
    public func generateRecipeWithStreaming(mealType: String, styleType: String, userContext: String? = nil) async {
        logger.info("🚀 [GENERATION] Starting spontaneous generation with streaming")
        isGenerating = true
        logger.info("▶️ [STATE] isGenerating set to true")
        animationController.startGenerationAnimation()
        generationError = nil
        streamingContent = ""
        tokenCount = 0

        let userId = getUserId()
        let shouldUseMemory = userContext == nil || userContext?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true

        let recentRecipes: [SimpleRecentRecipe]
        let diversityConstraints: DiversityConstraints?

        if shouldUseMemory {

            // Fetch memory for diversity checking
            let memoryDicts = await fetchMemoryForGeneration(mealType: mealType, styleType: styleType)

            // Convert to SimpleRecentRecipe for service call
            recentRecipes = memoryDicts?.compactMap { dict in
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

            diversityConstraints = await buildDiversityConstraints(mealType: mealType, styleType: styleType)
        } else {
            recentRecipes = []
            diversityConstraints = nil
        }

        await streamingService.generateSpontaneous(
            mealType: mealType,
            styleType: styleType,
            userId: userId,
            recentRecipes: recentRecipes,
            diversityConstraints: diversityConstraints,
            userContext: userContext,
            onConnected: {},
            onChunk: { chunkText, fullContent, count in
                Task { @MainActor in
                    // SSE STREAMING: Direct display without animation
                    if let recipeName = self.extractRecipeName(from: fullContent) {
                        self.formState.recipeName = recipeName
                    }

                    if let times = self.extractTimes(from: fullContent) {
                        self.prepTime = times.prepTime
                        self.cookTime = times.cookTime

                        // CRITICAL: Update formState with extracted times for persistence
                        if let prep = times.prepTime {
                            self.formState.prepTime = "\(prep)"
                        }
                        if let cook = times.cookTime {
                            self.formState.cookTime = "\(cook)"
                        }
                    }

                    // CRITICAL FIX: Parse ingredients and directions from markdown during streaming
                    // This ensures formState has ingredients even if stream ends without "completed" event
                    let parsed = self.formState.parseMarkdownContent(fullContent)
                    if !parsed.ingredients.isEmpty {
                        self.formState.ingredients = parsed.ingredients
                        self.logger.debug("🔧 [STREAMING] Parsed \(parsed.ingredients.count) ingredients from markdown during streaming")
                    }
                    if !parsed.directions.isEmpty {
                        self.formState.directions = parsed.directions
                        self.logger.debug("🔧 [STREAMING] Parsed \(parsed.directions.count) directions from markdown during streaming")
                    }

                    let cleanedContent = self.removeHeaderAndMetadata(from: fullContent)
                    self.streamingContent = cleanedContent
                    self.tokenCount = count

                    // Update formState content directly (SSE streaming - no animation)
                    self.formState.recipeContent = cleanedContent
                }
            },
            onComplete: { [weak self] response in
                guard let self else { return }

                // CRITICAL: This closure is @MainActor so executes synchronously on MainActor
                // This ensures isGenerating is set to false BEFORE the streaming function returns
                self.logger.info("🏁 [GENERATION] onComplete called for spontaneous generation")
                self.logger.info("📊 [STATE] isGenerating before stop: \(self.isGenerating)")

                // Stop animation and update state immediately (non-blocking)
                self.logger.info("🎬 [ANIMATION] Calling stopGenerationAnimation()")
                self.animationController.stopGenerationAnimation()

                self.showPhotoButton = true

                self.logger.info("🛑 [STATE] Setting isGenerating = false")
                self.isGenerating = false
                self.logger.info("✅ [STATE] isGenerating after stop: \(self.isGenerating)")

                // Load response asynchronously to avoid blocking main thread during typewriter animation
                // Only load response if it contains actual data (real completed event from server)
                if !response.recipeName.isEmpty {
                    self.logger.info("📥 [RESPONSE] Loading response asynchronously with recipe name: '\(response.recipeName)'")
                    Task {
                        await MainActor.run {
                            self.formState.loadFromGenerationResponse(response)
                        }
                    }
                } else {
                    self.logger.info("⏭️ [RESPONSE] Skipping loadFromGenerationResponse - using already-streamed content")
                }

                // Record in memory asynchronously (non-blocking)
                // Only if we have actual extracted ingredients from server response
                if let extractedIngredients = response.extractedIngredients, !extractedIngredients.isEmpty {
                    Task {
                        await self.recordRecipeInMemory(
                            mealType: mealType,
                            styleType: styleType,
                            extractedIngredients: extractedIngredients,
                            recipeName: response.recipeName
                        )
                    }
                }
            },
            onError: { [weak self] error in
                guard let self else { return }

                // CRITICAL: This closure is @MainActor so executes synchronously on MainActor
                self.logger.error("❌ [GENERATION] onError called (spontaneous): \(error.localizedDescription)")
                self.logger.info("🛑 [STATE] Stopping animation and setting isGenerating = false in error handler")

                // CRITICAL: Stop animation BEFORE setting isGenerating = false
                // This ensures loading UI transitions to stopped state properly
                self.animationController.stopGenerationAnimation()
                self.isGenerating = false
                self.logger.info("✅ [STATE] isGenerating after error: \(self.isGenerating)")

                // Handle error asynchronously (non-blocking)
                Task {
                    await self.handleGenerationError(error)
                }
            }
        )
    }

    // MARK: - Memory Integration

    /// Fetch memory entries for a subcategory and convert to Cloud Functions format
    private func fetchMemoryForGeneration(mealType: String, styleType: String) async -> [[String: Any]]? {
        let subcategoryName = determineSubcategory(mealType: mealType, styleType: styleType)

        guard let subcategory = RecipeSubcategory(rawValue: subcategoryName) else {
            logger.error("Failed to parse subcategory from: \(subcategoryName)")
            return nil
        }

        let memoryEntries = await memoryService.getMemoryForCloudFunctions(for: subcategory, limit: 10)
        return memoryEntries.isEmpty ? nil : memoryEntries
    }

    /// Determine subcategory from mealType and styleType
    private func determineSubcategory(mealType: String, styleType: String) -> String {
        let subcategoryMap: [String: String] = [
            "Doyurucu Salata": "Doyurucu Salata",
            "Hafif Salata": "Hafif Salata",
            "Karbonhidrat ve Protein Uyumu": "Karbonhidrat ve Protein Uyumu",
            "Tam Buğday Makarna": "Tam Buğday Makarna",
            "Sana Özel Tatlılar": "Sana Özel Tatlılar",
            "Dondurma": "Dondurma",
            "Meyve Salatası": "Meyve Salatası"
        ]

        if !styleType.isEmpty, let mappedSubcategory = subcategoryMap[styleType] {
            return mappedSubcategory
        }

        let mealTypeMap: [String: String] = [
            "Kahvaltı": "Kahvaltı",
            "Atıştırmalık": "Atıştırmalık"
        ]

        return mealTypeMap[mealType] ?? mealType
    }

    /// Build diversity constraints based on protein variety analysis
    private func buildDiversityConstraints(mealType: String, styleType: String) async -> DiversityConstraints? {
        let subcategoryName = determineSubcategory(mealType: mealType, styleType: styleType)

        guard let subcategory = RecipeSubcategory(rawValue: subcategoryName) else {
            logger.error("Could not parse subcategory from: \(subcategoryName)")
            return nil
        }

        let analysis = await memoryService.analyzeProteinVariety(for: subcategory)

        var avoidProteins: [String]? = nil
        var suggestProteins: [String]? = nil

        let proteinsToAvoid = Set(analysis.overusedProteins + analysis.recentProteins)
        if !proteinsToAvoid.isEmpty {
            avoidProteins = Array(proteinsToAvoid).sorted()
        }

        if !analysis.suggestedProteins.isEmpty {
            suggestProteins = analysis.suggestedProteins
        }

        guard avoidProteins != nil || suggestProteins != nil else {
            return nil
        }

        return DiversityConstraints(
            avoidCuisines: nil,
            avoidProteins: avoidProteins,
            avoidMethods: nil,
            suggestCuisines: nil,
            suggestProteins: suggestProteins
        )
    }

    /// Record generated recipe in memory
    private func recordRecipeInMemory(
        mealType: String,
        styleType: String,
        extractedIngredients: [String]?,
        recipeName: String
    ) async {
        let subcategoryName = determineSubcategory(mealType: mealType, styleType: styleType)

        guard let subcategory = RecipeSubcategory(rawValue: subcategoryName) else {
            logger.error("Failed to parse subcategory from: \(subcategoryName)")
            return
        }

        guard let ingredients = extractedIngredients, !ingredients.isEmpty else {
            logger.error("No extracted ingredients to record for recipe: \(recipeName)")
            return
        }

        do {
            try await memoryService.recordRecipe(
                subcategory: subcategory,
                ingredients: ingredients,
                recipeName: recipeName
            )
        } catch {
            logger.error("Failed to record recipe in memory: \(error.localizedDescription)")
        }
    }

    // MARK: - Error Handling

    /// Handle generation errors
    private func handleGenerationError(_ error: Error) async {
        logger.error("Recipe generation failed: \(error.localizedDescription)")

        generationError = error.localizedDescription
        resetAll()
        animationController.stopGenerationAnimation()
        animationController.reset()
        ErrorHandler.shared.handle(error)
    }

    // MARK: - User ID Management

    /// Get user ID - hardcoded for personal app with 2 users
    /// Returns: "serhat@balli.com" or "dilara@balli.com" based on stored preference
    private func getUserId() -> String {
        let userIdKey = "balli.currentUserId"

        if let savedUserId = UserDefaults.standard.string(forKey: userIdKey) {
            return savedUserId
        }

        let defaultUserId = "serhat@balli.com"
        UserDefaults.standard.set(defaultUserId, forKey: userIdKey)
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
        prepTime = nil
        cookTime = nil
    }

    /// Reset everything including form state (called on generation failure)
    public func resetAll() {
        isGenerating = false
        generationError = nil
        showPhotoButton = false
        streamingContent = ""
        tokenCount = 0
        prepTime = nil
        cookTime = nil
        formState.clearAll()
    }
}
