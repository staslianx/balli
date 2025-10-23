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

    let container: ModelContainer
    private let logger = Logger(subsystem: "com.anaxoniclabs.balli", category: "MemoryPersistence")

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

            logger.info("✅ MemoryModelContainer initialized successfully")

        } catch {
            // Fatal error - memory persistence is critical for health data
            fatalError("❌ Failed to initialize MemoryModelContainer: \(error.localizedDescription)")
        }
    }

    // MARK: - Context Creation

    /// Create a new ModelContext for background operations
    func makeContext() -> ModelContext {
        return ModelContext(container)
    }
}
