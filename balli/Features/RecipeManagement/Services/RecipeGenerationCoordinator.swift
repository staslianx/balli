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
    @Published public var streamingContent = ""  // Real-time markdown content as it streams
    @Published public var tokenCount = 0  // Track streaming progress

    // Dependencies
    private let animationController: RecipeAnimationController
    private let formState: RecipeFormState
    private let generationService: RecipeGenerationServiceProtocol
    private let streamingService: RecipeStreamingService
    private let memoryService: RecipeMemoryService
    private let typewriterAnimator = TypewriterAnimator()  // Client-side character animation
    private var animatorCancellable: AnyCancellable?  // Bind animator → formState

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

        // Bind animator's displayedText to formState.recipeContent for character-by-character animation
        self.animatorCancellable = typewriterAnimator.$displayedText
            .sink { [weak formState] text in
                formState?.recipeContent = text
            }
    }

    // MARK: - Helper Functions

    /// Removes recipe name heading and portion information from recipe content
    /// - Removes first line if it's a heading (starts with # or ##)
    /// - Removes portion info from metadata line
    /// Format: **Hazırlık:** 15 dakika | **Pişirme:** 20 dakika | **Porsiyon:** 1 kişi
    /// Result: **Hazırlık:** 15 dakika | **Pişirme:** 20 dakika
    private func removePortionInfo(from content: String) -> String {
        var lines = content.components(separatedBy: "\n")
        guard !lines.isEmpty else { return content }

        // STEP 1: Remove recipe name heading (first line if it's a markdown heading)
        if let firstLine = lines.first, firstLine.trimmingCharacters(in: .whitespaces).starts(with: "#") {
            lines.removeFirst()
            // Remove empty line after heading if present
            if lines.first?.trimmingCharacters(in: .whitespaces).isEmpty == true {
                lines.removeFirst()
            }
        }

        // STEP 2: Remove portion info from metadata line
        guard lines.count >= 1 else { return lines.joined(separator: "\n") }

        // Find the metadata line (contains Hazırlık and Porsiyon)
        if let metadataIndex = lines.firstIndex(where: { $0.contains("**Hazırlık:**") && $0.contains("**Porsiyon:**") }) {
            // Remove everything from | **Porsiyon:** onwards
            let cleanedLine = lines[metadataIndex].replacingOccurrences(
                of: #"\s*\|\s*\*\*Porsiyon:\*\*[^\n]*"#,
                with: "",
                options: .regularExpression
            )
            lines[metadataIndex] = cleanedLine
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Recipe Generation

    /// Smart router: Generate recipe with or without ingredients based on availability
    /// - Parameters:
    ///   - mealType: The type of meal (e.g., "Kahvaltı", "Akşam Yemeği")
    ///   - styleType: The style subcategory for the meal type
    ///   - ingredients: Optional array of ingredients user has on hand
    ///   - userContext: Optional user notes/context (e.g., "diabetes-friendly tiramisu")
    public func generateRecipeSmartRouting(
        mealType: String,
        styleType: String,
        ingredients: [String]?,
        userContext: String?
    ) async {
        // Smart routing based on ingredients availability
        if let ingredients = ingredients, !ingredients.isEmpty {
            logger.info("🧭 [ROUTER] Routing to INGREDIENTS-BASED generation with \(ingredients.count) ingredients")
            await generateRecipeFromIngredients(
                mealType: mealType,
                styleType: styleType,
                ingredients: ingredients,
                userContext: userContext
            )
        } else {
            logger.info("🧭 [ROUTER] Routing to SPONTANEOUS generation (STREAMING MODE)")
            // FIXED: Use streaming version since Firebase Function returns SSE format
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
        logger.info("📥 [COORDINATOR] generateRecipeFromIngredients called (STREAMING MODE) - mealType: \(mealType), styleType: \(styleType), ingredients: \(ingredients.joined(separator: ", "))")

        isGenerating = true
        animationController.startGenerationAnimation()
        generationError = nil
        streamingContent = ""
        tokenCount = 0

        // Get user ID for personalization
        let userId = getUserId()

        logger.info("👤 [COORDINATOR] User ID resolved: \(userId)")
        logger.info("🥕 [COORDINATOR] Using \(ingredients.count) ingredients: \(ingredients.joined(separator: ", "))")
        if let context = userContext, !context.isEmpty {
            logger.info("📝 [COORDINATOR] User context: '\(context)'")
        }

        let startTime = Date()

        // Call streaming service for ingredients-based generation
        await streamingService.generateWithIngredients(
            ingredients: ingredients,
            mealType: mealType,
            styleType: styleType,
            userId: userId,
            userContext: userContext,
            onConnected: {
                Task { @MainActor in
                    self.logger.info("✅ [STREAMING] Connected to ingredients-based generation")
                }
            },
            onChunk: { chunkText, fullContent, count in
                Task { @MainActor in
                    // Remove portion info from displayed content
                    let cleanedContent = self.removePortionInfo(from: fullContent)
                    self.streamingContent = cleanedContent
                    self.tokenCount = count

                    // Feed into TypewriterAnimator for smooth character-by-character animation
                    // The animator will update displayedText, which flows to formState.recipeContent via Combine binding
                    self.typewriterAnimator.animateText(cleanedContent)

                    // Detailed logging to debug streaming
                    self.logger.info("📦 [STREAMING] Chunk #\(count): chunkText='\(chunkText.prefix(50))...', fullContent length=\(fullContent.count), animator target length=\(cleanedContent.count)")
                }
            },
            onComplete: { response in
                Task { @MainActor in
                    let duration = Date().timeIntervalSince(startTime)
                    self.logger.info("⏱️ [COORDINATOR] Recipe generation completed in \(String(format: "%.2f", duration))s")
                    self.logger.info("🍳 [COORDINATOR] Recipe generated successfully: \(response.recipeName)")

                    // Populate form state with complete response
                    self.formState.loadFromGenerationResponse(response)

                    // Record in memory using extracted ingredients from Cloud Functions
                    await self.recordRecipeInMemory(
                        mealType: mealType,
                        styleType: styleType,
                        extractedIngredients: response.extractedIngredients,
                        recipeName: response.recipeName
                    )

                    // Debug: Verify form state was populated
                    self.logger.info("📊 [DEBUG] Form state after loading:")
                    self.logger.info("   recipeName: '\(self.formState.recipeName)'")
                    self.logger.info("   ingredients count: \(self.formState.ingredients.count)")
                    self.logger.info("   directions count: \(self.formState.directions.count)")
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
    }

    /// Generate recipe with AI (spontaneous, no ingredients)
    public func generateRecipe(mealType: String, styleType: String, userContext: String? = nil) async {
        logger.info("📥 [COORDINATOR] ========== GENERATE RECIPE CALLED ==========")
        logger.info("📥 [COORDINATOR] generateRecipe called - mealType: \(mealType), styleType: \(styleType)")

        isGenerating = true
        animationController.startGenerationAnimation()
        generationError = nil

        do {
            // Get user ID for personalization
            let userId = getUserId()

            logger.info("👤 [COORDINATOR] User ID resolved: \(userId)")

            // SMART MEMORY USAGE: Only use recipe memory when input is vague/minimal
            let shouldUseMemory = userContext == nil || userContext?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true

            let recentRecipes: [SimpleRecentRecipe]
            let diversityConstraints: DiversityConstraints?

            if shouldUseMemory {
                logger.info("🧠 [MEMORY] User input is vague - using memory for variety")

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

                // Analyze protein variety for diversity constraints
                diversityConstraints = await buildDiversityConstraints(mealType: mealType, styleType: styleType)
            } else {
                logger.info("🎯 [MEMORY] User is being specific - skipping memory to respect their intent")
                logger.info("📝 [MEMORY] User context: '\(userContext ?? "")'")
                recentRecipes = []
                diversityConstraints = nil
            }

            logger.info("🚀 [COORDINATOR] Starting recipe generation - mealType: \(mealType), styleType: \(styleType), userId: \(userId), recentRecipesCount: \(recentRecipes.count), diversityEnabled: \(diversityConstraints != nil)")

            let startTime = Date()

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

            let duration = Date().timeIntervalSince(startTime)
            logger.info("⏱️ [COORDINATOR] Recipe generation completed in \(String(format: "%.2f", duration))s")

            // Back on MainActor for UI updates
            logger.info("🍳 [COORDINATOR] Recipe generated successfully: \(response.recipeName)")

            // Populate form state
            formState.loadFromGenerationResponse(response)

            // Record in memory using extracted ingredients from Cloud Functions
            await recordRecipeInMemory(
                mealType: mealType,
                styleType: styleType,
                extractedIngredients: response.extractedIngredients,
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

    /// Generate recipe using ONLY user context (no meal type hints)
    /// This is used for Flow 3 (Notes only) and Flow 4 (Ingredients + Notes)
    /// When the user writes notes, they're telling us exactly what to make
    public func generateRecipeWithUserContextOnly(
        ingredients: [String]?,
        userContext: String?
    ) async {
        logger.info("🎯 [USER-CONTEXT-ONLY] Generating with user context ONLY - NO meal type hints")
        logger.info("📝 [USER-CONTEXT] '\(userContext ?? "nil")'")

        if let ingredients = ingredients {
            logger.info("🥕 [FLOW-4] With ingredients: \(ingredients.joined(separator: ", "))")
            // Use ingredients-based generation with user context
            await generateRecipeFromIngredients(
                mealType: "Genel",  // Placeholder (will be ignored by prompt)
                styleType: "Genel",  // Placeholder (will be ignored by prompt)
                ingredients: ingredients,
                userContext: userContext
            )
        } else {
            logger.info("📝 [FLOW-3] Notes only, no ingredients")
            // Use spontaneous generation with user context ONLY
            await generateRecipeWithStreaming(
                mealType: "Genel",  // Placeholder (will be ignored by prompt)
                styleType: "Genel",  // Placeholder (will be ignored by prompt)
                userContext: userContext
            )
        }
    }

    /// Generate recipe with streaming support
    public func generateRecipeWithStreaming(mealType: String, styleType: String, userContext: String? = nil) async {
        logger.info("📥 [COORDINATOR] generateRecipeWithStreaming called - mealType: \(mealType), styleType: \(styleType)")
        if let context = userContext {
            logger.info("📝 [COORDINATOR] User context: '\(context)'")
        }

        isGenerating = true
        animationController.startGenerationAnimation()
        generationError = nil
        streamingContent = ""
        tokenCount = 0

        // Get user ID for personalization
        let userId = getUserId()

        logger.info("👤 [COORDINATOR] User ID resolved: \(userId)")

        // SMART MEMORY USAGE: Only use recipe memory when input is vague/minimal
        // Flow 1 (Empty): Use memory - AI needs context
        // Flow 2 (Ingredients only): Use memory - helps avoid repetition
        // Flow 3 (Notes only): Skip memory - user is explicit about what they want
        // Flow 4 (Ingredients + notes): Skip memory - user already giving full context
        let shouldUseMemory = userContext == nil || userContext?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true

        let recentRecipes: [SimpleRecentRecipe]
        let diversityConstraints: DiversityConstraints?

        if shouldUseMemory {
            logger.info("🧠 [MEMORY] User input is vague - using memory for variety")

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

            // Analyze protein variety for diversity constraints
            diversityConstraints = await buildDiversityConstraints(mealType: mealType, styleType: styleType)
        } else {
            logger.info("🎯 [MEMORY] User is being specific - skipping memory to respect their intent")
            logger.info("📝 [MEMORY] User context: '\(userContext ?? "")'")
            recentRecipes = []
            diversityConstraints = nil
        }

        logger.info("🚀 [COORDINATOR] Starting recipe generation with streaming - mealType: \(mealType), styleType: \(styleType), userId: \(userId), recentRecipesCount: \(recentRecipes.count), diversityEnabled: \(diversityConstraints != nil)")

        let startTime = Date()

        // Call streaming service with diversity constraints and user context
        await streamingService.generateSpontaneous(
            mealType: mealType,
            styleType: styleType,
            userId: userId,
            recentRecipes: recentRecipes,
            diversityConstraints: diversityConstraints,
            userContext: userContext,
            onConnected: {
                Task { @MainActor in
                    self.logger.info("✅ [STREAMING] Connected to recipe generation")
                }
            },
            onChunk: { chunkText, fullContent, count in
                Task { @MainActor in
                    // Remove portion info from displayed content
                    let cleanedContent = self.removePortionInfo(from: fullContent)
                    self.streamingContent = cleanedContent
                    self.tokenCount = count

                    // Feed into TypewriterAnimator for smooth character-by-character animation
                    // The animator will update displayedText, which flows to formState.recipeContent via Combine binding
                    self.typewriterAnimator.animateText(cleanedContent)

                    // Detailed logging to debug streaming
                    self.logger.info("📦 [STREAMING] Chunk #\(count): chunkText='\(chunkText.prefix(50))...', fullContent length=\(fullContent.count), animator target length=\(cleanedContent.count)")
                }
            },
            onComplete: { response in
                Task { @MainActor in
                    let duration = Date().timeIntervalSince(startTime)
                    self.logger.info("⏱️ [COORDINATOR] Recipe generation completed in \(String(format: "%.2f", duration))s")
                    self.logger.info("🍳 [COORDINATOR] Recipe generated successfully: \(response.recipeName)")

                    // Populate form state with complete response
                    self.formState.loadFromGenerationResponse(response)

                    // Record in memory using extracted ingredients from Cloud Functions
                    await self.recordRecipeInMemory(
                        mealType: mealType,
                        styleType: styleType,
                        extractedIngredients: response.extractedIngredients,
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
    }

    // MARK: - Memory Integration

    /// Fetch memory entries for a subcategory and convert to Cloud Functions format
    private func fetchMemoryForGeneration(mealType: String, styleType: String) async -> [[String: Any]]? {
        logger.info("🔍 [INTEGRATION] ========== FETCHING MEMORY FOR GENERATION ==========")
        logger.info("🔍 [INTEGRATION] MealType: \(mealType), StyleType: \(styleType)")

        // Determine subcategory: try styleType first, then fall back to mealType
        let subcategoryName = determineSubcategory(mealType: mealType, styleType: styleType)
        logger.info("🔍 [INTEGRATION] Resolved subcategory name: \(subcategoryName)")

        // Parse subcategory from resolved name
        guard let subcategory = RecipeSubcategory(rawValue: subcategoryName) else {
            logger.error("🔍 [INTEGRATION] ❌ FAILED: Could not parse subcategory from: \(subcategoryName)")
            logger.error("🔍 [INTEGRATION] Available subcategories: \(RecipeSubcategory.allCases.map { $0.rawValue }.joined(separator: ", "))")
            return nil
        }

        logger.info("🔍 [INTEGRATION] Subcategory: \(subcategory.rawValue) (limit: \(subcategory.memoryLimit))")
        let memoryEntries = await memoryService.getMemoryForCloudFunctions(for: subcategory, limit: 10)
        logger.info("🔍 [INTEGRATION] Retrieved \(memoryEntries.count) memory entries for Cloud Functions")

        if memoryEntries.isEmpty {
            logger.info("🔍 [INTEGRATION] ⚠️ Memory is EMPTY - first recipe in this subcategory!")
            return nil
        } else {
            // Log first few entries for debugging
            for (index, entry) in memoryEntries.prefix(3).enumerated() {
                if let ingredients = entry["mainIngredients"] as? [String],
                   let name = entry["recipeName"] as? String {
                    logger.info("🔍 [INTEGRATION] Entry \(index + 1): '\(name)' - [\(ingredients.joined(separator: ", "))]")
                }
            }
            return memoryEntries
        }
    }

    /// Determine subcategory from mealType and styleType
    private func determineSubcategory(mealType: String, styleType: String) -> String {
        logger.debug("🔍 [SUBCATEGORY-MAP] Input - mealType: '\(mealType)', styleType: '\(styleType)'")

        // Subcategory mapping from UI values to memory system values
        // IMPORTANT: Keys must EXACTLY match what RecipeMealSelectionView sends (line 49-53)
        // Rule: Every first letter capitalized EXCEPT "ve" (lowercase)
        let subcategoryMap: [String: String] = [
            // Salatalar subcategories
            "Doyurucu Salata": "Doyurucu Salata",
            "Hafif Salata": "Hafif Salata",

            // Akşam Yemeği subcategories
            "Karbonhidrat ve Protein Uyumu": "Karbonhidrat ve Protein Uyumu",
            "Tam Buğday Makarna": "Tam Buğday Makarna",

            // Tatlılar subcategories
            "Sana Özel Tatlılar": "Sana Özel Tatlılar",
            "Dondurma": "Dondurma",
            "Meyve Salatası": "Meyve Salatası"
        ]

        // If styleType is NOT empty and is a known subcategory, use it
        if !styleType.isEmpty, let mappedSubcategory = subcategoryMap[styleType] {
            logger.debug("🔍 [SUBCATEGORY-MAP] Found mapping for styleType: '\(styleType)' → '\(mappedSubcategory)'")
            return mappedSubcategory
        }

        // Otherwise, use mealType for categories without subcategories
        let mealTypeMap: [String: String] = [
            "Kahvaltı": "Kahvaltı",
            "Atıştırmalık": "Atıştırmalık"
        ]

        let result = mealTypeMap[mealType] ?? mealType
        logger.debug("🔍 [SUBCATEGORY-MAP] Using mealType mapping: '\(mealType)' → '\(result)'")
        return result
    }

    /// Build diversity constraints based on protein variety analysis
    private func buildDiversityConstraints(mealType: String, styleType: String) async -> DiversityConstraints? {
        logger.info("🎯 [DIVERSITY] ========== BUILDING DIVERSITY CONSTRAINTS ==========")

        // Determine subcategory
        let subcategoryName = determineSubcategory(mealType: mealType, styleType: styleType)
        logger.info("🎯 [DIVERSITY] Subcategory: \(subcategoryName)")

        // Parse subcategory from resolved name
        guard let subcategory = RecipeSubcategory(rawValue: subcategoryName) else {
            logger.error("🎯 [DIVERSITY] ❌ Could not parse subcategory from: \(subcategoryName)")
            return nil
        }

        // Analyze protein variety
        let analysis = await memoryService.analyzeProteinVariety(for: subcategory)

        // Build constraints if we have meaningful data
        var avoidProteins: [String]? = nil
        var suggestProteins: [String]? = nil

        // Combine overused proteins AND recent proteins (high priority)
        let proteinsToAvoid = Set(analysis.overusedProteins + analysis.recentProteins)
        if !proteinsToAvoid.isEmpty {
            let proteins = Array(proteinsToAvoid).sorted()
            avoidProteins = proteins
            logger.info("🎯 [DIVERSITY] Avoid proteins: \(proteins.joined(separator: ", "))")
        }

        // Suggest underused proteins
        if !analysis.suggestedProteins.isEmpty {
            suggestProteins = analysis.suggestedProteins
            logger.info("🎯 [DIVERSITY] Suggest proteins: \(analysis.suggestedProteins.joined(separator: ", "))")
        }

        // Only create constraints if we have actionable data
        guard avoidProteins != nil || suggestProteins != nil else {
            logger.info("🎯 [DIVERSITY] No diversity constraints needed (insufficient memory)")
            return nil
        }

        let constraints = DiversityConstraints(
            avoidCuisines: nil,
            avoidProteins: avoidProteins,
            avoidMethods: nil,
            suggestCuisines: nil,
            suggestProteins: suggestProteins
        )

        logger.info("🎯 [DIVERSITY] ✅ Diversity constraints built successfully")
        return constraints
    }

    /// Record generated recipe in memory
    private func recordRecipeInMemory(
        mealType: String,
        styleType: String,
        extractedIngredients: [String]?,
        recipeName: String
    ) async {
        logger.info("💾 [INTEGRATION] ========== RECORDING RECIPE IN MEMORY ==========")
        logger.info("💾 [INTEGRATION] Recipe: '\(recipeName)'")
        logger.info("💾 [INTEGRATION] MealType: \(mealType), StyleType: \(styleType)")

        // Determine subcategory
        let subcategoryName = determineSubcategory(mealType: mealType, styleType: styleType)
        logger.info("💾 [INTEGRATION] Resolved subcategory name: \(subcategoryName)")

        // Parse subcategory from resolved name
        guard let subcategory = RecipeSubcategory(rawValue: subcategoryName) else {
            logger.error("💾 [INTEGRATION] ❌ FAILED: Could not parse subcategory from: \(subcategoryName)")
            return
        }

        logger.info("💾 [INTEGRATION] Subcategory: \(subcategory.rawValue)")

        // Only record if we have extracted ingredients
        guard let ingredients = extractedIngredients, !ingredients.isEmpty else {
            logger.error("💾 [INTEGRATION] ❌ FAILED: No extracted ingredients to record")
            logger.error("💾 [INTEGRATION] This means Cloud Functions didn't extract ingredients!")
            return
        }

        logger.info("💾 [INTEGRATION] Extracted ingredients from Cloud Functions: \(ingredients.joined(separator: ", "))")

        do {
            try await memoryService.recordRecipe(
                subcategory: subcategory,
                ingredients: ingredients,
                recipeName: recipeName
            )
            logger.info("💾 [INTEGRATION] ✅ Successfully recorded recipe in memory system")
        } catch {
            logger.error("💾 [INTEGRATION] ❌ FAILED to record recipe: \(error.localizedDescription)")
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

        // Reset typewriter animator
        typewriterAnimator.reset()

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
        typewriterAnimator.reset()  // Clear animator state
    }

    /// Reset everything including form state (called on generation failure)
    public func resetAll() {
        isGenerating = false
        generationError = nil
        showPhotoButton = false
        streamingContent = ""
        tokenCount = 0
        typewriterAnimator.reset()  // Clear animator state
        formState.clearAll()
    }
}
