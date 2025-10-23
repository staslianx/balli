/**
 * Stopping Condition Evaluator
 * Determines if multi-round research should stop based on multiple criteria
 */

import { ResearchReflection, RoundResult } from '../flows/deep-research-v2-types';
import { logger } from 'firebase-functions/v2';

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
export function evaluateStoppingConditions(
  roundNumber: number,
  maxRounds: number,
  currentRound: RoundResult,
  allRounds: RoundResult[],
  reflection: ResearchReflection
): StoppingDecision {
  const triggeredConditions: string[] = [];

  logger.info(
    `🛑 [STOPPING-EVAL] Evaluating conditions for Round ${roundNumber}/${maxRounds}: ` +
    `quality=${reflection.evidenceQuality}, shouldContinue=${reflection.shouldContinue}, ` +
    `sources=${currentRound.sourceCount}`
  );

  // CONDITION 1: Max rounds reached (hard limit)
  if (roundNumber >= maxRounds) {
    triggeredConditions.push(`Max rounds (${maxRounds}) reached`);
  }

  // CONDITION 2: High evidence quality with no gaps
  if (reflection.evidenceQuality === 'high' && reflection.gapsIdentified.length === 0) {
    triggeredConditions.push('High evidence quality with comprehensive coverage');
  }

  // CONDITION 3: No sources found this round (diminishing returns)
  if (currentRound.sourceCount === 0) {
    triggeredConditions.push('No new sources found (diminishing returns)');
  }

  // CONDITION 4: Reflection explicitly says stop
  if (!reflection.shouldContinue) {
    triggeredConditions.push(`Reflection recommends stopping: ${reflection.reasoning}`);
  }

  // CONDITION 5: Total sources exceed comprehensive threshold
  const totalSources = allRounds.reduce((sum, r) => sum + r.sourceCount, 0);
  const COMPREHENSIVE_THRESHOLD = 30; // Stop if we have 30+ sources

  if (totalSources >= COMPREHENSIVE_THRESHOLD) {
    triggeredConditions.push(`Comprehensive source coverage (${totalSources} sources)`);
  }

  // CONDITION 6: High quality with few gaps
  if (reflection.evidenceQuality === 'high' && reflection.gapsIdentified.length <= 1) {
    triggeredConditions.push('High quality evidence with minimal gaps');
  }

  // CONDITION 7: Diminishing returns (very few sources in last 2 rounds)
  if (allRounds.length >= 2) {
    const lastTwoRounds = allRounds.slice(-2);
    const sourcesInLastTwo = lastTwoRounds.reduce((sum, r) => sum + r.sourceCount, 0);

    if (sourcesInLastTwo < 3) {
      triggeredConditions.push('Diminishing returns (< 3 sources in last 2 rounds)');
    }
  }

  // Decision: Stop if ANY condition triggered
  const shouldStop = triggeredConditions.length > 0;

  const reason = shouldStop
    ? `Stopping research: ${triggeredConditions.join('; ')}`
    : `Continuing research: Evidence quality = ${reflection.evidenceQuality}, ` +
      `${reflection.gapsIdentified.length} gaps identified, ` +
      `${totalSources} sources collected`;

  const decision: StoppingDecision = {
    shouldStop,
    reason,
    triggeredConditions
  };

  if (shouldStop) {
    logger.info(
      `🛑 [STOPPING-EVAL] STOP triggered: ${triggeredConditions.join(', ')}`
    );
  } else {
    logger.info(
      `▶️ [STOPPING-EVAL] CONTINUE: ` +
      `quality=${reflection.evidenceQuality}, gaps=${reflection.gapsIdentified.length}, ` +
      `sources=${totalSources}`
    );
  }

  return decision;
}

/**
 * Should we do reflection after this round?
 * Skip reflection on final round (no point evaluating if we can't continue)
 */
export function shouldDoReflection(roundNumber: number, maxRounds: number): boolean {
  // Always do reflection except on final round
  return roundNumber < maxRounds;
}

/**
 * Calculate confidence score for research completeness
 * 0.0 (no confidence) to 1.0 (very confident)
 */
export function calculateCompletenessScore(
  allRounds: RoundResult[],
  finalReflection: ResearchReflection
): number {
  let score = 0.0;

  // Evidence quality contribution (0-40 points)
  if (finalReflection.evidenceQuality === 'high') {
    score += 40;
  } else if (finalReflection.evidenceQuality === 'medium') {
    score += 25;
  } else {
    score += 10;
  }

  // Source count contribution (0-30 points)
  const totalSources = allRounds.reduce((sum, r) => sum + r.sourceCount, 0);
  if (totalSources >= 25) {
    score += 30;
  } else if (totalSources >= 15) {
    score += 20;
  } else if (totalSources >= 8) {
    score += 10;
  } else {
    score += 5;
  }

  // Gap coverage contribution (0-30 points)
  if (finalReflection.gapsIdentified.length === 0) {
    score += 30;
  } else if (finalReflection.gapsIdentified.length <= 1) {
    score += 20;
  } else if (finalReflection.gapsIdentified.length <= 3) {
    score += 10;
  } else {
    score += 5;
  }

  // Convert to 0-1 range
  return Math.min(1.0, score / 100);
}
