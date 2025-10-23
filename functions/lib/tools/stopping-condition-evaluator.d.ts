/**
 * Stopping Condition Evaluator
 * Determines if multi-round research should stop based on multiple criteria
 */
import { ResearchReflection, RoundResult } from '../flows/deep-research-v2-types';
/**
 * Stopping condition decision with reasoning
 */
export interface StoppingDecision {
    shouldStop: boolean;
    reason: string;
    triggeredConditions: string[];
}
/**
 * Evaluate whether to stop multi-round research
 *
 * STOPPING CONDITIONS (any one triggers stop):
 * 1. Evidence quality = "high" AND no gaps identified
 * 2. Max rounds reached
 * 3. No new sources found in last round (diminishing returns)
 * 4. Reflection explicitly says shouldContinue = false
 * 5. Total sources exceed threshold (comprehensive coverage)
 *
 * @param roundNumber - Current round number
 * @param maxRounds - Maximum allowed rounds
 * @param currentRound - Results from current round
 * @param allRounds - All round results so far
 * @param reflection - Reflection from current round
 * @returns StoppingDecision with should_stop and reasoning
 */
export declare function evaluateStoppingConditions(roundNumber: number, maxRounds: number, currentRound: RoundResult, allRounds: RoundResult[], reflection: ResearchReflection): StoppingDecision;
/**
 * Should we do reflection after this round?
 * Skip reflection on final round (no point evaluating if we can't continue)
 */
export declare function shouldDoReflection(roundNumber: number, maxRounds: number): boolean;
/**
 * Calculate confidence score for research completeness
 * 0.0 (no confidence) to 1.0 (very confident)
 */
export declare function calculateCompletenessScore(allRounds: RoundResult[], finalReflection: ResearchReflection): number;
//# sourceMappingURL=stopping-condition-evaluator.d.ts.map