//
//  RecipeSyncCoordinatorProtocol.swift
//  balli
//
//  Protocol definition for RecipeSyncCoordinator
//  Enables dependency injection and testing
//

import Foundation

/// Protocol for recipe synchronization coordinator
/// Manages bidirectional sync between CoreData and Firestore for recipes
@MainActor
protocol RecipeSyncCoordinatorProtocol: AnyObject, ObservableObject {

    // MARK: - Published Properties

    var isSyncing: Bool { get }
    var lastSyncTime: Date? { get }
    var syncError: Error? { get }
    var pendingChangesCount: Int { get }

    // MARK: - Sync Operations

    /// Manually trigger recipe synchronization
    func manualSync() async

    /// Sync recipes when app becomes active
    func syncOnAppActivation() async

    /// Enable automatic synchronization
    func enableAutoSync()

    /// Disable automatic synchronization
    func disableAutoSync()
}
