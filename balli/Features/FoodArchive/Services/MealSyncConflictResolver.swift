//
//  MealSyncConflictResolver.swift
//  balli
//
//  Handles conflict resolution for meal entry synchronization
//  Uses last-write-wins strategy with timestamp comparison
//  Swift 6 strict concurrency compliant
//

import Foundation
import CoreData
import OSLog

/// Resolves conflicts when the same meal is edited on different devices
struct MealSyncConflictResolver {

    // MARK: - Properties

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.balli", category: "ConflictResolver")

    // MARK: - Conflict Resolution Strategy

    /// Resolve conflict between local CoreData meal and remote Firestore meal
    /// - Parameters:
    ///   - localMeal: The meal stored in CoreData
    ///   - remoteMeal: The meal from Firestore
    /// - Returns: The meal that should be kept (winner)
    func resolveConflict(
        localMeal: MealEntry,
        remoteMeal: FirestoreMeal
    ) -> MealSyncResolution {
        logger.info("Resolving conflict for meal \(localMeal.id)")

        let localModified = localMeal.lastModified ?? Date.distantPast
        let remoteModified = remoteMeal.lastModified

        // Log conflict details
        logger.debug("Local lastModified: \(localModified)")
        logger.debug("Remote lastModified: \(remoteModified)")
        logger.debug("Local device: \(localMeal.deviceId ?? "unknown")")
        logger.debug("Remote device: \(remoteMeal.deviceId)")

        // Strategy 1: Last-write-wins based on timestamp
        if remoteModified > localModified {
            logger.info("✅ Remote wins (newer timestamp)")
            return .useRemote(remoteMeal)
        } else if localModified > remoteModified {
            logger.info("✅ Local wins (newer timestamp)")
            return .useLocal(localMeal)
        }

        // Strategy 2: If timestamps are equal, prefer non-pending sync status
        if localMeal.firestoreSyncStatus == "synced" && remoteMeal.lastModified == localModified {
            logger.info("✅ Already synced - no action needed")
            return .alreadySynced
        }

        // Strategy 3: If still tied, prefer remote (safer to keep server state)
        logger.warning("⚠️ Timestamps equal - defaulting to remote")
        return .useRemote(remoteMeal)
    }

    /// Check if a conflict exists between local and remote meal
    /// - Parameters:
    ///   - localMeal: The meal stored in CoreData
    ///   - remoteMeal: The meal from Firestore
    /// - Returns: True if there's a potential conflict
    func hasConflict(localMeal: MealEntry, remoteMeal: FirestoreMeal) -> Bool {
        guard let localModified = localMeal.lastModified else {
            return false // No local modifications
        }

        // Conflict exists if:
        // 1. Both have been modified
        // 2. Modifications happened at different times
        // 3. Local version hasn't been synced yet
        return localModified != remoteMeal.lastModified &&
               localMeal.firestoreSyncStatus == "pending"
    }

    /// Detect if meals are functionally identical (ignoring metadata)
    /// - Parameters:
    ///   - localMeal: The meal stored in CoreData
    ///   - remoteMeal: The meal from Firestore
    /// - Returns: True if meal content is identical
    func areContentEqual(localMeal: MealEntry, remoteMeal: FirestoreMeal) -> Bool {
        return localMeal.timestamp == remoteMeal.timestamp &&
               localMeal.mealType == remoteMeal.mealType &&
               localMeal.quantity == remoteMeal.quantity &&
               localMeal.unit == remoteMeal.unit &&
               localMeal.consumedCarbs == remoteMeal.consumedCarbs &&
               localMeal.consumedProtein == remoteMeal.consumedProtein &&
               localMeal.consumedFat == remoteMeal.consumedFat &&
               localMeal.notes == remoteMeal.notes
    }
}

// MARK: - Meal Sync Resolution Result

enum MealSyncResolution {
    /// Use the remote version from Firestore
    case useRemote(FirestoreMeal)

    /// Keep the local version from CoreData
    case useLocal(MealEntry)

    /// Already synced, no action needed
    case alreadySynced

    /// Provide human-readable description
    var description: String {
        switch self {
        case .useRemote:
            return "Using remote version (newer)"
        case .useLocal:
            return "Keeping local version (newer)"
        case .alreadySynced:
            return "Already synced"
        }
    }
}

// MARK: - Meal Sync Statistics

/// Track conflict resolution statistics for monitoring
struct MealSyncStatistics {
    var totalConflicts: Int = 0
    var remoteWins: Int = 0
    var localWins: Int = 0
    var alreadySynced: Int = 0

    mutating func record(_ resolution: MealSyncResolution) {
        totalConflicts += 1
        switch resolution {
        case .useRemote:
            remoteWins += 1
        case .useLocal:
            localWins += 1
        case .alreadySynced:
            alreadySynced += 1
        }
    }

    var summary: String {
        """
        Conflict Resolution Summary:
        - Total: \(totalConflicts)
        - Remote wins: \(remoteWins)
        - Local wins: \(localWins)
        - Already synced: \(alreadySynced)
        """
    }
}

// MARK: - Conflict Detection Helpers

extension MealEntry {
    /// Check if this meal has pending changes that haven't been synced
    var hasPendingChanges: Bool {
        firestoreSyncStatus == "pending"
    }

    /// Check if this meal was recently modified (within last 5 minutes)
    var wasRecentlyModified: Bool {
        guard let modified = lastModified else { return false }
        return Date().timeIntervalSince(modified) < 300 // 5 minutes
    }

    /// Mark this meal as needing sync
    func markAsPendingSync() {
        self.firestoreSyncStatus = "pending"
        self.lastModified = Date()
        // Device ID is set on insert; only update if not set
        if self.deviceId == nil {
            self.deviceId = UUID().uuidString
        }
    }
}
