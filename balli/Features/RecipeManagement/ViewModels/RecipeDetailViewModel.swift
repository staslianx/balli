//
//  RecipeDetailViewModel.swift
//  balli
//
//  ViewModel for recipe detail screen
//  Handles all business logic, Core Data operations, and state management
//  Swift 6 strict concurrency compliant
//

import Foundation
import SwiftUI
import CoreData
import OSLog

/// ViewModel for RecipeDetailView
/// Manages recipe state, editing, photo generation, nutrition calculation
@MainActor
final class RecipeDetailViewModel: ObservableObject {
    // MARK: - Published State

    @Published var showingShareSheet = false
    @Published var imageToShare: UIImage?
    @Published var showingNutritionalValues = false
    @Published var showingNotesModal = false
    @Published var isGeneratingPhoto = false
    @Published var generatedImageData: Data?
    @Published var isCalculatingNutrition = false
    @Published var nutritionCalculationProgress = 0
    @Published var currentLoadingStep: String?
    @Published var digestionTimingInsights: DigestionTiming?
    @Published var toastMessage: ToastType?

    // Inline editing state
    @Published var isEditing = false
    @Published var editedName: String = ""
    @Published var editedIngredients: [String] = []
    @Published var editedInstructions: [String] = []
    @Published var editedNotes: String = ""
    @Published var userNotes: String = ""

    // Shopping list state
    @Published var hasUncheckedIngredients = false

    // MARK: - Dependencies

    private let viewContext: NSManagedObjectContext
    private let nutritionRepository = RecipeNutritionRepository()
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.balli", category: "RecipeDetailViewModel")

    // Recipe data
    let recipeData: RecipeDetailData

    // Data manager
    private var dataManager: RecipeDataManager {
        RecipeDataManager(context: viewContext)
    }

    // Loading animation steps with start/end progress for smooth animations
    private let loadingSteps: [(label: String, duration: TimeInterval, startProgress: Int, endProgress: Int)] = [
        ("Tarife tekrar bakıyorum", 5.0, 5, 10),
        ("Malzemeleri gruplara ayırıyorum", 6.0, 10, 18),
        ("Ham besin değerlerini hesaplıyorum", 7.0, 18, 28),
        ("Pişirme yöntemlerini analiz ediyorum", 7.0, 28, 38),
        ("Pişirme etkilerini belirliyorum", 7.0, 38, 48),
        ("Sıvı emilimini hesaplıyorum", 7.0, 48, 58),
        ("Pişirme kayıplarını hesaplıyorum", 7.0, 58, 68),
        ("Pişmiş değerleri hesaplıyorum", 7.0, 68, 78),
        ("Porsiyon değerlerini hesaplıyorum", 7.0, 78, 86),
        ("100g için değerleri hesaplıyorum", 7.0, 86, 93),
        ("Glisemik yükü hesaplıyorum", 7.0, 93, 98),
        ("Sağlamasını yapıyorum", 8.0, 98, 100)
    ]

    // MARK: - Initialization

    init(recipeData: RecipeDetailData, viewContext: NSManagedObjectContext) {
        self.recipeData = recipeData
        self.viewContext = viewContext
        self.userNotes = recipeData.recipe.notes ?? ""
    }

    // MARK: - Shopping List

    func checkShoppingListStatus() async {
        // Use the Recipe's UUID (id attribute), not the CoreData objectID
        let recipeUUID = recipeData.recipe.id

        let request = ShoppingListItem.fetchRequest()
        request.predicate = NSPredicate(
            format: "recipeId == %@ AND isCompleted == NO",
            recipeUUID as NSUUID
        )

        do {
            let count = try viewContext.count(for: request)
            hasUncheckedIngredients = count > 0
        } catch {
            logger.error("Failed to check shopping list status: \(error.localizedDescription)")
            hasUncheckedIngredients = false
        }
    }

    // MARK: - Recipe Actions

    func toggleFavorite() {
        recipeData.recipe.toggleFavorite()

        do {
            try viewContext.save()
            logger.info("Toggled favorite status")
        } catch {
            logger.error("Failed to toggle favorite: \(error.localizedDescription)")
        }
    }

    func deleteRecipe(dismiss: DismissAction) {
        logger.info("🗑️ Deleting recipe: \(self.recipeData.recipeName)")

        viewContext.delete(self.recipeData.recipe)

        do {
            try viewContext.save()
            logger.info("✅ Recipe deleted successfully")
            dismiss()
        } catch {
            logger.error("❌ Failed to delete recipe: \(error.localizedDescription)")
        }
    }

    // MARK: - Editing

    func startEditing() {
        editedName = recipeData.recipeName

        // Parse markdown content
        if let content = recipeData.recipe.recipeContent {
            let parsed = parseMarkdownContent(content)
            editedIngredients = parsed.ingredients
            editedInstructions = parsed.instructions
        } else {
            editedIngredients = []
            editedInstructions = []
        }

        editedNotes = recipeData.recipe.notes ?? ""

        isEditing = true
    }

    func saveChanges() {
        recipeData.recipe.name = editedName
        recipeData.recipe.ingredients = editedIngredients.filter { !$0.isEmpty } as NSArray
        recipeData.recipe.instructions = editedInstructions.filter { !$0.isEmpty } as NSArray

        // Rebuild markdown from edited content
        recipeData.recipe.recipeContent = buildMarkdownFromEdited()
        recipeData.recipe.notes = editedNotes

        do {
            try viewContext.save()
            logger.info("✅ Recipe changes saved")
        } catch {
            logger.error("❌ Failed to save changes: \(error.localizedDescription)")
        }

        isEditing = false
    }

    func cancelEditing() {
        isEditing = false
    }

    // MARK: - Private Helpers

    private func parseMarkdownContent(_ markdown: String) -> (ingredients: [String], instructions: [String]) {
        var ingredients: [String] = []
        var instructions: [String] = []
        var currentSection: String?

        let lines = markdown.split(separator: "\n", omittingEmptySubsequences: false)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("## ") {
                currentSection = trimmed.replacingOccurrences(of: "## ", with: "")
                continue
            }

            // Extract item content from both bullet points (- ) and numbered lists (1. 2. etc.)
            var itemContent: String?

            if trimmed.hasPrefix("- ") {
                // Bullet point format: "- item" or "- **Adım 1:** item"
                var content = trimmed.replacingOccurrences(of: "- ", with: "")
                // Strip "**Adım N:**" prefix if present to avoid duplication
                content = content.replacingOccurrences(of: #"^\*\*Adım \d+:\*\*\s*"#, with: "", options: .regularExpression)
                itemContent = content
            } else if let match = trimmed.range(of: #"^\d+\.\s+"#, options: .regularExpression) {
                // Numbered list format: "1. item" or "2. item"
                var content = String(trimmed[match.upperBound...])
                // Strip "**Adım N:**" prefix if present to avoid duplication
                content = content.replacingOccurrences(of: #"^\*\*Adım \d+:\*\*\s*"#, with: "", options: .regularExpression)
                itemContent = content
            }

            // Add to appropriate section if we extracted content
            if let item = itemContent, !item.isEmpty {
                if currentSection?.lowercased().contains("malzeme") == true ||
                   currentSection?.lowercased().contains("ingredients") == true {
                    ingredients.append(item)
                } else if currentSection?.lowercased().contains("talimat") == true ||
                          currentSection?.lowercased().contains("hazırlanış") == true ||
                          currentSection?.lowercased().contains("yapılış") == true ||
                          currentSection?.lowercased().contains("instructions") == true {
                    instructions.append(item)
                }
            }
        }

        return (ingredients, instructions)
    }

    private func buildMarkdownFromEdited() -> String {
        var markdown = ""

        if !editedIngredients.isEmpty {
            markdown += "## Malzemeler\n\n"
            for ingredient in editedIngredients where !ingredient.isEmpty {
                markdown += "- \(ingredient)\n"
            }
            markdown += "\n"
        }

        if !editedInstructions.isEmpty {
            markdown += "## Yapılışı\n\n"
            for (index, instruction) in editedInstructions.enumerated() where !instruction.isEmpty {
                markdown += "\(index + 1). \(instruction)\n"
            }
        }

        return markdown
    }

    // MARK: - Action Handling

    func handleAction(_ action: RecipeAction) {
        logger.info("🎯 [ACTION] handleAction called with: \(String(describing: action))")

        switch action {
        case .favorite:
            logger.info("➡️ [ACTION] Routing to handleFavorite()")
            handleFavorite()
        case .notes:
            logger.info("➡️ [ACTION] Routing to handleNotes()")
            handleNotes()
        case .shopping:
            logger.info("➡️ [ACTION] Routing to handleShopping()")
            handleShopping()
        default:
            logger.warning("⚠️ [ACTION] Unhandled action: \(String(describing: action))")
            break
        }
    }

    private func handleFavorite() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            recipeData.recipe.toggleFavorite()
        }

        do {
            try viewContext.save()
        } catch {
            logger.error("Failed to save favorite status: \(error.localizedDescription)")
        }
    }

    private func handleNotes() {
        logger.info("📝 Opening notes modal")
        showingNotesModal = true
    }

    private func handleShopping() {
        logger.info("🛒 [SHOPPING] handleShopping() called for recipe: '\(self.recipeData.recipeName)'")

        let ingredients = self.recipeData.recipe.ingredientsArray
        logger.info("🛒 [SHOPPING] Found \(ingredients.count) ingredients: \(ingredients)")

        guard !ingredients.isEmpty else {
            logger.warning("⚠️ [SHOPPING] No ingredients found in recipe - aborting")
            toastMessage = .error("Tarifde malzeme bulunamadı")
            return
        }

        let dataManager = RecipeDataManager(context: viewContext)
        logger.info("🛒 [SHOPPING] Starting Task to add ingredients...")

        Task {
            logger.info("🛒 [SHOPPING-TASK] Task started")

            do {
                logger.info("🛒 [SHOPPING-TASK] Calling dataManager.addIngredientsToShoppingList()...")

                _ = try await dataManager.addIngredientsToShoppingList(
                    ingredients: ingredients,
                    sentIngredients: [],
                    recipeName: self.recipeData.recipeName,
                    recipeId: self.recipeData.recipe.id
                )

                logger.info("✅ [SHOPPING-TASK] Successfully added \(ingredients.count) ingredients to shopping list")

                await MainActor.run {
                    logger.info("🛒 [SHOPPING-TASK] Setting success toast message")
                    self.toastMessage = .success("Alışveriş listesine eklendi!")
                }

                logger.info("🛒 [SHOPPING-TASK] Updating shopping list status...")
                await checkShoppingListStatus()
                logger.info("🛒 [SHOPPING-TASK] Complete!")

            } catch {
                logger.error("❌ [SHOPPING-TASK] Failed to add to shopping list: \(error.localizedDescription)")
                await MainActor.run {
                    self.toastMessage = .error("Malzemeler eklenirken hata oluştu")
                }
            }
        }

        logger.info("🛒 [SHOPPING] handleShopping() returning (Task continues in background)")
    }

    // MARK: - Photo Sharing

    func shareRecipePhoto() {
        logger.info("📤 Share photo button tapped")

        // Get the image to share (priority: generated > local > none)
        let imageData = generatedImageData ?? recipeData.recipe.imageData ?? recipeData.imageData

        guard let data = imageData,
              let image = UIImage(data: data) else {
            logger.warning("⚠️ No image available to share")
            toastMessage = .error("Paylaşılacak fotoğraf bulunamadı")
            return
        }

        logger.info("✅ Preparing to share recipe photo")
        imageToShare = image
        showingShareSheet = true
    }

    // MARK: - Photo Generation

    func generatePhoto() async {
        logger.info("🎬 Photo generation started: \(self.recipeData.recipeName)")

        isGeneratingPhoto = true

        do {
            let ingredients = self.recipeData.recipe.ingredientsArray
            let directions = self.recipeData.recipe.instructionsArray

            let photoService = RecipePhotoGenerationService.shared
            let imageURL = try await photoService.generateRecipePhoto(
                recipeName: self.recipeData.recipeName,
                ingredients: ingredients,
                directions: directions,
                mealType: "Genel",
                styleType: "Klasik"
            )

            logger.info("✅ Photo generated successfully")

            if let imageData = extractImageData(from: imageURL) {
                await saveGeneratedImage(imageData)
                toastMessage = .success("Fotoğraf oluşturuldu")
            } else {
                logger.error("❌ Failed to extract image data from URL")
                toastMessage = .error("Fotoğraf oluşturulamadı")
            }

        } catch {
            logger.error("❌ Photo generation failed: \(error.localizedDescription)")
            toastMessage = .error("Fotoğraf oluşturulamadı: \(error.localizedDescription)")
        }

        isGeneratingPhoto = false
    }

    private func extractImageData(from imageURL: String) -> Data? {
        guard imageURL.hasPrefix("data:image") else {
            logger.warning("⚠️ Image URL is not a data URL")
            return nil
        }

        let components = imageURL.components(separatedBy: ",")
        guard components.count == 2, let base64String = components.last else {
            logger.error("❌ Failed to extract base64 from image URL")
            return nil
        }

        return Data(base64Encoded: base64String)
    }

    private func saveGeneratedImage(_ imageData: Data) async {
        generatedImageData = imageData
        recipeData.recipe.imageData = imageData

        do {
            try viewContext.save()
            logger.info("✅ Generated image saved to Core Data")
        } catch {
            logger.error("❌ Failed to save generated image: \(error.localizedDescription)")
        }
    }

    // MARK: - Story Card

    var hasNutritionData: Bool {
        recipeData.recipe.calories > 0 &&
        recipeData.recipe.totalCarbs > 0 &&
        recipeData.recipe.protein > 0
    }

    func handleStoryCardTap() {
        logger.info("🔍 Story card tapped")

        let hasNutrition = recipeData.recipe.calories > 0 &&
                          recipeData.recipe.totalCarbs > 0 &&
                          recipeData.recipe.protein > 0

        if hasNutrition {
            logger.info("✅ Nutrition data exists, showing modal")
            showingNutritionalValues = true
        } else {
            logger.info("🔄 Starting nutrition calculation")
            Task {
                await calculateNutritionValues()
            }
        }
    }

    // MARK: - Nutrition Calculation

    func startLoadingAnimation() {
        Task {
            for step in loadingSteps {
                // Set text and start progress immediately
                await MainActor.run {
                    currentLoadingStep = step.label
                    nutritionCalculationProgress = step.startProgress
                }

                // Animate progress smoothly over the step duration
                let progressRange = step.endProgress - step.startProgress
                let updateInterval: TimeInterval = 0.1 // Update every 100ms
                let totalUpdates = Int(step.duration / updateInterval)

                for i in 1...totalUpdates {
                    try? await Task.sleep(for: .seconds(updateInterval))
                    guard !Task.isCancelled else { break }

                    let progressIncrement = Double(progressRange) * (Double(i) / Double(totalUpdates))
                    let currentProgress = step.startProgress + Int(progressIncrement)

                    await MainActor.run {
                        withAnimation(.linear(duration: updateInterval)) {
                            nutritionCalculationProgress = currentProgress
                        }
                    }
                }

                guard !Task.isCancelled else { break }
            }
        }
    }

    func calculateNutritionValues() async {
        guard let recipeContent = self.recipeData.recipe.recipeContent,
              !self.recipeData.recipeName.isEmpty else {
            logger.error("❌ Cannot calculate nutrition - missing recipe content or name")
            return
        }

        isCalculatingNutrition = true
        nutritionCalculationProgress = 0

        // Start loading animation
        startLoadingAnimation()

        do {
            logger.info("📊 Starting nutrition calculation for: \(self.recipeData.recipeName)")

            let result = try await nutritionRepository.calculateNutrition(
                recipeName: self.recipeData.recipeName,
                recipeContent: recipeContent,
                servings: 1
            )

            // Save to Core Data
            recipeData.recipe.calories = result.calories
            recipeData.recipe.totalCarbs = result.carbohydrates
            recipeData.recipe.fiber = result.fiber
            recipeData.recipe.sugars = result.sugar
            recipeData.recipe.protein = result.protein
            recipeData.recipe.totalFat = result.fat
            recipeData.recipe.glycemicLoad = result.glycemicLoad

            recipeData.recipe.caloriesPerServing = result.caloriesPerServing
            recipeData.recipe.carbsPerServing = result.carbohydratesPerServing
            recipeData.recipe.fiberPerServing = result.fiberPerServing
            recipeData.recipe.sugarsPerServing = result.sugarPerServing
            recipeData.recipe.proteinPerServing = result.proteinPerServing
            recipeData.recipe.fatPerServing = result.fatPerServing
            recipeData.recipe.glycemicLoadPerServing = result.glycemicLoadPerServing
            recipeData.recipe.totalRecipeWeight = result.totalRecipeWeight

            digestionTimingInsights = result.digestionTiming

            try viewContext.save()

            logger.info("✅ Nutrition calculation complete")

        } catch let error as RecipeNutritionError {
            logger.error("❌ Nutrition calculation failed: \(error.localizedDescription)")

            // Show specific error with recovery suggestion
            let errorMessage = error.errorDescription ?? "Besin değerleri hesaplanamadı"
            let recoverySuggestion = error.recoverySuggestion ?? ""
            let fullMessage = recoverySuggestion.isEmpty ? errorMessage : "\(errorMessage)\n\n\(recoverySuggestion)"

            toastMessage = .error(fullMessage)

        } catch {
            logger.error("❌ Nutrition calculation failed: \(error.localizedDescription)")
            toastMessage = .error("Besin değerleri hesaplanamadı: \(error.localizedDescription)")
        }

        isCalculatingNutrition = false
        nutritionCalculationProgress = 0
        currentLoadingStep = nil
    }

    // MARK: - Notes

    func saveUserNotes(_ notes: String) {
        recipeData.recipe.notes = notes

        do {
            try viewContext.save()
            logger.info("✅ User notes saved")
        } catch {
            logger.error("❌ Failed to save notes: \(error.localizedDescription)")
        }
    }

    // MARK: - Portion Management

    func savePortionMultiplier() {
        do {
            try viewContext.save()
            logger.info("✅ Portion multiplier saved")
        } catch {
            logger.error("❌ Failed to save portion multiplier: \(error.localizedDescription)")
        }
    }
}
