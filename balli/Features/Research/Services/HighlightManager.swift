//
//  HighlightManager.swift
//  balli
//
//  Purpose: Manages text highlights for research answers
//  Handles add/update/delete operations and rendering
//  Swift 6 strict concurrency compliant
//

import Foundation
import UIKit
import OSLog

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.balli",
    category: "HighlightManager"
)

/// Manages text highlights for research answers with persistence
@MainActor
final class HighlightManager: ObservableObject {
    /// In-memory cache of highlights per answer ID
    @Published private(set) var highlights: [String: [TextHighlight]] = [:]

    /// Persistence coordinator for saving to SwiftData (for SessionMessage highlights)
    private weak var sessionManager: ResearchSessionManager?

    /// Repository for CoreData persistence (for SearchAnswer highlights)
    private let repository = ResearchHistoryRepository()

    init(sessionManager: ResearchSessionManager? = nil) {
        self.sessionManager = sessionManager
    }

    /// Set the session manager after initialization
    func setSessionManager(_ sessionManager: ResearchSessionManager) {
        self.sessionManager = sessionManager
    }

    // MARK: - Highlight Operations

    /// Add a new highlight to an answer
    func addHighlight(
        _ highlight: TextHighlight,
        to answerId: String
    ) async throws {
        logger.info("📝 [HIGHLIGHT] Adding highlight to answer: \(answerId)")

        // Basic validation: ensure range is valid
        guard highlight.startOffset >= 0 && highlight.length > 0 else {
            logger.error("❌ [HIGHLIGHT] Invalid range: \(highlight.startOffset)+\(highlight.length)")
            throw HighlightError.invalidRange
        }

        // Add to in-memory cache
        highlights[answerId, default: []].append(highlight)
        logger.info("✅ [HIGHLIGHT] Added highlight (total: \(self.highlights[answerId]?.count ?? 0))")

        // Persist to CoreData for SearchAnswer highlights
        do {
            let allHighlights = highlights[answerId] ?? []
            try await repository.saveHighlights(allHighlights, for: answerId)
            logger.info("💾 [HIGHLIGHT] Persisted to CoreData")
        } catch {
            // If CoreData save fails, try SwiftData (for SessionMessage highlights)
            if let sessionManager = sessionManager {
                try await sessionManager.saveHighlight(highlight, for: answerId)
                logger.info("💾 [HIGHLIGHT] Persisted to SwiftData")
            } else {
                logger.error("❌ [HIGHLIGHT] No persistence available for answer: \(answerId)")
                throw error
            }
        }
    }

    /// Update the color of an existing highlight
    func updateHighlightColor(
        _ highlightId: UUID,
        to color: TextHighlight.HighlightColor,
        in answerId: String
    ) async throws {
        logger.info("🎨 [HIGHLIGHT] Updating color for highlight: \(highlightId)")

        guard var answerHighlights = highlights[answerId],
              let index = answerHighlights.firstIndex(where: { $0.id == highlightId }) else {
            logger.error("❌ [HIGHLIGHT] Highlight not found")
            throw HighlightError.highlightNotFound
        }

        // Create updated highlight
        let oldHighlight = answerHighlights[index]
        let updatedHighlight = TextHighlight(
            id: oldHighlight.id,
            color: color,
            startOffset: oldHighlight.startOffset,
            length: oldHighlight.length,
            text: oldHighlight.text,
            createdAt: oldHighlight.createdAt
        )

        // Update in-memory cache
        answerHighlights[index] = updatedHighlight
        highlights[answerId] = answerHighlights
        logger.info("✅ [HIGHLIGHT] Color updated to \(color.displayName)")

        // Persist to SwiftData
        if let sessionManager = sessionManager {
            try await sessionManager.updateHighlight(updatedHighlight, for: answerId)
            logger.info("💾 [HIGHLIGHT] Update persisted to SwiftData")
        }
    }

    /// Delete a highlight
    func deleteHighlight(
        _ highlightId: UUID,
        from answerId: String
    ) async throws {
        logger.info("🗑️ [HIGHLIGHT] Deleting highlight: \(highlightId)")

        guard var answerHighlights = highlights[answerId] else {
            logger.error("❌ [HIGHLIGHT] No highlights for answer")
            throw HighlightError.highlightNotFound
        }

        // Remove from in-memory cache
        answerHighlights.removeAll { $0.id == highlightId }
        highlights[answerId] = answerHighlights
        logger.info("✅ [HIGHLIGHT] Deleted (remaining: \(answerHighlights.count))")

        // Persist deletion to CoreData for SearchAnswer highlights
        do {
            try await repository.deleteHighlight(highlightId, from: answerId)
            logger.info("💾 [HIGHLIGHT] Deletion persisted to CoreData")
        } catch {
            // If CoreData delete fails, try SwiftData (for SessionMessage highlights)
            if let sessionManager = sessionManager {
                try await sessionManager.deleteHighlight(id: highlightId, from: answerId)
                logger.info("💾 [HIGHLIGHT] Deletion persisted to SwiftData")
            } else {
                logger.error("❌ [HIGHLIGHT] No persistence available for answer: \(answerId)")
                throw error
            }
        }
    }

    /// Load highlights for an answer from persistence
    /// Always reloads from database to ensure fresh data
    func loadHighlights(for answerId: String) async {
        logger.info("📂 [HIGHLIGHT] Loading highlights for answer: \(answerId)")

        // Try loading from CoreData first (for SearchAnswer highlights)
        do {
            let loaded = try await repository.loadHighlights(for: answerId)
            // CRITICAL: Update @Published property on main thread
            await MainActor.run {
                highlights[answerId] = loaded
            }
            logger.info("💾 [HIGHLIGHT] Loaded \(loaded.count) highlights from CoreData")
        } catch {
            // If CoreData load fails, try SwiftData (for SessionMessage highlights)
            if let sessionManager = sessionManager {
                let loaded = await sessionManager.loadHighlights(for: answerId)
                // CRITICAL: Update @Published property on main thread
                await MainActor.run {
                    highlights[answerId] = loaded ?? []
                }
                logger.info("💾 [HIGHLIGHT] Loaded \(loaded?.count ?? 0) highlights from SwiftData")
            } else {
                // CRITICAL: Update @Published property on main thread
                await MainActor.run {
                    highlights[answerId] = []
                }
                logger.info("ℹ️ [HIGHLIGHT] No persistence available, using empty highlights")
            }
        }
    }

    // MARK: - Rendering

    /// Apply highlights to an attributed string
    func applyHighlights(
        to attributedString: NSMutableAttributedString,
        for answerId: String
    ) {
        guard let answerHighlights = highlights[answerId], !answerHighlights.isEmpty else {
            return
        }

        logger.debug("🎨 [HIGHLIGHT] Applying \(answerHighlights.count) highlights")

        for highlight in answerHighlights {
            let range = NSRange(location: highlight.startOffset, length: highlight.length)

            // Validate range is within bounds
            guard range.location >= 0,
                  range.location + range.length <= attributedString.length else {
                logger.warning("⚠️ [HIGHLIGHT] Skipping out-of-bounds highlight at \(range.location)")
                continue
            }

            // Apply background color with transparency (fixed color, no dark mode adaptation)
            attributedString.addAttribute(
                .backgroundColor,
                value: highlight.color.highlightColor,
                range: range
            )
        }

        logger.debug("✅ [HIGHLIGHT] Applied highlights successfully")
    }

    /// Find highlight at a specific range (for context menu)
    func findHighlight(at range: NSRange, in answerId: String) -> TextHighlight? {
        guard let answerHighlights = highlights[answerId] else {
            return nil
        }

        // Check if range overlaps with any highlight
        return answerHighlights.first { highlight in
            let highlightRange = NSRange(location: highlight.startOffset, length: highlight.length)
            return NSIntersectionRange(range, highlightRange).length > 0
        }
    }

}

// MARK: - Errors

enum HighlightError: LocalizedError {
    case invalidRange
    case highlightNotFound
    case persistenceFailure(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .invalidRange:
            return "Selected text range is invalid or out of bounds"
        case .highlightNotFound:
            return "Highlight not found"
        case .persistenceFailure(let error):
            return "Failed to save highlight: \(error.localizedDescription)"
        }
    }
}
