//
//  RecipeFirestoreService.swift
//  balli
//
//  Service for syncing Recipe data with Firestore
//  Handles upload, download, and bidirectional sync for recipes with photos and nutrition
//  Swift 6 strict concurrency compliant
//

import Foundation
import FirebaseFirestore
import FirebaseStorage
import CoreData
import OSLog
import UIKit

/// Service for syncing recipe entries with Firestore
@MainActor
final class RecipeFirestoreService: ObservableObject {

    // MARK: - Published State

    @Published var syncStatus: SyncStatus = .idle
    @Published var lastSyncTime: Date?
    @Published var syncError: Error?

    // MARK: - Sync Status

    enum SyncStatus {
        case idle
        case syncing
        case success
        case error(String)
    }

    // MARK: - Properties

    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    private let userSession: UserSession
    private let persistenceController: Persistence.PersistenceController
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.balli", category: "RecipeSync")

    // MARK: - Initialization

    init(
        userSession: UserSession = .shared,
        persistenceController: Persistence.PersistenceController = .shared
    ) {
        self.userSession = userSession
        self.persistenceController = persistenceController
    }

    // MARK: - Upload Operations

    /// Upload a single recipe to Firestore
    /// - Parameters:
    ///   - recipeData: Thread-safe snapshot of recipe data
    ///   - recipeObjectID: NSManagedObjectID for status updates
    func uploadRecipe(_ recipeData: RecipeData, recipeObjectID: NSManagedObjectID) async throws {
        let userId = userSession.firestoreUserId
        logger.info("Uploading recipe \(recipeData.id) for user \(userId)")

        do {
            // NOTE: Recipe photos are now stored only in CoreData, not uploaded to Firebase Storage
            // Only sync recipe metadata to Firestore

            // Create Firestore document (without photo URL)
            let firestoreDoc = createFirestoreDocument(from: recipeData, photoURL: nil)

            try await db
                .collection("users")
                .document(userId)
                .collection("recipes")
                .document(recipeData.id.uuidString)
                .setData(firestoreDoc, merge: true)

            logger.info("✅ Successfully uploaded recipe \(recipeData.id)")
        } catch {
            logger.error("❌ Failed to upload recipe: \(error.localizedDescription)")
            throw error
        }
    }

    /// Upload multiple recipes in batch
    /// - Parameter recipeDataArray: Array of (RecipeData, NSManagedObjectID) tuples
    /// - Returns: Count of successfully uploaded recipes
    func uploadRecipes(_ recipeDataArray: [(data: RecipeData, objectID: NSManagedObjectID)]) async throws -> Int {
        logger.info("Batch uploading \(recipeDataArray.count) recipes")

        var successCount = 0

        for (recipeData, _) in recipeDataArray {
            do {
                try await uploadRecipe(recipeData, recipeObjectID: recipeData.objectID)
                successCount += 1
            } catch {
                logger.error("Failed to upload recipe \(recipeData.id): \(error.localizedDescription)")
                // Continue with remaining recipes
            }
        }

        logger.info("✅ Batch upload complete: \(successCount)/\(recipeDataArray.count) successful")
        return successCount
    }

    // MARK: - Download Operations

    /// Download recipes from Firestore for the current user
    /// - Parameters:
    ///   - since: Optional date to fetch only recipes modified after this date
    ///   - limit: Maximum number of recipes to fetch (default: 100)
    /// - Returns: Array of Firestore recipe documents
    func downloadRecipes(since: Date? = nil, limit: Int = 100) async throws -> [FirestoreRecipe] {
        let userId = userSession.firestoreUserId
        logger.info("Downloading recipes for user \(userId)")

        var query: Query = db
            .collection("users")
            .document(userId)
            .collection("recipes")
            .order(by: "lastModified", descending: true)
            .limit(to: limit)

        // Add timestamp filter if provided
        if let sinceDate = since {
            query = query.whereField("lastModified", isGreaterThan: Timestamp(date: sinceDate))
        }

        let snapshot = try await query.getDocuments()
        logger.info("Fetched \(snapshot.documents.count) recipes from Firestore")

        return try snapshot.documents.compactMap { document in
            try document.data(as: FirestoreRecipe.self)
        }
    }

    /// Sync downloaded recipes to CoreData
    /// - Parameter firestoreRecipes: Array of FirestoreRecipe objects from Firestore
    /// - Returns: Count of recipes synced to CoreData
    func syncToCoreData(_ firestoreRecipes: [FirestoreRecipe]) async throws -> Int {
        logger.info("Syncing \(firestoreRecipes.count) recipes to CoreData")

        var syncedCount = 0

        for firestoreRecipe in firestoreRecipes {
            do {
                try await upsertRecipeToCoreData(firestoreRecipe)
                syncedCount += 1
            } catch {
                logger.error("Failed to sync recipe \(firestoreRecipe.id): \(error.localizedDescription)")
            }
        }

        logger.info("✅ Synced \(syncedCount)/\(firestoreRecipes.count) recipes to CoreData")
        return syncedCount
    }

    // MARK: - Delete Operations

    /// Delete a recipe from both CoreData and Firestore
    /// - Parameter recipeId: UUID of the recipe to delete
    func deleteRecipe(id recipeId: UUID) async throws {
        let userId = userSession.firestoreUserId
        logger.info("Deleting recipe \(recipeId) from Firestore and CoreData")

        // NOTE: Photos are stored only in CoreData, so no Firebase Storage deletion needed

        // Delete from Firestore
        try await db
            .collection("users")
            .document(userId)
            .collection("recipes")
            .document(recipeId.uuidString)
            .delete()

        // Delete from CoreData (this also deletes the photo from imageData)
        try await persistenceController.performBackgroundTask { context in
            let request = Recipe.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", recipeId as CVarArg)

            if let recipe = try context.fetch(request).first {
                context.delete(recipe)
                try context.save()
            }
        }

        logger.info("✅ Successfully deleted recipe \(recipeId)")
    }

    // MARK: - Bidirectional Sync

    /// Perform bidirectional sync: upload pending CoreData changes, then download Firestore updates
    func performBidirectionalSync() async throws {
        syncStatus = .syncing
        syncError = nil

        logger.info("🔄 Starting bidirectional recipe sync")

        do {
            // Step 1: Upload pending local changes
            let pendingRecipes = try await fetchPendingRecipes()
            if !pendingRecipes.isEmpty {
                logger.info("Uploading \(pendingRecipes.count) pending recipes")
                _ = try await uploadRecipes(pendingRecipes)
            }

            // Step 2: Download updates from Firestore
            // Use Unix epoch (1970) instead of Date.distantPast (0001) - Firestore doesn't support dates before 1970
            let lastSync = lastSyncTime ?? Date(timeIntervalSince1970: 0)
            let firestoreRecipes = try await downloadRecipes(since: lastSync)

            if !firestoreRecipes.isEmpty {
                logger.info("Syncing \(firestoreRecipes.count) recipes from Firestore")
                _ = try await syncToCoreData(firestoreRecipes)
            }

            // Update sync time and status
            lastSyncTime = Date()
            syncStatus = .success

            logger.info("✅ Bidirectional recipe sync complete")

        } catch {
            logger.error("❌ Recipe sync failed: \(error.localizedDescription)")
            syncStatus = .error(error.localizedDescription)
            syncError = error
            throw error
        }
    }

    // MARK: - Private Helpers - Photo Management

    /// Upload recipe photo to Firebase Storage
    nonisolated private func uploadRecipePhoto(recipeId: UUID, imageData: Data, userId: String) async throws -> String {
        let storage = Storage.storage()
        let storageRef = storage.reference()
        let photoPath = "users/\(userId)/recipes/\(recipeId.uuidString)/photo.jpg"
        let photoRef = storageRef.child(photoPath)

        // Upload with metadata
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        _ = try await photoRef.putDataAsync(imageData, metadata: metadata)

        // Get download URL
        let downloadURL = try await photoRef.downloadURL()

        return downloadURL.absoluteString
    }

    /// Delete recipe photo from Firebase Storage
    nonisolated private func deleteRecipePhoto(recipeId: UUID, userId: String) async throws {
        let storage = Storage.storage()
        let storageRef = storage.reference()
        let photoPath = "users/\(userId)/recipes/\(recipeId.uuidString)/photo.jpg"
        let photoRef = storageRef.child(photoPath)

        do {
            try await photoRef.delete()
        } catch {
            // Photo might not exist, which is fine - silently ignore
        }
    }

    // MARK: - Private Helpers - Document Conversion

    /// Create Firestore document from thread-safe RecipeData
    private func createFirestoreDocument(from recipeData: RecipeData, photoURL: String?) -> [String: Any] {
        var data: [String: Any] = [
            "id": recipeData.id.uuidString,
            "name": recipeData.name,
            "dateCreated": Timestamp(date: recipeData.dateCreated),
            "lastModified": Timestamp(date: recipeData.lastModified),
            "source": recipeData.source,

            // Recipe content
            "prepTime": recipeData.prepTime,
            "cookTime": recipeData.cookTime,
            "servings": recipeData.servings,

            // Nutrition per 100g
            "calories": recipeData.calories,
            "totalCarbs": recipeData.totalCarbs,
            "fiber": recipeData.fiber,
            "sugars": recipeData.sugars,
            "protein": recipeData.protein,
            "totalFat": recipeData.totalFat,
            "glycemicLoad": recipeData.glycemicLoad,

            // Nutrition per serving
            "caloriesPerServing": recipeData.caloriesPerServing,
            "carbsPerServing": recipeData.carbsPerServing,
            "fiberPerServing": recipeData.fiberPerServing,
            "sugarsPerServing": recipeData.sugarsPerServing,
            "proteinPerServing": recipeData.proteinPerServing,
            "fatPerServing": recipeData.fatPerServing,
            "glycemicLoadPerServing": recipeData.glycemicLoadPerServing,
            "totalRecipeWeight": recipeData.totalRecipeWeight,

            // Metadata
            "isVerified": recipeData.isVerified,
            "isFavorite": recipeData.isFavorite,
            "timesCooked": recipeData.timesCooked,
            "userRating": recipeData.userRating
        ]

        // Optional fields
        if let mealType = recipeData.mealType {
            data["mealType"] = mealType
        }
        if let styleType = recipeData.styleType {
            data["styleType"] = styleType
        }
        if let notes = recipeData.notes {
            data["notes"] = notes
        }
        if let recipeContent = recipeData.recipeContent {
            data["recipeContent"] = recipeContent
        }
        if let paperColor = recipeData.paperColor {
            data["paperColor"] = paperColor
        }
        if let photoURL = photoURL {
            data["imageURL"] = photoURL
        }
        if let ingredients = recipeData.ingredients {
            data["ingredients"] = ingredients
        }
        if let instructions = recipeData.instructions {
            data["instructions"] = instructions
        }

        return data
    }

    /// Upsert a Firestore recipe into CoreData
    private func upsertRecipeToCoreData(_ firestoreRecipe: FirestoreRecipe) async throws {
        try await persistenceController.performBackgroundTask { context in
            // Check if recipe already exists
            let request = Recipe.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", firestoreRecipe.id as CVarArg)

            let existingRecipe = try context.fetch(request).first

            if let existing = existingRecipe {
                // Update existing recipe if Firestore version is newer
                if firestoreRecipe.lastModified > existing.lastModified {
                    self.updateRecipeEntry(existing, with: firestoreRecipe, in: context)
                    self.logger.debug("Updated existing recipe \(firestoreRecipe.id)")
                } else {
                    self.logger.debug("Skipped recipe \(firestoreRecipe.id) - local version is newer")
                }
            } else {
                // Create new recipe entry
                let newRecipe = Recipe(context: context)
                self.updateRecipeEntry(newRecipe, with: firestoreRecipe, in: context)
                self.logger.debug("Created new recipe \(firestoreRecipe.id)")
            }

            try context.save()
        }
    }

    /// Update Recipe with data from FirestoreRecipe
    nonisolated private func updateRecipeEntry(_ recipe: Recipe, with firestoreRecipe: FirestoreRecipe, in context: NSManagedObjectContext) {
        recipe.id = firestoreRecipe.id
        recipe.name = firestoreRecipe.name
        recipe.dateCreated = firestoreRecipe.dateCreated
        recipe.lastModified = firestoreRecipe.lastModified
        recipe.source = firestoreRecipe.source

        // Recipe content
        recipe.prepTime = firestoreRecipe.prepTime
        recipe.cookTime = firestoreRecipe.cookTime
        recipe.servings = firestoreRecipe.servings

        // Nutrition per 100g
        recipe.calories = firestoreRecipe.calories
        recipe.totalCarbs = firestoreRecipe.totalCarbs
        recipe.fiber = firestoreRecipe.fiber
        recipe.sugars = firestoreRecipe.sugars
        recipe.protein = firestoreRecipe.protein
        recipe.totalFat = firestoreRecipe.totalFat
        recipe.glycemicLoad = firestoreRecipe.glycemicLoad

        // Nutrition per serving
        recipe.caloriesPerServing = firestoreRecipe.caloriesPerServing
        recipe.carbsPerServing = firestoreRecipe.carbsPerServing
        recipe.fiberPerServing = firestoreRecipe.fiberPerServing
        recipe.sugarsPerServing = firestoreRecipe.sugarsPerServing
        recipe.proteinPerServing = firestoreRecipe.proteinPerServing
        recipe.fatPerServing = firestoreRecipe.fatPerServing
        recipe.glycemicLoadPerServing = firestoreRecipe.glycemicLoadPerServing
        recipe.totalRecipeWeight = firestoreRecipe.totalRecipeWeight

        // Metadata
        recipe.mealType = firestoreRecipe.mealType
        recipe.styleType = firestoreRecipe.styleType
        recipe.isVerified = firestoreRecipe.isVerified
        recipe.isFavorite = firestoreRecipe.isFavorite
        recipe.timesCooked = firestoreRecipe.timesCooked
        recipe.userRating = firestoreRecipe.userRating
        recipe.notes = firestoreRecipe.notes
        recipe.recipeContent = firestoreRecipe.recipeContent
        recipe.imageURL = firestoreRecipe.imageURL
        recipe.paperColor = firestoreRecipe.paperColor
        recipe.ingredients = firestoreRecipe.ingredients as? NSObject
        recipe.instructions = firestoreRecipe.instructions as? NSObject
    }

    /// Fetch recipes with pending sync status from CoreData
    /// Returns thread-safe snapshots for cross-context transfer
    private func fetchPendingRecipes() async throws -> [(data: RecipeData, objectID: NSManagedObjectID)] {
        try await persistenceController.performBackgroundTask { context in
            let request = Recipe.fetchRequest()
            // Fetch all recipes - we'll sync them all for now
            let recipes = try context.fetch(request)

            // Extract data within the correct context
            return recipes.map { recipe in
                (data: RecipeData(from: recipe), objectID: recipe.objectID)
            }
        }
    }
}

// MARK: - Recipe Data Models

/// Thread-safe snapshot of Recipe data for cross-context transfer
struct RecipeData: Sendable {
    let id: UUID
    let name: String
    let dateCreated: Date
    let lastModified: Date
    let source: String

    // Recipe content
    let ingredients: [String]?
    let instructions: [String]?
    let prepTime: Int16
    let cookTime: Int16
    let servings: Int16

    // Nutrition per 100g
    let calories: Double
    let totalCarbs: Double
    let fiber: Double
    let sugars: Double
    let protein: Double
    let totalFat: Double
    let glycemicLoad: Double

    // Nutrition per serving
    let caloriesPerServing: Double
    let carbsPerServing: Double
    let fiberPerServing: Double
    let sugarsPerServing: Double
    let proteinPerServing: Double
    let fatPerServing: Double
    let glycemicLoadPerServing: Double
    let totalRecipeWeight: Double

    // Metadata
    let mealType: String?
    let styleType: String?
    let isVerified: Bool
    let isFavorite: Bool
    let timesCooked: Int32
    let userRating: Int16
    let notes: String?
    let recipeContent: String?
    let imageURL: String?
    let imageData: Data?
    let paperColor: String?
    let objectID: NSManagedObjectID

    /// Create RecipeData snapshot from CoreData Recipe
    init(from recipe: Recipe) {
        self.id = recipe.id
        self.name = recipe.name
        self.dateCreated = recipe.dateCreated
        self.lastModified = recipe.lastModified
        self.source = recipe.source

        // Convert NSObject arrays to String arrays
        self.ingredients = (recipe.ingredients as? [String])
        self.instructions = (recipe.instructions as? [String])

        self.prepTime = recipe.prepTime
        self.cookTime = recipe.cookTime
        self.servings = recipe.servings

        self.calories = recipe.calories
        self.totalCarbs = recipe.totalCarbs
        self.fiber = recipe.fiber
        self.sugars = recipe.sugars
        self.protein = recipe.protein
        self.totalFat = recipe.totalFat
        self.glycemicLoad = recipe.glycemicLoad

        self.caloriesPerServing = recipe.caloriesPerServing
        self.carbsPerServing = recipe.carbsPerServing
        self.fiberPerServing = recipe.fiberPerServing
        self.sugarsPerServing = recipe.sugarsPerServing
        self.proteinPerServing = recipe.proteinPerServing
        self.fatPerServing = recipe.fatPerServing
        self.glycemicLoadPerServing = recipe.glycemicLoadPerServing
        self.totalRecipeWeight = recipe.totalRecipeWeight

        self.mealType = recipe.mealType
        self.styleType = recipe.styleType
        self.isVerified = recipe.isVerified
        self.isFavorite = recipe.isFavorite
        self.timesCooked = recipe.timesCooked
        self.userRating = recipe.userRating
        self.notes = recipe.notes
        self.recipeContent = recipe.recipeContent
        self.imageURL = recipe.imageURL
        self.imageData = recipe.imageData
        self.paperColor = recipe.paperColor
        self.objectID = recipe.objectID
    }
}

/// Codable model representing a recipe document in Firestore
struct FirestoreRecipe: Codable, Sendable {
    let id: UUID
    let name: String
    let dateCreated: Date
    let lastModified: Date
    let source: String

    let ingredients: [String]?
    let instructions: [String]?
    let prepTime: Int16
    let cookTime: Int16
    let servings: Int16

    let calories: Double
    let totalCarbs: Double
    let fiber: Double
    let sugars: Double
    let protein: Double
    let totalFat: Double
    let glycemicLoad: Double

    let caloriesPerServing: Double
    let carbsPerServing: Double
    let fiberPerServing: Double
    let sugarsPerServing: Double
    let proteinPerServing: Double
    let fatPerServing: Double
    let glycemicLoadPerServing: Double
    let totalRecipeWeight: Double

    let mealType: String?
    let styleType: String?
    let isVerified: Bool
    let isFavorite: Bool
    let timesCooked: Int32
    let userRating: Int16
    let notes: String?
    let recipeContent: String?
    let imageURL: String?
    let paperColor: String?

    enum CodingKeys: String, CodingKey {
        case id, name, dateCreated, lastModified, source
        case ingredients, instructions, prepTime, cookTime, servings
        case calories, totalCarbs, fiber, sugars, protein, totalFat, glycemicLoad
        case caloriesPerServing, carbsPerServing, fiberPerServing, sugarsPerServing
        case proteinPerServing, fatPerServing, glycemicLoadPerServing, totalRecipeWeight
        case mealType, styleType, isVerified, isFavorite, timesCooked, userRating
        case notes, recipeContent, imageURL, paperColor
    }
}

// MARK: - Firestore Timestamp Decoding

extension FirestoreRecipe {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Decode UUID from string
        let idString = try container.decode(String.self, forKey: .id)
        guard let uuid = UUID(uuidString: idString) else {
            throw DecodingError.dataCorruptedError(
                forKey: .id,
                in: container,
                debugDescription: "Invalid UUID string"
            )
        }
        self.id = uuid

        // Decode Firestore Timestamp as Date
        self.dateCreated = try container.decode(Timestamp.self, forKey: .dateCreated).dateValue()
        self.lastModified = try container.decode(Timestamp.self, forKey: .lastModified).dateValue()

        // Decode remaining fields
        self.name = try container.decode(String.self, forKey: .name)
        self.source = try container.decode(String.self, forKey: .source)

        self.ingredients = try container.decodeIfPresent([String].self, forKey: .ingredients)
        self.instructions = try container.decodeIfPresent([String].self, forKey: .instructions)
        self.prepTime = try container.decode(Int16.self, forKey: .prepTime)
        self.cookTime = try container.decode(Int16.self, forKey: .cookTime)
        self.servings = try container.decode(Int16.self, forKey: .servings)

        self.calories = try container.decode(Double.self, forKey: .calories)
        self.totalCarbs = try container.decode(Double.self, forKey: .totalCarbs)
        self.fiber = try container.decode(Double.self, forKey: .fiber)
        self.sugars = try container.decode(Double.self, forKey: .sugars)
        self.protein = try container.decode(Double.self, forKey: .protein)
        self.totalFat = try container.decode(Double.self, forKey: .totalFat)
        self.glycemicLoad = try container.decode(Double.self, forKey: .glycemicLoad)

        self.caloriesPerServing = try container.decode(Double.self, forKey: .caloriesPerServing)
        self.carbsPerServing = try container.decode(Double.self, forKey: .carbsPerServing)
        self.fiberPerServing = try container.decode(Double.self, forKey: .fiberPerServing)
        self.sugarsPerServing = try container.decode(Double.self, forKey: .sugarsPerServing)
        self.proteinPerServing = try container.decode(Double.self, forKey: .proteinPerServing)
        self.fatPerServing = try container.decode(Double.self, forKey: .fatPerServing)
        self.glycemicLoadPerServing = try container.decode(Double.self, forKey: .glycemicLoadPerServing)
        self.totalRecipeWeight = try container.decode(Double.self, forKey: .totalRecipeWeight)

        self.mealType = try container.decodeIfPresent(String.self, forKey: .mealType)
        self.styleType = try container.decodeIfPresent(String.self, forKey: .styleType)
        self.isVerified = try container.decode(Bool.self, forKey: .isVerified)
        self.isFavorite = try container.decode(Bool.self, forKey: .isFavorite)
        self.timesCooked = try container.decode(Int32.self, forKey: .timesCooked)
        self.userRating = try container.decode(Int16.self, forKey: .userRating)
        self.notes = try container.decodeIfPresent(String.self, forKey: .notes)
        self.recipeContent = try container.decodeIfPresent(String.self, forKey: .recipeContent)
        self.imageURL = try container.decodeIfPresent(String.self, forKey: .imageURL)
        self.paperColor = try container.decodeIfPresent(String.self, forKey: .paperColor)
    }
}
