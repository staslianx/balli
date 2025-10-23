//
//  StoppingConditionEvaluator.swift
//  balli
//
//  Evaluates stopping conditions for multi-round research
//  Swift 6 strict concurrency compliant
//

import Foundation
import OSLog

/// Evaluates stopping conditions for multi-round research
final class StoppingConditionEvaluator: Sendable {
    private static let logger = AppLoggers.Research.search

    /// Evaluate if research should continue
    /// - Returns: Tuple of (shouldContinue, reason if stopping)
    static func shouldContinue(
        currentRound: Int,
        evidenceQuality: EvidenceQuality,
        elapsedTime: TimeInterval,
        reflection: ResearchReflection,
        previousReflection: ResearchReflection?,
        lastRoundSources: Int
    ) -> (shouldContinue: Bool, reason: StopReason?) {

        // Priority 1: Hard stops (safety)
        if elapsedTime >= 45 {
            logger.warning("Stopping: UX timeout at \(Int(elapsedTime))s")
            return (false, .timeout)
        }

        if currentRound >= 4 {
            logger.warning("Stopping: Max rounds reached")
            return (false, .roundLimit)
        }

        // Priority 2: Zero sources (abort)
        if currentRound == 1 && lastRoundSources == 0 {
            logger.critical("Stopping: Round 1 zero sources")
            return (false, .zeroSources)
        }

        // Priority 3: Quality gates
        if evidenceQuality == .high {
            logger.info("Stopping: High quality achieved")
            return (false, .qualityGate)
        }

        if reflection.suggestedNextQuery == nil || reflection.suggestedNextQuery?.isEmpty == true {
            logger.info("Stopping: No next query suggested")
            return (false, .noProgress)
        }

        // Priority 4: Soft stops (optional)
        if currentRound >= 3 && evidenceQuality == .moderate {
            logger.info("Stopping: Good enough after 3 rounds")
            return (false, .qualityGate)
        }

        // Priority 5: Diminishing returns
        if let prevReflection = previousReflection {
            if reflection.hasEnoughEvidence && prevReflection.hasEnoughEvidence {
                logger.info("Stopping: Consecutive 'enough evidence'")
                return (false, .diminishingReturns)
            }
        }

        // Continue research
        return (true, nil)
    }
}
