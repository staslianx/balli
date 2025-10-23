/**
 * Query Refiner - Adaptive Query Refinement Between Rounds
 * Refines search queries based on gaps identified in reflection
 */
import { RefinedQuery } from '../flows/deep-research-v2-types';
/**
 * Refine query based on identified knowledge gaps
 * Uses fast Flash model for quick query generation
 *
 * @param originalQuery - Original user query
 * @param gaps - Knowledge gaps identified in reflection
 * @param roundNumber - Current round number (for logging)
 * @returns Refined query focused on filling gaps
 */
export declare function refineQueryForGaps(originalQuery: string, gaps: string[], roundNumber: number): Promise<RefinedQuery>;
/**
 * Generate diverse query variations for initial round
 * Helps avoid getting stuck in narrow search space
 */
export declare function generateQueryVariations(originalQuery: string, count?: number): Promise<string[]>;
//# sourceMappingURL=query-refiner.d.ts.map