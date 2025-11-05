//
//  MealFirestoreService.swift
//  balli
//
//  Service for syncing MealEntry data with Firestore
//  Handles upload, download, and bidirectional sync
//  Swift 6 strict concurrency compliant
//

import Foundation
import FirebaseFirestore
import CoreData
import OSLog

/// Service for syncing meal entries with Firestore
@MainActor
final class MealFirestoreService: ObservableObject {

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
    private let userSession: UserSession
    private let persistenceController: Persistence.PersistenceController
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.balli", category: "MealSync")

    // MARK: - Initialization

    init(
        userSession: UserSession = .shared,
        persistenceController: Persistence.PersistenceController = .shared
    ) {
        self.userSession = userSession
        self.persistenceController = persistenceController
    }

    // MARK: - Upload Operations

    /// Upload a single meal entry to Firestore
    /// - Parameters:
    ///   - mealData: Thread-safe snapshot of meal data
    ///   - mealObjectID: NSManagedObjectID for status updates
    func uploadMeal(_ mealData: MealData, mealObjectID: NSManagedObjectID) async throws {
        let userId = userSession.firestoreUserId
        logger.info("Uploading meal \(mealData.id) for user \(userId)")

        do {
            let firestoreDoc = createFirestoreDocument(from: mealData)

            try await db
                .collection("users")
                .document(userId)
                .collection("meals")
                .document(mealData.id.uuidString)
                .setData(firestoreDoc, merge: true)

            // Update sync status in CoreData
            await updateMealSyncStatus(mealObjectID: mealObjectID, status: "synced")

            logger.info("✅ Successfully uploaded meal \(mealData.id)")
        } catch {
            logger.error("❌ Failed to upload meal: \(error.localizedDescription)")
            await updateMealSyncStatus(mealObjectID: mealObjectID, status: "error")
            throw error
        }
    }

    /// Upload multiple meal entries in batch
    /// - Parameter mealDataArray: Array of (MealData, NSManagedObjectID) tuples
    /// - Returns: Count of successfully uploaded meals
    func uploadMeals(_ mealDataArray: [(data: MealData, objectID: NSManagedObjectID)]) async throws -> Int {
        logger.info("Batch uploading \(mealDataArray.count) meals")

        var successCount = 0

        for (mealData, objectID) in mealDataArray {
            do {
                try await uploadMeal(mealData, mealObjectID: objectID)
                successCount += 1
            } catch {
                logger.error("Failed to upload meal \(mealData.id): \(error.localizedDescription)")
                // Continue with remaining meals
            }
        }

        logger.info("✅ Batch upload complete: \(successCount)/\(mealDataArray.count) successful")
        return successCount
    }

    // MARK: - Download Operations

    /// Download meals from Firestore for the current user
    /// - Parameters:
    ///   - since: Optional date to fetch only meals modified after this date
    ///   - limit: Maximum number of meals to fetch (default: 100)
    /// - Returns: Array of Firestore meal documents
    func downloadMeals(since: Date? = nil, limit: Int = 100) async throws -> [FirestoreMeal] {
        let userId = userSession.firestoreUserId
        logger.info("Downloading meals for user \(userId)")

        var query: Query = db
            .collection("users")
            .document(userId)
            .collection("meals")
            .order(by: "lastModified", descending: true)
            .limit(to: limit)

        // Add timestamp filter if provided
        if let sinceDate = since {
            query = query.whereField("lastModified", isGreaterThan: Timestamp(date: sinceDate))
        }

        let snapshot = try await query.getDocuments()
        logger.info("Fetched \(snapshot.documents.count) meals from Firestore")

        return try snapshot.documents.compactMap { document in
            try document.data(as: FirestoreMeal.self)
        }
    }

    /// Sync downloaded meals to CoreData
    /// - Parameter firestoreMeals: Array of FirestoreMeal objects from Firestore
    /// - Returns: Count of meals synced to CoreData
    func syncToCoreDa(_ firestoreMeals: [FirestoreMeal]) async throws -> Int {
        logger.info("Syncing \(firestoreMeals.count) meals to CoreData")

        var syncedCount = 0

        for firestoreMeal in firestoreMeals {
            do {
                try await upsertMealToCoreData(firestoreMeal)
                syncedCount += 1
            } catch {
                logger.error("Failed to sync meal \(firestoreMeal.id): \(error.localizedDescription)")
            }
        }

        logger.info("✅ Synced \(syncedCount)/\(firestoreMeals.count) meals to CoreData")
        return syncedCount
    }

    // MARK: - Delete Operations

    /// Delete a meal from both CoreData and Firestore
    /// - Parameter mealId: UUID of the meal to delete
    func deleteMeal(id mealId: UUID) async throws {
        let userId = userSession.firestoreUserId
        logger.info("Deleting meal \(mealId) from Firestore and CoreData")

        // Delete from Firestore
        try await db
            .collection("users")
            .document(userId)
            .collection("meals")
            .document(mealId.uuidString)
            .delete()

        // Delete from CoreData
        try await persistenceController.performBackgroundTask { context in
            let request = MealEntry.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", mealId as CVarArg)

            if let meal = try context.fetch(request).first {
                context.delete(meal)
                try context.save()
            }
        }

        logger.info("✅ Successfully deleted meal \(mealId)")
    }

    // MARK: - Bidirectional Sync

    /// Perform bidirectional sync: upload pending CoreData changes, then download Firestore updates
    func performBidirectionalSync() async throws {
        syncStatus = .syncing
        syncError = nil

        logger.info("🔄 Starting bidirectional sync")

        do {
            // Step 1: Upload pending local changes
            let pendingMeals = try await fetchPendingMeals()
            if !pendingMeals.isEmpty {
                logger.info("Uploading \(pendingMeals.count) pending meals")
                _ = try await uploadMeals(pendingMeals)
            }

            // Step 2: Download updates from Firestore
            // Use Unix epoch (1970) instead of Date.distantPast (0001) - Firestore doesn't support dates before 1970
            let lastSync = lastSyncTime ?? Date(timeIntervalSince1970: 0)
            let firestoreMeals = try await downloadMeals(since: lastSync)

            if !firestoreMeals.isEmpty {
                logger.info("Syncing \(firestoreMeals.count) meals from Firestore")
                _ = try await syncToCoreDa(firestoreMeals)
            }

            // Update sync time and status
            lastSyncTime = Date()
            syncStatus = .success

            logger.info("✅ Bidirectional sync complete")

        } catch {
            logger.error("❌ Sync failed: \(error.localizedDescription)")
            syncStatus = .error(error.localizedDescription)
            syncError = error
            throw error
        }
    }

    // MARK: - Private Helpers

    /// Create Firestore document from thread-safe MealData
    private func createFirestoreDocument(from mealData: MealData) -> [String: Any] {
        var data: [String: Any] = [
            "id": mealData.id.uuidString,
            "timestamp": Timestamp(date: mealData.timestamp),
            "mealType": mealData.mealType,
            "quantity": mealData.quantity,
            "unit": mealData.unit,
            "portionGrams": mealData.portionGrams,
            "consumedCarbs": mealData.consumedCarbs,
            "consumedProtein": mealData.consumedProtein,
            "consumedFat": mealData.consumedFat,
            "consumedCalories": mealData.consumedCalories,
            "consumedFiber": mealData.consumedFiber,
            "glucoseBefore": mealData.glucoseBefore,
            "glucoseAfter": mealData.glucoseAfter,
            "insulinUnits": mealData.insulinUnits,
            "lastModified": Timestamp(date: mealData.lastModified),
            "deviceId": mealData.deviceId
        ]

        // Optional fields
        if let notes = mealData.notes {
            data["notes"] = notes
        }

        // Food item reference
        if let foodItemId = mealData.foodItemId {
            data["foodItemId"] = foodItemId.uuidString
        }
        if let foodItemName = mealData.foodItemName {
            data["foodItemName"] = foodItemName
        }

        return data
    }

    /// Upsert a Firestore meal into CoreData
    private func upsertMealToCoreData(_ firestoreMeal: FirestoreMeal) async throws {
        try await persistenceController.performBackgroundTask { context in
            // Check if meal already exists
            let request = MealEntry.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", firestoreMeal.id as CVarArg)

            let existingMeal = try context.fetch(request).first

            if let existing = existingMeal {
                // Update existing meal if Firestore version is newer
                if firestoreMeal.lastModified > (existing.lastModified ?? Date.distantPast) {
                    self.updateMealEntry(existing, with: firestoreMeal, in: context)
                    self.logger.debug("Updated existing meal \(firestoreMeal.id)")
                } else {
                    self.logger.debug("Skipped meal \(firestoreMeal.id) - local version is newer")
                }
            } else {
                // Create new meal entry
                let newMeal = MealEntry(context: context)
                self.updateMealEntry(newMeal, with: firestoreMeal, in: context)
                self.logger.debug("Created new meal \(firestoreMeal.id)")
            }

            try context.save()
        }
    }

    /// Update MealEntry with data from FirestoreMeal
    nonisolated private func updateMealEntry(_ meal: MealEntry, with firestoreMeal: FirestoreMeal, in context: NSManagedObjectContext) {
        meal.id = firestoreMeal.id
        meal.timestamp = firestoreMeal.timestamp
        meal.mealType = firestoreMeal.mealType
        meal.quantity = firestoreMeal.quantity
        meal.unit = firestoreMeal.unit
        meal.portionGrams = firestoreMeal.portionGrams
        meal.consumedCarbs = firestoreMeal.consumedCarbs
        meal.consumedProtein = firestoreMeal.consumedProtein
        meal.consumedFat = firestoreMeal.consumedFat
        meal.consumedCalories = firestoreMeal.consumedCalories
        meal.consumedFiber = firestoreMeal.consumedFiber
        meal.glucoseBefore = firestoreMeal.glucoseBefore
        meal.glucoseAfter = firestoreMeal.glucoseAfter
        meal.insulinUnits = firestoreMeal.insulinUnits
        meal.notes = firestoreMeal.notes
        meal.lastModified = firestoreMeal.lastModified
        meal.deviceId = firestoreMeal.deviceId
        meal.firestoreSyncStatus = "synced"
        meal.lastSyncAttempt = Date()

        // TODO: Handle foodItem relationship if foodItemId is provided
    }

    /// Fetch meals with pending sync status from CoreData
    /// Returns thread-safe snapshots for cross-context transfer
    private func fetchPendingMeals() async throws -> [(data: MealData, objectID: NSManagedObjectID)] {
        try await persistenceController.performBackgroundTask { context in
            let request = MealEntry.fetchRequest()
            request.predicate = NSPredicate(format: "firestoreSyncStatus == %@", "pending")
            let meals = try context.fetch(request)

            // Extract data within the correct context
            return meals.map { meal in
                (data: MealData(from: meal), objectID: meal.objectID)
            }
        }
    }

    /// Update meal sync status in CoreData
    private func updateMealSyncStatus(mealObjectID: NSManagedObjectID, status: String) async {
        do {
            try await persistenceController.performBackgroundTask { context in
                if let mealInContext = try context.existingObject(with: mealObjectID) as? MealEntry {
                    mealInContext.firestoreSyncStatus = status
                    mealInContext.lastSyncAttempt = Date()
                    try context.save()
                }
            }
        } catch {
            logger.error("Failed to update sync status: \(error.localizedDescription)")
        }
    }
}

// MARK: - Meal Data Models

/// Thread-safe snapshot of MealEntry data for cross-context transfer
/// Prevents EXC_BREAKPOINT crashes when accessing CoreData objects across contexts
struct MealData: Sendable {
    let id: UUID
    let timestamp: Date
    let mealType: String
    let quantity: Double
    let unit: String
    let portionGrams: Double
    let consumedCarbs: Double
    let consumedProtein: Double
    let consumedFat: Double
    let consumedCalories: Double
    let consumedFiber: Double
    let glucoseBefore: Double
    let glucoseAfter: Double
    let insulinUnits: Double
    let notes: String?
    let lastModified: Date
    let deviceId: String
    let foodItemId: UUID?
    let foodItemName: String?

    /// Create MealData snapshot from CoreData MealEntry
    /// MUST be called within the same context as the meal object
    init(from meal: MealEntry) {
        self.id = meal.id
        self.timestamp = meal.timestamp
        self.mealType = meal.mealType
        self.quantity = meal.quantity
        self.unit = meal.unit
        self.portionGrams = meal.portionGrams
        self.consumedCarbs = meal.consumedCarbs
        self.consumedProtein = meal.consumedProtein
        self.consumedFat = meal.consumedFat
        self.consumedCalories = meal.consumedCalories
        self.consumedFiber = meal.consumedFiber
        self.glucoseBefore = meal.glucoseBefore
        self.glucoseAfter = meal.glucoseAfter
        self.insulinUnits = meal.insulinUnits
        self.notes = meal.notes
        self.lastModified = meal.lastModified ?? Date()
        // Use stored deviceId or provide a fallback at creation time
        self.deviceId = meal.deviceId ?? "unknown"
        self.foodItemId = meal.foodItem?.id
        self.foodItemName = meal.foodItem?.name
    }
}

/// Codable model representing a meal document in Firestore
struct FirestoreMeal: Codable {
    let id: UUID
    let timestamp: Date
    let mealType: String
    let quantity: Double
    let unit: String
    let portionGrams: Double
    let consumedCarbs: Double
    let consumedProtein: Double
    let consumedFat: Double
    let consumedCalories: Double
    let consumedFiber: Double
    let glucoseBefore: Double
    let glucoseAfter: Double
    let insulinUnits: Double
    let notes: String?
    let lastModified: Date
    let deviceId: String
    let foodItemId: String?
    let foodItemName: String?

    enum CodingKeys: String, CodingKey {
        case id, timestamp, mealType, quantity, unit, portionGrams
        case consumedCarbs, consumedProtein, consumedFat, consumedCalories, consumedFiber
        case glucoseBefore, glucoseAfter, insulinUnits, notes
        case lastModified, deviceId, foodItemId, foodItemName
    }
}

// MARK: - Firestore Timestamp Decoding

extension FirestoreMeal {
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
        self.timestamp = try container.decode(Timestamp.self, forKey: .timestamp).dateValue()
        self.lastModified = try container.decode(Timestamp.self, forKey: .lastModified).dateValue()

        // Decode remaining fields
        self.mealType = try container.decode(String.self, forKey: .mealType)
        self.quantity = try container.decode(Double.self, forKey: .quantity)
        self.unit = try container.decode(String.self, forKey: .unit)
        self.portionGrams = try container.decode(Double.self, forKey: .portionGrams)
        self.consumedCarbs = try container.decode(Double.self, forKey: .consumedCarbs)
        self.consumedProtein = try container.decode(Double.self, forKey: .consumedProtein)
        self.consumedFat = try container.decode(Double.self, forKey: .consumedFat)
        self.consumedCalories = try container.decode(Double.self, forKey: .consumedCalories)
        self.consumedFiber = try container.decode(Double.self, forKey: .consumedFiber)
        self.glucoseBefore = try container.decode(Double.self, forKey: .glucoseBefore)
        self.glucoseAfter = try container.decode(Double.self, forKey: .glucoseAfter)
        self.insulinUnits = try container.decode(Double.self, forKey: .insulinUnits)
        self.notes = try container.decodeIfPresent(String.self, forKey: .notes)
        self.deviceId = try container.decode(String.self, forKey: .deviceId)
        self.foodItemId = try container.decodeIfPresent(String.self, forKey: .foodItemId)
        self.foodItemName = try container.decodeIfPresent(String.self, forKey: .foodItemName)
    }
}
