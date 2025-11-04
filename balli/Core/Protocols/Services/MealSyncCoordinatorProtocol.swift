//
//  MealSyncCoordinatorProtocol.swift
//  balli
//
//  Protocol definition for MealSyncCoordinator
//  Enables dependency injection and testing
//

import Foundation

/// Protocol for meal synchronization coordinator
/// Manages bidirectional sync between CoreData and Firestore for meal entries
@MainActor
protocol MealSyncCoordinatorProtocol: AnyObject, ObservableObject {

    // MARK: - Published Properties

    var isSyncing: Bool { get }
    var lastSyncTime: Date? { get }
    var syncError: Error? { get }
    var pendingChangesCount: Int { get }

    // MARK: - Sync Operations

    /// Manually trigger meal synchronization
    func manualSync() async

    /// Sync meals when app becomes active
    func syncOnAppActivation() async

    /// Enable automatic synchronization
    func enableAutoSync()

    /// Disable automatic synchronization
    func disableAutoSync()
}
