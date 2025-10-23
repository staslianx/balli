//
//  RecipePhotoGenerationCoordinator.swift
//  balli
//
//  Coordinates AI photo generation for recipes
//  Handles photo generation state and error management
//  Swift 6 strict concurrency compliant
//

import Foundation
import OSLog

/// Coordinates recipe photo generation with AI
@MainActor
public final class RecipePhotoGenerationCoordinator: ObservableObject {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.balli", category: "PhotoGeneration")
    // MARK: - Photo Generation State
    @Published public var isGeneratingPhoto = false
    @Published public var generatedPhotoURL: String?
    @Published public var photoGenerationError: String?

    private let formState: RecipeFormState

    public init(formState: RecipeFormState) {
        self.formState = formState
    }

    // MARK: - Photo Generation

    /// Generate AI photo for the current recipe
    /// PERFORMANCE: Photo generation happens in actor (background thread)
    /// Only UI updates occur on MainActor
    public func generatePhoto() async {
        logger.info("🎬 [PHOTO-GEN] generatePhoto() called - starting photo generation")

        logger.debug("📋 [PHOTO-GEN] Recipe data check:")
        logger.debug("  - recipeName: '\(self.formState.recipeName)'")
        logger.debug("  - ingredients count: \(self.formState.ingredients.count)")
        logger.debug("  - directions count: \(self.formState.directions.count)")
        logger.debug("  - hasRecipeData: \(self.formState.hasRecipeData)")

        guard formState.hasRecipeData else {
            logger.error("❌ [PHOTO-GEN] Recipe data is incomplete - aborting")
            photoGenerationError = "Recipe data is incomplete. Please fill in recipe name, ingredients, and directions."
            return
        }

        logger.info("✅ [PHOTO-GEN] Recipe data valid - proceeding with generation")
        isGeneratingPhoto = true
        photoGenerationError = nil
        generatedPhotoURL = nil

        do {
            logger.info("🌐 [PHOTO-GEN] Calling RecipePhotoGenerationService.generateRecipePhoto()")

            // Extract ingredients and directions from arrays or provide recipe name as fallback
            let ingredients = formState.ingredients.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            let directions = formState.directions.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

            // For markdown recipes with empty arrays, use recipe name as context
            let finalIngredients = ingredients.isEmpty ? [formState.recipeName] : ingredients
            let finalDirections = directions.isEmpty ? ["Prepare \(formState.recipeName)"] : directions

            logger.debug("📋 [PHOTO-GEN] Sending to service:")
            logger.debug("  - ingredients: \(finalIngredients.count) items")
            logger.debug("  - directions: \(finalDirections.count) items")

            // RecipePhotoGenerationService is an actor, so this automatically
            // executes on a background thread. Network calls take 5-30 seconds.
            let photoService = RecipePhotoGenerationService.shared
            let imageURL = try await photoService.generateRecipePhoto(
                recipeName: formState.recipeName,
                ingredients: finalIngredients,
                directions: finalDirections,
                mealType: "Genel", // Could be enhanced to pass actual meal type
                styleType: "Klasik"
            )

            logger.info("✅ [PHOTO-GEN] Received imageURL from service")
            logger.debug("🔍 [PHOTO-GEN] imageURL prefix: \(imageURL.prefix(50))...")
            logger.debug("🔍 [PHOTO-GEN] imageURL length: \(imageURL.count) characters")
            logger.debug("🔍 [PHOTO-GEN] Is data URL: \(imageURL.hasPrefix("data:"))")

            // Back on MainActor for UI updates
            generatedPhotoURL = imageURL
            isGeneratingPhoto = false

            logger.info("✅ [PHOTO-GEN] Updated generatedPhotoURL and set isGeneratingPhoto = false")

            // ✨ Trigger background upload to Firebase Storage
            if imageURL.hasPrefix("data:") {
                logger.info("📤 [PHOTO-GEN] Starting background upload to Firebase Storage")
                Task.detached(priority: .background) {
                    do {
                        let storageURL = try await RecipePhotoUploadService.shared.uploadBase64Image(
                            base64String: imageURL,
                            recipeName: await self.formState.recipeName,
                            userId: "serhat@balli.com" // TODO: Get from AuthService
                        )

                        // Update URL to storage URL after upload completes
                        await MainActor.run {
                            self.logger.info("✅ [PHOTO-GEN] Background upload completed - updating to storage URL")
                            self.generatedPhotoURL = storageURL
                        }
                    } catch {
                        // Upload failed, but keep base64 URL for display
                        let logger = AppLoggers.Recipe.generation
                        logger.error("❌ [PHOTO-GEN] Background upload failed: \(error.localizedDescription)")
                        // Don't update UI with error - base64 display still works
                    }
                }
            } else {
                logger.warning("⚠️ [PHOTO-GEN] imageURL is NOT a data URL - skipping background upload")
            }

        } catch {
            // Error handling on MainActor
            logger.error("❌ [PHOTO-GEN] Photo generation failed: \(error.localizedDescription)")
            photoGenerationError = error.localizedDescription
            isGeneratingPhoto = false
            ErrorHandler.shared.handle(error)
        }

        logger.info("🏁 [PHOTO-GEN] generatePhoto() completed")
    }

    // MARK: - Reset

    /// Clear photo generation state
    public func reset() {
        isGeneratingPhoto = false
        generatedPhotoURL = nil
        photoGenerationError = nil
    }
}
