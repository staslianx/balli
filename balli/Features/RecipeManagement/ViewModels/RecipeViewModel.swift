//
//  RecipeViewModel.swift
//  balli
//
//  Slim coordinator ViewModel for recipe entry
//  Delegates to specialized services for separation of concerns
//  Swift 6 strict concurrency compliant
//

import SwiftUI
import CoreData
import Foundation
import OSLog
import Combine

@MainActor
public class RecipeViewModel: ObservableObject {
    // MARK: - State Objects (Single Source of Truth)
    // PERFORMANCE: These ObservableObjects should NOT be @Published - causes double-publishing cascade
    // Their own @Published properties will trigger objectWillChange via Combine
    public var formState: RecipeFormState
    public var animationController: RecipeAnimationController
    public var generationCoordinator: RecipeGenerationCoordinator
    public var photoCoordinator: RecipePhotoGenerationCoordinator
    public var persistenceCoordinator: RecipePersistenceCoordinator

    // MARK: - Image Service State (Internal)
    @Published private var _recipeImageURL: String?
    @Published private var _recipeImageData: Data?
    @Published private var _isUploadingImage = false
    @Published private var _isLoadingImageFromStorage = false

    // MARK: - Pre-decoded Image Cache (Performance Optimization)
    /// Pre-decoded UIImage to eliminate synchronous UIImage(data:) calls in SwiftUI body
    /// This prevents main thread blocking and eliminates unsafeForcedSync warnings
    @Published public var preparedImage: UIImage?

    // MARK: - Shopping List Service State (Internal)
    @Published private var _isShoppingListExpanded = false
    @Published private var _isShoppingListActive = false
    @Published private var _navigateToShoppingList = false
    @Published private var _sentIngredients: Set<String> = []

    // MARK: - Legacy UI State (For Backward Compatibility)
    @Published public var isInitializing = false
    @Published public var useHandwrittenFont = true

    // MARK: - Services
    private let imageService: RecipeImageService
    private let shoppingListService: ShoppingListIntegrationService
    private let dataManager: RecipeDataManager
    private let viewContext: NSManagedObjectContext
    private let logger = AppLoggers.Recipe.generation

    // MARK: - Combine
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Computed Properties for Backward Compatibility

    // Form State Delegation
    public var recipeName: String {
        get { formState.recipeName }
        set { formState.recipeName = newValue }
    }

    public var prepTime: String {
        get { formState.prepTime }
        set { formState.prepTime = newValue }
    }

    public var cookTime: String {
        get { formState.cookTime }
        set { formState.cookTime = newValue }
    }

    public var ingredients: [String] {
        get { formState.ingredients }
        set { formState.ingredients = newValue }
    }

    public var directions: [String] {
        get { formState.directions }
        set { formState.directions = newValue }
    }

    public var notes: String {
        get { formState.notes }
        set { formState.notes = newValue }
    }

    public var recipeContent: String {
        get { formState.recipeContent }
        set { formState.recipeContent = newValue }
    }

    public var calories: String {
        get { formState.calories }
        set { formState.calories = newValue }
    }

    public var carbohydrates: String {
        get { formState.carbohydrates }
        set { formState.carbohydrates = newValue }
    }

    public var fiber: String {
        get { formState.fiber }
        set { formState.fiber = newValue }
    }

    public var protein: String {
        get { formState.protein }
        set { formState.protein = newValue }
    }

    public var fat: String {
        get { formState.fat }
        set { formState.fat = newValue }
    }

    public var sugar: String {
        get { formState.sugar }
        set { formState.sugar = newValue }
    }

    public var glycemicLoad: String {
        get { formState.glycemicLoad }
        set { formState.glycemicLoad = newValue }
    }

    // MARK: - Adjusted Nutrition Values (Performance Optimized with Caching)

    // Cache for adjusted values - invalidated when portionGrams or nutrition values change
    private var nutritionCache: NutritionCache = NutritionCache()

    private struct NutritionCache {
        var lastPortionGrams: Double = 100.0
        var lastCalories: String = ""
        var lastCarbs: String = ""
        var lastFiber: String = ""
        var lastSugar: String = ""
        var lastProtein: String = ""
        var lastFat: String = ""
        var lastGlycemicLoad: String = ""

        var cachedAdjustedCalories: String = ""
        var cachedAdjustedCarbs: String = ""
        var cachedAdjustedFiber: String = ""
        var cachedAdjustedSugar: String = ""
        var cachedAdjustedProtein: String = ""
        var cachedAdjustedFat: String = ""
        var cachedAdjustedGlycemicLoad: String = ""

        mutating func shouldInvalidate(
            portionGrams: Double,
            calories: String,
            carbs: String,
            fiber: String,
            sugar: String,
            protein: String,
            fat: String,
            glycemicLoad: String
        ) -> Bool {
            portionGrams != lastPortionGrams ||
            calories != lastCalories ||
            carbs != lastCarbs ||
            fiber != lastFiber ||
            sugar != lastSugar ||
            protein != lastProtein ||
            fat != lastFat ||
            glycemicLoad != lastGlycemicLoad
        }
    }

    /// Adjustment ratio based on current portion grams vs 100g base
    public var adjustmentRatio: Double {
        // Nutrition values are per 100g, so ratio is portionGrams / 100
        return formState.portionGrams / 100.0
    }

    /// Adjusted calorie value based on serving size
    public var adjustedCalories: String {
        updateCacheIfNeeded()
        return nutritionCache.cachedAdjustedCalories
    }

    /// Adjusted carbohydrates value based on serving size
    public var adjustedCarbohydrates: String {
        updateCacheIfNeeded()
        return nutritionCache.cachedAdjustedCarbs
    }

    /// Adjusted fiber value based on serving size
    public var adjustedFiber: String {
        updateCacheIfNeeded()
        return nutritionCache.cachedAdjustedFiber
    }

    /// Adjusted sugar value based on serving size
    public var adjustedSugar: String {
        updateCacheIfNeeded()
        return nutritionCache.cachedAdjustedSugar
    }

    /// Adjusted protein value based on serving size
    public var adjustedProtein: String {
        updateCacheIfNeeded()
        return nutritionCache.cachedAdjustedProtein
    }

    /// Adjusted fat value based on serving size
    public var adjustedFat: String {
        updateCacheIfNeeded()
        return nutritionCache.cachedAdjustedFat
    }

    /// Adjusted glycemic load value based on serving size
    public var adjustedGlycemicLoad: String {
        updateCacheIfNeeded()
        return nutritionCache.cachedAdjustedGlycemicLoad
    }

    /// Update nutrition cache if any values changed
    private func updateCacheIfNeeded() {
        if nutritionCache.shouldInvalidate(
            portionGrams: formState.portionGrams,
            calories: calories,
            carbs: carbohydrates,
            fiber: fiber,
            sugar: sugar,
            protein: protein,
            fat: fat,
            glycemicLoad: glycemicLoad
        ) {
            // Recalculate all values
            let ratio = adjustmentRatio

            nutritionCache.cachedAdjustedCalories = calculateAdjusted(calories, ratio: ratio, isCalories: true)
            nutritionCache.cachedAdjustedCarbs = calculateAdjusted(carbohydrates, ratio: ratio)
            nutritionCache.cachedAdjustedFiber = calculateAdjusted(fiber, ratio: ratio)
            nutritionCache.cachedAdjustedSugar = calculateAdjusted(sugar, ratio: ratio)
            nutritionCache.cachedAdjustedProtein = calculateAdjusted(protein, ratio: ratio)
            nutritionCache.cachedAdjustedFat = calculateAdjusted(fat, ratio: ratio)
            nutritionCache.cachedAdjustedGlycemicLoad = calculateAdjusted(glycemicLoad, ratio: ratio)

            // Update cache state
            nutritionCache.lastPortionGrams = formState.portionGrams
            nutritionCache.lastCalories = calories
            nutritionCache.lastCarbs = carbohydrates
            nutritionCache.lastFiber = fiber
            nutritionCache.lastSugar = sugar
            nutritionCache.lastProtein = protein
            nutritionCache.lastFat = fat
            nutritionCache.lastGlycemicLoad = glycemicLoad
        }
    }

    /// Calculate adjusted value with caching
    private func calculateAdjusted(_ baseString: String, ratio: Double, isCalories: Bool = false) -> String {
        guard let baseValue = Double(baseString) else { return baseString }
        let adjusted = baseValue * ratio

        if isCalories {
            return String(format: "%.0f", adjusted)
        }
        return formatNutritionValue(adjusted)
    }

    /// Format nutrition value with appropriate precision
    private func formatNutritionValue(_ value: Double) -> String {
        if value < 10 {
            return String(format: "%.1f", value)
        } else {
            return String(format: "%.0f", value)
        }
    }

    // Generation State Delegation
    public var isGeneratingRecipe: Bool {
        generationCoordinator.isGenerating
    }

    public var generationError: String? {
        generationCoordinator.generationError
    }

    public var showPhotoButton: Bool {
        get { generationCoordinator.showPhotoButton }
        set { generationCoordinator.showPhotoButton = newValue }
    }

    // Animation State Delegation
    public var isRotatingLogo: Bool {
        animationController.isRotatingLogo
    }

    public var isFadingOutContent: Bool {
        animationController.isFadingOutContent
    }

    public var textVisible: Bool {
        animationController.textVisible
    }

    public var isLogoAnimationComplete: Bool {
        animationController.isLogoAnimationComplete
    }

    // Photo Generation State Delegation
    public var isGeneratingPhoto: Bool {
        photoCoordinator.isGeneratingPhoto
    }

    public var generatedPhotoURL: String? {
        photoCoordinator.generatedPhotoURL
    }

    public var photoGenerationError: String? {
        photoCoordinator.photoGenerationError
    }

    // Persistence State Delegation
    public var showingSaveConfirmation: Bool {
        get { persistenceCoordinator.showingSaveConfirmation }
        set { persistenceCoordinator.showingSaveConfirmation = newValue }
    }

    public var showingValidationError: Bool {
        get { persistenceCoordinator.showingValidationError }
        set { persistenceCoordinator.showingValidationError = newValue }
    }

    public var validationErrorMessage: String {
        persistenceCoordinator.validationErrorMessage
    }

    // Image Service Properties
    public var recipeImageURL: String? {
        get { _recipeImageURL }
        set { _recipeImageURL = newValue }
    }

    public var recipeImageData: Data? {
        get { _recipeImageData }
        set {
            _recipeImageData = newValue
            // PERFORMANCE FIX: Decode image asynchronously to prevent main thread blocking
            prepareImageAsync(from: newValue)
        }
    }

    public var isUploadingImage: Bool {
        _isUploadingImage
    }

    public var isLoadingImageFromStorage: Bool {
        _isLoadingImageFromStorage
    }

    public var isImageFromLocalData: Bool {
        return _recipeImageData != nil && !_isLoadingImageFromStorage
    }

    // Shopping List Properties
    public var isShoppingListExpanded: Bool {
        get { _isShoppingListExpanded }
        set { _isShoppingListExpanded = newValue }
    }

    public var isShoppingListActive: Bool {
        get { _isShoppingListActive }
        set { _isShoppingListActive = newValue }
    }

    public var navigateToShoppingList: Bool {
        get { _navigateToShoppingList }
        set { _navigateToShoppingList = newValue }
    }

    public var sentIngredients: Set<String> {
        get { _sentIngredients }
        set { _sentIngredients = newValue }
    }

    public var hasRecipeData: Bool {
        formState.hasRecipeData
    }

    // MARK: - Initialization

    public init(context: NSManagedObjectContext, recipe: Recipe? = nil) {
        self.viewContext = context
        self.dataManager = RecipeDataManager(context: context)
        self.imageService = RecipeImageService(context: context)
        self.shoppingListService = ShoppingListIntegrationService()

        // Initialize state objects
        let formState = RecipeFormState()
        let animationController = RecipeAnimationController()

        self.formState = formState
        self.animationController = animationController

        // Initialize coordinators with dependencies
        self.generationCoordinator = RecipeGenerationCoordinator(
            animationController: animationController,
            formState: formState
        )

        self.photoCoordinator = RecipePhotoGenerationCoordinator(formState: formState)

        self.persistenceCoordinator = RecipePersistenceCoordinator(
            context: context,
            dataManager: dataManager,
            imageService: imageService,
            formState: formState,
            existingRecipe: recipe
        )

        // Forward changes from nested ObservableObjects to this ViewModel
        // This ensures SwiftUI views re-render when nested properties change
        formState.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)

        animationController.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)

        generationCoordinator.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)

        photoCoordinator.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)

        // Load existing recipe if provided
        if let recipe = recipe {
            loadRecipe(recipe)
            isInitializing = false
        }
    }

    // MARK: - Public Methods

    public func loadExistingRecipeIfNeeded() {
        // No-op for backward compatibility
    }

    private func loadRecipe(_ recipe: Recipe) {
        persistenceCoordinator.loadExistingRecipe(recipe)

        // Load image data - this will trigger async image preparation via setter
        if let imageData = recipe.imageData {
            _recipeImageData = imageData
            // Manually trigger image preparation since we're using private setter
            prepareImageAsync(from: imageData)
        }

        if let imageURL = recipe.imageURL, !imageURL.isEmpty {
            _recipeImageURL = imageURL
        }

        // Set animation to completed state
        animationController.setCompleted()
        generationCoordinator.showPhotoButton = formState.hasRecipeData
    }

    // MARK: - Recipe Generation

    public func generateRecipeWithAI(mealType: String, styleType: String) async {
        logger.info("🎯 [RECIPE-ENTRY] User initiated recipe generation - mealType: \(mealType), styleType: \(styleType)")

        // Clear photo state before starting generation
        _recipeImageData = nil
        _recipeImageURL = nil
        photoCoordinator.reset()

        await generationCoordinator.generateRecipe(mealType: mealType, styleType: styleType)

        // PERFORMANCE FIX: Removed redundant objectWillChange.send()
        // The formState now batches all updates in a single transaction internally
        logger.info("🏁 [RECIPE-ENTRY] Recipe generation completed - hasRecipeData: \(self.formState.hasRecipeData)")
    }

    public func onLogoAnimationComplete() {
        animationController.onLogoAnimationComplete()
    }

    // MARK: - Photo Generation

    public func generateRecipePhoto() async {
        await photoCoordinator.generatePhoto()
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

    /// Loads image data from a URL and updates the recipe image
    /// Handles both base64 data URLs and HTTP/HTTPS URLs
    public func loadImageFromGeneratedURL() async {
        logger.info("🖼️ [LOAD-IMAGE] loadImageFromGeneratedURL() called")
        if let photoURL = self.generatedPhotoURL {
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
                logger.info("💾 [LOAD-IMAGE] Setting _recipeImageData = imageData (\(imageData.count) bytes)")
                _recipeImageData = imageData
                _recipeImageURL = imageURL
                logger.info("✅ [LOAD-IMAGE] _recipeImageData has been set")
            }
            // CRITICAL: Trigger async image preparation to update preparedImage
            prepareImageAsync(from: imageData)
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
                    _recipeImageData = data
                    _recipeImageURL = imageURL
                }
                // CRITICAL: Trigger async image preparation to update preparedImage
                prepareImageAsync(from: data)
                logger.info("✅ Successfully loaded generated recipe image from network")
            } catch {
                logger.error("❌ Failed to load generated image from URL: \(error.localizedDescription)")
                ErrorHandler.shared.handle(error)
            }
        }
    }

    // MARK: - Save Recipe

    public func saveRecipe() {
        logger.info("💾 [SAVE] saveRecipe() called")
        logger.debug("📋 [SAVE] Image state:")
        logger.debug("  - _recipeImageURL: \(self._recipeImageURL != nil ? "present" : "nil")")
        if let imageData = self._recipeImageData {
            logger.debug("  - _recipeImageData: \(imageData.count) bytes")
        } else {
            logger.debug("  - _recipeImageData: nil")
        }
        logger.debug("  - preparedImage: \(self.preparedImage != nil ? "present" : "nil")")

        Task {
            await persistenceCoordinator.saveRecipe(imageURL: _recipeImageURL, imageData: _recipeImageData)
            logger.info("✅ [SAVE] persistenceCoordinator.saveRecipe() completed")
        }
    }

    // MARK: - Content Management

    public func addIngredient() {
        formState.addIngredient()
    }

    public func removeIngredient(at index: Int) {
        formState.removeIngredient(at: index)
    }

    public func updateIngredient(at index: Int, oldValue: String, newValue: String) {
        formState.updateIngredient(at: index, newValue: newValue)
    }

    public func addDirection() {
        formState.addDirection()
    }

    public func removeDirection(at index: Int) {
        formState.removeDirection(at: index)
    }

    public func clearAllFields() {
        formState.clearAll()
        _recipeImageURL = nil
        _recipeImageData = nil
        preparedImage = nil
        resetShoppingListState()

        animationController.reset()
        generationCoordinator.reset()
        photoCoordinator.reset()
    }

    // MARK: - Shopping List Integration

    public func toggleShoppingList() {
        toggleShoppingListInternal(ingredients: formState.ingredients, recipeName: formState.recipeName)

        if _isShoppingListActive {
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

    // MARK: - Private Shopping List Methods

    private func resetShoppingListState() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            _isShoppingListExpanded = false
            _isShoppingListActive = false
            _navigateToShoppingList = false
        }
        _sentIngredients.removeAll()
    }

    private func toggleShoppingListInternal(ingredients: [String], recipeName: String) {
        let hasValidIngredients = ingredients.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let hasTitle = !recipeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            if !_isShoppingListExpanded && hasValidIngredients && hasTitle {
                _isShoppingListExpanded = true
                _isShoppingListActive = false
            } else if !_isShoppingListActive && _isShoppingListExpanded {
                _isShoppingListActive = true

                Task {
                    await addIngredientsToShoppingListInternal(ingredients: ingredients, recipeName: recipeName)
                }
            }
        }
    }

    private func addIngredientsToShoppingListInternal(ingredients: [String], recipeName: String) async {
        do {
            let recipeId = UUID()
            let recipeNameToUse = recipeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "Yeni Tarif"
                : recipeName.trimmingCharacters(in: .whitespacesAndNewlines)

            let updatedSentIngredients = try await dataManager.addIngredientsToShoppingList(
                ingredients: ingredients,
                sentIngredients: _sentIngredients,
                recipeName: recipeNameToUse,
                recipeId: recipeId
            )

            _sentIngredients = updatedSentIngredients
            logger.info("Successfully added \(updatedSentIngredients.count) ingredients to shopping list for '\(recipeNameToUse)'")

            try? await Task.sleep(for: .milliseconds(1500))

            await MainActor.run {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    _isShoppingListActive = false
                    _isShoppingListExpanded = false
                }
            }
        } catch {
            logger.error("Failed to add ingredients to shopping list: \(error.localizedDescription)")
            ErrorHandler.shared.handle(error)
            await MainActor.run {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    _isShoppingListActive = false
                    _isShoppingListExpanded = false
                }
            }
        }
    }
}
