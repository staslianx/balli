import Foundation
import SwiftData
import OSLog

/// Singleton managing the SwiftData ModelContainer for research session persistence
@MainActor
final class ResearchSessionModelContainer {
    // MARK: - Singleton

    static let shared = ResearchSessionModelContainer()

    // MARK: - Properties

    let container: ModelContainer
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.balli",
        category: "ResearchSessionPersistence"
    )

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

            logger.info("✅ ResearchSessionModelContainer initialized successfully")

        } catch {
            // Fatal error - session persistence is critical for research history
            fatalError("❌ Failed to initialize ResearchSessionModelContainer: \(error.localizedDescription)")
        }
    }

    // MARK: - Context Creation

    /// Create a new ModelContext for background operations
    func makeContext() -> ModelContext {
        return ModelContext(container)
    }
}
