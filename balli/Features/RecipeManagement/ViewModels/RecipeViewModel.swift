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

    // MARK: - Handler Objects
    public var nutritionHandler: RecipeNutritionHandler
    public var imageHandler: RecipeImageHandler

    // MARK: - Legacy UI State (For Backward Compatibility)
    @Published public var isInitializing = false
    @Published public var useHandwrittenFont = true

    // MARK: - Services
    private let viewContext: NSManagedObjectContext
    private let logger = AppLoggers.Recipe.generation

    // MARK: - Combine
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Computed Properties for Backward Compatibility

    // Form State Delegation (Read-Write)
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

    // MARK: - Per-Serving Nutrition Values
    public var caloriesPerServing: String {
        get { formState.caloriesPerServing }
        set { formState.caloriesPerServing = newValue }
    }

    public var carbohydratesPerServing: String {
        get { formState.carbohydratesPerServing }
        set { formState.carbohydratesPerServing = newValue }
    }

    public var fiberPerServing: String {
        get { formState.fiberPerServing }
        set { formState.fiberPerServing = newValue }
    }

    public var proteinPerServing: String {
        get { formState.proteinPerServing }
        set { formState.proteinPerServing = newValue }
    }

    public var fatPerServing: String {
        get { formState.fatPerServing }
        set { formState.fatPerServing = newValue }
    }

    public var sugarPerServing: String {
        get { formState.sugarPerServing }
        set { formState.sugarPerServing = newValue }
    }

    public var glycemicLoadPerServing: String {
        get { formState.glycemicLoadPerServing }
        set { formState.glycemicLoadPerServing = newValue }
    }

    public var totalRecipeWeight: String {
        get { formState.totalRecipeWeight }
        set { formState.totalRecipeWeight = newValue }
    }

    public var portionMultiplier: Double {
        get { formState.portionMultiplier }
        set { formState.portionMultiplier = newValue }
    }

    public var digestionTiming: DigestionTiming? {
        get { formState.digestionTiming }
        set { formState.digestionTiming = newValue }
    }

    // MARK: - Nutrition Handler Delegation
    public var isCalculatingNutrition: Bool {
        nutritionHandler.isCalculatingNutrition
    }

    public var nutritionCalculationError: String? {
        nutritionHandler.nutritionCalculationError
    }

    public var nutritionCalculationProgress: Int {
        nutritionHandler.nutritionCalculationProgress
    }

    public var adjustmentRatio: Double {
        nutritionHandler.adjustmentRatio
    }

    public var adjustedCalories: String {
        nutritionHandler.adjustedCalories
    }

    public var adjustedCarbohydrates: String {
        nutritionHandler.adjustedCarbohydrates
    }

    public var adjustedFiber: String {
        nutritionHandler.adjustedFiber
    }

    public var adjustedSugar: String {
        nutritionHandler.adjustedSugar
    }

    public var adjustedProtein: String {
        nutritionHandler.adjustedProtein
    }

    public var adjustedFat: String {
        nutritionHandler.adjustedFat
    }

    public var adjustedGlycemicLoad: String {
        nutritionHandler.adjustedGlycemicLoad
    }

    // MARK: - Image Handler Delegation
    public var recipeImageURL: String? {
        get { imageHandler.recipeImageURL }
        set { imageHandler.recipeImageURL = newValue }
    }

    public var recipeImageData: Data? {
        get { imageHandler.recipeImageData }
        set { imageHandler.recipeImageData = newValue }
    }

    public var isUploadingImage: Bool {
        imageHandler.isUploadingImage
    }

    public var isLoadingImageFromStorage: Bool {
        imageHandler.isLoadingImageFromStorage
    }

    public var isImageFromLocalData: Bool {
        imageHandler.isImageFromLocalData
    }

    public var preparedImage: UIImage? {
        imageHandler.preparedImage
    }

    public var isShoppingListExpanded: Bool {
        get { imageHandler.isShoppingListExpanded }
        set { imageHandler.isShoppingListExpanded = newValue }
    }

    public var isShoppingListActive: Bool {
        get { imageHandler.isShoppingListActive }
        set { imageHandler.isShoppingListActive = newValue }
    }

    public var navigateToShoppingList: Bool {
        get { imageHandler.navigateToShoppingList }
        set { imageHandler.navigateToShoppingList = newValue }
    }

    public var sentIngredients: Set<String> {
        get { imageHandler.sentIngredients }
        set { imageHandler.sentIngredients = newValue }
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

    public var hasRecipeData: Bool {
        formState.hasRecipeData
    }

    // MARK: - Initialization

    public init(context: NSManagedObjectContext, recipe: Recipe? = nil) {
        self.viewContext = context

        // Initialize state objects
        let formState = RecipeFormState()
        let animationController = RecipeAnimationController()

        self.formState = formState
        self.animationController = animationController

        // Initialize handlers
        self.nutritionHandler = RecipeNutritionHandler(formState: formState)
        self.imageHandler = RecipeImageHandler(formState: formState, context: context)

        // Initialize coordinators with dependencies
        self.generationCoordinator = RecipeGenerationCoordinator(
            animationController: animationController,
            formState: formState
        )

        self.photoCoordinator = RecipePhotoGenerationCoordinator(formState: formState)

        self.persistenceCoordinator = RecipePersistenceCoordinator(
            context: context,
            dataManager: RecipeDataManager(context: context),
            imageService: RecipeImageService(context: context),
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

        nutritionHandler.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)

        imageHandler.objectWillChange.sink { [weak self] _ in
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

        // Load image data
        if let imageData = recipe.imageData {
            imageHandler.recipeImageData = imageData
        }

        if let imageURL = recipe.imageURL, !imageURL.isEmpty {
            imageHandler.recipeImageURL = imageURL
        }

        // Set animation to completed state
        animationController.setCompleted()
        generationCoordinator.showPhotoButton = formState.hasRecipeData
    }

    // MARK: - Recipe Generation

    public func generateRecipeWithAI(mealType: String, styleType: String) async {
        logger.info("🎯 [RECIPE-ENTRY] User initiated recipe generation - mealType: \(mealType), styleType: \(styleType)")

        // Clear photo state before starting generation
        imageHandler.clearImageData()
        photoCoordinator.reset()

        await generationCoordinator.generateRecipe(mealType: mealType, styleType: styleType)

        logger.info("🏁 [RECIPE-ENTRY] Recipe generation completed - hasRecipeData: \(self.formState.hasRecipeData)")
    }

    public func onLogoAnimationComplete() {
        animationController.onLogoAnimationComplete()
    }

    // MARK: - Photo Generation

    public func generateRecipePhoto() async {
        await photoCoordinator.generatePhoto()
    }

    public func loadImageFromGeneratedURL() async {
        await imageHandler.loadImageFromGeneratedURL(generatedPhotoURL: generatedPhotoURL)
    }

    // MARK: - Nutrition Calculation

    public func calculateNutrition(isManualRecipe: Bool = false) {
        nutritionHandler.calculateNutrition(isManualRecipe: isManualRecipe)
    }

    // MARK: - Save Recipe

    public func saveRecipe() {
        logger.info("💾 [SAVE] saveRecipe() called")
        logger.debug("📋 [SAVE] Image state:")
        logger.debug("  - recipeImageURL: \(self.recipeImageURL != nil ? "present" : "nil")")
        if let imageData = self.recipeImageData {
            logger.debug("  - recipeImageData: \(imageData.count) bytes")
        } else {
            logger.debug("  - recipeImageData: nil")
        }
        logger.debug("  - preparedImage: \(self.preparedImage != nil ? "present" : "nil")")

        Task {
            await persistenceCoordinator.saveRecipe(imageURL: recipeImageURL, imageData: recipeImageData)
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
        imageHandler.clearImageData()
        imageHandler.resetShoppingListState()

        animationController.reset()
        generationCoordinator.reset()
        photoCoordinator.reset()
    }

    // MARK: - Shopping List Integration

    public func toggleShoppingList() {
        imageHandler.toggleShoppingList()
    }

    public func addIngredientsToShoppingList() async {
        await imageHandler.addIngredientsToShoppingList()
    }
}
