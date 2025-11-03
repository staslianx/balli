//
//  MedicationFirestoreService.swift
//  balli
//
//  Service for syncing MedicationEntry data with Firestore
//  Handles upload, download, and bidirectional sync for standalone medications (e.g., basal insulin)
//  Swift 6 strict concurrency compliant
//

import Foundation
import FirebaseFirestore
import CoreData
import OSLog

/// Service for syncing medication entries with Firestore
@MainActor
final class MedicationFirestoreService: ObservableObject {

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
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.balli", category: "MedicationSync")

    // MARK: - Initialization

    init(
        userSession: UserSession = .shared,
        persistenceController: Persistence.PersistenceController = .shared
    ) {
        self.userSession = userSession
        self.persistenceController = persistenceController
    }

    // MARK: - Upload Operations

    /// Upload a single medication entry to Firestore
    /// - Parameters:
    ///   - medicationData: Thread-safe snapshot of medication data
    ///   - medicationObjectID: NSManagedObjectID for status updates
    func uploadMedication(_ medicationData: MedicationData, medicationObjectID: NSManagedObjectID) async throws {
        let userId = userSession.firestoreUserId
        logger.info("Uploading medication \(medicationData.id) for user \(userId)")

        do {
            let firestoreDoc = createFirestoreDocument(from: medicationData)

            try await db
                .collection("users")
                .document(userId)
                .collection("medications")
                .document(medicationData.id.uuidString)
                .setData(firestoreDoc, merge: true)

            logger.info("✅ Successfully uploaded medication \(medicationData.id)")
        } catch {
            logger.error("❌ Failed to upload medication: \(error.localizedDescription)")
            throw error
        }
    }

    /// Upload multiple medication entries in batch
    /// - Parameter medicationDataArray: Array of (MedicationData, NSManagedObjectID) tuples
    /// - Returns: Count of successfully uploaded medications
    func uploadMedications(_ medicationDataArray: [(data: MedicationData, objectID: NSManagedObjectID)]) async throws -> Int {
        logger.info("Batch uploading \(medicationDataArray.count) medications")

        var successCount = 0

        for (medicationData, _) in medicationDataArray {
            do {
                try await uploadMedication(medicationData, medicationObjectID: medicationData.objectID)
                successCount += 1
            } catch {
                logger.error("Failed to upload medication \(medicationData.id): \(error.localizedDescription)")
                // Continue with remaining medications
            }
        }

        logger.info("✅ Batch upload complete: \(successCount)/\(medicationDataArray.count) successful")
        return successCount
    }

    // MARK: - Download Operations

    /// Download medications from Firestore for the current user
    /// - Parameters:
    ///   - since: Optional date to fetch only medications modified after this date
    ///   - limit: Maximum number of medications to fetch (default: 100)
    /// - Returns: Array of Firestore medication documents
    func downloadMedications(since: Date? = nil, limit: Int = 100) async throws -> [FirestoreMedication] {
        let userId = userSession.firestoreUserId
        logger.info("Downloading medications for user \(userId)")

        var query: Query = db
            .collection("users")
            .document(userId)
            .collection("medications")
            .order(by: "lastModified", descending: true)
            .limit(to: limit)

        // Add timestamp filter if provided
        if let sinceDate = since {
            query = query.whereField("lastModified", isGreaterThan: Timestamp(date: sinceDate))
        }

        let snapshot = try await query.getDocuments()
        logger.info("Fetched \(snapshot.documents.count) medications from Firestore")

        return try snapshot.documents.compactMap { document in
            try document.data(as: FirestoreMedication.self)
        }
    }

    /// Sync downloaded medications to CoreData
    /// - Parameter firestoreMedications: Array of FirestoreMedication objects from Firestore
    /// - Returns: Count of medications synced to CoreData
    func syncToCoreData(_ firestoreMedications: [FirestoreMedication]) async throws -> Int {
        logger.info("Syncing \(firestoreMedications.count) medications to CoreData")

        var syncedCount = 0

        for firestoreMedication in firestoreMedications {
            do {
                try await upsertMedicationToCoreData(firestoreMedication)
                syncedCount += 1
            } catch {
                logger.error("Failed to sync medication \(firestoreMedication.id): \(error.localizedDescription)")
            }
        }

        logger.info("✅ Synced \(syncedCount)/\(firestoreMedications.count) medications to CoreData")
        return syncedCount
    }

    // MARK: - Delete Operations

    /// Delete a medication from both CoreData and Firestore
    /// - Parameter medicationId: UUID of the medication to delete
    func deleteMedication(id medicationId: UUID) async throws {
        let userId = userSession.firestoreUserId
        logger.info("Deleting medication \(medicationId) from Firestore and CoreData")

        // Delete from Firestore
        try await db
            .collection("users")
            .document(userId)
            .collection("medications")
            .document(medicationId.uuidString)
            .delete()

        // Delete from CoreData
        try await persistenceController.performBackgroundTask { context in
            let request = MedicationEntry.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", medicationId as CVarArg)

            if let medication = try context.fetch(request).first {
                context.delete(medication)
                try context.save()
            }
        }

        logger.info("✅ Successfully deleted medication \(medicationId)")
    }

    // MARK: - Bidirectional Sync

    /// Perform bidirectional sync: upload pending CoreData changes, then download Firestore updates
    func performBidirectionalSync() async throws {
        syncStatus = .syncing
        syncError = nil

        logger.info("🔄 Starting bidirectional medication sync")

        do {
            // Step 1: Upload pending local changes
            let pendingMedications = try await fetchPendingMedications()
            if !pendingMedications.isEmpty {
                logger.info("Uploading \(pendingMedications.count) pending medications")
                _ = try await uploadMedications(pendingMedications)
            }

            // Step 2: Download updates from Firestore
            let lastSync = lastSyncTime ?? Date.distantPast
            let firestoreMedications = try await downloadMedications(since: lastSync)

            if !firestoreMedications.isEmpty {
                logger.info("Syncing \(firestoreMedications.count) medications from Firestore")
                _ = try await syncToCoreData(firestoreMedications)
            }

            // Update sync time and status
            lastSyncTime = Date()
            syncStatus = .success

            logger.info("✅ Bidirectional medication sync complete")

        } catch {
            logger.error("❌ Medication sync failed: \(error.localizedDescription)")
            syncStatus = .error(error.localizedDescription)
            syncError = error
            throw error
        }
    }

    // MARK: - Private Helpers

    /// Create Firestore document from thread-safe MedicationData
    private func createFirestoreDocument(from medicationData: MedicationData) -> [String: Any] {
        var data: [String: Any] = [
            "id": medicationData.id.uuidString,
            "timestamp": Timestamp(date: medicationData.timestamp),
            "medicationName": medicationData.medicationName,
            "medicationType": medicationData.medicationType,
            "dosage": medicationData.dosage,
            "dosageUnit": medicationData.dosageUnit,
            "administrationRoute": medicationData.administrationRoute,
            "glucoseAtTime": medicationData.glucoseAtTime,
            "isScheduled": medicationData.isScheduled,
            "dateAdded": Timestamp(date: medicationData.dateAdded),
            "lastModified": Timestamp(date: medicationData.lastModified),
            "source": medicationData.source,
            "deviceId": medicationData.deviceId
        ]

        // Optional fields
        if let injectionSite = medicationData.injectionSite {
            data["injectionSite"] = injectionSite
        }
        if let timingRelation = medicationData.timingRelation {
            data["timingRelation"] = timingRelation
        }
        if let notes = medicationData.notes {
            data["notes"] = notes
        }

        // Meal relationship (if connected to a meal)
        if let mealId = medicationData.mealId {
            data["mealId"] = mealId.uuidString
        }

        return data
    }

    /// Upsert a Firestore medication into CoreData
    private func upsertMedicationToCoreData(_ firestoreMedication: FirestoreMedication) async throws {
        try await persistenceController.performBackgroundTask { context in
            // Check if medication already exists
            let request = MedicationEntry.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", firestoreMedication.id as CVarArg)

            let existingMedication = try context.fetch(request).first

            if let existing = existingMedication {
                // Update existing medication if Firestore version is newer
                if firestoreMedication.lastModified > existing.lastModified {
                    self.updateMedicationEntry(existing, with: firestoreMedication, in: context)
                    self.logger.debug("Updated existing medication \(firestoreMedication.id)")
                } else {
                    self.logger.debug("Skipped medication \(firestoreMedication.id) - local version is newer")
                }
            } else {
                // Create new medication entry
                let newMedication = MedicationEntry(context: context)
                self.updateMedicationEntry(newMedication, with: firestoreMedication, in: context)
                self.logger.debug("Created new medication \(firestoreMedication.id)")
            }

            try context.save()
        }
    }

    /// Update MedicationEntry with data from FirestoreMedication
    nonisolated private func updateMedicationEntry(_ medication: MedicationEntry, with firestoreMedication: FirestoreMedication, in context: NSManagedObjectContext) {
        medication.id = firestoreMedication.id
        medication.timestamp = firestoreMedication.timestamp
        medication.medicationName = firestoreMedication.medicationName
        medication.medicationType = firestoreMedication.medicationType
        medication.dosage = firestoreMedication.dosage
        medication.dosageUnit = firestoreMedication.dosageUnit
        medication.administrationRoute = firestoreMedication.administrationRoute
        medication.injectionSite = firestoreMedication.injectionSite
        medication.timingRelation = firestoreMedication.timingRelation
        medication.glucoseAtTime = firestoreMedication.glucoseAtTime
        medication.notes = firestoreMedication.notes
        medication.isScheduled = firestoreMedication.isScheduled
        medication.dateAdded = firestoreMedication.dateAdded
        medication.lastModified = firestoreMedication.lastModified
        medication.source = firestoreMedication.source

        // Handle meal relationship if mealId is provided
        if let mealId = firestoreMedication.mealId {
            let mealRequest = MealEntry.fetchRequest()
            mealRequest.predicate = NSPredicate(format: "id == %@", mealId as CVarArg)
            if let meal = try? context.fetch(mealRequest).first {
                medication.mealEntry = meal
            }
        }
    }

    /// Fetch medications with pending sync status from CoreData
    /// Returns thread-safe snapshots for cross-context transfer
    private func fetchPendingMedications() async throws -> [(data: MedicationData, objectID: NSManagedObjectID)] {
        try await persistenceController.performBackgroundTask { context in
            let request = MedicationEntry.fetchRequest()
            // Fetch all medications - we'll sync them all for now
            // In the future, add sync status tracking
            let medications = try context.fetch(request)

            // Extract data within the correct context
            return medications.map { medication in
                (data: MedicationData(from: medication), objectID: medication.objectID)
            }
        }
    }
}

// MARK: - Medication Data Models

/// Thread-safe snapshot of MedicationEntry data for cross-context transfer
/// Prevents EXC_BREAKPOINT crashes when accessing CoreData objects across contexts
struct MedicationData: Sendable {
    let id: UUID
    let timestamp: Date
    let medicationName: String
    let medicationType: String
    let dosage: Double
    let dosageUnit: String
    let administrationRoute: String
    let injectionSite: String?
    let timingRelation: String?
    let glucoseAtTime: Double
    let notes: String?
    let isScheduled: Bool
    let dateAdded: Date
    let lastModified: Date
    let source: String
    let deviceId: String
    let mealId: UUID?
    let objectID: NSManagedObjectID

    /// Create MedicationData snapshot from CoreData MedicationEntry
    /// MUST be called within the same context as the medication object
    init(from medication: MedicationEntry) {
        self.id = medication.id
        self.timestamp = medication.timestamp
        self.medicationName = medication.medicationName
        self.medicationType = medication.medicationType
        self.dosage = medication.dosage
        self.dosageUnit = medication.dosageUnit
        self.administrationRoute = medication.administrationRoute
        self.injectionSite = medication.injectionSite
        self.timingRelation = medication.timingRelation
        self.glucoseAtTime = medication.glucoseAtTime
        self.notes = medication.notes
        self.isScheduled = medication.isScheduled
        self.dateAdded = medication.dateAdded
        self.lastModified = medication.lastModified
        self.source = medication.source
        self.deviceId = medication.deviceIdentifier
        self.mealId = medication.mealEntry?.id
        self.objectID = medication.objectID
    }
}

/// Codable model representing a medication document in Firestore
struct FirestoreMedication: Codable {
    let id: UUID
    let timestamp: Date
    let medicationName: String
    let medicationType: String
    let dosage: Double
    let dosageUnit: String
    let administrationRoute: String
    let injectionSite: String?
    let timingRelation: String?
    let glucoseAtTime: Double
    let notes: String?
    let isScheduled: Bool
    let dateAdded: Date
    let lastModified: Date
    let source: String
    let mealId: UUID?

    enum CodingKeys: String, CodingKey {
        case id, timestamp, medicationName, medicationType, dosage, dosageUnit
        case administrationRoute, injectionSite, timingRelation, glucoseAtTime
        case notes, isScheduled, dateAdded, lastModified, source, mealId
    }
}

// MARK: - Firestore Timestamp Decoding

extension FirestoreMedication {
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
        self.dateAdded = try container.decode(Timestamp.self, forKey: .dateAdded).dateValue()
        self.lastModified = try container.decode(Timestamp.self, forKey: .lastModified).dateValue()

        // Decode remaining fields
        self.medicationName = try container.decode(String.self, forKey: .medicationName)
        self.medicationType = try container.decode(String.self, forKey: .medicationType)
        self.dosage = try container.decode(Double.self, forKey: .dosage)
        self.dosageUnit = try container.decode(String.self, forKey: .dosageUnit)
        self.administrationRoute = try container.decode(String.self, forKey: .administrationRoute)
        self.injectionSite = try container.decodeIfPresent(String.self, forKey: .injectionSite)
        self.timingRelation = try container.decodeIfPresent(String.self, forKey: .timingRelation)
        self.glucoseAtTime = try container.decode(Double.self, forKey: .glucoseAtTime)
        self.notes = try container.decodeIfPresent(String.self, forKey: .notes)
        self.isScheduled = try container.decode(Bool.self, forKey: .isScheduled)
        self.source = try container.decode(String.self, forKey: .source)

        // Decode optional meal ID
        if let mealIdString = try container.decodeIfPresent(String.self, forKey: .mealId),
           let mealUUID = UUID(uuidString: mealIdString) {
            self.mealId = mealUUID
        } else {
            self.mealId = nil
        }
    }
}
