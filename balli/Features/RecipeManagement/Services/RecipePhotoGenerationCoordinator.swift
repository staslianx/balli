//
//  RecipePhotoGenerationCoordinator.swift
//  balli
//
//  Coordinates AI photo generation for recipes
//  Handles photo generation state and error management
//  Swift 6 strict concurrency compliant
//

import Foundation

/// Coordinates recipe photo generation with AI
@MainActor
public final class RecipePhotoGenerationCoordinator: ObservableObject {
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
        guard formState.hasRecipeData else {
            photoGenerationError = "Recipe data is incomplete. Please fill in recipe name, ingredients, and directions."
            return
        }

        isGeneratingPhoto = true
        photoGenerationError = nil
        generatedPhotoURL = nil

        do {
            // RecipePhotoGenerationService is an actor, so this automatically
            // executes on a background thread. Network calls take 5-30 seconds.
            let photoService = RecipePhotoGenerationService.shared
            let imageURL = try await photoService.generateRecipePhoto(
                recipeName: formState.recipeName,
                ingredients: formState.ingredients.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty },
                directions: formState.directions.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty },
                mealType: "Genel", // Could be enhanced to pass actual meal type
                styleType: "Klasik"
            )

            // Back on MainActor for UI updates
            generatedPhotoURL = imageURL
            isGeneratingPhoto = false

            // ✨ Trigger background upload to Firebase Storage
            if imageURL.hasPrefix("data:") {
                Task.detached(priority: .background) {
                    do {
                        let storageURL = try await RecipePhotoUploadService.shared.uploadBase64Image(
                            base64String: imageURL,
                            recipeName: await self.formState.recipeName,
                            userId: "serhat@balli.com" // TODO: Get from AuthService
                        )

                        // Update URL to storage URL after upload completes
                        await MainActor.run {
                            self.generatedPhotoURL = storageURL
                        }
                    } catch {
                        // Upload failed, but keep base64 URL for display
                        let logger = AppLoggers.Recipe.generation
                        logger.error("❌ Background upload failed: \(error.localizedDescription)")
                        // Don't update UI with error - base64 display still works
                    }
                }
            }

        } catch {
            // Error handling on MainActor
            photoGenerationError = error.localizedDescription
            isGeneratingPhoto = false
            ErrorHandler.shared.handle(error)
        }
    }

    // MARK: - Reset

    /// Clear photo generation state
    public func reset() {
        isGeneratingPhoto = false
        generatedPhotoURL = nil
        photoGenerationError = nil
    }
}
