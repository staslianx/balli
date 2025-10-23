/**
 * Latents Reflector - Reflection Phase with Extended Thinking
 * Uses Gemini 2.0 Flash Thinking (Latents) to evaluate evidence quality
 */
import { ResearchReflection, RoundResult } from '../flows/deep-research-v2-types';
/**
 * Use Latents to evaluate evidence quality and decide if more research is needed
 *
 * @param question - Original research query
 * @param roundNumber - Current round number
 * @param currentRound - Results from current round
 * @param allPreviousRounds - Results from all previous rounds
 * @param maxRounds - Maximum rounds allowed
 * @returns ResearchReflection with quality assessment and continuation decision
 */
export declare function reflectOnResearchQuality(question: string, roundNumber: number, currentRound: RoundResult, allPreviousRounds: RoundResult[], maxRounds: number): Promise<ResearchReflection>;
//# sourceMappingURL=latents-reflector.d.ts.map