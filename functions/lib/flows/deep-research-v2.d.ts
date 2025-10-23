/**
 * Deep Research V2 - Multi-Round Research with Latents Planning and Reflection
 *
 * COMPLETE FLOW:
 * 1. Planning Phase (Latents) → ResearchPlan
 * 2. Round 1: Initial Fetch → Sources
 * 3. Reflection Phase (Latents) → ResearchReflection
 * 4. Decision: Continue or Synthesize?
 * 5. Rounds 2-4: Refined Fetches (if needed)
 * 6. Final Synthesis
 *
 * iOS APP expects these SSE events (DO NOT CHANGE):
 * - planning_started, planning_complete
 * - round_started, round_complete
 * - api_started, api_completed, source_found
 * - reflection_started, reflection_complete
 * - synthesis_started, answer_complete
 */
import { Response } from 'express';
import { DeepResearchResults } from './deep-research-v2-types';
/**
 * Execute multi-round deep research with Latents planning and reflection
 *
 * @param question - User's research query
 * @param res - Express response object for SSE streaming
 * @returns DeepResearchResults with all rounds and sources
 */
export declare function executeDeepResearchV2(question: string, res: Response): Promise<DeepResearchResults>;
/**
 * Format research results for AI synthesis
 * Uses selected sources if available, otherwise uses all sources
 */
export declare function formatResearchForSynthesis(results: DeepResearchResults): string;
//# sourceMappingURL=deep-research-v2.d.ts.map