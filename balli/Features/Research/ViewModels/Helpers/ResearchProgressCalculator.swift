//
//  ResearchProgressCalculator.swift
//  balli
//
//  Calculates progress percentage for research stages
//  Prevents backwards progress during multi-round research
//  Pure business logic - fully testable
//

import Foundation

/// Calculates and tracks research progress to prevent backwards movement
/// Maps Turkish research stage messages to progress percentages (0.0 - 1.0)
struct ResearchProgressCalculator {
    // MARK: - State

    /// Highest progress reached - prevents backwards movement
    private(set) var maxProgressReached: Double = 0.0

    // MARK: - Progress Calculation

    /// Get effective progress - never goes backwards during multi-round research
    /// Returns max of current stage progress and highest reached so far
    mutating func effectiveProgress(for stageMessage: String) -> Double {
        let rawProgress = calculateProgress(for: stageMessage)

        // Always return the max between current and what we've reached
        // This prevents backwards movement during multi-round research
        maxProgressReached = max(rawProgress, maxProgressReached)

        return maxProgressReached
    }

    /// Calculate raw progress for a given stage message
    /// Does not consider previous progress - use effectiveProgress for UI
    private func calculateProgress(for stageMessage: String) -> Double {
        switch stageMessage {
        case "Araştırma planını yapıyorum":        return 0.10  // Stage 1: Planning
        case "Araştırmaya başlıyorum":             return 0.20  // Stage 2: Starting research
        case "Kaynakları topluyorum":              return 0.35  // Stage 3: Collecting sources
        case "Kaynakları değerlendiriyorum":       return 0.50  // Stage 4: Evaluating sources
        case "Ek kaynaklar arıyorum":              return 0.60  // Stage 5: Searching additional
        case "Ek kaynakları inceliyorum":          return 0.70  // Stage 6: Examining additional
        case "En ilgili kaynakları seçiyorum":     return 0.80  // Stage 7: Selecting best
        case "Bilgileri bir araya getiriyorum":    return 0.90  // Stage 8: Gathering info
        case "Kapsamlı bir rapor yazıyorum":       return 0.95  // Stage 9: Writing report
        default:                                    return 0.50  // Unknown stage - show halfway
        }
    }

    // MARK: - Reset

    /// Reset progress to zero (useful for new research sessions)
    mutating func reset() {
        maxProgressReached = 0.0
    }
}
