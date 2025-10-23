/**
 * Latents Planner - Planning Phase with Extended Thinking
 * Uses Gemini 2.0 Flash Thinking (Latents) for strategic research planning
 */
import { ResearchPlan } from '../flows/deep-research-v2-types';
/**
 * Use Latents (extended thinking) to analyze query and plan research strategy
 *
 * @param question - User's research query
 * @returns ResearchPlan with estimated rounds, strategy, and focus areas
 */
export declare function planResearchStrategy(question: string): Promise<ResearchPlan>;
//# sourceMappingURL=latents-planner.d.ts.map