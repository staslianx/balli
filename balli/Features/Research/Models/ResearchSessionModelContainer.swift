import Foundation
import SwiftData
import OSLog

/// Singleton managing the SwiftData ModelContainer for research session persistence
@MainActor
final class ResearchSessionModelContainer {
    // MARK: - Singleton

    static let shared = ResearchSessionModelContainer()

    // MARK: - Properties

    let container: ModelContainer?
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.balli",
        category: "ResearchSessionPersistence"
    )

    /// Error encountered during initialization (if any)
    private(set) var initializationError: Error?

    /// Whether the container is ready for operations
    var isReady: Bool {
        container != nil
    }

    // MARK: - Initialization

    private init() {
        do {
            // Define SwiftData schema with research session models
            let schema = Schema([
                ResearchSession.self,
                SessionMessage.self
            ])

            // Configure for local-only storage (no iCloud)
            let configuration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true,
                cloudKitDatabase: .none // Local storage only
            )

            // Create container
            self.container = try ModelContainer(
                for: schema,
                configurations: [configuration]
            )
            self.initializationError = nil

            logger.info("✅ ResearchSessionModelContainer initialized successfully")

        } catch {
            logger.error("❌ Failed to initialize ResearchSessionModelContainer: \(error.localizedDescription)")
            self.container = nil
            self.initializationError = error
            // App continues - research history will be unavailable
        }
    }

    // MARK: - Error Handling

    /// Error types for ResearchSessionModelContainer operations
    enum StorageError: LocalizedError {
        case storageUnavailable

        var errorDescription: String? {
            switch self {
            case .storageUnavailable:
                return "Research session storage is unavailable. The app will continue without research history."
            }
        }
    }

    /// Helper to ensure storage is ready before operations
    private func ensureReady() throws {
        guard isReady else {
            logger.error("❌ Operation attempted on unavailable research storage")
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
