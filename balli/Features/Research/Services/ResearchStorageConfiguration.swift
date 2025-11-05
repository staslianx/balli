//
//  ResearchStorageConfiguration.swift
//  balli
//
//  Storage configuration helper for research feature
//  Provides graceful degradation when persistence is unavailable
//  Swift 6 strict concurrency compliant
//

import Foundation
import SwiftData
import OSLog

/// Storage state for research session persistence
enum ResearchStorageState: Sendable {
    /// Persistent storage available (on-disk SwiftData)
    case persistent(ModelContainer)

    /// In-memory storage available (fallback mode)
    case inMemory(ModelContainer)

    /// Storage unavailable (degraded mode - no persistence)
    case unavailable(Error)

    /// Check if persistence is available (either persistent or in-memory)
    var hasStorage: Bool {
        switch self {
        case .persistent, .inMemory:
            return true
        case .unavailable:
            return false
        }
    }

    /// Get the model container if available
    var container: ModelContainer? {
        switch self {
        case .persistent(let container), .inMemory(let container):
            return container
        case .unavailable:
            return nil
        }
    }
}

/// Helper for configuring research session storage with graceful fallbacks
final class ResearchStorageConfiguration {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.balli",
        category: "ResearchStorage"
    )

    /// Configure storage with automatic fallback chain:
    /// 1. Try persistent storage (preferred)
    /// 2. Fall back to in-memory storage
    /// 3. Return unavailable if both fail
    @MainActor
    static func configureStorage() -> ResearchStorageState {
        // Step 1: Try persistent storage
        if let container = try? ResearchSessionModelContainer.shared.makeContext().container {
            logger.info("✅ Using persistent storage")
            return .persistent(container)
        }

        logger.warning("⚠️ Persistent storage unavailable, trying in-memory fallback")

        // Step 2: Try in-memory fallback
        let schema = Schema([ResearchSession.self, SessionMessage.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)

        if let container = try? ModelContainer(for: schema, configurations: [config]) {
            logger.info("✅ Using in-memory fallback storage")
            return .inMemory(container)
        }

        // Step 3: Both failed - return unavailable
        let error = NSError(
            domain: "com.balli.research.storage",
            code: -1,
            userInfo: [
                NSLocalizedDescriptionKey: "Storage unavailable. Highlights and session history will not be saved."
            ]
        )

        logger.error("❌ Storage completely unavailable: \(error.localizedDescription)")
        return .unavailable(error)
    }

    /// User-friendly error message for degraded mode
    static func degradedModeMessage() -> String {
        "Storage unavailable. Your research will work, but highlights and history won't be saved. Try restarting the app."
    }
}
