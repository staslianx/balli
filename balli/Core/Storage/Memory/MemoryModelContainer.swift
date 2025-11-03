//
//  MemoryModelContainer.swift
//  balli
//
//  SwiftData ModelContainer setup for memory persistence
//  Configures local-only storage (no iCloud, uses HTTP sync instead)
//
//  Swift 6 strict concurrency compliant
//

import Foundation
import SwiftData
import OSLog

// MARK: - Memory Model Container

/// Singleton managing the SwiftData ModelContainer for memory persistence
@MainActor
final class MemoryModelContainer {
    // MARK: - Singleton

    static let shared = MemoryModelContainer()

    // MARK: - Properties

    let container: ModelContainer?
    private let logger = Logger(subsystem: "com.anaxoniclabs.balli", category: "MemoryPersistence")

    /// Error encountered during initialization (if any)
    private(set) var initializationError: Error?

    /// Whether the container is ready for operations
    var isReady: Bool {
        container != nil
    }

    // MARK: - Initialization

    private init() {
        do {
            // Define SwiftData schema with all memory models
            let schema = Schema([
                PersistentUserFact.self,
                PersistentConversationSummary.self,
                PersistentRecipePreference.self,
                PersistentGlucosePattern.self,
                PersistentUserPreference.self
            ])

            // Configure for local-only storage (no iCloud)
            let configuration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true,
                cloudKitDatabase: .none // NO iCloud - we use HTTP sync to Cloud Functions
            )

            // Create container
            self.container = try ModelContainer(
                for: schema,
                configurations: [configuration]
            )
            self.initializationError = nil

            logger.info("✅ MemoryModelContainer initialized successfully")

        } catch {
            logger.error("❌ Failed to initialize MemoryModelContainer: \(error.localizedDescription)")
            self.container = nil
            self.initializationError = error
            // App continues - AI memory feature will be unavailable
        }
    }

    // MARK: - Error Handling

    /// Error types for MemoryModelContainer operations
    enum StorageError: LocalizedError {
        case storageUnavailable

        var errorDescription: String? {
            switch self {
            case .storageUnavailable:
                return "AI memory storage is unavailable. The app will continue without memory features."
            }
        }
    }

    /// Helper to ensure storage is ready before operations
    private func ensureReady() throws {
        guard isReady else {
            logger.error("❌ Operation attempted on unavailable memory storage")
            throw StorageError.storageUnavailable
        }
    }

    // MARK: - Context Creation

    /// Create a new ModelContext for background operations
    func makeContext() throws -> ModelContext {
        try ensureReady()
        guard let container = container else { throw StorageError.storageUnavailable }
        return ModelContext(container)
    }
}
