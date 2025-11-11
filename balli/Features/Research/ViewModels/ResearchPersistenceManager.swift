//
//  ResearchPersistenceManager.swift
//  balli
//
//  Handles all persistence operations for research sessions
//  Split from MedicalResearchViewModel for better organization
//  Swift 6 strict concurrency compliant
//

import Foundation
import SwiftUI
import OSLog

/// Manages persistence operations for research sessions and answers
@MainActor
final class ResearchPersistenceManager {
    // MARK: - Properties

    private let repository = ResearchHistoryRepository()
    private let logger = AppLoggers.Research.search

    // MARK: - Session Persistence

    /// Attempt to recover an active session from storage (e.g., after app crash)
    func recoverActiveSession(using sessionManager: ResearchSessionManager) async {
        do {
            let recovered = try await sessionManager.recoverActiveSession()
            if recovered {
                logger.info("Recovered active research session")
                // Optionally show a message to the user asking if they want to continue
            }
        } catch {
            logger.error("Failed to recover active session: \(error.localizedDescription)")
        }
    }

    /// Save the current research session WITHOUT clearing it (for app backgrounding)
    func saveCurrentSession(using sessionManager: ResearchSessionManager) async {
        do {
            try await sessionManager.saveActiveSession()
            logger.info("💾 Current research session saved (conversation history preserved)")
        } catch {
            logger.error("Failed to save active session: \(error.localizedDescription)")
        }
    }

    /// End the current research session and persist it with metadata
    func endCurrentSession(using sessionManager: ResearchSessionManager) async {
        do {
            try await sessionManager.endSession(generateMetadata: true)
            logger.info("✅ Current research session ended and persisted")
        } catch {
            logger.error("Failed to end session: \(error.localizedDescription)")
        }
    }

    /// Load research history based on session state:
    /// - If app was KILLED/CRASHED/CLOSED → Show empty state (fresh conversation)
    /// - If app was BACKGROUNDED → Restore last state exactly as user left it
    /// - If user switches tabs within app → Show last state exactly as user left it
    /// - forceLoad parameter bypasses timeout check (used for tab switching within active app)
    func loadSessionHistory(forceLoad: Bool = false) async -> [SearchAnswer] {
        let appStateManager = AppLifecycleCoordinator.shared

        // Check if app gracefully went to background (vs being terminated)
        let wasGracefullyBackgrounded = await appStateManager.wasGracefullyBackgrounded
        let persistedBackgroundTime = await appStateManager.persistedLastBackgroundTime

        // Calculate time since last background
        let timeInBackground = persistedBackgroundTime.map {
            Date().timeIntervalSince($0)
        } ?? Double.infinity  // If nil, treat as infinite time (fresh install)

        // Format time for logging (handle infinity case)
        let timeString = timeInBackground.isInfinite ? "∞" : "\(Int(timeInBackground))s"

        // LIFECYCLE FIX: If forceLoad is true (tab switch scenario), ALWAYS load history
        // This handles cases where the view is recreated during tab switching
        if forceLoad {
            logger.info("🔄 [PERSISTENCE] Force loading history (tab switch or view recreation)")
            return await loadPersistedHistory()
        }

        // Load history ONLY if:
        // 1. App was gracefully backgrounded (not killed/crashed)
        // 2. Time in background < 15 minutes (active conversation window)
        let shouldLoadHistory = wasGracefullyBackgrounded && (timeInBackground < 900)

        logger.info("🔍 [PERSISTENCE] Session check: gracefulBackground=\(wasGracefullyBackgrounded), timeInBackground=\(timeString), shouldLoad=\(shouldLoadHistory)")

        if shouldLoadHistory {
            logger.info("✅ [PERSISTENCE] Restoring previous research session (app was backgrounded)")
            return await loadPersistedHistory()
        } else {
            if !wasGracefullyBackgrounded {
                logger.info("🆕 [PERSISTENCE] Starting fresh - app was killed/crashed/closed")
            } else {
                logger.info("🆕 [PERSISTENCE] Starting fresh - too much time passed (\(timeString))")
            }
            // Return empty array; user sees clean Research tab
            return []
        }
    }

    /// Load persisted history from CoreData
    private func loadPersistedHistory() async -> [SearchAnswer] {
        do {
            let persistedAnswers = try await repository.loadAll()
            logger.info("Loaded \(persistedAnswers.count) research answers from persistence")
            return persistedAnswers
        } catch {
            logger.error("Failed to load persisted history: \(error.localizedDescription)")
            return []
        }
    }

    /// Sync all in-memory answers to CoreData persistence
    /// Called when app backgrounds to ensure research is saved if app is killed
    func syncAnswersToPersistence(_ answers: [SearchAnswer]) async {
        guard !answers.isEmpty else {
            logger.debug("No answers to sync to persistence")
            return
        }

        logger.info("🔄 Syncing \(answers.count) answers to persistence")

        for answer in answers {
            // Skip placeholder answers (no content yet)
            guard !answer.content.isEmpty else {
                logger.debug("Skipping placeholder answer: \(answer.id)")
                continue
            }

            do {
                try await repository.save(answer)
                logger.debug("✅ Synced answer to persistence: \(answer.id)")
            } catch {
                logger.error("❌ Failed to sync answer \(answer.id): \(error.localizedDescription)")
            }
        }

        logger.info("✅ Sync to persistence complete")
    }

    /// Save a single answer to persistence
    func saveAnswer(_ answer: SearchAnswer) async throws {
        try await repository.save(answer)
        logger.info("✅ Persisted answer to CoreData: \(answer.id)")
    }

    /// Clear all persisted history
    func clearHistory() async throws {
        try await repository.deleteAll()
        logger.info("✅ Cleared all history from persistence")
    }
}
